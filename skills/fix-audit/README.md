# fix-audit

Fix the security advisories that `pnpm audit` or `bun audit` reports, and keep the overrides list clean. It prefers a real upgrade to an override, and when an override is the only choice, it merges the new entry with the entries already there, so the list does not grow one line for each advisory.

## Install

```
npx skills add venables/skills --skill fix-audit
```

Install `update-deps` too. This skill uses its age-gate version picker and its fix-or-flag rules, and `update-deps` calls this skill after its upgrade batches. Requires Node.js 20+.

## How to use it

Ask Claude Code in plain English, from the project root:

- "fix the audit"
- "pnpm audit is failing"
- "fix the vulnerabilities"
- "clean up the overrides"

## What it does

- **Cleans the overrides first:** removes entries that another entry covers, and entries that no longer match any installed version, before it reads the audit.
- **Fixes with the smallest change:** a lockfile update inside the declared ranges, then a direct-dependency upgrade, then a parent upgrade. An override is the last choice.
- **Writes one override for each vulnerable release line:** a target on the same line, never an open-ended `>=` that can pull in a new major.
- **Writes versions the way the repo does:** it reads `saveExact` / `savePrefix`, the Renovate config, and the existing specifiers. A repo that installs exact versions gets `"tar@<6.2.1": "6.2.1"`. A repo that uses carets gets `"^6.2.1"`.
- **Merges, not appends:** a new advisory on a line that already has an entry changes that entry.
- **Obeys the project rules:** the age gate, catalogs, and the audit ignore list and level.
- **Verifies each fix:** the advisory is gone, no installed version is in the vulnerable range, and the CI checks are at baseline. One commit for each package.
- **Flags, does not force:** no published fix, a patched version that the age gate blocks, or a fix that needs significant code changes goes in the report for you to decide.

## The duplication it removes

`pnpm audit --fix` adds one entry for each advisory and removes nothing, so a package collects lines such as:

```yaml
overrides:
  "package@<10": "10.1"
  "package@<=10.1": "10.2"
```

The second entry matches every version the first one matches, and its target is newer. `scripts/consolidate-overrides.mjs` reports the first one as covered:

```
node skills/fix-audit/scripts/consolidate-overrides.mjs --file pnpm-workspace.yaml
```

It removes an entry only when it can prove that another entry does the same work on the same release line. Entries that overlap without one covering the other stay, with a warning. The script never writes a file.

## Gotchas

- **It never runs `pnpm audit --fix` or `--fix=override`.** That command is the cause of the duplication.
- **It does not ignore advisories for you.** Adding to `audit.ignore` is your decision.
- **Bun overrides have no range selectors.** A Bun override forces every copy of the package to one range, so the skill checks every dependent first and flags the fix when they need different majors.
- **It does not push or open a PR** unless you ask.

## Tests

```
bash skills/fix-audit/tests/consolidate-overrides.sh
```
