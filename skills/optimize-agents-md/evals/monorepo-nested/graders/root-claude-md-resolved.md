---
type: llm
arm: with-only
---

You are grading the assistant's final reply after it restructured a monorepo's
agent instructions into a root AGENTS.md plus nested AGENTS.md files.

Background fact: under Claude Code's default setting, any CLAUDE.md in the
working directory or above it makes Claude Code skip every AGENTS.md, including
nested ones. Nested AGENTS.md files load only when there is no CLAUDE.md on the
path.

PASS if the reply reports one of these outcomes:

- The root CLAUDE.md was deleted and no CLAUDE.md remains, so Claude Code reads
  the root and nested AGENTS.md files directly; or
- A root CLAUDE.md was kept (as an `@AGENTS.md` import) for a stated reason, AND
  the reply says each nested AGENTS.md got its own sibling CLAUDE.md import so
  the nested files still load.

FAIL if a root CLAUDE.md remains without sibling imports in the nested packages,
if CLAUDE.md became a symlink, if the reply keeps CLAUDE.md as a duplicate of
AGENTS.md, or if the reply never says what happened to CLAUDE.md.
