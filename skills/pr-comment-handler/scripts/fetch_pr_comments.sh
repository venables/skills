#!/usr/bin/env bash
# Fetch every open review thread on a PR plus any review summary bodies,
# in a single GraphQL call, and emit them as a clean JSON document.
#
# Why GraphQL: the REST `pulls/N/comments` endpoint does not expose
# `isResolved` per-thread, and reconstructing reply chains from a flat
# comment list is fiddly. GraphQL gives us threads with their resolution
# state and reply chains directly.
#
# Output shape (stdout, single JSON object):
#   {
#     "pr": { "url": "...", "head_sha": "...", "number": N, "title": "..." },
#     "threads": [
#       {
#         "thread_id": "PRRT_...",
#         "is_resolved": false,
#         "is_outdated": false,
#         "path": "src/foo.ts",
#         "line": 42,
#         "start_line": null,
#         "side": "RIGHT",
#         "comments": [
#           {
#             "node_id": "PRRC_...",
#             "database_id": 1234567890,
#             "author": "reviewer",
#             "is_bot": false,
#             "body": "...",
#             "created_at": "...",
#             "url": "..."
#           }
#         ]
#       }
#     ],
#     "reviews_with_body": [
#       {
#         "node_id": "PRR_...",
#         "database_id": 9876543210,
#         "author": "reviewer",
#         "state": "COMMENTED",
#         "body": "...",
#         "submitted_at": "...",
#         "url": "..."
#       }
#     ]
#   }
#
# Notes
#   - `database_id` is what the REST replies endpoint wants:
#     POST /repos/{owner}/{repo}/pulls/{N}/comments/{database_id}/replies
#   - `is_bot` is heuristic: author login ends in `[bot]` or matches the
#     known set (dependabot, coderabbitai, copilot-pull-request-reviewer,
#     github-actions). Override in the skill if a "bot" comment is actually
#     actionable.
#   - Reviews with empty bodies (the usual pass-through "approved" reviews)
#     are dropped from `reviews_with_body`. Approvals carry no actionable
#     text.
#
# Usage:
#   fetch_pr_comments.sh <pr-number-or-url> [--include-resolved] [--include-outdated]
#
# Defaults: skip resolved and outdated threads. The flags include them.
#
# Requires: gh, jq.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <pr-number-or-url> [--include-resolved] [--include-outdated]" >&2
  exit 1
fi

pr_ref="$1"
shift

include_resolved=false
include_outdated=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --include-resolved) include_resolved=true ;;
    --include-outdated) include_outdated=true ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
  shift
done

for tool in gh jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "fetch_pr_comments.sh: missing required tool: $tool" >&2
    exit 1
  fi
done

# Resolve owner/repo/number. `gh pr view` accepts a number (uses the current
# repo) or a URL, and prints the canonical fields.
pr_json="$(gh pr view "$pr_ref" --json number,url,title,headRefOid 2>/dev/null || true)"
if [[ -z "$pr_json" ]]; then
  echo "fetch_pr_comments.sh: could not resolve PR '$pr_ref' via gh" >&2
  exit 1
fi

pr_number="$(jq -r '.number' <<<"$pr_json")"
pr_url="$(jq -r '.url' <<<"$pr_json")"
pr_title="$(jq -r '.title' <<<"$pr_json")"
pr_head_sha="$(jq -r '.headRefOid' <<<"$pr_json")"

# Owner/repo come from the URL — handles forks correctly (the base repo owns
# the PR number, not the head repo).
owner_repo="$(printf '%s' "$pr_url" | sed -E 's|https?://github.com/([^/]+)/([^/]+)/pull/.*|\1/\2|')"
owner="${owner_repo%/*}"
repo="${owner_repo#*/}"

read -r -d '' query <<'GRAPHQL' || true
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          isOutdated
          path
          line
          startLine
          diffSide
          comments(first: 50) {
            nodes {
              id
              databaseId
              author { login }
              body
              createdAt
              url
            }
          }
        }
      }
      reviews(first: 100) {
        nodes {
          id
          databaseId
          state
          author { login }
          body
          submittedAt
          url
        }
      }
    }
  }
}
GRAPHQL

raw="$(gh api graphql \
  -f query="$query" \
  -F owner="$owner" \
  -F repo="$repo" \
  -F pr="$pr_number")"

# Shape into the documented output. Filtering of resolved/outdated is done
# here so consumers don't have to repeat the predicate.
jq \
  --argjson include_resolved "$include_resolved" \
  --argjson include_outdated "$include_outdated" \
  --arg pr_url "$pr_url" \
  --arg pr_title "$pr_title" \
  --arg pr_head_sha "$pr_head_sha" \
  --argjson pr_number "$pr_number" '
  def is_bot(login):
    (login | endswith("[bot]"))
    or (login | ascii_downcase | IN(
      "dependabot", "coderabbitai", "copilot-pull-request-reviewer",
      "github-actions", "renovate", "snyk-bot"
    ));

  {
    pr: {
      url: $pr_url,
      number: $pr_number,
      title: $pr_title,
      head_sha: $pr_head_sha
    },
    threads: (
      .data.repository.pullRequest.reviewThreads.nodes
      | map(select(
          ($include_resolved or (.isResolved | not))
          and ($include_outdated or (.isOutdated | not))
        ))
      | map({
          thread_id: .id,
          is_resolved: .isResolved,
          is_outdated: .isOutdated,
          path: .path,
          line: .line,
          start_line: .startLine,
          side: .diffSide,
          comments: (
            .comments.nodes
            | map({
                node_id: .id,
                database_id: .databaseId,
                author: (.author.login // "ghost"),
                is_bot: is_bot(.author.login // "ghost"),
                body: .body,
                created_at: .createdAt,
                url: .url
              })
          )
        })
    ),
    reviews_with_body: (
      .data.repository.pullRequest.reviews.nodes
      | map(select((.body // "") | length > 0))
      | map({
          node_id: .id,
          database_id: .databaseId,
          author: (.author.login // "ghost"),
          state: .state,
          body: .body,
          submitted_at: .submittedAt,
          url: .url
        })
    )
  }
' <<<"$raw"
