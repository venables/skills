# Other ecosystems

The procedure is the same: read the rules, record a baseline, pick targets,
upgrade in batches, fix or flag, and report. Only the commands change.
`pick-version.mjs` reads the npm registry only. For other registries, read the
release dates yourself and apply the same gate.

## Python (uv)

- Rules: `pyproject.toml` `[tool.uv]` `exclude-newer` (a cut-off date; treat it as the gate),
  `constraint-dependencies`, `override-dependencies`, and
  `requires-python`.
- Outdated: `uv tree --outdated --depth 1`.
- Upgrade: edit the specifier in `pyproject.toml`, then `uv lock` and
  `uv sync`. For one package: `uv lock --upgrade-package <name>`.
- Release dates: `https://pypi.org/pypi/<name>/json` (`releases.<version>[].upload_time_iso_8601`).

## Rust (Cargo)

- Rules: `rust-version` in `Cargo.toml`, `[patch]` sections, and
  `deny.toml` (cargo-deny) bans.
- Outdated: `cargo outdated --root-deps-only` (cargo-outdated), or
  `cargo update --dry-run --verbose`.
- Upgrade: edit the version in `Cargo.toml`, then `cargo update -p <name>`.
- Release dates: `https://crates.io/api/v1/crates/<name>/versions`
  (`created_at`).

## Go

- Rules: the `go` and `toolchain` lines in `go.mod`, and `replace`
  directives.
- Outdated: `go list -m -u all` (direct dependencies have no `// indirect`).
- Upgrade: `go get <module>@<version>`, then `go mod tidy`. A new major
  version is a new import path (`/v2`), so a Go major upgrade is always
  flagged.
- Release dates: `go list -m -json <module>@<version>` (`Time`).
