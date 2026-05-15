#!/usr/bin/env bash
# Post a reply to an inline PR review comment. The reply lands inside the
# same thread as the parent comment, which is what reviewers expect when
# we're answering them.
#
# GitHub's REST endpoint for this is:
#   POST /repos/{owner}/{repo}/pulls/{N}/comments/{comment_database_id}/replies
#
# It takes the *numeric* database id of the parent comment, not the GraphQL
# node id. `fetch_pr_comments.sh` exposes both as `database_id` and `node_id`
# respectively — pass `database_id` here.
#
# Usage:
#   post_reply.sh <pr-number-or-url> <parent-comment-database-id> <body>
#   post_reply.sh <pr-number-or-url> <parent-comment-database-id> -
#       (reads body from stdin when the third arg is `-`)
#
# Emits the new reply's URL on stdout.
#
# Requires: gh, jq.

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <pr-number-or-url> <parent-comment-database-id> <body|-strict>" >&2
  exit 1
fi

pr_ref="$1"
parent_id="$2"
body_arg="$3"

for tool in gh jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "post_reply.sh: missing required tool: $tool" >&2
    exit 1
  fi
done

if [[ "$body_arg" == "-" ]]; then
  body="$(cat)"
else
  body="$body_arg"
fi

if [[ -z "${body// }" ]]; then
  echo "post_reply.sh: refusing to post an empty reply" >&2
  exit 1
fi

pr_json="$(gh pr view "$pr_ref" --json number,url 2>/dev/null || true)"
if [[ -z "$pr_json" ]]; then
  echo "post_reply.sh: could not resolve PR '$pr_ref' via gh" >&2
  exit 1
fi

pr_number="$(jq -r '.number' <<<"$pr_json")"
pr_url="$(jq -r '.url' <<<"$pr_json")"
owner_repo="$(printf '%s' "$pr_url" | sed -E 's|https?://github.com/([^/]+)/([^/]+)/pull/.*|\1/\2|')"

# Use `-f body=@-` style via a heredoc-ish jq build to keep newlines intact.
payload="$(jq -n --arg body "$body" '{body: $body}')"

gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  --input - \
  "repos/${owner_repo}/pulls/${pr_number}/comments/${parent_id}/replies" \
  <<<"$payload" \
  | jq -r '.html_url'
