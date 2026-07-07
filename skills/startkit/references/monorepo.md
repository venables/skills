# Variant: monorepo

STATUS: stub. Not yet implemented. Build the base first, then note to the user
that the monorepo variant is not filled in yet.

Intended deltas over the base (to implement later):

- Root `pnpm-workspace.yaml` gains a `packages:` glob (`apps/*`, `packages/*`)
  alongside the base security settings.
- Root `package.json` is private, holds only workspace-wide scripts, and
  delegates `check`/`test`/`build` to a task runner (turbo or `pnpm -r`).
- `apps/` for deployables, `packages/` for shared libs; each package carries its
  own minimal `package.json` and extends a shared `tsconfig.base.json`.
- Shared config lives in a `packages/config` (or `tooling/`) package so
  `.oxlintrc.json`, `tsconfig.base.json`, and `vitest` setup are defined once.
- CI runs the task runner's `check` across the graph with remote caching off by
  default.

Reference the existing `~/dev/startkit/hono-monorepo` template when building this
out, but modernize it to pnpm + vitest (it currently uses bun + turbo).
