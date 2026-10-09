# Project rules

Where each dependency rule lives, and how to read it. Check every source. A
project can set the same rule in more than one place. When two sources
disagree, use the stricter value.

## Age gate (minimum release age)

Convert every value to minutes. Then use the largest one.

| Source                                                                 | Key                                                                                         | Unit                      | Excludes                                                     |
| ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | ------------------------- | ------------------------------------------------------------ |
| `pnpm-workspace.yaml`                                                  | `minimumReleaseAge`                                                                         | minutes                   | `minimumReleaseAgeExclude` (names, globs, or `name@version`) |
| `.npmrc` (npm 11+)                                                     | `min-release-age`                                                                           | days                      | `min-release-age-exclude`                                    |
| `.npmrc` (any npm)                                                     | `before`                                                                                    | absolute date             | none                                                         |
| `.yarnrc.yml` (Yarn 4.12+)                                             | `npmMinimalAgeGate`                                                                         | duration (`"3d"`, `"1w"`) | `npmPreapprovedPackages`                                     |
| `bunfig.toml` `[install]`                                              | `minimumReleaseAge`                                                                         | **seconds**               | `minimumReleaseAgeExcludes`                                  |
| `renovate.json` / `.github/renovate.json5` / `package.json` `renovate` | `minimumReleaseAge` (top level or in `packageRules`)                                        | duration (`"3 days"`)     | the `packageRules` match                                     |
| `.github/dependabot.yml`                                               | `cooldown.default-days` and `semver-major-days` / `semver-minor-days` / `semver-patch-days` | days                      | `cooldown.exclude`                                           |

Notes:

- pnpm 11 applies `minimumReleaseAge: 1440` (1 day) by default, even when the
  file does not set it. Count it as a source.
- pnpm `minimumReleaseAgeStrict` and npm `min-release-age` make the install
  fail when no version is old enough. That is correct behavior. Do not turn it
  off.
- A Renovate or Dependabot rule for one bump type (for example
  `semver-major-days`) applies only to that bump type. Use the `bump` from
  `pick-version.mjs` to find which value applies, and run the script again with
  that gate.
- Also check the global config the user may have (`~/.npmrc`,
  `~/.config/pnpm/rc`, `~/.bunfig.toml`, `~/.yarnrc.yml`). Report a global
  gate, but the project value controls when both exist.
- If no source sets a gate, use 4320 minutes (3 days). Say so in the report.

## pnpm trust and build rules

- `trustPolicy: no-downgrade` makes pnpm block a version with weaker publish
  provenance than an earlier one. `trustPolicyExclude` lists the exceptions.
  Do not add to the exclude list. Flag the upgrade.
- `allowBuilds` (pnpm 11+), or `onlyBuiltDependencies` /
  `ignoredBuiltDependencies` (pnpm 10), control install scripts. A new version
  that needs a build script that is not allowed is flagged. Do not change the
  list.
- `blockExoticSubdeps` blocks git and tarball dependencies in the tree. Obey
  it.

## Versions the project controls

- **Catalogs.** `catalog:` (default) and `catalogs:` (named) in
  `pnpm-workspace.yaml`. A `package.json` specifier `catalog:` or
  `catalog:<name>` takes its version from there. Change the catalog entry.
  `catalogMode: strict` means that every new specifier must use the catalog.
- **Overrides.** `overrides` in `pnpm-workspace.yaml` or `pnpm.overrides` in
  `package.json`, npm `overrides`, Yarn `resolutions`, Bun `overrides` /
  `resolutions`. An override often pins a transitive dependency for a security
  fix or a bug. If an upgrade makes an override unnecessary, report it. Do not
  remove it.
- **`peerDependencies` in a published package.** A change to the peer range
  changes the contract for the consumers of the package. Flag it.
- **Pins.** An exact version in a project that otherwise uses `^` is probably
  intentional. Look for a comment, a Renovate `rangeStrategy: pin`, or a note
  in `AGENTS.md`. If you find a reason, do not move it. If you do not find a
  reason, upgrade it and keep it exact.

## Ignore and hold rules

- Renovate: `ignoreDeps`, `ignorePaths`, `packageRules` with `enabled: false`,
  `allowedVersions`, `matchUpdateTypes` with `enabled: false`, and `extends`
  presets that set these.
- Dependabot: `ignore` with `dependency-name` and `versions` or
  `update-types`.
- `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`: plain-language rules such as
  "do not upgrade Next.js past 15".

## Runtime

- `engines.node`, `engines.pnpm`, `.nvmrc`, `.node-version`, `.tool-versions`,
  `mise.toml`, and the `packageManager` field.
- If a target needs a newer runtime than the project allows, flag it. A
  runtime upgrade is a separate decision.
- Update `packageManager` (the package manager itself) only when the user
  asks.
