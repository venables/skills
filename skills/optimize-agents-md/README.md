# optimize-agents-md

Create, audit, and prune `AGENTS.md` / `CLAUDE.md` so every AI coding tool (Claude Code, Codex, Cursor, Copilot, Gemini, Windsurf) reads one lean source of truth.

## Install

```
npx skills add venables/skills --skill optimize-agents-md
```

## What it does

- Surveys existing instruction files and detects objective facts from the repo (package manager, test/lint commands, monorepo layout).
- Drafts a 60-80 line `AGENTS.md` focused on non-obvious knowledge — the stuff a linter can't enforce.
- Wires `CLAUDE.md` to `@AGENTS.md` so Claude-specific behavior stays scoped without duplication.
- Handles monorepos by deciding what belongs at the root vs. in nested per-package files.

## Gotchas

- **Existing files are hypotheses, not ground truth.** Bloated `AGENTS.md` files routinely describe stacks that drifted years ago. The skill verifies stack claims against the actual lockfile/source before carrying them forward.
- **Compliance has a budget.** Frontier LLMs reliably follow ~150-200 instructions per session. Every line dilutes compliance with all the others — when in doubt, the skill cuts.
- **Style-guide content is out of scope.** Semicolons, import ordering, naming — those belong in ESLint/Prettier/Ruff/etc., not in a file the model has to re-read every turn.
