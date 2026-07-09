# verify

Run a quick, repeatable quality pass over your changes before you open a PR: build and test checks, a lightweight secret and debug-log scan, and a diff review, all summarized in one PASS/FAIL verification report.

## Install

```
npx skills add venables/skills --skill verify
```

## How to use it

Ask Claude Code in plain English, usually right after finishing a chunk of work:

- "verify this"
- "run the verification loop"
- "make sure quality gates pass before I open a PR"
- "check this over after the refactor"
- "is this ready for a PR?"

## What it does

- **Runs checks:** executes the project's build/type/lint/test command (`bun run check`, or `make check` for Makefile projects) and stops to fix failures before going further.
- **Security scan:** greps changed code for leaked secrets (`sk-`, `api_key`) and stray `console.log` calls.
- **Diff review:** runs `git diff --stat` and inspects changed files for unintended edits, missing error handling, and unhandled edge cases.
- **Verification report:** rolls the phases into a single report with PASS/FAIL per gate (build, types, lint, tests, security, diff) and an overall READY / NOT READY verdict plus an issues-to-fix list.
- **Continuous mode:** for long sessions, re-runs the pass at checkpoints (after each function or component, before the next task) so quality stays green as you go.

## Gotchas

- **Checks come first.** If Phase 1 build/test checks fail, the skill stops and fixes them before scanning or reviewing the diff.
- **The scan is grep-based.** The secret and `console.log` checks are simple pattern matches, not a full security audit; they catch obvious cases, not everything.
- **Commands assume a bun or Makefile project.** The default `bun run check` / `make check` may need adapting for other stacks.
