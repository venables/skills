# AGENTS.md

## Commands

```bash
pnpm install       # Install dependencies
pnpm dev           # Run the app (node --watch, native TS)
pnpm test          # Run tests once (vitest run)
pnpm test:watch    # Run tests in watch mode

pnpm check         # lint + format:check + test (what CI runs)
pnpm fix           # Auto-fix lint then format
pnpm lint          # oxlint, type-aware (no separate typecheck needed)
pnpm format        # oxfmt
```

There is no `typecheck` script: oxlint runs with `typeAware` + `typeCheck`
enabled, so type errors surface through `pnpm lint`.

## Coding Rules

- Use `pnpm`. Never `npm` or `yarn`.
- ALL filenames are kebab-case, including React components
  (`user-card.tsx`, not `UserCard.tsx`).
- ALWAYS strict TypeScript. NEVER use `any`.
- AVOID inline casting with `as`; validate with `valibot` or `zod` instead.
- ALWAYS create new objects/arrays; never mutate. Immutability matters.
- Use `vitest` for tests, colocated with source as `*.test.ts`.
- PREFER many small, focused files over few large ones; organize by
  feature/domain, not by type.
- PREFER thin input layers (route handlers, CLI commands) that validate and
  delegate to services.
- AVOID unnecessary try/catch.
- AVOID mocking in tests where a real implementation is cheap.
- Use clear names over inline comments; block comments for multi-line notes.

## UI & styling

- For ANY CSS/styling, use the latest **Tailwind CSS** (v4, global CSS file
  format) by default. Do not reach for CSS Modules, styled-components, or plain
  stylesheets unless there is a specific reason.
- For UI components, use **shadcn/ui** whenever possible instead of hand-rolling
  or pulling in another component library.
- When using shadcn/ui, use **Base UI** (`@base-ui/react`) as the primitive
  layer, NOT Radix. Install shadcn components in their Base UI variant.

## Before marking work complete

- [ ] `pnpm check` passes
- [ ] Files are focused, functions small, no deep nesting
- [ ] No `console.log`, hardcoded values, or secrets
- [ ] No mutation (immutable patterns used)
