# tdd-workflow

Enforce test-driven development on any code change: write the tests first, watch them fail, implement until they pass, then refactor. Aims for 80%+ coverage across unit, integration, and E2E tests, with concrete patterns for Vitest/Bun/Jest, API routes, and Playwright.

## Install

```
npx skills add venables/skills --skill tdd-workflow
```

## How to use it

Ask Claude Code in plain English when you start a change:

- "build this feature test-first"
- "fix this bug with TDD"
- "refactor this module and keep it covered"
- "add an API endpoint with tests"
- "create a new component, tests first"

## What it does

- **Tests before code:** Drives the red-green-refactor loop: write user journeys, generate test cases, run them so they fail, implement minimal code to pass, then refactor while green.
- **Three test layers:** Covers unit tests (functions, components, helpers), integration tests (API endpoints, database, service calls), and Playwright E2E for critical user flows.
- **Coverage target:** Pushes for 80%+ across branches, functions, lines, and statements, including edge cases, error paths, and boundary conditions, verified via a coverage report.
- **Concrete patterns:** Supplies ready-to-adapt snippets for component tests, API route tests, E2E specs, and mocking external services, plus a suggested test file layout.
- **Guards against bad tests:** Steers toward user-visible behavior and semantic selectors over implementation details and brittle CSS selectors, and toward isolated, independent tests.

## Gotchas

- **It's a discipline, not a runner:** The skill guides how you write and order tests. It does not install a test framework or configure your toolchain for you.
- **Examples lean on a specific stack:** The snippets assume TypeScript with React Testing Library, Next.js API routes, Playwright, and mocks for services like Supabase, Redis, and OpenAI. Adapt them to your own stack and test runner.
- **Mixed runner references:** Examples reference both `jest.fn`/`jest.mock` and Vitest/Bun test in places. Use the mock API that matches your chosen runner rather than copying verbatim.
- **80% is a floor, not proof:** Coverage thresholds catch untested lines but do not guarantee meaningful assertions. Still test error paths and edge cases deliberately.
