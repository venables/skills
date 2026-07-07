#!/usr/bin/env bash
# ensure_worktree.sh <branch> — print an absolute path to a worktree checked out
# to <branch>, reusing an existing worktree for that branch if one exists,
# otherwise creating a fresh one. Prints ONLY the path on stdout (progress goes
# to stderr) so callers can capture it directly.
#
# Reuse rule: if any registered worktree (including the main working copy) is
# already on <branch>, its path is returned unchanged — no new checkout. This is
# what lets the skill land work in an existing branch worktree instead of a
# duplicate.
#
# New worktrees are created under "<repo-parent>/<repo-name>-worktrees/<slug>"
# where <slug> is the branch with "/" replaced by "-".
#
# Run this SERIALLY (once per PR from the main repo) before fanning out parallel
# work — `git worktree add` takes a repo-wide lock and racing it can fail.
#
# Requires: git, run from inside the target repo.
set -euo pipefail

[[ $# -ge 1 && -n "${1:-}" ]] || { echo "usage: ensure_worktree.sh <branch>" >&2; exit 2; }
branch="$1"

root="$(git rev-parse --show-toplevel)"
git -C "$root" fetch origin --quiet 2>/dev/null || true

# Existing worktree already on this branch? Reuse it.
existing="$(git -C "$root" worktree list --porcelain \
  | awk -v b="refs/heads/$branch" '
      /^worktree /{ p=substr($0, 10) }
      /^branch /{ if (substr($0, 8) == b) { print p; exit } }')"
if [[ -n "$existing" ]]; then
  echo "ensure_worktree.sh: reusing existing worktree for $branch at $existing" >&2
  echo "$existing"
  exit 0
fi

slug="$(printf '%s' "$branch" | tr '/' '-')"
name="$(basename "$root")"
dest="$(dirname "$root")/${name}-worktrees/${slug}"
mkdir -p "$(dirname "$dest")"

if [[ -d "$dest" ]]; then
  echo "ensure_worktree.sh: reusing worktree directory at $dest" >&2
elif git -C "$root" show-ref --verify --quiet "refs/heads/$branch"; then
  git -C "$root" worktree add "$dest" "$branch" >&2
elif git -C "$root" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
  git -C "$root" worktree add --track -b "$branch" "$dest" "origin/$branch" >&2
else
  echo "ensure_worktree.sh: branch '$branch' not found locally or on origin" >&2
  exit 1
fi

echo "$dest"
