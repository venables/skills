# babysit-my-prs

Sweep every open PR **you authored** in a repo and, for each one that actually
needs it, resolve merge conflicts, handle the review comments, and fix failing
CI — each on its own git worktree, all in parallel. A PR with no conflicts, no
review comments, and no failing checks is skipped untouched.

This is the outer layer: it discovers your authored PRs, filters to the ones
that need work, sets up a worktree per branch, and fans the per-PR work out to
the [`babysit-pr`](../babysit-pr) skill (which in turn hands comments to
[`pr-comment-handler`](../pr-comment-handler) and CI to `fix-ci`). Every PR gets
the same resolve-conflicts, fix / defer-to-Linear / reply-and-resolve, get-CI-green
treatment.

## Install

```
npx skills add venables/skills --skill babysit-my-prs
```

## How to use it

From inside the repo, just ask Claude Code in plain English:

- "babysit my PRs"
- "sweep all my open PRs — fix conflicts and handle the comments"
- "go through every PR I've got open and keep them mergeable"

It auto-detects the repo from the current directory; pass a different one with
`--repo owner/name` to the scanner.

## What it does

1. **Scans, read-only.** `scripts/scan.sh` lists your open PRs (`--author @me`)
   and, per PR, reports whether it has merge conflicts, how many unhandled review
   comments it carries, and how many required checks are failing.
2. **Skips the clean ones.** Any PR with no conflicts, no review comments, and no
   failing checks is reported as skipped and never touched.
3. **One worktree per PR.** The [`git-worktree`](../git-worktree) skill (`wt
create`) makes a dedicated worktree for each actionable branch, or reuses the
   branch's existing worktree if one is already checked out. Each lands at
   `<repo-parent>/<repo-name>-<branch-slug>`, flat alongside the repo. Worktrees
   are resolved serially (git locks the repo during `worktree add`) before any
   parallel work starts.
4. **Works each PR in parallel.** Inside Herdr, it renames the workspace to
   `<repo> (babysitting)` and opens one pane per PR, 4 per tab in a 2x2 grid (a
   new tab for each next 4). Each pane is a Claude agent running
   `/babysit-pr <N>` in the PR's worktree. Outside Herdr, it uses one subagent
   per PR instead. Either way, each PR runs the `babysit-pr` skill: resolve conflicts by merging
   `origin/main` (never a rebase or force-push on a non-draft PR), run
   `pr-comment-handler` to work the comments, fix any failing CI with `fix-ci`,
   then push.
5. **Reports back.** In Herdr mode: the pane map (PR, tab, pane, status), since
   the agents keep working on their own. Otherwise: a single summary of what was worked, what was skipped, and
   any PR that stopped for a human (divergent conflict, dirty tree, a comment
   needing a design call, a CI failure needing a human, a failed push).
6. **Cleans up the worktrees** (subagent mode only — in Herdr mode the panes
   still use them, so the report lists them for you to remove later). `wt rm` (the `git-worktree` skill) tears down
   each worktree the sweep created — safely: it never removes the main working
   copy or one with uncommitted changes. A PR that stopped for a human keeps its
   worktree so the work can be picked up in place.

## Gotchas

- **Herdr mode needs `HERDR_ENV=1` and `herdr` on PATH.** Pane agents start
  with `--dangerously-skip-permissions` so they run unattended.
- **Needs `gh` (authenticated), `jq`, and `wt`.** Scanning and discovery run
  through `gh` (comment counts via GraphQL, CI status via `gh pr checks`);
  worktrees are made and removed via the `wt` CLI (the `git-worktree` skill).
- **Never rewrites history on a non-draft PR.** Conflicts are resolved with a
  merge commit and appended fixes, so reviewers keep their place.
- **Divergent conflicts stop and ask.** A mechanical overlap is resolved
  automatically; a genuine two-intent conflict is escalated, not guessed.
- **Worktrees are cleaned up when done.** They live alongside the repo at
  `<repo-parent>/<repo-name>-<branch-slug>` and are torn down (`wt rm`) at the end
  of the sweep. The teardown is guarded — it never touches the main working copy
  or a worktree with uncommitted work, and a PR that stopped for a human keeps its
  checkout.
- **Worktree mechanics live in `git-worktree` / `wt`.** This skill just decides
  which branches need a worktree and when to tear them down; the `<repo>-<slug>`
  path, reuse, and safe removal are owned by the `git-worktree` skill (which
  requires the `wt` CLI).
- **`babysit-pr` owns the per-PR work.** This skill discovers PRs and sets up
  worktrees; the per-PR conflict resolution, comment handling (delegated to
  `pr-comment-handler`), and CI fixing (delegated to `fix-ci`) live in
  `babysit-pr`.

## Scripts

- `scripts/scan.sh [--repo owner/name]` — your open PRs with per-PR conflict,
  review-comment, and failing-check counts, split into `actionable` and
  `skipped`.
- `scripts/herdr-grid.sh --repo-name <name> <N>=<worktree-path> ...` — renames
  the Herdr workspace, builds the 2x2 pane grid (a new tab per 4 PRs), and
  starts `/babysit-pr <N>` in each pane.

Worktree setup and teardown are handled by the [`git-worktree`](../git-worktree)
skill (`wt create` / `wt rm`), not bundled scripts.
