# coding-standards

A reusable reference of universal coding standards and best practices for TypeScript, JavaScript, React, and Node.js. Hand it to Claude Code so new code follows consistent naming, immutability, error handling, API design, and testing conventions across your projects.

## Install

```
npx skills add venables/skills --skill coding-standards
```

## How to use it

Pull it in whenever you want Claude Code to write or review code against a shared bar:

- "follow our coding standards for this"
- "write this the TypeScript/React best-practices way"
- "make sure this is immutable and properly typed"
- "add input validation and error handling to this API route"
- "check this for code smells before I commit"

## What it does

- **Core principles:** frames every suggestion around readability, KISS, DRY, and YAGNI, favoring the simplest solution that works over clever or speculative code.
- **TypeScript and JavaScript conventions:** descriptive variable names, verb-noun function names, spread-based immutability, comprehensive error handling, parallel `Promise.all`, and proper types instead of `any`.
- **React patterns:** typed functional components, reusable custom hooks, functional state updates, and clear conditional rendering over nested ternaries.
- **API design:** REST conventions, a consistent `ApiResponse<T>` shape, and Zod schema validation for request input.
- **Structure and docs:** project layout, file naming rules, comment-the-why guidance, and JSDoc for public APIs.
- **Performance and testing:** memoization, lazy loading, narrow database selects, plus the AAA test pattern and descriptive test names, with a code-smell checklist for long functions, deep nesting, and magic numbers.

## Gotchas

- **It's a style reference, not a linter.** The skill supplies conventions and examples for Claude to apply; it does not run, format, or automatically enforce anything on your codebase.
- **Opinionated stack assumptions.** Examples lean on Next.js, Zod, and Supabase idioms. The principles are universal, but some snippets assume that toolchain and may not map one-to-one onto other frameworks.
- **General guidance, not project-specific.** These are cross-project defaults. Anything unique to your repo (its own lint config, framework choices, or house rules) still needs to live in that repo and takes precedence.
