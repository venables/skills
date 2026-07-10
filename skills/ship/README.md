# ship

Your standing build-to-merged-PR playbook: the default end-to-end lifecycle for any non-trivial change, from greenlight to an open PR. Follow the same rhythm every time so you never have to spell out the steps.

## Install

```
npx skills add venables/skills --skill ship
```

## How to use it

Just greenlight the work in plain English and Claude Code runs the whole playbook:

- "start on it"
- "lets build this"
- "tee it up"
- "lets get cracking"
- "implement these" / "ship it"
- "panel review loop it and then PR"
- "open individual PRs for these"

## What it does

- **Starts on a fresh branch over origin/main.** Never builds on a dirty or shared branch. If the work belongs to someone else's PR, it stops rather than pushing without approval.
- **Builds in phases with small conventional commits.** Each commit (`feat:`, `fix:`, `refactor:`, ...) is a single logical change, committed as soon as it is coherent, never batching a day's work into one commit.
- **Runs a panel review loop after each phase.** Delegates to the `panel-review-loop` skill, fixes what matters, and continues. This is the universal quality gate before any PR.
- **Syncs with main before the PR.** Merges origin/main in and resolves conflicts, and for repos with numbered DB migrations, renumbers if main claimed your number while the branch lived.
- **Titles the PR in plain language.** Says what changed and its effect, so the PR list is readable without opening anything. Keeps the repo's conventional-commit prefix, but never lets a ticket ID, codename, or file path carry the meaning.
- **Opens the PR with a skimmable body:** Changes (an unordered list of short lines, one per change, so the diff is legible in seconds), then Problem (what was wrong or missing), Solution (what was done, why this approach, how it works), and Testing (how to validate, plus screenshots for UI states). References the Linear ticket when one exists, and folds plan findings into the PR body rather than committing a `plans/` folder. Multiple independent changes get individual PRs, not one omnibus.
- **Defers out-of-scope work to a tracker.** Files Linear tickets in triage with no priority set and links them in the PR body.
- **Monitors CI and handles comments after the PR exists.** Fixes CI failures and routes review comments through the `pr-comment-handler` skill.
- **Never merges for you.** You merge manually; it will not merge unless you say to.

## Gotchas

- **It delegates to other skills.** The panel gate calls `panel-review-loop` and comment handling calls `pr-comment-handler`, so install those too for the full workflow.
- **It assumes an oxlint/tsgo toolchain and a Linear tracker.** Typechecking runs through oxlint (tsgolint/tsgo), not eslint or raw tsc, and deferred work goes to Linear. Adapt these to your own stack if they differ.
- **It deliberately does not merge.** The playbook ends at an open, green, comment-handled PR and leaves the merge to you.
- **It overrides "do not commit unless asked" in favor of committing often.** For your own repos, this opinionated preference wins over a repo instruction that says to hold commits.
- **Style rules travel with it.** Multi-line comments are block comments (never stacked `//`), and no emojis or emdashes anywhere.
