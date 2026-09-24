# optimize-agents-md

Create, audit, and prune `AGENTS.md` / `CLAUDE.md` so every AI coding tool
(Claude Code, Codex, Cursor, Copilot, Gemini, Windsurf) reads one lean source of
truth.

## Install

```bash
npx skills add venables/skills --skill optimize-agents-md
```

## How to use it

Just ask Claude Code in plain English. The skill triggers off natural phrasings:

- "set up CLAUDE.md for this repo"
- "create an AGENTS.md"
- "onboard this repo for Claude Code" / "make Claude follow my conventions"
- "audit my AGENTS.md"
- "my CLAUDE.md is too long, clean it up"
- "we upgraded to Opus 5 / Fable, what can I cut"
- "set this up for Codex / Cursor / Copilot / Gemini / Windsurf too"

## What it does

- Surveys existing instruction files and detects objective facts from the repo
  (package manager, test/lint commands, monorepo layout).
- Classifies every existing line as repo context, model compensation, derivable
  filler, procedure, enforcement, or personal preference, and sends each to the
  right venue.
- Drafts a 30-60 line `AGENTS.md` focused on commands, gotchas, and the
  conventions that differ from what the model would do anyway.
- Wires it for Claude Code: `AGENTS.md` alone by default (Claude Code reads it
  natively since v2.1.277), or a one-line `@AGENTS.md` import in `CLAUDE.md`
  when the team needs it.
- Handles monorepos by deciding what belongs at the root vs. in nested
  per-package files, and avoids the root `CLAUDE.md` that silently hides nested
  `AGENTS.md` files.
- Runs a model-upgrade audit: delete the lines that compensated for an older
  model, keep the lines that encode the repo.

## Gotchas

- **Existing files are hypotheses, not ground truth.** Bloated `AGENTS.md` files
  routinely describe stacks that drifted years ago. The skill verifies stack
  claims against the actual lockfile/source before carrying them forward.
- **Compensation lines rot.** "Always run tests", "double-check", "be thorough",
  and `CRITICAL: you MUST` were written for older models. On Claude 5 generation
  models they cause over-verification and literal over-compliance. Anthropic cut
  over 80% of Claude Code's own system prompt for the same reason.
- **A root CLAUDE.md hides nested AGENTS.md files.** Under Claude Code's default
  setting, any `CLAUDE.md` in the working directory or above switches the whole
  tree to CLAUDE.md-only mode. In monorepos, prefer `AGENTS.md` at every level.
- **Style-guide content is out of scope.** Semicolons, import ordering, naming:
  those belong in ESLint/Prettier/Ruff/etc., not in a file the model re-reads
  every session.

## Tests

`evals/` holds cases for
[`claude plugin eval`](https://code.claude.com/docs/en/plugin-evals). Each case
scaffolds a fixture repo, runs the skill, and grades the resulting files. From
the repo root:

```bash
claude plugin eval skills/optimize-agents-md \
  --scaffold --trust-plugin --no-publish \
  --allow-tools Write Edit Bash \
  --max-cost-usd 30
```

`evals/evals.json` is the older skill-creator format and stays in sync with the
same three scenarios. See `RESEARCH.md` for the sourced findings behind the
advice.
