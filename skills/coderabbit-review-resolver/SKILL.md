---
name: coderabbit-review-resolver
description: Fetch open CodeRabbit AI review comments from a GitHub PR and produce a high-signal triage report, including likely false positives, effort vs impact, and recommended actions.
compatibility: Requires gh CLI (authenticated), jq, git repository with GitHub remote
metadata:
  author: gainforest
  version: "1.1.0"
---

# CodeRabbit Review Resolver

This skill analyzes open CodeRabbit inline review comments and produces a decision-ready triage report. It does not create tasks, dispatch workers, or modify code.

## When to Apply

Use this skill when:
- A PR has unresolved CodeRabbit review comments and you need to decide what to do
- The user asks for a quality pass on CodeRabbit feedback before implementation
- You need to separate high-value fixes from low-value or likely false-positive comments

## Prerequisites

Before starting, verify:
- `gh` CLI is installed and authenticated (`gh auth status`)
- `jq` is installed (`jq --version`)
- Current directory is a git repo with a GitHub remote
- The current branch has an open PR (or user provides a PR number)

## Critical Rules

1. Never modify code directly - this skill only fetches and analyzes comments
2. Always run the fetch script first - do not infer comments from memory
3. Analyze every open CodeRabbit thread root before making recommendations
4. Explicitly call out likely false positives and uncertain calls
5. Always include effort vs impact so users can choose what is worth doing
6. Prefer actionable, concrete recommendations over generic advice

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

## Phase 2: Triage and Recommendation

**Step 1 - Classify each comment:**

For each thread-root comment, assign:
- category and priority (see [references/comment-triage-guide.md](references/comment-triage-guide.md))
- confidence in the claim (`high`, `medium`, `low`)
- false-positive likelihood (`low`, `medium`, `high`)

**Step 2 - Evaluate effort vs impact:**

Use [references/recommendation-rubric.md](references/recommendation-rubric.md) to score:
- implementation effort (`S`, `M`, `L`, `XL`)
- expected impact (`high`, `medium`, `low`)
- risk if ignored (`high`, `medium`, `low`)

**Step 3 - Recommend an action per comment:**

Choose exactly one action:
- `do now` - high impact or high risk if ignored, with reasonable effort
- `do later` - valid but lower urgency or higher implementation cost
- `skip` - likely false positive, preference-only, or poor ROI

Each recommendation must include a one-line "why".

**Step 4 - Produce per-comment summaries:**

For each comment, provide this structure:

```text
Comment <N> - <path>:<line>
- Category/Priority: <category> / <P1|P2|P3>
- CodeRabbit claim: <plain-language summary>
- What likely needs changing: <specific fix direction>
- Effort: <S|M|L|XL>
- Impact: <high|medium|low>
- False-positive likelihood: <low|medium|high>
- Recommendation: <do now|do later|skip>
- Why: <1 sentence>
- Link: <url>
```

## Phase 3: Rollup for Decision-Making

After per-comment analysis, provide a concise rollup with four sections:

1. **Must do now**
   - Critical/high-leverage fixes that materially improve correctness, security, or reliability

2. **Good but not worth it right now**
   - Valid suggestions where complexity/cost is high relative to current benefit

3. **Likely false positives or low-value nits**
   - Comments to skip or defer unless the team has strict style goals

4. **Recommended execution order**
   - A practical sequence (top 3-5) that maximizes risk reduction first

When possible, include estimated total effort for the "Must do now" set.

## Output Quality Bar

Your report is successful only if it:
- Covers all open thread-root CodeRabbit comments
- Clearly separates high-confidence issues from uncertain ones
- Explains false-positive calls explicitly
- Makes tradeoffs visible (effort, impact, risk if ignored)
- Gives the user a clear, prioritized path forward

## Expected File Structure

```text
skills/
  coderabbit-review-resolver/
    SKILL.md
    references/
      gh-api-patterns.md
      comment-triage-guide.md
      recommendation-rubric.md
    scripts/
      fetch-review-comments.sh
```

## Further Reading

- [gh-api-patterns.md](references/gh-api-patterns.md) - GitHub API patterns for fetching PR review comments
- [comment-triage-guide.md](references/comment-triage-guide.md) - How to categorize and prioritize CodeRabbit comments
- [recommendation-rubric.md](references/recommendation-rubric.md) - How to decide do now/do later/skip based on effort, impact, risk, and confidence
- [fetch-review-comments.sh](scripts/fetch-review-comments.sh) - Script to fetch open CodeRabbit inline review comments
