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
5. **Open the PR** with a title and body a human can skim. See "PR title" and "PR body" below.
   - Reference the Linear ticket when one exists. When shipping from a plan, include the plan findings in the PR body itself; never commit a `plans/` folder.
   - Multiple independent changes get individual PRs, not one omnibus.
6. **Defer out-of-scope work to Linear**: file tickets in triage, no priority set, and link them in the PR body.
7. **After the PR exists**: monitor CI and fix failures, and handle review comments (use `pr-comment-handler`). The user merges manually; do not merge unless they say to.

## PR title

Write the title in plain language, so someone scanning a list of PRs understands what changed without opening it. Keep the repo's conventional-commit prefix when it uses one; everything after the prefix reads like a sentence a person would say out loud.

Say what changed and, where it fits, the effect. Do not describe the implementation, and never lean on a ticket ID, a codename, or a file path to carry the meaning.

| Instead of                       | Write                                                  |
| -------------------------------- | ------------------------------------------------------ |
| `fix: CHK-1042`                  | `fix: stop double-charging cards on retried checkouts` |
| `fix: patch the retry handler`   | `fix: stop double-charging cards on retried checkouts` |
| `refactor: update auth.ts`       | `refactor: move session checks into one middleware`    |
| `feat: wire up the new endpoint` | `feat: let admins export a team's invoices as CSV`     |

## PR body

Four sections, in this order. `Changes` comes first because it is what reviewers read.

### Changes

An unordered list of what changed, one short line each, so the whole diff is legible in a few seconds.

- One line per change, and keep it under about ten words.
- Lead with the thing that changed, not with "Added" or "Updated".
- No paragraphs, no nested bullets, no trailing prose. If a line needs a subordinate clause, it belongs in `Solution`.
- Group by what a reader cares about, not by file.

```markdown
## Changes

- Retried checkouts no longer double-charge
- `charge()` deduplicates on idempotency key
- Failed retries now surface to the user
- Regression test for the retry path
```

### Problem

What was wrong or missing.

### Solution

What was done, why this approach was chosen, and how it works. This is where the reasoning and the walls of text go, not in `Changes`.

### Testing

How to validate, plus screenshots for UI states when applicable (use the repo's screenshot convention if one exists in AGENTS.md).

## Standing style rules (repeat offenders)

- Multi-line comments are block comments (`/* ... */` or JSDoc), never stacked `//` lines.
- No emojis anywhere. No emdashes in prose.
- oxlint runs typechecking in these repos (tsgolint/tsgo); do not reach for eslint or raw tsc.

## Phases and continuation

When the user says "ok that merged, next phase" or "what else do we need", pick up the next unit from the plan, return to step 1 on a fresh branch, and keep the same rhythm.
