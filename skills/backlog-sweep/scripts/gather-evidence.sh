#!/usr/bin/env bash
# Gather git + GitHub evidence for a Linear backlog sweep.
#
# Usage: gather-evidence.sh <TEAM_KEY> <OUTDIR>
#   TEAM_KEY  Linear ticket prefix, e.g. ENG
#   OUTDIR    directory for outputs (created if missing)
#
# Outputs (all in OUTDIR):
#   shipped-in-commits.txt  ticket IDs in merged commit subjects
#   merged-prs.tsv          number, date, branch, title, body snippet
#   open-prs.tsv            number, branch, title
#   shipped-in-prs.txt      ticket IDs in merged PR titles/bodies/branches
#   shipped-ids.txt         union of the two shipped sources
#   open-pr-ids.txt         ticket IDs referenced by open PRs
set -euo pipefail

TEAM_KEY="${1:?usage: gather-evidence.sh <TEAM_KEY> <OUTDIR>}"
OUTDIR="${2:?usage: gather-evidence.sh <TEAM_KEY> <OUTDIR>}"
mkdir -p "$OUTDIR"

ID_PATTERN="${TEAM_KEY}-[0-9]+"

# A stale local checkout has produced wrong "still broken" verdicts before;
# all evidence must come from origin/main.
git fetch origin main --quiet

git log origin/main --oneline \
  | { grep -oiE "$ID_PATTERN" || true; } \
  | tr '[:lower:]' '[:upper:]' | sort -u \
  > "$OUTDIR/shipped-in-commits.txt"

gh pr list --state merged --limit 300 \
  --json number,mergedAt,headRefName,title,body \
  --jq '.[] | "\(.number)\t\(.mergedAt[:10])\t\(.headRefName)\t\(.title)\t\(((.body // "") | gsub("[\n\t]"; " "))[:300])"' \
  > "$OUTDIR/merged-prs.tsv"

gh pr list --state open --limit 100 \
  --json number,headRefName,title \
  --jq '.[] | "\(.number)\t\(.headRefName)\t\(.title)"' \
  > "$OUTDIR/open-prs.tsv"

{ grep -oiE "$ID_PATTERN" "$OUTDIR/merged-prs.tsv" || true; } \
  | tr '[:lower:]' '[:upper:]' | sort -u \
  > "$OUTDIR/shipped-in-prs.txt"

sort -u "$OUTDIR/shipped-in-commits.txt" "$OUTDIR/shipped-in-prs.txt" \
  > "$OUTDIR/shipped-ids.txt"

{ grep -oiE "$ID_PATTERN" "$OUTDIR/open-prs.tsv" || true; } \
  | tr '[:lower:]' '[:upper:]' | sort -u \
  > "$OUTDIR/open-pr-ids.txt"

echo "shipped IDs: $(wc -l < "$OUTDIR/shipped-ids.txt" | tr -d ' ')"
echo "open PR IDs: $(wc -l < "$OUTDIR/open-pr-ids.txt" | tr -d ' ')"
echo "merged PRs:  $(wc -l < "$OUTDIR/merged-prs.tsv" | tr -d ' ')"
echo "open PRs:    $(wc -l < "$OUTDIR/open-prs.tsv" | tr -d ' ')"
