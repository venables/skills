# pr-comment-handler

Autonomously work through the open review comments on a GitHub PR using your own judgment. Fixes what's valid, defers worthwhile-but-out-of-scope work to a Linear ticket, replies to every comment with the fix / ticket / rationale, and resolves the threads it handled.

This is the lean, judgment-first version: it doesn't ask you to pre-approve a triage plan or stop at a push checkpoint. You hand it the PR; it acts and reports back.

## Install

```
npx skills add venables/skills --skill pr-comment-handler
```

## How to use it

From the PR's branch, just ask Claude Code in plain English:

- "check all the comments on the PR and fix the ones you think are valid and relevant"
- "handle the review comments on this PR"
- "address the PR feedback and reply to each comment"
- "work through the reviewers' comments"

If you don't name a PR, it auto-detects from your current branch via `gh pr view`.

## The contract

Whatever it decides per comment, it holds to three things:

- **Every open comment gets a reply** — no thread left silent.
- **Each reply carries an answer** — the fix and its commit SHA, the Linear ticket link, or an honest rationale for not fixing.
- **Handled threads get resolved.**

Everything else — which comments deserve a fix, what the fix is, what's out of scope — is left to the model's judgment.

## What it does

- Fetches every open review thread (resolved/outdated dropped by default).
- For each comment, decides **fix**, **defer**, or **decline** on its own.
- Commits each fix separately (one commit per comment), pushes, and replies `Fixed in <sha> — <summary>`.
- For deferrals: files a Linear ticket (no priority — that's the receiving team's call) and replies with the link.
- For declines: replies with a short, honest rationale.
- Resolves each thread it genuinely handled, then reports counts, the pushed commit range, and any Linear links.

## Gotchas

- **Be on the PR's branch with a clean tree.** It bails rather than auto-stashing or `gh pr checkout`-ing (both can quietly discard work).
- **Auto-pushes by default.** It commits and pushes without a checkpoint unless you tell it to hold. Say "don't push" / "stop before pushing" if you want to inspect first.
- **Linear MCP needed for deferrals.** Without it, fixes and declines still work; it tells you what it would have filed.
- **Different from `post-panel-review-comments`** (which posts _new_ findings) and `panel-review` (which _generates_ them). This one _consumes_ comments already on the PR.

## Scripts

One script, for the one fiddly part:

- `scripts/fetch_pr_comments.sh <pr>` — open threads + review summaries as JSON (GraphQL under the hood, since REST doesn't expose per-thread resolution state).

Replying and resolving threads are plain inline `gh api` calls — see SKILL.md.
