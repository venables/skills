---
name: startkit
description: >
  Scaffold a new strict-TypeScript project from the startkit standard:
  pnpm, native-TS Node, oxlint (type-aware) + oxfmt, vitest, ultra-strict
  tsconfig, kebab-case filenames, and a GitHub Actions check on PRs and main.
  Use whenever the user wants to start a new TypeScript project, app, package,
  library, or service from scratch, or says things like "make a starter app",
  "start a new typescript app", "new startkit app", "scaffold a typescript
  project", "make me a starter", "spin up a fresh TS repo", "start a new project
  with my standards", "bootstrap a node/typescript app", or "create a strict
  typescript starter". Trigger on any request to create/scaffold/bootstrap/spin
  up a new TS or Node project, even when the word "startkit" is not used. This is
  the baseline; monorepo, CLI, and tanstack-start variants layer on top (see
  references/).
---

# startkit

Scaffold a new TypeScript project matching the baseline standard. The bundled
`assets/` are the source of truth for every config file. This skill copies them,
resolves current tool versions at scaffold time, installs, and verifies.

## When to reach for a variant

This SKILL builds the **base** single-package app. For a different shape, read
the matching reference AFTER the base steps and apply its deltas:

- Monorepo (pnpm workspace + turbo, apps/ + packages/) -> `references/monorepo.md`
- CLI (bin entry, arg parsing, build) -> `references/cli.md`
- TanStack Start web app (+ optional auth) -> `references/web.md`

If the user did not ask for a variant, build the base and stop.

## Steps

### 1. Get the target directory and project name

Ask for a project name/path if not given. Create the directory. The
`PROJECT_NAME` placeholder in `package.json` and `README.md` should become the
scoped or plain package name the user wants (default: the directory name).

### 2. Copy the bundled template

Copy every file from this skill's `assets/` into the project, renaming the
`dot-` prefixed files and the `github/` directory. Given `$SKILL` = this skill's
directory and `$DIR` = the target project:

```bash
mkdir -p "$DIR/src" "$DIR/.github/workflows"
cp "$SKILL/assets/tsconfig.json"        "$DIR/tsconfig.json"
cp "$SKILL/assets/vitest.config.ts"     "$DIR/vitest.config.ts"
cp "$SKILL/assets/pnpm-workspace.yaml"  "$DIR/pnpm-workspace.yaml"
cp "$SKILL/assets/package.json"         "$DIR/package.json"
cp "$SKILL/assets/AGENTS.md"            "$DIR/AGENTS.md"
cp "$SKILL/assets/CLAUDE.md"            "$DIR/CLAUDE.md"
cp "$SKILL/assets/README.md"           "$DIR/README.md"
cp "$SKILL/assets/dot-gitignore"        "$DIR/.gitignore"
cp "$SKILL/assets/dot-oxlintrc.json"    "$DIR/.oxlintrc.json"
cp "$SKILL/assets/dot-oxfmtrc.jsonc"    "$DIR/.oxfmtrc.jsonc"
cp "$SKILL/assets/src/index.ts"         "$DIR/src/index.ts"
cp "$SKILL/assets/src/index.test.ts"    "$DIR/src/index.test.ts"
cp "$SKILL/assets/github/workflows/check.yml" "$DIR/.github/workflows/check.yml"
```

### 3. Resolve versions (do NOT hardcode stale ones)

Fill the placeholders in `package.json`:

- `PROJECT_NAME` -> the package name.
- `PNPM_VERSION` -> the pnpm the user is actually running: `pnpm -v`. Pin the
  active version, NOT `npm view pnpm version` — pinning a newer version than is
  installed makes `onFail: error` hard-block every command. If the user wants
  the newest pnpm, have them `pnpm self-update` (or `corepack use pnpm@latest`)
  first, then scaffold. This value fills BOTH `packageManager` (as
  `pnpm@<version>`) and `devEngines.packageManager.version`; they must be
  identical.
- `NODE_MAJOR` -> current active Node LTS major. Prefer `mise` if available
  (`mise ls-remote node | tail`), else the running major from `node -v`, else
  the latest LTS you know is released. Node must be recent enough to run TS
  natively (Node 22.6+ with type stripping; 24+ preferred for `import.meta.main`
  and stable `--watch`). Fills `devEngines.runtime.version` as `>=<major>`.

### 4. Install dependencies

`pnpm-workspace.yaml` sets `saveExact: true`, so installs pin exact versions.
Run from `$DIR`:

```bash
pnpm add -D typescript oxlint oxfmt oxlint-tsgolint vitest @types/node
```

`oxlint-tsgolint` is what makes oxlint's `typeAware`/`typeCheck` options work,
which is why there is no separate `typecheck` script.

Note: `minimumReleaseAge: 1440` blocks packages published in the last 24h. If an
install fails on that, tell the user rather than lowering the setting.

### 5. Initialize git and verify

```bash
cd "$DIR"
git init -q
pnpm fix     # oxfmt the copied files into canonical form + apply lint fixes
pnpm check   # lint (type-aware) + format:check + test — must pass
```

Run `pnpm fix` before `pnpm check`: the bundled assets are not pre-formatted to
oxfmt's exact output (key order, prose wrap), so `fix` normalizes them and then
`check` passes cleanly. Make an initial commit if the user wants one.

## The standard (what these files encode)

- **pnpm** as the package manager; **Node LTS** as the runtime, both declared in
  `package.json` via `packageManager` + `devEngines`.
- **Ultra-strict TypeScript**: `strict` plus `noUncheckedIndexedAccess`,
  `exactOptionalPropertyTypes`, `noImplicitReturns`, `noUnusedLocals/Parameters`,
  `noPropertyAccessFromIndexSignature`, and more (see `assets/tsconfig.json`).
- **oxlint** type-aware (`options.typeAware` + `options.typeCheck`) so linting
  also type-checks; **oxfmt** for formatting. No ESLint/Prettier/tsc scripts.
- **vitest** for tests, colocated as `*.test.ts`.
- **kebab-case** filenames everywhere, including React components.
- Scripts: `dev`, `test` (`vitest run`), `test:watch`, `lint`, `lint:fix`,
  `format`, `format:check`, `check` (= lint + format:check + test), `fix`
  (= lint:fix + format).
- **CI**: `.github/workflows/check.yml` runs `pnpm check` on PRs to `main` and
  pushes to `main`.

Note on `test`: the spec lists `test` as vitest, but `check`/CI must terminate,
so `test` is `vitest run` (one-shot) and `test:watch` is the watch-mode `vitest`.

## Maintaining this skill

Edit the real files in `assets/` to change the standard — they are copied
verbatim (only versions are resolved at scaffold time). Keep the placeholder
tokens (`PROJECT_NAME`, `PNPM_VERSION`, `PNPM_MAJOR`, `NODE_MAJOR`) intact.
