# Package managers

## Find the package manager

Use the `packageManager` field in the root `package.json` first. If there is
no field, use the lockfile.

| Lockfile                                    | Manager         |
| ------------------------------------------- | --------------- |
| `pnpm-lock.yaml`                            | pnpm            |
| `package-lock.json` / `npm-shrinkwrap.json` | npm             |
| `yarn.lock` with `.yarnrc.yml`              | Yarn 2+ (Berry) |
| `yarn.lock` with no `.yarnrc.yml`           | Yarn 1          |
| `bun.lock` / `bun.lockb`                    | Bun             |

If there is more than one lockfile, ask the user which one is real.

## Workspaces

- pnpm: `packages` in `pnpm-workspace.yaml`.
- npm, Yarn, Bun: `workspaces` in the root `package.json` (an array, or an
  object with `packages`).
- Turborepo or Nx do not change this. They use the package-manager
  workspaces. Use their task runner for the checks (`turbo run lint test
build`), because CI usually does.

## Commands

| Task                             | pnpm                                     | npm                                                         | Yarn 2+                                                                  | Bun                             |
| -------------------------------- | ---------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------ | ------------------------------- |
| List outdated                    | `pnpm outdated -r --format json`         | `npm outdated --workspaces --include-workspace-root --json` | `yarn upgrade-interactive` (interactive only), or `npm view` per package | `bun outdated --recursive`      |
| Show why a package is installed  | `pnpm why -r <name>`                     | `npm explain <name>`                                        | `yarn why <name>`                                                        | `bun why <name>`                |
| Install after editing specifiers | `pnpm install`                           | `npm install`                                               | `yarn install`                                                           | `bun install`                   |
| Frozen install                   | `pnpm install --frozen-lockfile`         | `npm ci`                                                    | `yarn install --immutable`                                               | `bun install --frozen-lockfile` |
| Audit                            | `pnpm audit`                             | `npm audit`                                                 | `yarn npm audit --all --recursive`                                       | `bun audit`                     |
| Registry metadata                | `pnpm view <name> time dist-tags --json` | `npm view <name> time dist-tags --json`                     | `yarn npm info <name> --fields time,dist-tags --json`                    | `npm view`                      |

For Yarn 1, use `yarn outdated --json` and `yarn install --frozen-lockfile`.

## Find the installed version

`pick-version.mjs` needs the installed version, not the range. Use the
`current` value from the outdated output, or the version in the lockfile.
When workspaces have different installed versions, run the script for each
one.

## Edit specifiers

Change the version in the manifest yourself, then install. Keep the range
operator:

- `^1.2.3` to `^2.0.1`
- `~1.2.3` to `~1.2.9`
- `1.2.3` to `1.2.9`
- `catalog:` in `package.json`: change the entry in `pnpm-workspace.yaml`.
- `npm:other-name@^1.0.0` (an alias): change only the version part. Run
  `pick-version.mjs` against `other-name`.

Do not use `pnpm update --latest` or `npm install <pkg>@latest`. They ignore
the batch plan, can change the range operator, and can choose a version that
the gate blocks when the gate is not strict.

## Install output to watch for

- `WARN Issues with peer dependencies found` / `ERESOLVE` / `unmet peer`: a
  peer range does not accept the new version. Look for a newer version of the
  package that has the peer. If there is none that the gate allows, hold the
  upgrade back and report "blocked by `<package>` peer range".
- `Ignored build scripts` (pnpm 10+), or Bun `blocked postinstall`: a new
  version wants to run an install script. Flag it.
- A resolution error that names the release age (pnpm), or npm "no versions
  available": the age gate blocks every version in the range. Run
  `pick-version.mjs` again with the gate that the error names, and use its
  target.
- `deprecated` warnings for a direct dependency: report them.
