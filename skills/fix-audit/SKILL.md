---
name: fix-audit
description: >
  Fix the security advisories that `pnpm audit` or `bun audit` reports, and
  keep the overrides list clean. Prefer a real upgrade (lockfile update,
  direct dependency, or parent dependency) to an override. Add an override
  only as the last choice, and never blindly: merge it with the entries
  already there, remove entries that another entry covers, and remove
  entries that no longer do anything. Verify each fix with the project's
  own checks, and flag fixes that need significant code changes for the
  user to decide. Use whenever the user says "fix the audit", "pnpm audit
  is failing", "bun audit", "fix the vulnerabilities", "fix the security
  advisories", "clean up the overrides", "dedupe the overrides", or a CI
  audit step is red. The `update-deps` skill calls this skill after its
  upgrade batches. Do NOT use to update dependencies in general
  (`update-deps`), or to review code for security problems
  (`security-review`).
---

# fix-audit

Make the audit clean with the smallest change to the dependency tree, and
leave the overrides list shorter or the same length when that is possible.

Four rules control every decision:

- **An override is the last choice.** An override hides a problem from the
  package manager. An upgrade removes the problem. Try the upgrades first.
- **One override for each vulnerable release line.** Before you add an entry,
  look at the entries for the same package. Do not leave two entries where
  one does the work.
- **Write versions the way the project does.** A project that installs exact
  versions gets an exact specifier and an exact override target. A project
  that uses carets gets a caret. Do not bring in a different style.
- **Significant code change is the user's decision.** This is the same rule
  as `update-deps`. Use its `references/fix-or-flag.md`.

## 0. Prepare

If `update-deps` called this skill, use its branch, its baseline, and its
project rules, which include the range style. Do only item 4, for the audit
settings and the audit flags that CI uses.

1. Make sure the working tree is clean. If it is not, stop and tell the user.
2. If you are on the default branch, make a branch: `fix/audit-<YYYY-MM-DD>`.
3. Find the checks that CI runs, and record a baseline before you change
   anything. Include the audit command that CI uses and its flags
   (`--prod`, `--audit-level`).
4. Read the project rules: the age gate and its excludes, catalogs, and the
   audit ignore settings. See
   [references/audit-commands.md](references/audit-commands.md). An advisory
   that the project ignores is not yours to fix. List it in the report.
5. Find the range style of the project (exact, caret, or tilde). Use
   `references/range-style.md` in the `update-deps` skill. Write it down. Every
   specifier and every override target you write uses it.

## 1. Clean the overrides that are there (pnpm)

Do this before you read the audit. Old overrides hide the true state of the
tree. Bun does not use range selectors, so go to
[references/overrides.md](references/overrides.md) for its shorter procedure.

1. **Remove covered entries.** Run the script from this skill's directory, by
   its absolute path:

   ```bash
   node <this-skill>/scripts/consolidate-overrides.mjs --file pnpm-workspace.yaml
   ```

   Use `--file package.json` when the overrides are in `pnpm.overrides`.
   The script changes no file. It prints:
   - `removed`: entries that another entry covers (`coveredBy`). Delete each
     one from the file.
   - `warnings`: `overlap` (two entries match some of the same versions, and
     neither covers the other) and `self-match` (the target is inside the
     range that the selector matches, so the override does not fix
     anything). Correct a `self-match` in step 3. Report an `overlap` that
     you cannot resolve from the advisories.
   - `skipped`: entries it cannot read (`-`, `$name`, `npm:`, `catalog:`,
     `||`). Do not change them.

2. **Find entries that no longer do anything.** For each entry with a version
   range in its selector (`name@<range>`), and no comment that gives a
   reason for it:
   1. Delete the entries (all at one time), and run the install.
   2. List the installed versions of each package
      (`pnpm why -r <name>`).
   3. Decide for each deleted entry:
      - No installed version is in the selector range: the entry did
        nothing. Leave it deleted.
      - A version is in the range, and the audit reports the package: fix it
        again in step 3. The ladder can find a better fix than the old
        override.
      - A version is in the range, and the audit does not report the
        package: the entry has a different purpose. Put it back unchanged.
3. Do not touch an entry that has no version range (`name: 1.2.3`), an entry
   with a parent path (`parent>name`), or an entry with a comment, unless the
   script reports it as covered.
4. Run the checks. Commit: `chore(deps): remove overrides that are covered or
unused`.

## 2. Read the audit

1. Run the audit with JSON output (`pnpm audit --json`, `bun audit --json`).
2. Group the advisories by package. For each package, record:
   - The installed vulnerable versions, and the paths to them
     (`pnpm why -r <name>`, `bun why <name>`).
   - Direct or transitive.
   - The vulnerable range and the first patched version for **each** release
     line. `patched_versions: null` means that no fix is published.
   - The highest severity, and the advisory IDs (GHSA).
3. Fix the highest severity first.

## 3. Fix each package: the ladder

Go down the ladder. Stop at the first step that removes the advisory.

1. **Lockfile update.** The ranges that the dependents declare already accept
   a patched version. No manifest changes.
   - pnpm 11 or later: `pnpm audit --fix=update`.
   - pnpm 10: `pnpm update -r <name>`.
   - Bun: `bun audit fix`.
2. **Upgrade the direct dependency.** The vulnerable package is a direct
   dependency, and the patched version is outside its range. Change the
   specifier (in the catalog, if it uses one). Write it in the range style
   of the project.
3. **Upgrade the parent.** The vulnerable package is transitive, and a
   dependent holds it in the vulnerable range. Look for a newer version of
   the dependent (go up the path until you get to a direct dependency) that
   accepts a patched version: `npm view <parent>@<version> dependencies`.
4. **Override.** Use this only when steps 1 to 3 are not possible, or when
   they are flagged and the user is not there to decide. Write the entry as
   [references/overrides.md](references/overrides.md) tells you, then run
   `consolidate-overrides.mjs` again and apply its `removed` list.
5. **Flag.** No fix is published, the age gate blocks the patched version, or
   every fix needs a significant code change. Do not add an ignore entry or
   an age-gate exclude yourself. Put the options in the report.

Rules for steps 2 and 3:

- These are upgrades, so the `update-deps` rules apply. Use its
  `scripts/pick-version.mjs` with the project age gate, but do not go below
  the first patched version. If the gate blocks every patched version, flag
  it. A sensible recommendation is an exclude for that one version
  (`minimumReleaseAgeExclude: [name@x.y.z]`), which the user must approve.
- Choose the smallest upgrade that includes the fix. An audit fix is not the
  time to move to a new major, unless the fix is only in the new major.
- A major upgrade that breaks a check goes through
  `update-deps/references/fix-or-flag.md`. If it is flagged, go down to step 4
  and tell the user that the override is temporary.

After each package:

1. Run the install, and read the output (peer warnings, ignored build
   scripts).
2. Make sure that the audit does not report the package, and that
   `pnpm why -r <name>` shows no version in the vulnerable range.
3. Run the checks and compare them to the baseline.
4. Commit: `fix(deps): patch <name> for <GHSA id>`. Say in the body which
   step of the ladder you used.

## 4. Final checks

1. Run `consolidate-overrides.mjs` one more time. `removed` must be empty, and
   there must be no `self-match` warning.
2. Do a frozen install, and run every check.
3. Run the audit with the flags that CI uses.
4. Do not push and do not open a PR unless the user asked for it.

## 5. Report

Give the answer first. Then use one table for each section that has entries:

- **Fixed:** package, advisory, severity, `from -> to`, and the ladder step
  (lockfile, direct, parent, override).
- **Overrides:** entries added, entries removed as covered, entries removed
  as unused, and the number of entries before and after. Give the range
  style you used and where you found it.
- **Needs your decision:** package, advisory, why it is not fixed (no
  published fix, age gate, significant change), and the options: wait,
  replace the package, approve an age-gate exclude, approve the major
  upgrade, or ignore the advisory with a written reason.
- **Ignored by project rules:** advisories on the project's ignore list.
- **Checks:** the baseline failures, and the final audit result.

If `update-deps` called this skill, give these sections to it. It puts them
in its report, and it asks about the flagged items together with its own.

## Do not

- Do not run `pnpm audit --fix` with no value, or `--fix=override`. It adds
  one `>=` entry for each advisory and removes nothing. That is the cause of
  the duplication this skill removes.
- Do not write an open-ended target (`>=1.2.3`) in a new override. It lets a
  dependent get a new major that it does not support. Use the range style of
  the project: `1.2.3` where it pins exact versions, `^1.2.3` where it uses
  carets.
- Do not write a caret in a project that pins exact versions, and do not
  change the setting that controls the style (`saveExact`, `savePrefix`).
- Do not add an advisory to an ignore list (`audit.ignore`,
  `auditConfig.ignoreGhsas`, `--ignore`). That is the user's decision.
- Do not add an age-gate exclude, loosen the gate, or lower the audit level.
- Do not use `--force` or `--legacy-peer-deps`, and do not approve new build
  scripts.
- Do not remove an override only because the audit is clean without it. The
  test is the selector range: it is unused only when no installed version is
  in that range.
