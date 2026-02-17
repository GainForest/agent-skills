---
name: coderabbit-review-resolver
description: Fetch open CodeRabbit AI review comments from a GitHub PR, plan fixes as beads tasks, and dispatch workers to resolve them. Use when a PR has unresolved CodeRabbit reviews that need addressing.
compatibility: Requires gh CLI (authenticated), hb CLI (beads), git repository with GitHub remote
metadata:
  author: gainforest
  version: "1.0.0"
---

# CodeRabbit Review Resolver

This skill resolves open CodeRabbit inline review comments by planning and dispatching worker agents to implement the required fixes.

## When to Apply

Use this skill when:
- A PR has unresolved CodeRabbit review comments that need fixing
- The user asks to address/fix/resolve CodeRabbit feedback
- After a CodeRabbit review is posted and the user wants to act on it

## Prerequisites

Before starting, verify:
- `gh` CLI is installed and authenticated (`gh auth status`)
- `hb` CLI is installed (`hb version`)
- Current directory is a git repo with a GitHub remote
- The current branch has an open PR (or user provides a PR number)

## Critical Rules

1. Never modify code directly — this skill plans and dispatches, it does not implement fixes
2. Always run the fetch script first — don't assume you know what CodeRabbit said
3. Present the triage plan to the user before creating beads tasks — get approval first
4. One beads epic per PR — don't create multiple epics for the same PR's review
5. Workers must not change code outside the scope of the CodeRabbit comment they're fixing
6. After all workers complete, review the aggregate diff for seam issues before marking the epic done

## Phase 1: Fetch Review Comments

**Step 1 — Detect PR context:**

```bash
# Auto-detect PR number from current branch
PR_NUMBER=$(gh pr view --json number -q .number)
```

If auto-detection fails (no open PR for the current branch), ask the user to provide a PR number explicitly.

**Step 2 — Run the fetch script:**

```bash
# Auto-detect PR from current branch
bash scripts/fetch-review-comments.sh

# Or with an explicit PR number
bash scripts/fetch-review-comments.sh --pr 123
```

See [scripts/fetch-review-comments.sh](scripts/fetch-review-comments.sh) for implementation details.

**Step 3 — Parse the output:**

The script outputs a JSON array to stdout. Each element has:

| Field | Description |
|---|---|
| `path` | File path the comment is on |
| `line` | Line number in the file |
| `side` | `RIGHT` (new) or `LEFT` (old) side of the diff |
| `body` | The comment text from CodeRabbit |
| `url` | Direct link to the comment on GitHub |
| `id` | Numeric comment ID |
| `in_reply_to_id` | `null` for thread roots; non-null for replies |
| `created_at` | ISO 8601 timestamp |
| `updated_at` | ISO 8601 timestamp |

Thread root comments have `in_reply_to_id: null`; replies have a non-null value. After parsing, report to the user: **"Found X open CodeRabbit comments across Y files."**

**Step 4 — Handle edge cases:**

- **Zero comments:** Tell the user "No open CodeRabbit comments found" and stop — there is nothing to resolve.
- **Script error:** Check `gh auth status` to verify authentication, confirm the PR exists with `gh pr view`, then report the error message to the user.

For details on the underlying API calls, see [references/gh-api-patterns.md](references/gh-api-patterns.md).

## Phase 2: Plan and Triage

**Step 1 — Categorize each comment:**

Read each comment body and assign a category and priority:

| Category | Priority |
|---|---|
| `bug`, `security` | P1 |
| `error-handling`, `type-safety` | P2 |
| `performance`, `style`, `nit` | P3 |

See [references/comment-triage-guide.md](references/comment-triage-guide.md) for detailed criteria, example patterns, and when to skip a comment.

**Step 2 — Group comments into tasks:**

- **By file**: 3+ comments in the same file at the same priority → one task
- **By theme**: Comments across files sharing the same category → one task
- **Never group across priority levels** — a P1 bug and a P3 nit in the same file become two tasks
- **Max 5–7 comments per task** — split larger groups further

**Step 3 — Present the plan to the user:**

Output a summary table before creating any beads:

```
| # | Task Title                          | Files                        | Comments | Priority | Est. |
|---|-------------------------------------|------------------------------|----------|----------|------|
| 1 | Fix null check in auth.ts           | auth.ts:42,58                | 2        | P1       | 15m  |
| 2 | Add error handling across API routes | api/foo.ts:10, api/bar.ts:22 | 2        | P2       | 30m  |
| 3 | Style fixes in utils                | utils.ts:5,12,18             | 3        | P3       | 15m  |
```

**Wait for user approval before proceeding to Phase 3.**

If the user rejects or wants to revise the plan, adjust the grouping, priorities, or skipped comments based on their feedback and present the updated table. Repeat until approved.

**Step 4 — Handle skipped comments:**

List any comments you are intentionally skipping (questions, false positives, preference disagreements) in a separate section below the table. Ask the user to confirm each skip before continuing.

**Step 5 — Create the beads epic:**

After the user approves the plan:

```bash
hb create "Epic: Resolve CodeRabbit review for PR #<N>" -t epic -p 1 \
  -d "Resolve all open CodeRabbit inline review comments on PR #<N>. <count> comments across <files> files." \
  -l scope:small \
  --json
```

Save the returned epic ID — you will use it as the `--parent` for every task in Phase 3.

## Phase 3: Dispatch Workers

**Step 1 — Create beads tasks.**
For each row in the approved plan table from Phase 2, create a task using the template from [references/worker-dispatch-patterns.md](references/worker-dispatch-patterns.md):

```bash
hb create "<task title>" -t task -p <priority> --parent <epic-id> \
  -d "<description per worker-dispatch-patterns.md template>" \
  --acceptance "<binary pass/fail criteria>" \
  -e <minutes> \
  -l scope:small \
  --json
```

**Step 2 — Add dependencies (only when needed).**
Most CodeRabbit fixes are independent — default to no dependencies. Add one only when:
- Two tasks modify the same function in conflicting ways
- A refactor task must land before a feature task that builds on it

```bash
hb dep add <blocked-task> <blocker-task>
```

**Step 3 — Commit the plan.**

```bash
hb sync && git add .beads/ && git commit -m "beads: plan CodeRabbit fixes for PR #<N>" && git push
```

**Step 4 — Dispatch workers.**
Tell the user which task IDs are ready. Tasks with no dependencies can be dispatched in parallel:

```
Ready for dispatch:
- agent-skills-XXXX.1: Fix null check in auth.ts (P1, 15m)
- agent-skills-XXXX.2: Add error handling across API routes (P2, 30m)
- agent-skills-XXXX.3: Style fixes in utils (P3, 15m)

Dispatch with: @worker agent-skills-XXXX.1
```

**Step 5 — Post-dispatch: Integration check.**
After all workers complete:
1. Review the aggregate diff: `git diff <base-branch>...HEAD`
2. Check for seam issues: conflicting imports, duplicate declarations, broken references
3. If issues found, create follow-up tasks using the same template
4. If clean, mark the epic for integration review:

```bash
hb update <epic-id> --add-label needs-integration-review
hb sync && git add .beads/ && git commit -m "beads: mark <epic-id> for review" && git push
```

## Expected File Structure

```text
skills/
  coderabbit-review-resolver/
    SKILL.md
    references/
      gh-api-patterns.md
      comment-triage-guide.md
      worker-dispatch-patterns.md
    scripts/
      fetch-review-comments.sh
```

## Further Reading

- [gh-api-patterns.md](references/gh-api-patterns.md) — GitHub API patterns for fetching PR review comments
- [comment-triage-guide.md](references/comment-triage-guide.md) — How to categorize and prioritize CodeRabbit comments
- [worker-dispatch-patterns.md](references/worker-dispatch-patterns.md) — Task description templates and dispatch patterns for workers
- [fetch-review-comments.sh](scripts/fetch-review-comments.sh) — Shell script to fetch open CodeRabbit inline review comments
