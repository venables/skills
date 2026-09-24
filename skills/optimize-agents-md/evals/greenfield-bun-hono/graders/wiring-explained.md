---
type: llm
arm: with-only
---

You are grading the assistant's final reply after it set up agent instructions
for a repo.

PASS if the reply states that Claude Code reads AGENTS.md directly (natively,
without a CLAUDE.md), and therefore either no CLAUDE.md was created, or a
CLAUDE.md containing only an `@AGENTS.md` import was created for a stated reason
(for example Bedrock, Vertex, Foundry, an older Claude Code version, a
CLAUDE.local.md, or Claude-only content).

FAIL if the reply creates a CLAUDE.md symlink, creates a CLAUDE.md with
duplicated content, says CLAUDE.md is required for Claude Code, or never
addresses how Claude Code will read the file.
