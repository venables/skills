#!/usr/bin/env bash
set -euo pipefail
mkdir -p apps/web/src/routes apps/api/src/routes packages/shared/src infra
cat > package.json <<'JSON'
{
  "name": "acme",
  "private": true,
  "scripts": {
    "build": "turbo run build",
    "test": "turbo run test",
    "lint": "turbo run lint",
    "typecheck": "turbo run typecheck",
    "format": "oxfmt"
  },
  "devDependencies": { "turbo": "^2.5.0", "oxfmt": "^0.52.0", "oxlint": "^1.67.0", "typescript": "^5.8.0" },
  "packageManager": "pnpm@10.33.2"
}
JSON
cat > pnpm-workspace.yaml <<'YAML'
packages:
  - apps/*
  - packages/*
  - infra
YAML
cat > pnpm-lock.yaml <<'YAML'
lockfileVersion: '9.0'
importers:
  .:
    devDependencies:
      turbo: 2.5.0
      oxfmt: 0.52.0
      oxlint: 1.67.0
      typescript: 5.8.0
  apps/web:
    dependencies:
      react: 19.1.0
      react-dom: 19.1.0
      '@tanstack/react-router': 1.120.0
      '@acme/shared': link:../../packages/shared
    devDependencies:
      vite: 6.3.0
      '@vitejs/plugin-react': 4.4.0
      vitest: 3.1.0
      tailwindcss: 4.1.0
  apps/api:
    dependencies:
      hono: 4.7.0
      zod: 3.24.0
      drizzle-orm: 0.44.0
      '@acme/shared': link:../../packages/shared
    devDependencies:
      drizzle-kit: 0.31.0
      vitest: 3.1.0
  packages/shared:
    dependencies:
      zod: 3.24.0
  infra:
    dependencies:
      '@pulumi/pulumi': 3.160.0
      '@pulumi/aws': 6.75.0
YAML
cat > turbo.json <<'JSON'
{ "$schema": "https://turbo.build/schema.json", "tasks": { "build": { "dependsOn": ["^build"] }, "test": {}, "lint": {}, "typecheck": { "dependsOn": ["^build"] } } }
JSON
cat > apps/web/package.json <<'JSON'
{ "name": "@acme/web", "private": true, "scripts": { "dev": "vite", "build": "vite build", "test": "vitest run", "lint": "oxlint .", "typecheck": "tsc --noEmit" },
  "dependencies": { "react": "^19.1.0", "react-dom": "^19.1.0", "@tanstack/react-router": "^1.120.0", "@acme/shared": "workspace:*" },
  "devDependencies": { "vite": "^6.3.0", "@vitejs/plugin-react": "^4.4.0", "vitest": "^3.1.0", "tailwindcss": "^4.1.0" } }
JSON
cat > apps/web/vite.config.ts <<'TS'
import { defineConfig } from "vite"
import react from "@vitejs/plugin-react"
export default defineConfig({ plugins: [react()] })
TS
cat > apps/web/src/main.tsx <<'TSX'
import { createRoot } from "react-dom/client"
import { RouterProvider, createRouter } from "@tanstack/react-router"
import { routeTree } from "./routeTree.gen"
const router = createRouter({ routeTree })
createRoot(document.getElementById("root")!).render(<RouterProvider router={router} />)
TSX
cat > apps/web/src/routes/index.tsx <<'TSX'
import { createFileRoute } from "@tanstack/react-router"
export const Route = createFileRoute("/")({ component: () => <h1>Acme</h1> })
TSX
cat > apps/api/package.json <<'JSON'
{ "name": "@acme/api", "private": true, "scripts": { "dev": "tsx watch src/index.ts", "build": "tsc -p .", "test": "vitest run", "lint": "oxlint .", "typecheck": "tsc --noEmit", "db:migrate": "drizzle-kit migrate", "db:generate": "drizzle-kit generate" },
  "dependencies": { "hono": "^4.7.0", "zod": "^3.24.0", "drizzle-orm": "^0.44.0", "@acme/shared": "workspace:*" },
  "devDependencies": { "drizzle-kit": "^0.31.0", "vitest": "^3.1.0", "tsx": "^4.19.0" } }
JSON
cat > apps/api/src/index.ts <<'TS'
import { Hono } from "hono"
import { accounts } from "./routes/accounts"
const app = new Hono()
app.route("/accounts", accounts)
export default app
TS
cat > apps/api/src/routes/accounts.ts <<'TS'
import { Hono } from "hono"
import type { TypedResponse } from "hono"
import { accountSchema } from "@acme/shared"
export const accounts = new Hono().get("/:id", (c): TypedResponse<{ id: string }> => c.json({ id: accountSchema.shape.id.parse(c.req.param("id")) }))
TS
cat > packages/shared/package.json <<'JSON'
{ "name": "@acme/shared", "version": "0.0.0", "private": true, "main": "src/index.ts", "dependencies": { "zod": "^3.24.0" } }
JSON
cat > packages/shared/src/index.ts <<'TS'
import { z } from "zod"
export const accountSchema = z.object({ id: z.string().uuid(), name: z.string() })
export type Account = z.infer<typeof accountSchema>
TS
cat > infra/package.json <<'JSON'
{ "name": "@acme/infra", "private": true, "dependencies": { "@pulumi/pulumi": "^3.160.0", "@pulumi/aws": "^6.75.0" } }
JSON
cat > infra/Pulumi.yaml <<'YAML'
name: acme
runtime: nodejs
description: Acme AWS infrastructure
YAML
cat > infra/index.ts <<'TS'
import * as aws from "@pulumi/aws"
export const bucket = new aws.s3.Bucket("acme-assets")
TS
cat > CLAUDE.md <<'MD'
# CRITICAL — READ FIRST

- IMPORTANT: ALWAYS run `pnpm test` after every change.
- IMPORTANT: Double-check your work before responding.
- IMPORTANT: Never run `pulumi destroy`.

# Acme monorepo

You are a senior engineer. Be careful, thorough, and precise. Think step by
step before acting.

## Repository layout

```
acme/
├── apps/
│   ├── web/          # Vite + React + TanStack Router
│   └── api/          # Hono + Zod + Drizzle
├── packages/
│   └── shared/       # zod schemas shared by web and api
├── infra/            # Pulumi (AWS)
├── turbo.json
├── pnpm-workspace.yaml
└── package.json
```

## Workspace commands

- `pnpm test` — runs `turbo run test` across every package
- `pnpm typecheck` — `turbo run typecheck`
- `pnpm lint` — `turbo run lint` (oxlint)
- `pnpm build` — `turbo run build`
- `pnpm --filter @acme/api test` — one package
- `pnpm format` — oxfmt across the repo

## Cross-cutting conventions

- Shared types and zod schemas live in `packages/shared` and are imported as `@acme/shared`. Never duplicate a schema inside an app; the API and the web client must agree on the same source.
- Apps never import from each other. If web needs something from api, it goes through `@acme/shared` or the HTTP API.
- Conventional commits: feat, fix, chore, docs, refactor, test, ci.
- kebab-case file names everywhere.
- `pnpm typecheck` must pass before opening a PR; CI runs the same command.

## Web app (apps/web)

- Vite + React 19 + TanStack Router. Routes are file-based under `src/routes/`; `routeTree.gen.ts` is generated, never edit it by hand.
- Use TanStack Router loaders for data, not `useEffect` fetches; the March 2026 dashboard flicker came from a `useEffect` fetch racing the loader.
- Tailwind v4 with the single global CSS file; do not add `tailwind.config.js`, v4 does not use it.
- Components go in `src/components/` as kebab-case files exporting a named component.
- Prefer shadcn/ui primitives before writing a new primitive.
- Keep components small. Split anything over 150 lines.
- Use `pnpm --filter @acme/web dev` to run the dev server on port 5173.
- Vitest with `@testing-library/react`; test behavior, not implementation.
- Never use default exports in the web app.
- Always add aria labels to interactive elements.

## API (apps/api)

- Hono route handlers stay thin: validate with zod from `@acme/shared`, call a service in `src/services/`, return a `TypedResponse<T>` so the client can infer types.
- Every handler declares its response type with `TypedResponse<T>`; untyped `c.json()` breaks the client's inference and has been caught in review three times.
- Drizzle migrations: `pnpm --filter @acme/api db:generate` after a schema change, then `pnpm --filter @acme/api db:migrate`. Never edit a merged migration.
- Local Postgres runs on port 5433 because 5432 is used by the legacy service.
- Services throw `AppError` from `src/lib/errors.ts`; the global error handler maps it to HTTP. Do not return error objects from services.
- Use `pnpm --filter @acme/api dev` to run the API on port 3000.
- Log through `src/lib/logger.ts` (JSON lines); the collector cannot parse plain text.
- Always validate inputs.
- Handle errors gracefully.

## Infrastructure (infra)

- Pulumi with the AWS provider. Stacks are `dev`, `staging`, and `prod`; the stack name is the environment name, nothing else.
- `pulumi up` runs only from CI. Locally, run `pulumi preview` and paste the diff in the PR.
- Secrets go through `pulumi config set --secret`; never commit a plaintext secret to `Pulumi.<stack>.yaml`.
- Never run `pulumi destroy` against any stack; the prod bucket has versioning and retention that destroy will fail on halfway, leaving the stack half-torn-down (this happened in February).
- Resource names are prefixed with `acme-` and suffixed with the stack name.
- Tag every resource with `Environment` and `Owner`.

## Code style

- 2-space indentation, no semicolons, double quotes, trailing commas.
- Sort imports.
- No `any`. Prefer zod over inline `as` casts.
- Prefer immutability; never mutate arrays or objects in place.
- Small functions.
- Write clean code.
- Follow DRY.

## Best practices

- Add tests for every change.
- Write meaningful commit messages.
- Comment complex logic.
- Consider performance.
- Consider security.

# CRITICAL — READ LAST

- IMPORTANT: ALWAYS run `pnpm test` after every change.
- IMPORTANT: Double-check your work before responding.
- IMPORTANT: Never run `pulumi destroy`.
MD
cat > .gitignore <<'GI'
node_modules/
dist/
.turbo/
GI
git init -q
git add -A
git -c user.name=fixture -c user.email=fixture@example.com commit -q -m "init"
