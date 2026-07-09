# startkit

Scaffold a fresh, strict-TypeScript project from a single baseline standard: pnpm, native-TS Node, oxlint (type-aware) plus oxfmt, vitest, an ultra-strict tsconfig, kebab-case filenames, and a GitHub Actions check. Bundled config files are the source of truth; the skill copies them, resolves current tool versions at scaffold time, installs, and verifies.

## Install

```
npx skills add venables/skills --skill startkit
```

Requires `pnpm` on PATH and a Node recent enough to run TypeScript natively (Node 22.6+ for type stripping, 24+ preferred).

## How to use it

Ask Claude Code in plain English whenever you want to start a new TypeScript or Node project from scratch:

- "start a new typescript app"
- "make me a starter"
- "scaffold a typescript project"
- "spin up a fresh TS repo"
- "bootstrap a node/typescript app"
- "create a strict typescript starter"

## What it does

- **Copies the template:** lays down `tsconfig.json`, `vitest.config.ts`, `pnpm-workspace.yaml`, `package.json`, `.gitignore`, `.oxlintrc.json`, `.oxfmtrc.jsonc`, `src/` starter + test, agent docs, and a `.github/workflows/check.yml`.
- **Ultra-strict TypeScript:** `strict` plus `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `noImplicitReturns`, `noUnusedLocals/Parameters`, `noPropertyAccessFromIndexSignature`, and more.
- **oxlint type-aware + oxfmt:** linting also type-checks (via `oxlint-tsgolint`), so there is no separate `tsc` typecheck step, and no ESLint or Prettier.
- **vitest tests:** colocated as `*.test.ts`; `test` is one-shot (`vitest run`), `test:watch` is watch mode.
- **Pins your toolchain:** resolves the active pnpm and Node LTS at scaffold time into `packageManager` + `devEngines`, rather than hardcoding stale versions.
- **CI + verify:** runs `pnpm fix` then `pnpm check` (lint + format:check + test) locally, and installs a GitHub Actions check that runs `pnpm check` on PRs and pushes to `main`.

## Gotchas

- **Base only.** This skill builds the single-package baseline app. If you did not ask for a variant, it builds the base and stops.
- **Variants are stubs.** The monorepo, CLI, and TanStack Start web variants are only sketched in `references/` (intended deltas, not implemented). The skill will build the base and tell you the variant is not filled in yet.
- **pnpm version is pinned to what you run.** It pins your active `pnpm -v`, not the newest published version. Pinning a newer pnpm than is installed hard-blocks every command via `onFail: error`. Run `pnpm self-update` first if you want the latest.
- **24h publish delay.** `minimumReleaseAge: 1440` blocks packages published in the last 24 hours; a fresh release can make install fail until it ages in.
- **Fix before check.** The bundled assets are not pre-formatted to oxfmt's exact output, so `pnpm fix` runs before `pnpm check` to normalize them.
