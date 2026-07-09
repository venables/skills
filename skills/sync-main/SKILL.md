---
name: sync-main
description: Bring the current branch up to date with origin/main, resolving merge conflicts and repo-specific hazards like DB migration number collisions and lockfile drift. Use whenever the user says "merge main in", "we diverged from main", "fix the conflicts", "this PR is outdated", "rebase over main", or a PR shows merge conflicts. Trigger on terse asks like "omg conflicts again, please fix".
---

# Sync branch with main

Long-lived branches versus a fast-moving main is a constant source of churn in Matt's repos. Resolve it the same way every time.

## Procedure

1. `git fetch origin` and check divergence: `git log --oneline HEAD..origin/main | head`.
2. **Merge, don't rebase, once a PR exists.** Rebasing a pushed PR branch rewrites history under reviewers. Use `git merge origin/main`. Rebase only if Matt asks or the branch was never pushed.
3. Resolve conflicts by understanding both sides, not by picking one blindly:
   - Lockfiles (`pnpm-lock.yaml`, `bun.lock`): take main's version, then re-run the install so the branch's own dependency changes are re-applied.
   - Generated files: regenerate rather than hand-merge.
   - Real code conflicts: read the main-side change (why it landed) before deciding; when the two sides are both needed, integrate both.
4. **Migration numbers** (repos with numbered DB migrations): after merging, check whether main took the same migration number this branch uses. If so, renumber the branch's migration to the next free number and update any references. Check this even when git reports no conflict; identical numbers in different files do not conflict textually.
5. Re-run the checks that CI runs (lint/typecheck via oxlint, tests for touched areas) before pushing. A clean merge that does not compile is worse than a conflict.
6. Push and confirm the PR shows mergeable and checks running.

Report which files conflicted, how each was resolved, and whether a migration renumber happened.
