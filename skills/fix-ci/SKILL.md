---
name: fix-ci
description: Diagnose and fix a failing CI check on a PR or on main. Use whenever the user says "CI is failing", "the build broke", "looks like CI failed here please fix", "checks are red", or a PR cannot merge due to failing checks. Also use proactively after pushing when checks come back red. Covers GitHub Actions in Matt's repos (oxlint/tsgo toolchain, pnpm or bun monorepos).
---

# Fix CI

Get the failing check green with the smallest correct change, and distinguish "my change broke it" from "main is broken" before touching anything.

## Procedure

1. **Identify the failure**: `gh pr checks <n>` (or `gh run list --branch main` for main breakage), then `gh run view <run-id> --log-failed` to get the actual error. Read the real error, not the exit code; the first error in the log is usually the true one, later ones are cascade.
2. **Classify**:
   - Broken by this branch: reproduce locally with the same command CI ran (check the workflow file for the exact invocation; these repos use oxlint with type-aware checking via tsgo, not eslint/tsc). Fix the root cause, not the symptom.
   - Broken on main too: check whether main's latest run is also red. If so, fix on a fresh branch over main as its own PR and tell Matt; do not bury a main fix inside a feature branch.
   - Flake or infra (timeouts, registry errors, runner death): re-run with `gh run rerun <run-id> --failed` once before investigating. Say it was a rerun, not a fix.
   - Merge-skew: branch is stale versus main (e.g. migration number collisions, lockfile drift). Merge origin/main in, resolve, re-run.
3. **Verify locally before pushing**: run the failing job's command locally and confirm it passes. Do not push a guess and wait for CI to find out.
4. **Commit** with a conventional message (`fix:` or `ci:`), push, and confirm checks go green with `gh pr checks --watch` or by polling.
5. **Report**: what failed, root cause, what changed, and check status. If the fix was a workaround, file a Linear ticket in triage for the real fix and link it.

Never disable a test, add a lint ignore, or loosen a config to get green without calling that out explicitly and getting a nod first.
