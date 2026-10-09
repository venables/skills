# update-deps

Update every dependency in a project, or in every package of a monorepo, to the newest version that is safe. It obeys the rules the project sets (release-age gates, catalogs, overrides, pins, Renovate and Dependabot config), checks each upgrade with the project's own CI commands, and applies small fixes itself. Upgrades that need significant code changes are reported for you to decide, not done.

## Install

```
npx skills add venables/skills --skill update-deps
```

Requires Node.js 20+ and `npm` on PATH (the version picker reads the registry with `npm view`). Uses `gh` to read release notes when it is available.

## How to use it

Ask Claude Code in plain English, from the project root:

- "update dependencies"
- "bump deps"
- "bring everything up to date"
- "what's outdated here?"
- "update vitest to latest"

## What it does

- **Records a baseline first:** runs the checks CI runs before it changes anything, so a failure that was already there is not blamed on an upgrade.
- **Reads every project rule:** age gates from `pnpm-workspace.yaml`, `.npmrc`, `.yarnrc.yml`, `bunfig.toml`, Renovate, and Dependabot (the strictest one wins), their exclude lists, catalogs, overrides, pins, `engines`, and dependency notes in `AGENTS.md`.
- **Picks a safe target per dependency:** `scripts/pick-version.mjs` returns the newest stable version that is old enough, never above the `latest` dist-tag. It also reports what the gate holds back and when it becomes eligible.
- **Checks each target:** no deprecation, no lost publish provenance, no new install scripts.
- **Upgrades in batches:** all patch and minor upgrades together, then each major group (for example `vitest` with `@vitest/*`) on its own, with one commit per batch.
- **Fixes or flags:** applies small mechanical fixes (imports, types, renamed options). It reverts and reports any upgrade that changes behavior, touches many files, needs a design choice, or can only pass by weakening a check.
- **Reports and asks:** a table of what changed, what needs your decision, what the gate held back, and what the project rules skipped. Then it asks which flagged upgrades to do now.

## Gotchas

- **Default gate is 3 days.** If the project sets no age gate, the skill uses 3 days and says so. Set `minimumReleaseAge` (or your package manager's equivalent) to change it.
- **It does not push or open a PR** unless you ask. Use `write-pull-request` for that.
- **Transitive dependencies are left alone.** It does not refresh the lockfile within existing ranges unless you ask, because those diffs are large and hard to review.
- **JavaScript first.** Python (uv), Rust, and Go follow the same procedure with notes in `references/other-ecosystems.md`, but the version picker reads the npm registry only.

## Tests

```
bash skills/update-deps/tests/pick-version.sh
```
