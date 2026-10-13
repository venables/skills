# Audit commands and settings

## Commands

| Task                                        | pnpm                                                                    | Bun                               |
| ------------------------------------------- | ----------------------------------------------------------------------- | --------------------------------- |
| Audit                                       | `pnpm audit`                                                            | `bun audit`                       |
| JSON output                                 | `pnpm audit --json`                                                     | `bun audit --json`                |
| Production only                             | `pnpm audit --prod`                                                     | `bun audit --prod`                |
| Severity threshold                          | `pnpm audit --audit-level <low\|moderate\|high\|critical>`              | `bun audit --audit-level <level>` |
| Fix in the lockfile, inside declared ranges | `pnpm audit --fix=update` (pnpm 11+), `pnpm update -r <name>` (pnpm 10) | `bun audit fix`                   |
| Show why a package is installed             | `pnpm why -r <name>`                                                    | `bun why <name>`                  |

Use the same flags that the CI audit step uses, so that "clean" means the
same thing locally and in CI.

Notes:

- `bun audit --json` prints the raw registry response. `--audit-level` and
  `--ignore` do not filter it. Apply the project's threshold and ignore list
  yourself when you read it.
- `bun audit fix` prints the fixes it could not make: "blocked by a
  dependent's range" (go to step 3 of the ladder) and "no published version
  fixes" (flag it).
- `pnpm audit --fix=update` cannot move an exact pin that comes from an
  override or a `packageExtensions` entry. It prints a warning. Correct that
  override by hand.
- In `pnpm audit --json`, `patched_versions` is `null` when no fix is
  published.

## Project settings to obey

| Setting                                              | Where                                              | Meaning                              |
| ---------------------------------------------------- | -------------------------------------------------- | ------------------------------------ |
| `audit.ignore`                                       | `pnpm-workspace.yaml` (pnpm 11.15+)                | GHSA IDs that the project accepts    |
| `audit.level`                                        | `pnpm-workspace.yaml` (pnpm 11.15+)                | Lowest severity that fails the audit |
| `auditConfig.ignoreGhsas` / `auditConfig.ignoreCves` | `pnpm-workspace.yaml`, or `pnpm` in `package.json` | The older form of the ignore list    |
| `auditLevel`                                         | `pnpm-workspace.yaml` or `.npmrc`                  | The older form of the level          |
| `--ignore <id>` / `--audit-level`                    | CI workflow or `package.json` scripts              | Bun and pnpm flags that CI passes    |

Since pnpm 11, the audit matches advisories by GHSA ID, not by CVE. If the
project still has `ignoreCves` entries, tell the user. Do not convert them
yourself.

The age gate applies to a security fix as it does to any upgrade. The
sources and units are in the `update-deps` skill
(`references/project-rules.md`).

## Advisory fields to record

- Package name, and the installed versions that are vulnerable.
- `vulnerable_versions` and `patched_versions`, for each release line.
- Severity.
- GHSA ID and URL.
- Paths: which direct dependency brings the package in.
