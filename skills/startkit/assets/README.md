# PROJECT_NAME

A strict, fast, minimal TypeScript starter.

## What's included

| Tool                                   | Purpose                    |
| -------------------------------------- | -------------------------- |
| [pnpm](https://pnpm.io)                | Package manager            |
| [Node](https://nodejs.org) (native TS) | Runtime, runs `.ts` direct |
| [oxlint](https://oxc.rs)               | Linting (type-aware)       |
| [oxfmt](https://oxc.rs)                | Formatting                 |
| [vitest](https://vitest.dev)           | Testing                    |
| TypeScript                             | Ultra-strict mode          |

No ESLint. No Prettier. No separate typecheck step (oxlint is type-aware).

## Getting started

```bash
pnpm install
pnpm dev
```

## Scripts

```bash
pnpm dev          # Run the app (watch mode)
pnpm test         # Run tests once
pnpm test:watch   # Run tests in watch mode
pnpm check        # lint + format:check + test (CI runs this)
pnpm fix          # Auto-fix lint then format
pnpm lint         # oxlint (type-aware)
pnpm format       # oxfmt
```

## Conventions

- Ultra-strict TypeScript -- no `any`, no `as` casts
- All filenames kebab-case, even React components
- No semicolons, double quotes, imports auto-sorted
- Tests colocated as `*.test.ts`, run with vitest
