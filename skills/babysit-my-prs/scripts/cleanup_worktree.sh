#!/usr/bin/env bash
# cleanup_worktree.sh <path> — remove a sweep-created worktree once its PR is
# done, but only when it is SAFE to do so. Prints a one-line status to stderr.
#
# Safety rules (any failed check declines the removal, exit 3, never an error):
#   1. Never the main working copy — only linked worktrees.
#   2. Never a path outside the skill's managed "<repo>-worktrees/" directory
#      (where ensure_worktree.sh creates them). If a PR's branch happened to be
#      checked out in the main repo or some other worktree, ensure_worktree.sh
#      returned THAT path unchanged — this guard keeps us from removing it.
#   3. Never one with uncommitted changes. `git worktree remove` (no --force)
#      already refuses a dirty worktree; we don't force, so nothing gets lost.
#
# Removing a worktree keeps its branch and any committed-but-unpushed work — only
# the working directory is deleted, so a later sweep just recreates it.
#
# Exit codes: 0 removed · 2 usage/not-a-repo · 3 safely declined (caller should
# report the worktree as kept).
#
# Requires: git.
set -uo pipefail

[[ $# -ge 1 && -n "${1:-}" ]] || { echo "usage: cleanup_worktree.sh <path>" >&2; exit 2; }
path="$1"

main="$(git worktree list --porcelain 2>/dev/null \
  | awk '/^worktree /{print substr($0, 10); exit}')"
[[ -n "$main" ]] || { echo "cleanup_worktree.sh: not inside a git repo" >&2; exit 2; }

abspath="$(cd "$path" 2>/dev/null && pwd)" || abspath="$path"

if [[ "$abspath" == "$main" ]]; then
  echo "cleanup_worktree.sh: refusing to remove the main working copy ($abspath)" >&2
  exit 3
fi

name="$(basename "$main")"
managed="$(dirname "$main")/${name}-worktrees/"
case "$abspath/" in
  "$managed"*) ;;
  *) echo "cleanup_worktree.sh: $abspath is outside $managed — not removing" >&2; exit 3 ;;
esac

if git -C "$main" worktree remove "$abspath" 2>/dev/null; then
  git -C "$main" worktree prune 2>/dev/null || true
  echo "cleanup_worktree.sh: removed $abspath" >&2
  exit 0
fi

echo "cleanup_worktree.sh: kept $abspath (dirty or busy — remove by hand with 'git worktree remove')" >&2
exit 3
