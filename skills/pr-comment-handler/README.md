# pr-comment-handler

End-to-end handling of existing GitHub PR review comments. Reads every open thread, classifies each one as fix / push-back / defer-to-Linear, makes the code changes, replies on the right thread, and posts fix-replies with commit SHAs after you push.

## Install

```
npx skills add venables/skills --skill pr-comment-handler
```

## How to use it

Just ask Claude Code in plain English from the PR's branch:

- "handle the comments on PR 27"
- "fix the review comments on this PR"
- "address the PR feedback"
- "work through the comments on this pull request"
- "respond to the reviewers"

If you don't name a PR, the skill auto-detects from your current branch via `gh pr view`.

## What it does

- Fetches every open review thread on the PR (resolved and outdated threads are dropped by default).
- Classifies each comment as **FIX**, **INVALID**, or **DEFER**. Auto-classifies when confident, asks you about ambiguous ones.
- Shows the triage plan grouped by classification and waits for your approval before touching anything.
- For each **DEFER**: files a Linear ticket (no priority — that's the receiving team's call) and posts a reply on the PR comment linking to it.
- For each **INVALID**: posts a short rationale reply directly on the PR comment.
- For each **FIX**: edits the code, commits with conventional-commit form (one commit per comment), and tracks the SHA.
- Stops at a checkpoint before pushing so you can run `panel-review`, the test suite, or anything else you want first.
- When you say push: pushes the branch and posts `Fixed in <sha> — <one-line summary>.` on every FIX comment.

## Gotchas

- **You need to be on the PR's branch with a clean working tree.** The skill bails if not, rather than auto-stashing or `gh pr checkout`-ing (both of which can quietly discard work).
- **Linear MCP required for DEFER.** Without it, you can still FIX and INVALID; DEFER will degrade to "ask the user where to file this".
- **Review summary bodies don't have a reply API.** Only inline thread replies are first-class on GitHub. If a reviewer left their feedback in the review summary instead of inline, the skill posts a top-level PR comment instead.
- **One commit per comment.** Even when several comments touch the same file. Keeps revert granularity per comment and lets each fix-reply reference the exact SHA that fixed it.
- **Different from `post-panel-review-comments`.** That one _posts_ new findings (typically from `panel-review`). This one _consumes_ comments that already exist on the PR.
