#!/usr/bin/env bash
set -euo pipefail
mkdir -p app/dashboard app/api/events components/charts components/ui src/auth-legacy src/lib scripts tests/e2e
cat > package.json <<'JSON'
{
  "name": "acme-dashboard",
  "version": "2.4.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "test": "vitest run",
    "test:e2e": "playwright test",
    "typecheck": "tsc --noEmit",
    "lint": "eslint .",
    "db:seed": "tsx scripts/seed.ts",
    "db:migrate": "drizzle-kit migrate"
  },
  "dependencies": {
    "next": "^15.3.0",
    "react": "^19.1.0",
    "react-dom": "^19.1.0",
    "zod": "^3.24.0",
    "ioredis": "^5.6.0",
    "drizzle-orm": "^0.44.0",
    "recharts": "^2.15.0"
  },
  "devDependencies": {
    "typescript": "^5.8.0",
    "vitest": "^3.1.0",
    "@playwright/test": "^1.52.0",
    "eslint": "^9.25.0",
    "prettier": "^3.5.0",
    "drizzle-kit": "^0.31.0",
    "tsx": "^4.19.0"
  }
}
JSON
cat > pnpm-lock.yaml <<'YAML'
lockfileVersion: '9.0'
settings:
  autoInstallPeers: true
importers:
  .:
    dependencies:
      next: 15.3.0
      react: 19.1.0
      react-dom: 19.1.0
      zod: 3.24.0
      ioredis: 5.6.0
      drizzle-orm: 0.44.0
      recharts: 2.15.0
    devDependencies:
      typescript: 5.8.0
      vitest: 3.1.0
      '@playwright/test': 1.52.0
      eslint: 9.25.0
      prettier: 3.5.0
      drizzle-kit: 0.31.0
      tsx: 4.19.0
YAML
cat > next.config.ts <<'TS'
import type { NextConfig } from "next"
const config: NextConfig = { reactStrictMode: true }
export default config
TS
cat > app/layout.tsx <<'TSX'
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return <html lang="en"><body>{children}</body></html>
}
TSX
cat > app/dashboard/page.tsx <<'TSX'
import { EventsChart } from "@/components/charts/events-chart"
export default async function DashboardPage() {
  return <main><EventsChart /></main>
}
TSX
cat > app/api/events/route.ts <<'TS'
import { NextResponse } from "next/server"
import { z } from "zod"
const query = z.object({ days: z.coerce.number().int().min(1).max(90).default(7) })
export async function GET(req: Request) {
  const params = query.parse(Object.fromEntries(new URL(req.url).searchParams))
  return NextResponse.json({ days: params.days, events: [] })
}
TS
cat > components/charts/events-chart.tsx <<'TSX'
"use client"
import { LineChart, Line, XAxis, YAxis } from "recharts"
export const EventsChart = () => (
  <LineChart width={600} height={300} data={[]}>
    <XAxis dataKey="day" />
    <YAxis />
    <Line type="monotone" dataKey="count" />
  </LineChart>
)
TSX
cat > components/ui/button.tsx <<'TSX'
export const Button = (props: React.ButtonHTMLAttributes<HTMLButtonElement>) => <button {...props} />
TSX
cat > src/lib/session.ts <<'TS'
import Redis from "ioredis"
const redis = new Redis(process.env.REDIS_URL ?? "redis://localhost:6380")
export const getSession = async (id: string) => redis.get(`session:${id}`)
TS
cat > src/lib/logger.ts <<'TS'
export const logger = { info: (m: string) => console.log(JSON.stringify({ level: "info", m })) }
TS
cat > src/auth-legacy/jwt.ts <<'TS'
// Dead code kept for the mobile client migration. Do not extend.
export const signJwt = (_payload: unknown) => "legacy"
TS
cat > scripts/seed.ts <<'TS'
// WARNING: drops and recreates the events table before inserting fixtures.
console.log("drop table if exists events; create table events (...)")
TS
cat > tests/e2e/dashboard.spec.ts <<'TS'
import { test, expect } from "@playwright/test"
test("dashboard renders", async ({ page }) => { await page.goto("/dashboard"); await expect(page).toHaveTitle(/Acme/) })
TS
cat > CLAUDE.md <<'MD'
# CRITICAL — READ FIRST

- IMPORTANT: ALWAYS run the full test suite after every single change. Never skip this.
- IMPORTANT: Double-check your work before responding. Re-read every file you touched.
- IMPORTANT: Be extremely thorough. Explore the entire codebase before making any change.

# Acme Dashboard — Claude Instructions

You are a senior staff engineer with 15 years of experience in React and
TypeScript. You write clean, elegant, production-grade code. You never cut
corners. You think step by step. You are meticulous, careful, and precise.
Act like the best engineer on the team.

## What is Next.js

Next.js is a React framework that provides server-side rendering, static site
generation, API routes, and file-based routing. It was created by Vercel. The
App Router (introduced in Next.js 13) uses React Server Components by default.
Pages are defined by `page.tsx` files inside the `app/` directory. Layouts are
defined by `layout.tsx`. Route handlers live in `route.ts` files. Client
components must be marked with the `"use client"` directive at the top of the
file. Server components can be async and can fetch data directly.

## Project structure

```
acme-dashboard/
├── app/
│   ├── layout.tsx
│   ├── dashboard/
│   │   └── page.tsx
│   └── api/
│       └── events/
│           └── route.ts
├── components/
│   ├── charts/
│   │   └── events-chart.tsx
│   └── ui/
│       └── button.tsx
├── src/
│   ├── auth-legacy/
│   │   └── jwt.ts
│   ├── lib/
│   │   ├── logger.ts
│   │   └── session.ts
│   └── stores/
├── scripts/
│   └── seed.ts
├── tests/
│   └── e2e/
├── next.config.ts
├── package.json
└── tsconfig.json
```

## Tech stack

- Next.js 15 with the App Router
- React 19
- TypeScript 5
- React Router v6 for client-side navigation
- Zustand for state management (stores live in `src/stores/`)
- MSW (Mock Service Worker) for mocking APIs in tests
- Recharts for charts
- Drizzle ORM with Postgres
- ioredis for sessions
- Vitest for unit tests
- Playwright for end-to-end tests
- ESLint and Prettier
- Tailwind CSS
- pnpm as the package manager

## Commands

- `pnpm dev` — start the dev server
- `pnpm build` — production build
- `pnpm test` — unit tests with vitest
- `pnpm test:e2e` — Playwright end-to-end tests
- `pnpm typecheck` — `tsc --noEmit`
- `pnpm lint` — eslint
- `pnpm db:seed` — seed the local database
- `pnpm db:migrate` — run drizzle migrations

## Code style

- Use 2-space indentation.
- No semicolons.
- Use double quotes for strings.
- Use trailing commas everywhere.
- Maximum line length is 100 characters.
- Sort imports alphabetically: React first, then third-party, then local.
- Use PascalCase for components and camelCase for functions and variables.
- Use kebab-case for file names.
- Prefer `const` over `let`. Never use `var`.
- Prefer arrow functions.
- Always add a blank line between import groups.
- Use explicit return types on exported functions.
- Never use `any`.
- Never use `console.log`.
- Never use default exports (except for Next.js pages and layouts).
- Always destructure props.
- Keep functions under 30 lines.
- Keep files under 300 lines.

## Best practices

- Write clean code.
- Follow DRY. Do not repeat yourself.
- Follow SOLID principles.
- Handle errors gracefully.
- Add tests for every change.
- Write meaningful commit messages.
- Keep components small and focused.
- Use meaningful variable names.
- Comment complex logic.
- Avoid premature optimization.
- Think about edge cases.
- Consider accessibility.
- Consider performance.
- Consider security.

## Component example

```tsx
"use client"

import { useState } from "react"

interface CounterProps {
  initial: number
}

export const Counter = ({ initial }: CounterProps) => {
  const [count, setCount] = useState(initial)
  return (
    <div>
      <span>{count}</span>
      <button onClick={() => setCount((c) => c + 1)}>+</button>
    </div>
  )
}
```

## API route example

```ts
import { NextResponse } from "next/server"
import { z } from "zod"

const schema = z.object({ id: z.string() })

export async function GET(req: Request) {
  const params = schema.parse(Object.fromEntries(new URL(req.url).searchParams))
  return NextResponse.json({ id: params.id })
}
```

## Testing

- IMPORTANT: Run `pnpm test` after every change. Always. No exceptions.
- Run `pnpm test:e2e` before opening a PR.
- Integration tests need a local Redis on port 6380, not the default 6379, because 6379 is taken by the local job queue.
- Use `describe` and `it` blocks.
- Mock external services.
- Aim for 80% coverage.
- Test edge cases.
- Test error paths.

## Database

- The dev seed script (`pnpm db:seed`) drops the `events` table before inserting fixtures. Run it only on a fresh local database.
- Migrations live in `drizzle/` and run with `pnpm db:migrate`.
- Never edit a migration that has been merged.
- Use transactions for multi-table writes.

## Authentication

- Auth uses session cookies backed by Redis. The JWT helpers in `src/auth-legacy/` are dead code kept for the mobile migration; do not extend them or import from them.
- Always validate sessions on the server.
- Never trust client-side auth state.

## Charts

- Do not add your own event handlers inside `components/charts/`. Recharts already wires up hover and click reactivity, and doubling the handlers caused the March dashboard freeze incident.

## Git workflow

- IMPORTANT: Never force-push.
- Use conventional commits: feat, fix, chore, docs, refactor, test.
- Keep commits small.
- Write descriptive PR titles.
- Link the Linear ticket in the PR description.
- Request a review from the frontend team for UI changes.

## Performance

- Use React Server Components where possible.
- Avoid unnecessary client components.
- Lazy-load heavy components.
- Optimize images with next/image.
- Memoize expensive computations.

## Security

- Validate all inputs with zod.
- Never expose secrets to the client.
- Use environment variables for configuration.
- Sanitize user input.
- Use HTTPS in production.

## Accessibility

- Use semantic HTML.
- Add aria labels to interactive elements.
- Ensure keyboard navigation works.
- Test with a screen reader.

## Debugging tips

- Check the browser console for errors.
- Use React DevTools.
- Check the network tab for failed requests.
- Add logging with the logger utility.

# CRITICAL — READ LAST

- IMPORTANT: ALWAYS run the full test suite after every single change. Never skip this.
- IMPORTANT: Double-check your work before responding. Re-read every file you touched.
- IMPORTANT: Be extremely thorough. Explore the entire codebase before making any change.
MD
cat > .gitignore <<'GI'
node_modules/
.next/
.env
GI
git init -q
git add -A
git -c user.name=fixture -c user.email=fixture@example.com commit -q -m "init"
