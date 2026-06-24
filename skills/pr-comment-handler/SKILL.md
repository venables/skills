---
name: pr-comment-handler
description: >
  Autonomously work through every open review comment on a GitHub pull
  request using your own judgment: fix what's valid and relevant, defer
  worthwhile-but-out-of-scope work to a Linear ticket, and reply to
  every comment — with the fix, the ticket link, or an honest rationale
  for not fixing — then resolve the threads you've handled. Use this
  skill whenever the user says things like "check all the comments on
  the PR and fix the ones you think are valid", "handle the review
  comments", "address the PR feedback", "work through the comments and
  reply to each", "go deal with the reviewers", or any phrasing that
  means "act on what reviewers already said and leave each thread with
  an answer". Auto-detects the target PR from the current branch when
  the user doesn't name one. Different from `panel-review` (which
  *generates* findings) and `post-panel-review-comments` (which *posts*
  new findings): this skill *consumes* comments that already exist on
  the PR. Do NOT use to generate a review or to post findings produced
  elsewhere.
---

# pr-comment-handler

The user is handing you a PR's review inbox and trusting your judgment.
The job, per their standing instruction:

> Check all comments on the PR and fix the items you think are valid and
> relevant. If a fix is worthwhile but you'd rather defer it to a
> follow-up, file a Linear ticket for it. Regardless of fixing or not,
> reply directly to every comment and include the fix, the link to the
> Linear ticket, or the rationale for not fixing. If you can resolve the
> comment, resolve it.

So the contract is simple and you should hold yourself to it:

- **Every open comment gets a reply.** No thread is left silent.
- **Each reply carries an answer** — what you fixed (and the commit),
  the ticket you filed, or why you're not changing anything.
- **Threads you've handled get resolved.**

Everything else — which comments deserve a fix, what the fix is, what's
out of scope, when something is just wrong — is yours to decide. You
read PRs all day; don't ask the user to re-adjudicate what you can judge
yourself. Act, then report what you did.

## What you're working with

Fetching the comments is the one fiddly part, so a script handles it.
Everything else is a plain `gh` call you can run inline.

**Fetch** — `scripts/fetch_pr_comments.sh <pr>` emits every open thread +
any review summary bodies as one JSON document. (It exists because the
REST endpoint doesn't expose per-thread `isResolved`, so the script runs
a GraphQL query and shapes the result.) Resolved and outdated threads are
dropped by default — usually noise; `--include-resolved` /
`--include-outdated` if you need them. Read its header for the full shape.

Each comment in that output carries a `database_id` (numeric) and a
`node_id`; each thread carries a `thread_id`. It also flags `is_bot`
authors as a hint — but a bot comment is sometimes the sharpest one in
the thread, so weigh it on content, not author.

**Reply** to a thread (inline, so newlines/markdown survive — `gh`
fills `{owner}/{repo}` from the current repo):

```bash
gh api --method POST \
  "repos/{owner}/{repo}/pulls/<pr>/comments/<parent.database_id>/replies" \
  -f body="$(cat <<'EOF'
Fixed in abc1234 — extracted the shared helper.
EOF
)"
```

**Resolve** a handled thread (same as the UI button — needs the
`thread_id`, not a comment id):

```bash
gh api graphql -F threadId="<thread_id>" -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: { threadId: $threadId }) {
      thread { isResolved }
    }
  }'
```

## How to work

1. **Find the PR.** Usually unstated — auto-detect from the branch
   (`gh pr view --json number,url,title,headRefName,state`). If the user
   named one, use it. If detection is ambiguous (no PR, or several), ask
   once rather than guessing. Confirm you're on the PR's head branch with
   a clean tree before you start changing code — if not, stop and say so
   rather than stashing or checking out on the user's behalf, which can
   silently lose work.

2. **Read every thread and decide.** For each, read the comment, any
   replies (if the author already said "fixed in <sha>", it's likely
   moot — say so and resolve), and the actual code at `path:line`. The
   code often settles it. Then pick the path that's true, not the one
   that's least work:
   - **Fix it** when the comment points at a real, in-scope problem.
     Follow the _spirit_ of the comment — reviewers locate problems more
     reliably than they prescribe solutions.
   - **Defer it** when the fix is genuinely worth doing but doesn't
     belong in this PR (a broader refactor, a follow-up feature, a
     piggy-backed "we should also..."). File a Linear ticket so it isn't
     lost.
   - **Decline it** when the comment is wrong, stale, or already handled.
     A clear "no, because X" respects the reviewer more than a silent
     non-fix or a hedge.

3. **Make the fixes and push.** Commit each fix on its own — one logical
   change per commit, conventional-commit form, scope matching the repo's
   `git log` convention. Reference the comment in the body. Then push, so
   your reply can point at a real, fetchable SHA. The user wants this run
   autonomously: commit and push without a checkpoint unless they asked
   you to hold. Run cheap correctness checks (typecheck, the nearest test
   file) as you go; you don't need the full suite per fix.

4. **Reply to every comment**, then resolve the thread:
   - _Fixed:_ `Fixed in <short-sha> — <what you actually did>.` The short
     SHA is a clickable link in GitHub; the summary tells the reviewer
     whether your fix matches their intent without opening the diff.
   - _Deferred:_ link the Linear ticket and give a one-line reason it's a
     follow-up. Keep it honest — reviewers can tell when they're being
     brushed off.
   - _Declined:_ one or two sentences of real rationale, with file
     references if they help.

   After replying, resolve the thread (the GraphQL mutation above). If a
   reply fails
   (parent deleted, PR closed mid-run), surface the comment URL and the
   text you tried to post so the user can finish it by hand, and keep
   going with the rest.

5. **Report back** — a short summary: counts of fixed / deferred /
   declined, the commit range you pushed, the Linear links you filed, and
   anything that errored and needs a human.

## Linear tickets (for deferrals)

The first time you defer, ask once which Linear team and project tickets
should land in, then reuse that for the rest of the session — don't
re-ask per comment. Each ticket:

- **Title:** one-line summary of the follow-up.
- **Description:** the PR comment's URL, then `File: <path>:<line>` if
  inline, a blank line, then the reviewer's body verbatim.
- **No priority, no severity-to-priority mapping, no label workaround.**
  Triage is the receiving team's call — the user is firm on this.

If the Linear MCP isn't available, you can still fix and decline; tell
the user which comments you'd have deferred so they can file them.

## Worth knowing

- **Replies use `database_id`; resolves use `thread_id`.** Mixing them up
  gets a 404. The fetch output keeps them distinct for this reason.
- **Review _summary_ bodies have no reply API** — only inline threads do.
  If a reviewer left actionable feedback in a review summary, respond with
  a top-level PR comment that quotes the relevant part. If the summary
  just recaps inline threads you've already answered, you can skip it.
- **Don't `gh pr checkout` or auto-stash.** Both can quietly discard the
  user's uncommitted work. Bail and let them sort it out instead.
- **One commit per comment**, even when several touch the same file —
  keeps revert granularity per comment and lets each reply name the exact
  SHA that fixed it.
- **Resolve only what you genuinely handled.** Don't resolve a thread you
  declined if you think the reviewer may reasonably push back — leave that
  one open after replying so they can respond.
