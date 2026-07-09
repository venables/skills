# find-docs

Pulls up-to-date documentation, API references, and code examples for any developer library, framework, SDK, CLI, or cloud service. It resolves a library name to a stable ID and then queries current docs, so answers reflect the latest API instead of stale training data.

## Install

```
npx skills add venables/skills --skill find-docs
```

Requires the [Context7 CLI](https://www.npmjs.com/package/ctx7) (`ctx7`) on PATH, run as `npx ctx7@latest` or installed globally with `npm install -g ctx7@latest`. Works without auth; set `CONTEXT7_API_KEY` (or run `ctx7 login`) for higher rate limits.

## How to use it

Ask Claude Code in plain English whenever you have a library-specific question:

- "how do I set up the Next.js app router with middleware?"
- "what's the current React useEffect cleanup pattern for async work?"
- "show me Prisma one-to-many relations with cascade delete"
- "how do I configure JWT auth in Express?"
- "walk me through migrating to Tailwind v4"

## What it does

- **Two-step lookup:** Runs `ctx7 library <name> <query>` to resolve a Context7 ID (`/org/project`), then `ctx7 docs <id> <query>` to fetch docs and examples.
- **Smart selection:** Ranks matches by name similarity, description relevance, code-snippet count, source reputation, and benchmark score, and asks for clarification when a query is ambiguous.
- **Version awareness:** Uses a version-specific ID (`/org/project/version`) when you mention a version, drawn from the `ctx7 library` output.
- **Query hygiene:** Turns your full question into a specific query, since vague one-word queries return generic results.
- **Honest fallbacks:** On a quota error it tells you why Context7 was skipped and suggests authenticating rather than silently answering from training data.

## Gotchas

- **Three-command cap.** It runs Context7 at most 3 times per question and uses the best result it has if it can't find what it needs by then.
- **Library IDs need the `/` prefix and a resolve step first.** `ctx7 docs react "hooks"` fails; you must call `ctx7 library` first unless the user supplies a `/org/project` ID directly.
- **Docs only.** Use it for API syntax, config options, version migrations, setup, and CLI usage, not for refactoring, writing scripts from scratch, debugging your own business logic, or general programming concepts.
- **Never put secrets in queries.** API keys, passwords, credentials, personal data, or proprietary code do not belong in the query text.
- **Sandbox/DNS caveat.** Run Context7 outside a restrictive sandbox; on ENOTFOUND, host-resolution, or fetch failures, rerun outside the sandbox instead of retrying inside it.
