---
type: llm
arm: with-only
---

You are grading the assistant's final reply after it cleaned up a repo's
CLAUDE.md.

PASS if the reply says the content now lives in AGENTS.md and reports one of
these outcomes for CLAUDE.md:

- CLAUDE.md was deleted, with the reason that Claude Code reads AGENTS.md
  directly when no CLAUDE.md exists; or
- CLAUDE.md was reduced to a one-line `@AGENTS.md` import, with a stated reason
  such as Bedrock, Vertex, Foundry, an older Claude Code version, a
  CLAUDE.local.md, or Claude-only content kept below the import.

FAIL if CLAUDE.md was kept as a full copy of the content, was replaced with a
symlink, or the reply never says what happened to CLAUDE.md.
