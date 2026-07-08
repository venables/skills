---
name: git-worktree
description: >
  Create, reuse, or remove a git worktree via the `wt` CLI, so every
  worktree lands in the same predictable place —
  `<repo-parent>/<repo-name>-<branch-slug>`, flat and alongside the repo,
  sharing the repo-name prefix (e.g. `skills` -> `skills-fix-auth`). Use
  whenever the user or another skill says things like "make a worktree",
  "create a worktree for this branch", "spin up a worktree", "new
  worktree off main", "give each PR its own worktree", "check that branch
  out in a worktree", or "tear down the worktree". This is the single
  source of truth for where worktrees go and how they're made — other
  skills (e.g. `babysit-my-prs`) delegate here instead of calling
  `git worktree add` into an ad-hoc path. Requires the `wt` CLI on PATH.
---

# git-worktree

One job: make git worktrees land in a **consistent, predictable place**,
by shelling out to the **`wt`** CLI rather than hand-rolling
`git worktree add`. Every worktree this skill creates lives at:

```
<repo-parent>/<repo-name>-<branch-slug>
```

flat, **alongside** the repo (a sibling directory, not nested inside it),
sharing the repo's name as a prefix, with `/` in the branch replaced by
`-`. So in `~/dev/venables/skills` a worktree for branch `fix/auth`
becomes `~/dev/venables/skills-fix-auth`. `wt` owns this path math, the
`.worktreeinclude`/`.gitignore` copying, and its add/remove hooks — don't
re-derive any of it.

## Requires `wt`

This skill assumes the `wt` CLI is installed (`wt --version`). If it
isn't on PATH, **stop and say so** — do not fall back to a hand-rolled
`git worktree add` into some other path, which is exactly the
inconsistency this skill exists to prevent. Install it from
`~/dev/cli/wt` (or `brew`).

## Create or reuse a worktree

```bash
wt create <branch>
```

- Prints the **absolute worktree path to stdout** (all progress goes to
  stderr) — capture stdout; that path is where work happens.
- **Reuses** rather than duplicates: if `<branch>` is already checked out
  in any worktree (including the main working copy), `wt` enters that one
  and prints its path unchanged instead of erroring.
- Resolves the branch itself: an existing local branch is checked out; a
  branch that only exists on `origin` is created with `--track`; a
  brand-new branch is created off the current branch (or `--base <ref>`).

```bash
wt create feature/x --base main    # branch new off a specific base
wt create feature/x --path /tmp/x  # override the destination (rarely needed)
```

`wt create` does **not** fetch. If a branch you want lives only on the
remote, run `git fetch origin` first so `origin/<branch>` exists locally,
then `wt create <branch>`.

## Remove a worktree

```bash
wt rm <branch>     # or: wt rm <path>
wt done            # remove the CURRENT worktree, return to main
```

- Refuses a worktree with **uncommitted changes** (it wraps
  `git worktree remove` without `--force`) — nothing is silently lost.
  Only pass `-f` when the caller explicitly wants to discard that work.
- Removing a worktree **keeps its branch and any committed work** — only
  the directory goes, so a later `wt create <branch>` just recreates it.
- Never removes the main working copy.

Other useful commands: `wt list` (show all worktrees), `wt cleanup`
(interactively remove non-main worktrees), `wt back` (print the main
worktree path).

## Setting up many worktrees for parallel work

`wt create` calls `git worktree add`, which takes a **repo-wide lock**.
When a caller needs several worktrees (one per branch) before fanning out
parallel agents, create them **serially** — one `wt create` at a time
from the main repo — then start the parallel work. Racing `wt create`
across agents can fail on the lock.

## Common mistakes

| Mistake                                        | Reality                                                                     |
| ---------------------------------------------- | --------------------------------------------------------------------------- |
| `git worktree add <ad-hoc path>`               | Use `wt create <branch>` so it lands in `<repo>-<slug>` with hooks/copying  |
| Nesting worktrees inside the repo              | They go **alongside** it: a sibling `<repo>-<slug>` dir, never under it     |
| Hand-rolling a fallback when `wt` is missing   | Stop and report — the whole point is one consistent path; don't diverge     |
| Racing `wt create` across parallel agents      | `git worktree add` locks the repo; create serially, then fan out            |
| `wt create` for a remote-only branch, no fetch | `wt` doesn't fetch; `git fetch origin` first so `origin/<branch>` exists    |
| `wt rm -f` to get past a dirty worktree        | The refusal is the safety; only force when the caller wants to discard work |
| Parsing stderr for the path                    | The path is on **stdout**; stderr is progress. Capture stdout only          |
