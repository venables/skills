---
type: llm
focus: { source: file, path: AGENTS.md }
weight: 2
---

You are grading an AGENTS.md written for a small bun + Hono API repo.

PASS only if ALL of these hold:

- The file is under 120 lines.
- It names the exact commands from package.json (`bun test`, `bunx oxlint .`,
  `bunx tsgo --noEmit`, or the `bun run`/`bun` script equivalents) inside code
  formatting, not just "run the tests".
- It records at least one repo-specific fact the model could not guess from the
  code alone, such as the Postgres port 5433 / DATABASE_URL requirement, the
  TypedResponse convention, or the logger convention.
- It contains no directory tree or file-by-file listing.
- It contains no personality or role instruction ("you are a senior engineer").
- It contains no verification reminder such as "always run the tests",
  "double-check your work", "verify before responding", or "be thorough".
- It does not repeat the same rules in a block at the top and again at the
  bottom.
- It does not shout: no more than one line uses IMPORTANT, CRITICAL, MUST, or
  NEVER in capitals.

FAIL if any check above fails, or if AGENTS.md is missing.
