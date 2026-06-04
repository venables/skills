---
name: pr-comment-handler
description: >
  End-to-end handling of *existing* review comments on a GitHub pull
  request — read every open thread, decide per comment whether to fix,
  push back, or defer to a Linear ticket, then drive the work and post
  the right reply on each thread. Use this skill whenever the user says
  things like "handle the comments on PR 27", "fix the review comments",
  "address the PR feedback", "work through the comments on this PR",
  "respond to the reviewers", "clean up the review comments", or any
  phrasing that means "go act on what reviewers have already said".
  Auto-detects the target PR from the current branch when the user does
  not name one. Different from `post-panel-review-comments` (which posts
  *new* findings) and from `panel-review` (which generates findings):
  this skill consumes review comments that already exist and turns them
  into code changes, replies, and follow-up tickets. Do NOT use when the
  user wants to *generate* a review (use `panel-review` /
  `code-reviewer`), or to *post* findings produced elsewhere (use
  `post-panel-review-comments`).
---

# pr-comment-handler

Walks every open review thread on a PR and decides per comment:

- **FIX** — change the code, commit it, reply on push with the SHA.
- **INVALID** — reply now with a short rationale; nothing to change.
- **DEFER** — file a Linear ticket and reply now with the ticket URL.

The point is the _triage and follow-through_, not the API mechanics.
The user wants reviewer threads to leave the inbox with a clear answer
on each one, the right code change landed, and any out-of-scope work
captured somewhere it will not be forgotten.

## Inputs

1. **PR ref** — usually omitted. Auto-detect from the current branch
   (`gh pr view --json number,url,headRefName,headRefOid,title,state`).
   If the user names a PR explicitly ("handle the comments on PR 27",
   a `github.com/.../pull/N` URL), use that and skip auto-detect.

   If auto-detect fails (no PR for this branch, or multiple), ask the
   user once which PR — don't guess.

2. **Working tree** — assume the user is on the PR's head branch with a
   clean working tree. If `git status --porcelain` shows uncommitted
   changes or `git branch --show-current` ≠ PR head ref, **stop and
   tell the user** before doing anything. Don't auto-stash, don't auto
   `gh pr checkout` — both can quietly discard work.

3. **Linear team + project** (only when needed) — ask once, the first
   time a DEFER lands. Reuse for every later DEFER in the same session.
   Don't re-ask per comment.

## Workflow

### 1. Resolve the PR, sanity-check, fetch comments

Run `gh pr view` to confirm the PR and surface it to the user before
doing any work:

```
PR #N: <title> — <url>
```

Cheap sanity check that you're aimed at the right thing. If they
expected a different PR they'll say so now, not after you've made
commits.

Verify the branch state (current branch, no uncommitted changes). Bail
if not — see "Inputs" above.

Then fetch every open thread plus any review summary bodies with
`scripts/fetch_pr_comments.sh <pr-ref>`. Default behavior already drops
resolved and outdated threads — that filtering is intentional, those
are usually noise.

The script emits one JSON document; see its header for the shape. Two
things you'll keep using:

- Each comment has both a GraphQL `node_id` and a numeric `database_id`.
  Replies via REST need `database_id`. Tracking state across the
  session, prefer `node_id` (stable, unambiguous).
- `is_bot: true` flags author logins like `coderabbitai`, `copilot-...`,
  `[bot]` suffixes. Treat as a hint, not a verdict — sometimes a bot
  comment is the most useful one in the thread.

### 2. Classify each comment

The default is to **auto-classify** with high confidence and only ask
the user about ambiguous ones. That keeps the loop fast on the common
case where most comments are obvious.

For each thread, read:

- The original comment body (the first comment in the thread).
- Any replies — especially replies from the PR author. If the author
  already said "fixed in <sha>" or "addressed", the thread is probably
  closeable but wasn't resolved on the UI. Default to INVALID and say
  so in your reply.
- The file at `path:line` (or the diff hunk if `is_outdated`). The code
  often moots the comment by itself.

Then assign one of:

**FIX** — the comment points at a real, current issue and the change
is in scope. Most comments land here.

**INVALID** — the comment is wrong, stale, or already addressed. Common
shapes: "use the helper at X" but X doesn't exist; "this is O(n²)" on
code where n is bounded to 3; reviewer misread the diff; the suggestion
is already in a later commit.

**DEFER** — the comment is a valid improvement but explicitly or
obviously out of scope for this PR. Common shapes: "we should also
refactor Y", "add a metric for this", "follow-up: write a migration
guide", new feature requests piggy-backed on a bug fix. Reviewers
phrasing it as "follow-up", "in a future PR", "not blocking" is a
strong DEFER signal.

**ASK** — anything you're not sure about. Don't guess on the user's
behalf; the cost of a wrong fix is higher than the cost of one question.

Be conservative. When the comment is short, vague, or could mean two
things, mark it ASK — the user reads PRs in their own voice and will
classify in seconds what would take you several tool calls to verify.

### 3. Show the triage plan, confirm

Before executing, print a compact plan grouped by classification:

```
Triage plan for PR #N (<title>):

FIX (3):
  - src/auth.ts:42  @alice  "extract this into a helper"
  - src/auth.ts:88  @alice  "missing null check on session"
  - tests/auth.test.ts:12  @bob  "add a case for expired tokens"

INVALID (1):
  - src/auth.ts:14  @alice  "use the existing X helper"
    Rationale: X was removed in commit abc123; the inline version is
    intentional.

DEFER (1):
  - README.md:1  @bob  "we should document the new env var"
    Rationale: docs land in the follow-up PR per the description.

ASK (1):
  - src/auth.ts:99  @alice  "is this still needed?"
```

For ASK items, prompt the user one at a time with `AskUserQuestion`
offering Fix / Invalid / Defer / Skip. Use the same self-contained
question text pattern as `post-panel-review-comments`: include
panelist + path:line + body verbatim so the modal stands alone.

Once ASKs are resolved, also give the user a chance to flip any of the
auto-classified items before execution — e.g. "actually defer the
extract-helper one, that's a bigger change than it looks". Treat a
flat "looks good" / "go" as approval.

### 4. Execute

Walk approved items in this order. The order matters: DEFER and INVALID
both post replies during this phase, so the user sees Linear tickets
appear and reviewer threads light up _before_ any code commits — useful
signal that something is wrong if a Linear write fails.

#### DEFER first

The first time you hit a DEFER, ask the user **once** which Linear team
and project tickets should land in. Reuse for every later DEFER.

For each DEFER:

1. Create a Linear issue via the Linear MCP (`save_issue` or similar
   in your tool list).
   - **Title:** one-line summary of the follow-up; under ~80 chars.
   - **Description:** include in this order — link to the PR comment
     (the comment's `url` field), `File: <path>:<line>` if the comment
     is inline, blank line, then the reviewer's body verbatim.
   - **Do not set priority.** Triage priority is the issue owner's
     call. The user was explicit about this.
   - No severity → priority mapping. No sneaky label workarounds.

2. Post a reply on the PR comment via
   `scripts/post_reply.sh <pr-ref> <parent.database_id> -` (body on
   stdin so newlines survive). Body shape:

   ```
   Deferring to follow-up: <linear-url>

   <one-sentence rationale, e.g. "out of scope for this fix; the auth
   refactor lands in its own PR.">
   ```

   Keep the rationale honest and short. Reviewers can tell when they're
   being brushed off.

#### INVALID next

For each INVALID, post a reply on the parent comment with a short
rationale. Body shape:

```
Not making this change: <one or two sentence rationale>.
```

If the rationale needs file references, include them. Don't apologize,
don't pad. Reviewers respect a clear "no, because X" more than a
hedged maybe.

#### FIX last

For each FIX, in order (smallest/lowest-risk first when several touch
the same file — reduces merge conflicts mid-loop):

1. Read the file. Make the change. If the comment was vague about the
   exact fix, follow the _spirit_ of the comment, not a literal reading
   — reviewers point at problems more reliably than they prescribe
   solutions.
2. Run quick correctness checks if the project has them — typecheck,
   the most relevant test file. Don't run the full test suite per fix;
   that's what the push-time decision step is for.
3. Commit with conventional-commit form, one commit per comment fixed:

   ```
   fix(<scope>): <one-line description>

   Addresses review comment from @<author> on <path>:<line>.
   <comment URL>
   ```

   `<scope>` follows the project's existing convention from
   `git log --oneline` (often the directory or feature area). If
   there's no consistent scope, drop the parens.

4. **Track**: `{comment_database_id, sha, one_line_summary}` for the
   push-time reply. Keep this in conversation state — TodoWrite is a
   good place because it survives if the user side-tracks for an
   unrelated question.

   `sha` is the commit SHA you just produced (`git rev-parse HEAD`),
   not the PR's head SHA at fetch time. Truncate to 7 chars for the
   reply text; keep the full SHA internally in case you need it.

   `one_line_summary` is _what you did_, not what the reviewer asked
   for. "Extracted shared helper" beats "addressed the helper comment".

Do not push yet. The user explicitly wants a checkpoint before code
goes upstream.

### 5. Checkpoint: push, or run something locally first

After all FIX commits land, summarize and ask:

```
Local commits: 3 (sha1, sha2, sha3)
Replied to 1 INVALID, deferred 1 to LIN-NNN.

Push now, or run something locally first?
```

Offer concrete options via `AskUserQuestion`:

- **Push now** — `git push`, then post fix-replies on each FIX comment.
- **Run panel-review first** — invoke the `panel-review` skill on the
  unpushed work, then come back to this checkpoint.
- **Run tests / typecheck** — full suite, not the per-commit smoke
  check. Project-specific.
- **Hold** — user wants to inspect manually before deciding.

If the user picks one of the deferred actions, do that, then come
_back_ to the checkpoint. The fix-reply phase runs only once, after
the user has actually said "push".

### 6. Push and post fix-replies

When the user says push:

1. `git push` (the branch already exists upstream — the PR head — so
   no `-u`/`--set-upstream` needed; if that turns out wrong, surface
   the error).

2. For each tracked FIX entry, post a reply via `scripts/post_reply.sh`:

   ```
   Fixed in <short-sha> — <one_line_summary>.
   ```

   That's the whole reply. The short SHA is a clickable link in
   GitHub's UI; the summary tells the reviewer whether your fix
   matches what they asked for without making them open the diff.

3. If a reply fails (typically: parent comment was deleted, or the
   PR was closed mid-loop), surface the error with the comment URL and
   the body you tried to post, so the user can paste it manually. Keep
   going with the other replies — one failure shouldn't block the rest.

### 7. Report back

Final summary, single block:

```
PR #N <url>

Fixed:    3 (replies posted on N commits)
Invalid:  1 reply
Deferred: 1 → <linear-url>
Skipped:  0

Push: <commit-range-url>
```

If anything errored, list the affected comment URLs at the bottom so
the user can finish them manually.

## Gotchas

- **Replying needs `database_id`, not GraphQL `node_id`.**
  `fetch_pr_comments.sh` exposes both for exactly this reason. Mixing
  them up gets you a 404 from the replies endpoint.

- **Review summary bodies don't have a "reply" API.** The replies
  endpoint is for inline comments only. If a _review_ (not an inline
  thread) needs a response, post a top-level PR comment that quotes
  the relevant sentence and addresses it — or, if the review is mostly
  a recap of inline threads you've already answered, you can skip
  responding to the summary itself.

- **Don't `gh pr checkout` on the user's behalf.** It will silently
  blow away uncommitted work. Bail and let the user resolve.

- **Don't auto-stash either.** Same reason. Stashes are easy to forget;
  the user's work should stay where they put it.

- **Don't push without the checkpoint.** Even if the user said "go fix
  the comments" in their initial message, treat that as authorization
  for the local work, not the push. The push step is its own decision.

- **One commit per comment, not per file.** Even when several comments
  touch the same file, separate commits keep revert granularity per
  comment and let the fix-reply on push reference exactly the SHA that
  fixed that comment. (User preference, recorded in CLAUDE.md.)

- **Don't paraphrase the reviewer's comment when showing it to the
  user during triage.** They need the raw text to classify it the way
  they'd classify it themselves. Paraphrasing in your summary is fine
  for the _plan_ view; classification still reads the original body.

- **Linear tickets get no priority.** Setting priority is the
  receiving team's call. No mapping from severity or reviewer
  insistence to priority. No labels as a workaround.

- **`panel-review` and `post-panel-review-comments` are siblings, not
  alternatives.** If the user already ran a panel-review and has a list
  of _new_ findings to post, that's `post-panel-review-comments`. This skill
  is the _inverse_ flow: comments already exist on the PR and need to
  be acted on. Don't get them tangled.

## Dry-run mode

If the user asks for a dry run ("don't actually push", "show me what
you'd do") or sets `PR_COMMENT_HANDLER_DRY_RUN=1`, do everything up
through staging changes locally, but:

- Don't `git push`.
- Don't post any replies. Write what _would_ have been posted to
  `./pr_comment_handler_replies.json` — array of
  `{comment_url, parent_database_id, body, kind: "invalid"|"defer"|"fix"}`.
- Don't create Linear tickets. Write what would have been created to
  `./pr_comment_handler_linear.json` — array of
  `{team, project, title, description}`.
- Still make the local code commits — the user can `git reset --hard`
  to undo if they want. Document the resulting SHA range in the final
  summary.
