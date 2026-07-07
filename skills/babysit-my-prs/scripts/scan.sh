#!/usr/bin/env bash
# scan.sh — read-only discovery for the babysit-my-prs skill.
#
# Lists YOUR open PRs in a repo (author == the authenticated gh user) and, for
# each, reports whether it has merge conflicts and/or unhandled review comments,
# so the skill can skip the clean ones and fan out work only on the rest. It is
# strictly read-only: it never commits, pushes, merges, resolves, or touches a
# worktree.
#
# Output (stdout, one JSON object):
#   {
#     "repo": "owner/name",
#     "me": "login",
#     "actionable": [                 // PRs with conflicts, review comments, OR failing CI
#       { "number", "title", "branch", "url",
#         "mergeable", "mergeState",
#         "hasConflicts": bool,
#         "reviewComments": int,      // unhandled review threads + review bodies
#         "failingChecks": int,       // required checks in a failing state
#         "reason": "conflicts" | "comments" | "ci" | "multiple" }
#     ],
#     "skipped": [                    // PRs with none of the above — left untouched
#       { "number", "branch", "url", "reason": "clean" }
#     ]
#   }
#
# "reviewComments" counts unresolved, not-outdated review threads that carry a
# comment from someone other than you, plus non-dismissed review-summary bodies
# from someone other than you. Bot threads are counted (pr-comment-handler still
# triages them); the exact Fix/decline call is that skill's job, this is only a
# has-anything-to-do gate.
#
# Usage:
#   scan.sh [--repo owner/name]
#
# Requires: gh (authenticated), jq.
set -uo pipefail

REPO=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) [[ $# -ge 2 && -n "${2:-}" ]] || { echo "scan.sh: --repo requires owner/name" >&2; exit 2; }; REPO="$2"; shift 2 ;;
    -h|--help) sed -n '2,29p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "scan.sh: unknown arg: $1" >&2; exit 2 ;;
  esac
done

for bin in gh jq; do
  command -v "$bin" >/dev/null 2>&1 || { echo "scan.sh: need '$bin' on PATH" >&2; exit 1; }
done

if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)" || true
fi
[[ -z "$REPO" ]] && { echo "scan.sh: could not resolve repo slug (pass --repo owner/name)" >&2; exit 1; }
OWNER="${REPO%%/*}"
NAME="${REPO##*/}"

me="$(gh api user -q .login 2>/dev/null)" || { echo "scan.sh: could not resolve gh user (is gh authenticated?)" >&2; exit 1; }

# Your open PRs in this repo. --author @me resolves to the authenticated user.
prs="$(gh pr list --repo "$REPO" --author @me --state open --limit 100 \
  --json number,title,headRefName,url 2>/dev/null)" || { echo "scan.sh: 'gh pr list' failed" >&2; exit 1; }

read -r -d '' thread_query <<'GRAPHQL' || true
query($owner: String!, $repo: String!, $pr: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $pr) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          isOutdated
          comments(first: 50) { nodes { author { login } } }
        }
      }
      reviews(first: 100) {
        nodes { body state author { login } }
      }
    }
  }
}
GRAPHQL

objs=()
while read -r num; do
  [[ -z "$num" ]] && continue
  base="$(printf '%s' "$prs" | jq --argjson n "$num" '.[] | select(.number == $n)')"

  meta="$(gh pr view "$num" --repo "$REPO" --json mergeable,mergeStateStatus 2>/dev/null)" || meta='{}'
  mergeable="$(printf '%s' "$meta" | jq -r '.mergeable // "UNKNOWN"')"
  mergestate="$(printf '%s' "$meta" | jq -r '.mergeStateStatus // "UNKNOWN"')"

  g="$(gh api graphql -f query="$thread_query" -F owner="$OWNER" -F repo="$NAME" -F pr="$num" 2>/dev/null)" || g='{}'
  rc="$(printf '%s' "$g" | jq --arg me "$me" '
    (.data.repository.pullRequest // {}) as $p
    | ([ ($p.reviewThreads.nodes // [])[]
         | select((.isResolved | not) and (.isOutdated | not))
         | select([ (.comments.nodes // [])[] | (.author.login // "") ] | any(. != $me)) ] | length)
    + ([ ($p.reviews.nodes // [])[]
         | select(((.body // "") | gsub("\\s"; "") | length) > 0
                  and (.state != "DISMISSED")
                  and ((.author.login // "") != $me)) ] | length)
  ' 2>/dev/null)"
  [[ -z "$rc" ]] && rc=0

  # Failing required checks. `gh pr checks --json` emits an array with a `bucket`
  # per check ("pass" | "fail" | "pending" | "skipping" | "cancel"); it errors
  # when a PR has no checks at all, so fall back to an empty array. Exit code is
  # ignored on purpose (non-zero on failing/pending). Only "fail" counts — a
  # pending check isn't actionable and a cancel is usually a flake fix-ci reruns.
  checks="$(gh pr checks "$num" --repo "$REPO" --json bucket 2>/dev/null)" || checks='[]'
  fc="$(printf '%s' "$checks" | jq '[ .[] | select(.bucket == "fail") ] | length' 2>/dev/null)"
  [[ -z "$fc" ]] && fc=0

  hasconf=false
  [[ "$mergeable" == "CONFLICTING" || "$mergestate" == "DIRTY" ]] && hasconf=true

  objs+=("$(jq -n \
    --argjson base "$base" \
    --arg mergeable "$mergeable" \
    --arg mergeState "$mergestate" \
    --argjson hasConflicts "$hasconf" \
    --argjson reviewComments "$rc" \
    --argjson failingChecks "$fc" '
    $base + {
      mergeable: $mergeable,
      mergeState: $mergeState,
      hasConflicts: $hasConflicts,
      reviewComments: $reviewComments,
      failingChecks: $failingChecks
    }')")
done < <(printf '%s' "$prs" | jq -r '.[].number')

if [[ ${#objs[@]} -eq 0 ]]; then
  all="[]"
else
  all="$(printf '%s\n' "${objs[@]}" | jq -s '.')"
fi

printf '%s' "$all" | jq --arg repo "$REPO" --arg me "$me" '
  {
    repo: $repo,
    me: $me,
    actionable: [ .[]
      | select(.hasConflicts or (.reviewComments > 0) or (.failingChecks > 0))
      | . + { reason: (
          [ (if .hasConflicts then "conflicts" else empty end),
            (if .reviewComments > 0 then "comments" else empty end),
            (if .failingChecks > 0 then "ci" else empty end) ] as $r
          | if ($r | length) > 1 then "multiple" else $r[0] end) }
      | { number, title, branch: .headRefName, url, mergeable, mergeState,
          hasConflicts, reviewComments, failingChecks, reason } ],
    skipped: [ .[]
      | select((.hasConflicts | not) and (.reviewComments == 0) and (.failingChecks == 0))
      | { number, branch: .headRefName, url, reason: "clean" } ]
  }'
