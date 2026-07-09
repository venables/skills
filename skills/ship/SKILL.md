---
name: ship
description: Matt's standing build-and-ship playbook, from greenlight to merged PR. Use whenever he greenlights implementation work with phrasings like "start on it", "lets build this", "tee it up", "lets get cracking", "implement these", or explicitly says "ship it" for a feature or plan. Also use when he says "panel review loop it and then PR" or "open individual PRs for these". This is the default end-to-end workflow for any non-trivial change; follow it without being asked step by step.
---

# Ship: build to merged PR

This is the standard lifecycle Matt expects for every non-trivial change. He should not have to spell it out each time.

## The playbook

1. **Fresh branch over origin/main.** Never build on a dirty or shared branch. If work is for someone else's PR, stop: do not push to it without explicit approval.
2. **Build in phases, commit often.** Small conventional commits (`feat:`, `fix:`, `refactor:`, ...), each a single logical change, committed as soon as it is coherent. Do not batch a day's work into one commit. If repo instructions say "don't commit unless asked", Matt's preference overrides for his own repos: commit often.
3. **Panel review loop after each phase.** Run the `panel-review-loop` skill when a phase is complete, fix what matters, and continue. This is the universal quality gate before any PR.
4. **Sync with main before PR.** Merge origin/main in, resolve conflicts. If the repo has numbered DB migrations, check that main did not take your migration number while the branch lived; renumber if it did.
5. **Open the PR** with a clear human-readable body:
   - **Problem**: what was wrong or missing.
   - **Solution**: what was done, why this approach was chosen, and how it works.
   - **Testing**: how to validate, plus screenshots for UI states when applicable (use the repo's screenshot convention if one exists in AGENTS.md).
   - Reference the Linear ticket when one exists. When shipping from a plan, include the plan findings in the PR body itself; never commit a `plans/` folder.
   - Multiple independent changes get individual PRs, not one omnibus.
6. **Defer out-of-scope work to Linear**: file tickets in triage, no priority set, and link them in the PR body.
7. **After the PR exists**: monitor CI and fix failures, and handle review comments (use `pr-comment-handler`). Matt merges manually; do not merge unless he says to.

## Standing style rules (repeat offenders)

- Multi-line comments are block comments (`/* ... */` or JSDoc), never stacked `//` lines.
- No emojis anywhere. No emdashes in prose.
- oxlint runs typechecking in Matt's repos (tsgolint/tsgo); do not reach for eslint or raw tsc.

## Phases and continuation

When Matt says "ok that merged, next phase" or "what else do we need", pick up the next unit from the plan, return to step 1 on a fresh branch, and keep the same rhythm.
