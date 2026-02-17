#!/usr/bin/env bash
# fetch-review-comments.sh
#
# Fetches open (unresolved) CodeRabbit inline review comments from a GitHub PR.
#
# Usage:
#   bash fetch-review-comments.sh [--pr <number>]
#
# Prerequisites:
#   - gh CLI installed and authenticated (run: gh auth status)
#   - jq installed (https://jqlang.github.io/jq/download/)
#
# Output:
#   JSON array to stdout:
#   [{"path":"src/foo.ts","line":42,"side":"RIGHT","body":"...","url":"https://...","id":123,"in_reply_to_id":null,"created_at":"...","updated_at":"..."}]
#
# Exit codes:
#   0 = success (even if zero comments found — outputs [])
#   1 = missing deps / no PR found / API error

set -euo pipefail

# ── Argument parsing ──────────────────────────────────────────────────────────
PR_NUMBER=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --pr)
      PR_NUMBER="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--pr <number>]" >&2
      exit 1
      ;;
  esac
done

# ── Dependency check ──────────────────────────────────────────────────────────
if ! command -v gh &>/dev/null; then
  echo "Error: gh CLI is not installed. Install it from https://cli.github.com/" >&2
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo "Error: gh CLI is not authenticated. Run: gh auth login" >&2
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "Error: jq is required but not installed. Install it from https://jqlang.github.io/jq/download/" >&2
  exit 1
fi

# ── PR detection ──────────────────────────────────────────────────────────────
if [[ -z "$PR_NUMBER" ]]; then
  echo "Auto-detecting PR number from current branch..." >&2
  if ! PR_NUMBER=$(gh pr view --json number -q .number 2>/dev/null); then
    echo "Error: No open PR found for the current branch." >&2
    echo "Either push your branch and open a PR, or pass --pr <number>." >&2
    exit 1
  fi
  if [[ -z "$PR_NUMBER" ]]; then
    echo "Error: Could not determine PR number for the current branch." >&2
    exit 1
  fi
fi
echo "Using PR #${PR_NUMBER}" >&2

# ── Repo detection ────────────────────────────────────────────────────────────
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
echo "Repository: ${REPO}" >&2

# ── Fetch all inline review comments (paginated) ──────────────────────────────
echo "Fetching inline review comments..." >&2
ALL_COMMENTS=$(gh api \
  --paginate \
  "repos/${REPO}/pulls/${PR_NUMBER}/comments" \
  --jq '[.[] | {
    id: .id,
    node_id: .node_id,
    in_reply_to_id: .in_reply_to_id,
    path: .path,
    line: (.line // .original_line),
    side: (.side // "RIGHT"),
    body: .body,
    url: .html_url,
    created_at: .created_at,
    updated_at: .updated_at,
    user_login: .user.login
  }]' | jq -s 'add // []')

# ── Filter to CodeRabbit comments only ───────────────────────────────────────
echo "Filtering to coderabbitai comments..." >&2
CR_COMMENTS=$(echo "$ALL_COMMENTS" | jq '[.[] | select(.user_login == "coderabbitai[bot]")]')
CR_COUNT=$(echo "$CR_COMMENTS" | jq 'length')
echo "Found ${CR_COUNT} coderabbitai comment(s) total." >&2

if [[ "$CR_COUNT" -eq 0 ]]; then
  echo "[]"
  exit 0
fi

# ── Query GraphQL for review thread resolution status ─────────────────────────
echo "Checking thread resolution status via GraphQL..." >&2

OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)

# Fetch all review threads for the PR (paginated via cursor)
RESOLVED_NODE_IDS="[]"
CURSOR="null"
PAGE=1

while true; do
  echo "  Fetching review threads page ${PAGE}..." >&2

  if [[ "$CURSOR" == "null" ]]; then
    THREAD_DATA=$(gh api graphql -f query='
      query($owner: String!, $repo: String!, $pr: Int!) {
        repository(owner: $owner, name: $repo) {
          pullRequest(number: $pr) {
            reviewThreads(first: 100) {
              pageInfo { hasNextPage endCursor }
              nodes {
                isResolved
                comments(first: 100) {
                  nodes { databaseId }
                }
              }
            }
          }
        }
      }' -f owner="$OWNER" -f repo="$REPO_NAME" -F pr="$PR_NUMBER")
  else
    THREAD_DATA=$(gh api graphql -f query='
      query($owner: String!, $repo: String!, $pr: Int!, $after: String) {
        repository(owner: $owner, name: $repo) {
          pullRequest(number: $pr) {
            reviewThreads(first: 100, after: $after) {
              pageInfo { hasNextPage endCursor }
              nodes {
                isResolved
                comments(first: 100) {
                  nodes { databaseId }
                }
              }
            }
          }
        }
      }' -f owner="$OWNER" -f repo="$REPO_NAME" -F pr="$PR_NUMBER" -f after="$CURSOR")
  fi

  # Collect database IDs of comments in resolved threads
  PAGE_RESOLVED=$(echo "$THREAD_DATA" | jq '[
    .data.repository.pullRequest.reviewThreads.nodes[]
    | select(.isResolved == true)
    | .comments.nodes[].databaseId
  ]')

  RESOLVED_NODE_IDS=$(echo "$RESOLVED_NODE_IDS $PAGE_RESOLVED" | jq -s 'add // []')

  HAS_NEXT=$(echo "$THREAD_DATA" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.hasNextPage')
  if [[ "$HAS_NEXT" != "true" ]]; then
    break
  fi
  CURSOR=$(echo "$THREAD_DATA" | jq -r '.data.repository.pullRequest.reviewThreads.pageInfo.endCursor')
  PAGE=$((PAGE + 1))
done

RESOLVED_COUNT=$(echo "$RESOLVED_NODE_IDS" | jq 'length')
echo "Found ${RESOLVED_COUNT} comment(s) in resolved threads." >&2

# ── Filter out comments in resolved threads ───────────────────────────────────
OPEN_COMMENTS=$(echo "$CR_COMMENTS $RESOLVED_NODE_IDS" | jq -s '
  .[0] as $comments |
  .[1] as $resolved_ids |
  [$comments[] | select(.id as $id | ($resolved_ids | index($id)) == null)]
')

# ── Strip internal field and output ──────────────────────────────────────────
FINAL=$(echo "$OPEN_COMMENTS" | jq '[.[] | del(.user_login, .node_id)]')

FINAL_COUNT=$(echo "$FINAL" | jq 'length')
echo "Outputting ${FINAL_COUNT} open coderabbitai comment(s)." >&2

echo "$FINAL"
