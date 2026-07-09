# sync-main

Bring the current branch up to date with `origin/main`, resolving merge conflicts and repo-specific hazards along the way. It merges rather than rebases once a PR exists, watches for DB migration number collisions and lockfile drift, and re-runs CI's checks before pushing.

## Install

```
npx skills add venables/skills --skill sync-main
```

## How to use it

Just ask Claude Code in plain English:

- "merge main in"
- "we diverged from main"
- "fix the conflicts"
- "this PR is outdated"
- "rebase over main"
- "omg conflicts again, please fix"

## What it does

- **Checks divergence first:** runs `git fetch origin` and inspects `git log HEAD..origin/main` so you know what's landed before touching anything.
- **Merges, doesn't rebase, once a PR exists:** uses `git merge origin/main` on pushed branches, and only rebases if you ask or the branch was never pushed.
- **Resolves conflicts by understanding both sides:** takes main's lockfile then re-runs the install to re-apply your dependency changes, regenerates generated files rather than hand-merging, and reads the main-side change before deciding on real code conflicts (integrating both when both are needed).
- **Catches migration number collisions:** in repos with numbered DB migrations, checks whether main took the same number your branch uses (even when git reports no conflict), and renumbers the branch's migration to the next free number, updating references.
- **Re-runs CI's checks before pushing:** lint/typecheck and tests for touched areas, so you don't push a clean merge that fails to build.
- **Pushes and confirms:** verifies the PR shows mergeable with checks running, then reports which files conflicted, how each was resolved, and whether a migration renumber happened.

## Gotchas

- **It merges, it doesn't rebase, once a PR is pushed.** Rebasing a pushed PR branch rewrites history under reviewers who've already looked at it. Rebase is reserved for branches that were never pushed, or when you explicitly ask.
- **A clean merge that does not compile is worse than a conflict.** That's why the pre-push step re-runs the same lint, typecheck, and tests CI runs rather than trusting a conflict-free merge.
- **It assumes an oxlint toolchain** for the pre-push lint/typecheck pass.
- **Identical migration numbers do not conflict textually.** Two branches can pick the same number in different files and git will merge cleanly, so this hazard is checked explicitly rather than left to conflict markers.
