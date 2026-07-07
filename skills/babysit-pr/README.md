# babysit-pr

Take one pull request and leave it mergeable: resolve its merge
conflicts by merging `origin/main`, hand its review comments to the
[`pr-comment-handler`](../pr-comment-handler) skill, fix any failing CI
via the `fix-ci` skill, and push. Works in place on the current checkout
and auto-detects the PR from the current branch.

This is the single-PR worker. To sweep **every** PR you authored in a
repo — one dedicated worktree each, all in parallel — use
[`babysit-my-prs`](../babysit-my-prs), which fans out to this skill.

## Install

```
npx skills add venables/skills --skill babysit-pr
```

## How to use it

From inside the repo, on the PR's branch, ask Claude Code in plain
English:

- "babysit this PR"
- "get this one mergeable — fix conflicts and handle the comments"
- "babysit PR 27"

It auto-detects the PR from the current branch; name a number to target
a different one.

## What it does

1. **Finds the PR** from the current branch (or the number you give) and
   confirms you're on its head branch with a clean tree — bailing rather
   than stashing if the tree is dirty.
2. **Resolves conflicts** (if any) by merging `origin/main` — never a
   rebase or force-push on a non-draft PR. A genuinely divergent,
   two-intent conflict is escalated, not guessed.
3. **Handles the comments** (if any) by running `pr-comment-handler`,
   which fixes / defers-to-Linear / declines each comment, replies, and
   resolves the threads.
4. **Fixes failing CI** (if any) by running `fix-ci` — checked last, so
   it reacts to the PR's real final state after the merge and comment
   fixes. It never disables a test or loosens config to go green, and a
   failure that's really main being broken is surfaced, not buried here.
5. **Pushes** anything left and **reports** what it did — plus anything
   that stopped for a human.

## Gotchas

- **Needs `gh` (authenticated).** PR detection, conflict status, CI
  status, and the delegated comment work all run through `gh`.
- **Works in place.** It does not create or switch worktrees — it acts on
  whatever checkout you're in. (`babysit-my-prs` is the one that sets up a
  worktree per PR and calls this skill inside each.)
- **Never rewrites history on a non-draft PR.** Conflicts are resolved
  with a merge commit and appended fixes, so reviewers keep their place.
- **`pr-comment-handler` owns comment judgment; `fix-ci` owns CI
  judgment.** This skill does the conflict resolution and orchestration;
  the per-comment fix/defer/decline/reply/resolve work and the CI
  diagnose/fix work are delegated to those skills. If `fix-ci` isn't
  present, a failing check is reported for a human rather than guessed at.
