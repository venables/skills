# panel-review

Fan a code review out to multiple local CLI coding agents (codex, claude, opencode, gemini) running in parallel, then synthesize their findings into one report. In deep mode, each agent gets its own isolated git worktree so they can run tests and chase downstream effects in parallel without stepping on each other.

## What it does

- Builds a unified diff from the chosen target (`--uncommitted` / `--staged` / `--base` / `--commit` / `--pr`).
- Spawns each panelist as a fresh, non-interactive subprocess with no shared conversation state — the whole point is independent second opinions.
- Streams each panelist's section back as it lands, then groups results into consensus / unique findings / disagreements.
- `--checkout` deep mode spins up **a dedicated, throwaway git worktree per panelist**, all pinned to the same commit. Agents can run tests, install deps, and grep callers in parallel without racing each other's `node_modules/` / `target/` / `.next/`. One network fetch up front, then local-only worktree creation; everything is `git worktree remove --force`'d on exit.

## Gotchas

- **Background Bash + `BashOutput` polling is required.** Codex dominates wall clock, so foreground calls block silently for minutes. Do not launch via the `Agent` tool / subagents — there's no streaming-output API for in-flight subagents and the heartbeats become invisible.
- **Deep mode is strictly less safe than the default.** `--checkout` gives panelists write/exec access in the worktree and shares your parent repo's `.git` objects, so a stray `git push` from a panelist would publish from your machine. The prompt forbids it, but the prompt is a firewall, not a sandbox.
- **Each panelist embeds the full diff in its prompt.** Big rename / refactor PRs blow past the 200KB cap — bump `PANEL_REVIEW_MAX_DIFF_BYTES` rather than trimming the diff.
- Panelists pick up the project's `AGENTS.md` / `CLAUDE.md` — that's intentional, but worth knowing if the file biases their review.
