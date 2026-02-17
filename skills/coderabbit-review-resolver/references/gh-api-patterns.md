# GitHub API Patterns for PR Review Comments

Reference for fetching and filtering CodeRabbit inline review comments via `gh` CLI.

## 1. REST API: Pull Request Review Comments

**Endpoint:** `GET /repos/{owner}/{repo}/pulls/{pr}/comments`

### Basic fetch with pagination

```bash
gh api \
  --paginate \
  "repos/{owner}/{repo}/pulls/{pr_number}/comments"
```

### Filter for CodeRabbit comments only

```bash
gh api \
  --paginate \
  --jq '[.[] | select(.user.login == "coderabbitai[bot]")]' \
  "repos/myorg/myrepo/pulls/42/comments"
```

### Key response fields

| Field | Type | Description |
|---|---|---|
| `id` | integer | REST comment ID (use for cross-referencing GraphQL) |
| `in_reply_to_id` | integer\|null | `null` = thread root; non-null = reply |
| `path` | string | File path the comment is on |
| `line` | integer\|null | Current line in the diff (null if outdated) |
| `original_line` | integer | Line at time of comment (may differ from `line`) |
| `side` | string | `"RIGHT"` (new file) or `"LEFT"` (old file) |
| `body` | string | Comment text (Markdown) |
| `html_url` | string | Direct link to the comment on GitHub |
| `created_at` | string | ISO 8601 timestamp |
| `updated_at` | string | ISO 8601 timestamp |
| `user.login` | string | `"coderabbitai[bot]"` for CodeRabbit |

### Example output snippet

```json
[
  {
    "id": 1234567890,
    "in_reply_to_id": null,
    "path": "src/auth/handler.ts",
    "line": 42,
    "side": "RIGHT",
    "body": "Consider adding error handling here.",
    "html_url": "https://github.com/org/repo/pull/42#discussion_r1234567890",
    "user": { "login": "coderabbitai[bot]" }
  }
]
```

## 2. GraphQL API: Review Thread Resolution Status

### Query for thread resolution

```graphql
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          comments(first: 100) {
            nodes {
              id
              databaseId
            }
          }
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  }
}
```

> **Note:** Use `comments(first: 100)` rather than `comments(first: 1)` because a review thread can contain multiple comments. All comment `databaseId`s in a resolved thread must be collected to correctly filter them out from the REST results.

### Run via gh CLI

```bash
gh api graphql \
  -f query='query($owner:String!,$repo:String!,$pr:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$pr){reviewThreads(first:100){nodes{isResolved comments(first:100){nodes{id databaseId}}}pageInfo{hasNextPage endCursor}}}}}' \
  -f owner="myorg" \
  -f repo="myrepo" \
  -F pr=42
```

### Cross-referencing REST IDs with GraphQL threads

The REST `id` field maps to the GraphQL `databaseId` field on a comment node.

```bash
# Get unresolved thread root comment IDs
gh api graphql \
  -f query='...' \
  --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false) | .comments.nodes[0].databaseId]'
```

### Pagination for repos with >100 review threads

```bash
# Fetch next page using endCursor
gh api graphql \
  -f query='query($owner:String!,$repo:String!,$pr:Int!,$after:String){repository(owner:$owner,name:$repo){pullRequest(number:$pr){reviewThreads(first:100,after:$after){nodes{isResolved comments(first:100){nodes{databaseId}}}pageInfo{hasNextPage endCursor}}}}}' \
  -f owner="myorg" -f repo="myrepo" -F pr=42 -f after="<endCursor>"
```

## 3. Auto-detecting PR Context

### Detect PR number from current branch

```bash
PR_NUMBER=$(gh pr view --json number -q .number)
```

### Detect owner/repo

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
# Output: "myorg/myrepo"
OWNER=$(echo "$REPO" | cut -d/ -f1)
REPO_NAME=$(echo "$REPO" | cut -d/ -f2)
```

### Edge cases

- **Detached HEAD:** `gh pr view` fails — prompt user for PR number explicitly.
- **Multiple PRs for same branch:** `gh pr view` returns the most recently updated one; confirm with user if ambiguous.
- **Draft PRs:** Returned normally by the API; no special handling needed.

## 4. Common Pitfalls

| Pitfall | Detail |
|---|---|
| **3 different comment APIs** | Review comments (`/pulls/{pr}/comments`) ≠ issue comments (`/issues/{pr}/comments`) ≠ PR-level review bodies. Only review comments have `path`/`line`. |
| **`line` vs `original_line`** | `line` is null when the diff is outdated (file changed after comment). Use `original_line` as fallback for display, but warn the user the position may be stale. |
| **Rate limiting with `--paginate`** | Large PRs can hit secondary rate limits. Add `--header 'X-GitHub-Api-Version: 2022-11-28'` and consider adding `sleep 1` between pages in scripts. |
| **Comments on deleted files** | `path` still present, but `line` is null. The file no longer exists in HEAD — skip or flag these comments. |
