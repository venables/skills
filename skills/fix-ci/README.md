# fix-ci

Diagnose and fix a failing CI check on a PR (or on main) with the smallest correct change. Before touching anything, it works out whether your branch broke the build or main was already red, so a shared failure never gets buried in a feature branch.

## Install

```
npx skills add venables/skills --skill fix-ci
```

Requires the `gh` CLI on PATH (it drives GitHub Actions via `gh pr checks` and `gh run view`).

## How to use it

Ask Claude Code in plain English, or let another skill invoke it:

- "CI is failing"
- "the build broke"
- "looks like CI failed here please fix"
- "checks are red"
- "this PR can't merge, checks are failing"

It also kicks in proactively after a push when checks come back red.

## What it does

- **Identifies the real failure:** pulls the failing run with `gh run view <run-id> --log-failed` and reads the actual error (the first one, usually the true cause), not the exit code or later cascade errors.
- **Broken by this branch:** reproduces locally with the exact command CI ran (from the workflow file), then fixes the root cause rather than the symptom.
- **Broken on main too:** checks whether main's latest run is also red, and if so fixes it on a fresh branch over main as its own PR and tells you, instead of hiding a main fix inside a feature branch.
- **Flake or merge-skew:** re-runs a suspected flake or infra failure once with `gh run rerun --failed`, or merges origin/main in to resolve stale-branch collisions (migration numbers, lockfile drift).
- **Verifies before pushing:** runs the failing job's command locally and confirms it passes before committing a conventional `fix:`/`ci:` change and watching checks go green.
- **Reports:** what failed, the root cause, what changed, and final check status, filing a Linear ticket if the fix was only a workaround.

## Gotchas

- **Assumes an oxlint/tsgo toolchain and pnpm or bun monorepos.** The skill reproduces failures with oxlint (type-aware via tsgo), not eslint or tsc. If your repo uses eslint/tsc or npm/yarn, expect to adapt the reproduction commands.
- **A main-only failure gets its own branch and PR.** Rather than committing a shared fix onto your feature branch, the skill spins up a fresh branch over main and opens a separate PR so the main fix stands alone.
- **No silent green.** It never disables a test, adds a lint ignore, or loosens config to pass without calling that out explicitly and getting your go-ahead first.
- **Reruns are labeled as reruns.** When it re-runs a flake, it says so rather than claiming a fix.
