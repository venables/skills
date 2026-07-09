# branch-review

A single-session code review of everything on your current branch versus `origin/main`: committed, staged, unstaged, and untracked changes all in one pass. Findings stay in the conversation and are never posted to GitHub or Linear.

## Install

```
npx skills add venables/skills --skill branch-review
```

## How to use it

Ask Claude Code in plain English:

- "review all changes between this branch and origin/main"
- "review my working changes"
- "review this branch locally"
- "look over what I have so far"
- "give this a pre-PR sanity check"

## What it does

- **Full-branch scope:** diffs `origin/main...HEAD` for committed work, `HEAD` for staged and unstaged changes, and `git status --porcelain` for untracked files, so nothing on the branch is missed.
- **Includes untracked files:** new files that aren't committed yet are treated as part of the change, not skipped.
- **Reads in context:** reads the full diff plus enough surrounding code to judge correctness beyond the changed lines.
- **Prioritized findings:** correctness bugs first, then security (auth and money paths get extra scrutiny), then data safety, convention drift, and only clearly-worthwhile simplifications.
- **Structured output:** each finding gets a severity (must-fix / should-fix / nit), a `file:line` reference, a one-sentence issue, and a concrete suggested fix, ending with a verdict on whether it's ready to PR.

## Gotchas

- **In-session only.** Findings live in the conversation. Nothing is posted to GitHub or Linear, so this is a private pre-PR sanity check, not a review of record.
- **Not panel-review.** This is one review from the current session, not a multi-agent panel. If you want independent second opinions from other agents, use `panel-review`.
- **Not a GitHub PR review.** It reviews your local branch state, not a PR on GitHub. For an on-GitHub review, use the appropriate PR review skill instead.
- **No filler praise.** If the branch is clean, it says so in a single line rather than padding the report.
