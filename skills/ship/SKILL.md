---
name: ship
description: Your standing build-and-ship playbook, from greenlight to merged PR. Use whenever the user greenlights implementation work with phrasings like "start on it", "lets build this", "tee it up", "lets get cracking", "implement these", or explicitly says "ship it" for a feature or plan. Also use when they say "panel review loop it and then PR" or "open individual PRs for these". This is the default end-to-end workflow for any non-trivial change; follow it without being asked step by step.
---

# Ship: build to merged PR

This is the standard lifecycle for every non-trivial change. The user should not have to spell it out each time.

## The playbook

1. **Fresh branch over origin/main.** Never build on a dirty or shared branch. If work is for someone else's PR, stop: do not push to it without explicit approval.
2. **Build in phases, commit often.** Small conventional commits (`feat:`, `fix:`, `refactor:`, ...), each a single logical change, committed as soon as it is coherent. Do not batch a day's work into one commit. If repo instructions say "don't commit unless asked", this playbook overrides for the user's own repos: commit often.
3. **Panel review loop after each phase.** Run the `panel-review-loop` skill when a phase is complete, fix what matters, and continue. This is the universal quality gate before any PR.
4. **Sync with main before PR.** Merge origin/main in, resolve conflicts. If the repo has numbered DB migrations, check that main did not take your migration number while the branch lived; renumber if it did.
5. **Open the PR** using the `write-pull-request` skill. It writes the plain-language title and the skimmable body (a `Changes` list first, then Problem/Solution or a Goal for a net-new feature, then Testing), checks for a repo PR template, and opens the PR. Reference the tracker ticket when one exists, fold plan findings into the body rather than committing a `plans/` folder, and give multiple independent changes their own PRs, not one omnibus.
6. **Defer out-of-scope work to Linear**: file tickets in triage, no priority set, and link them in the PR body.
7. **After the PR exists**: monitor CI and fix failures, and handle review comments (use `pr-comment-handler`). The user merges manually; do not merge unless they say to.

## Standing style rules (repeat offenders)

- Every word that lands on GitHub or Linear — PR title, PR body, review comment, reply, ticket — is written in ASD-STE100 Simplified Technical English: short sentences (20 words for an instruction, 25 for a statement), one idea per sentence, active voice, simple tenses, one word for one meaning, no jargon, no idioms, no metaphors. `write-pull-request` and `pr-comment-handler` each carry the full rule.
- Multi-line comments are block comments (`/* ... */` or JSDoc), never stacked `//` lines.
- No emojis anywhere. No emdashes in prose.
- oxlint runs typechecking in these repos (tsgolint/tsgo); do not reach for eslint or raw tsc.

## Phases and continuation

When the user says "ok that merged, next phase" or "what else do we need", pick up the next unit from the plan, return to step 1 on a fresh branch, and keep the same rhythm.
