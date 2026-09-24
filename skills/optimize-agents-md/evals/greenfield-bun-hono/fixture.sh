#!/usr/bin/env bash
set -euo pipefail
mkdir -p src/routes src/lib
cat > package.json <<'JSON'
{
  "name": "acme-api",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "bun run --hot src/index.ts",
    "test": "bun test",
    "test:watch": "bun test --watch",
    "lint": "bunx oxlint .",
    "typecheck": "bunx tsgo --noEmit",
    "format": "bunx oxfmt"
  },
  "dependencies": {
    "hono": "^4.7.0",
    "zod": "^3.24.0"
  },
  "devDependencies": {
    "@types/bun": "^1.2.0",
    "@typescript/native-preview": "^7.0.0-dev",
    "oxfmt": "^0.52.0",
    "oxlint": "^1.67.0"
  }
}
JSON
cat > bun.lock <<'LOCK'
{
  "lockfileVersion": 1,
  "workspaces": {
    "": {
      "name": "acme-api",
      "dependencies": { "hono": "^4.7.0", "zod": "^3.24.0" },
      "devDependencies": { "@types/bun": "^1.2.0", "@typescript/native-preview": "^7.0.0-dev", "oxfmt": "^0.52.0", "oxlint": "^1.67.0" }
    }
  },
  "packages": {}
}
LOCK
cat > tsconfig.json <<'JSON'
{
  "compilerOptions": {
    "target": "ESNext",
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "exactOptionalPropertyTypes": true,
    "baseUrl": ".",
    "paths": { "@/*": ["src/*"] },
    "types": ["bun-types"]
  },
  "include": ["src"]
}
JSON
cat > src/index.ts <<'TS'
import { Hono } from "hono"
import { users } from "@/routes/users"

const app = new Hono()
app.route("/users", users)

export default app
TS
cat > src/routes/users.ts <<'TS'
import { Hono } from "hono"
import { z } from "zod"
import type { TypedResponse } from "hono"
import { listUsers } from "@/lib/users-service"

const querySchema = z.object({ limit: z.coerce.number().int().min(1).max(100).default(20) })

export const users = new Hono().get("/", async (c): Promise<TypedResponse<{ users: { id: string; name: string }[] }>> => {
  const query = querySchema.parse(c.req.query())
  const result = await listUsers(query.limit)
  return c.json({ users: result })
})
TS
cat > src/lib/users-service.ts <<'TS'
import { db } from "@/lib/db"

export const listUsers = async (limit: number) => db.query("select id, name from users limit $1", [limit])
TS
cat > src/lib/db.ts <<'TS'
const url = Bun.env.DATABASE_URL
if (!url) throw new Error("DATABASE_URL is required (local Postgres runs on 5433, not 5432)")

export const db = {
  query: async <T>(_sql: string, _params: unknown[]): Promise<T[]> => [],
}
TS
cat > src/lib/logger.ts <<'TS'
export const logger = {
  info: (msg: string, meta?: Record<string, unknown>) => console.log(JSON.stringify({ level: "info", msg, ...meta })),
  error: (msg: string, meta?: Record<string, unknown>) => console.error(JSON.stringify({ level: "error", msg, ...meta })),
}
TS
cat > README.md <<'MD'
# acme-api

Internal HTTP API for the Acme dashboard. Built with Hono on Bun.

## Setup

Requires `DATABASE_URL` pointing at a local Postgres on port 5433 (5432 is
taken by the legacy service on most dev machines).

```bash
bun install
bun run dev
```

## Conventions

- Route handlers validate input with zod and declare their output type with
  Hono's `TypedResponse` so the client package can infer it.
- Log through `src/lib/logger.ts`, which emits JSON lines the collector
  expects.
MD
cat > .gitignore <<'GI'
node_modules/
.env
GI
git init -q
git add -A
git -c user.name=fixture -c user.email=fixture@example.com commit -q -m "init"
