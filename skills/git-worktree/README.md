# git-worktree

Create, reuse, and remove git worktrees in **one consistent place** by shelling
out to the [`wt`](https://github.com/venables/wt) CLI. Every worktree lands at
`<repo-parent>/<repo-name>-<branch-slug>` — flat, alongside the repo, sharing
the repo-name prefix (so `~/dev/venables/skills` + branch `fix/auth` becomes
`~/dev/venables/skills-fix-auth`).

This is the single source of truth for _where worktrees go and how they're
made_. Other skills (e.g. [`babysit-my-prs`](../babysit-my-prs)) delegate here
instead of calling `git worktree add` into an ad-hoc path.

## Install

```
npx skills add venables/skills --skill git-worktree
```

Requires the [`wt`](https://github.com/venables/wt) CLI on PATH (`wt --version`).

## How to use it

Ask Claude Code in plain English, or let another skill invoke it:

- "make a worktree for this branch"
- "spin up a worktree off main called feature/x"
- "give each of these branches its own worktree"
- "tear down the worktree"

## What it does

- **Create / reuse:** `wt create <branch>` prints the absolute worktree path to
  stdout. If the branch is already checked out anywhere (including the main
  copy), it reuses that worktree instead of duplicating.
- **Remove:** `wt rm <branch>` (or `wt done` for the current one) — refuses a
  dirty worktree so nothing is lost, and always keeps the branch and committed
  work.
- **Consistent path:** `wt` owns the `<repo>-<slug>` path math, the
  `.worktreeinclude`/`.gitignore` copying, and its add/remove hooks.

## Gotchas

- **Requires `wt`.** If it isn't installed, the skill stops rather than
  hand-rolling `git worktree add` into a different path.
- **`wt create` doesn't fetch.** For a remote-only branch, `git fetch origin`
  first so `origin/<branch>` exists.
- **`git worktree add` locks the repo.** Setting up many worktrees for parallel
  work? Create them serially, then fan out.
