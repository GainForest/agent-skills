---
name: coderabbit-review-resolver
description: Fetch open CodeRabbit AI review comments from a GitHub PR, verify which comments are actual current issues, and summarize only confirmed issues.
compatibility: Requires gh CLI (authenticated), jq, git repository with GitHub remote
metadata:
  author: gainforest
  version: "1.2.0"
---

# CodeRabbit Review Resolver

This skill analyzes open CodeRabbit inline review comments, verifies each comment against the current code, and summarizes only comments that are actual current issues. It does not create tasks, dispatch workers, or modify code.

## When to Apply

Use this skill when:
- A PR has unresolved CodeRabbit review comments and you need to know which ones are real issues
- The user asks for CodeRabbit feedback to be verified before implementation
- You need to filter out false positives, already-fixed comments, or non-issues before summarizing the remaining issues

## Prerequisites

Before starting, verify:
- `gh` CLI is installed and authenticated (`gh auth status`)
- `jq` is installed (`jq --version`)
- Current directory is a git repo with a GitHub remote
- The current branch has an open PR (or user provides a PR number)

## Critical Rules

1. Never modify code directly - this skill only fetches and analyzes comments
2. Always run the fetch script first - do not infer comments from memory
3. Verify every open CodeRabbit thread root against the current code before summarizing anything
4. Do not report comments that are false positives, already fixed, or not actual issues
5. Do not classify comments by priority, likelihood, effort, impact, or recommendation
6. Provide only concise summaries of confirmed current issues

## Phase 1: Fetch Review Comments

**Step 1 - Detect PR context:**

```bash
# Auto-detect PR number from current branch
PR_NUMBER=$(gh pr view --json number -q .number)
```

If auto-detection fails (no open PR for the current branch), ask the user to provide a PR number explicitly.

**Step 2 - Run the fetch script:**

```bash
# Auto-detect PR from current branch
bash scripts/fetch-review-comments.sh

# Or with an explicit PR number
bash scripts/fetch-review-comments.sh --pr 123
```

See [scripts/fetch-review-comments.sh](scripts/fetch-review-comments.sh) for implementation details.

**Step 3 - Parse the output:**

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

**Step 4 - Handle edge cases:**

- **Zero comments:** Tell the user "No open CodeRabbit comments found" and stop.
- **Script error:** Check `gh auth status`, confirm the PR exists with `gh pr view`, then report the error message.

For details on underlying API calls, see [references/gh-api-patterns.md](references/gh-api-patterns.md).

## Phase 2: Verify Actual Issues

**Step 1 - Inspect the current code:**

For each thread-root comment, inspect the referenced file and surrounding code. Check whether the CodeRabbit claim still applies to the current code.

**Step 2 - Filter out non-issues:**

Exclude a comment from the final output if:
- the issue has already been fixed
- the comment is a false positive
- the comment is only a preference, style nit, question, or non-actionable suggestion
- the current code or surrounding context contradicts the claim

**Step 3 - Confirm actual issues:**

Only keep comments where the current code confirms there is an actual issue.

**Step 4 - Produce confirmed issue summaries:**

For each comment, provide this structure:

```text
Issue <N> - <path>:<line>
- CodeRabbit claim: <plain-language summary>
- Verification: <why this is an actual current issue>
- Issue summary: <concise explanation of the problem>
- Link: <url>
```

## Phase 3: Final Output

After verification, provide only:

- the total number of confirmed current issues
- the per-issue summaries using the template above

If no comments are confirmed as actual current issues, say: **"No confirmed current issues found."**

## Output Quality Bar

Your report is successful only if it:
- Covers all open thread-root CodeRabbit comments
- Verifies each comment against the current code
- Excludes false positives, already-fixed comments, and non-issues
- Includes only confirmed current issues in the final output
- Summarizes each confirmed issue clearly and concisely

## Expected File Structure

```text
skills/
  coderabbit-review-resolver/
    SKILL.md
    references/
      gh-api-patterns.md
    scripts/
      fetch-review-comments.sh
```

## Further Reading

- [gh-api-patterns.md](references/gh-api-patterns.md) - GitHub API patterns for fetching PR review comments
- [fetch-review-comments.sh](scripts/fetch-review-comments.sh) - Script to fetch open CodeRabbit inline review comments
