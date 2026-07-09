# frontend-patterns

A reference of modern frontend patterns for React and Next.js: component composition, custom hooks, state management, performance, forms, error boundaries, animation, and accessibility. Pull it in when you want Claude Code to build UI that follows these conventions instead of improvising.

## Install

```
npx skills add venables/skills --skill frontend-patterns
```

## How to use it

Ask Claude Code in plain English while working on frontend code:

- "build a compound Tabs component"
- "add a debounce hook for this search input"
- "set up context + reducer state for this feature"
- "virtualize this long list"
- "make this form controlled with validation"
- "add an error boundary around the dashboard"

## What it does

- **Component patterns:** shows composition over inheritance, compound components with context, and render-prop data loaders as typed React examples.
- **Custom hooks:** provides reusable `useToggle`, `useQuery`-style async fetching, and `useDebounce` hook implementations.
- **State and performance:** covers the context + reducer pattern plus memoization (`useMemo`, `useCallback`, `React.memo`), code splitting with lazy/Suspense, and list virtualization via `@tanstack/react-virtual`.
- **Forms and errors:** demonstrates controlled forms with manual validation and a class-based error boundary with a fallback UI.
- **Animation and accessibility:** includes Framer Motion list and modal animations, keyboard navigation, and focus management patterns.

## Gotchas

- **Reference, not a library:** it is a set of illustrative code patterns to follow, not an installable package of components or hooks. Adapt the snippets to your codebase.
- **Assumes React and TypeScript:** every example is typed TSX targeting React and Next.js. It does not cover other frameworks.
- **Some examples pull in third-party deps:** virtualization uses `@tanstack/react-virtual` and animations use `framer-motion`, which you would need to install yourself.
- **Patterns are illustrative, not prescriptive:** the guidance is to choose patterns that fit your project's complexity, so treat these as starting points rather than mandates.
