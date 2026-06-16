---
name: approve-pr
description: >
  Approve the GitHub pull request currently under discussion — typically
  right after a `panel-review`, `panel-review-loop`, or once review
  comments have been handled. Use whenever the user says things like
  "approve the PR", "approve this", "approve PR 27", "LGTM it", "ship
  it", "stamp it", "give it a thumbs up", or "approve with <message>".
  When the user gives no message, approve with a short, fun body — an
  LGTM or a single silly emoji (cowboy, ship-it, rocket, etc.) as the
  only text. When the user supplies a message, use it verbatim as the
  approval body. Auto-detects the target PR from the current branch when
  the user does not name one. Do NOT use to *request changes* or leave a
  non-approving review (use a plain `gh pr review` / the PR comment
  skills), to *generate* a review (`panel-review`), or to act on existing
  review comments (`pr-comment-handler`).
---

# approve-pr

Submits an **approving** review on a GitHub PR — the celebratory last
step after the work has been reviewed and is good to go. The whole point
is that it's quick and a little fun: no message needed, just a stamp.

- **No message given** → approve with a short fun body (an emoji or a
  tiny phrase, nothing else).
- **Message given** → approve with that message, verbatim.

## Inputs

1. **PR ref** — usually omitted. Auto-detect from the current branch:
   `gh pr view --json number,url,title,author,state`. If the user names
   a PR explicitly ("approve PR 27", a `github.com/.../pull/N` URL), use
   that.

   If auto-detect finds no PR for the branch, or the repo has several
   and it's ambiguous, ask the user once which PR — don't guess.

2. **Body** — optional. Whatever message the user attached to the
   request ("approve with 'great work, merging Monday'"). If they gave
   none, you pick a fun default (see below).

## Workflow

### 1. Resolve and surface the PR

Run `gh pr view <ref> --json number,url,title,author,state` and show it
back before approving — a cheap sanity check that you're stamping the
right thing:

```
PR #N: <title> — <url>
```

If the PR is already `MERGED` or `CLOSED`, stop and say so rather than
attempting an approval that can't apply.

### 2. Choose the body

If the user gave a message, use it exactly as written — don't embellish
it with extra emoji or prose.

If they gave none, pick **one** short, fun body. Vary it across
invocations rather than always using the same one. Keep it to just the
emoji or tiny phrase — no follow-up sentence. Good options:

- `🤠`
- `Ship it! 🚢`
- `🚀`
- `LGTM 🤠`
- `✅`
- `🎉`
- `🔥`
- `LGTM`
- `🙌`

Match the mood when there's an obvious cue (e.g. `Ship it! 🚢` right
after a clean `panel-review-loop`), otherwise just pick one.

### 3. Approve

```
gh pr review <ref> --approve --body "<body>"
```

Omit `<ref>` to let `gh` resolve the current branch's PR, or pass the
number / URL when the user named one.

### 4. Report back

One line, with the PR link and the body you used:

```
Approved PR #N <url> with "<body>".
```

## Gotchas

- **You can't approve your own PR.** GitHub rejects an approving review
  from the PR author (`gh` returns `Can not approve your own pull
request`). If `author` from step 1 is the current user, don't even try
  — tell the user they can't self-approve and offer to leave a plain
  comment review instead (`gh pr review <ref> --comment --body ...`).

- **Approve, never request-changes here.** This skill only ever passes
  `--approve`. If the user actually wants to block or request changes,
  that's a different action — don't shoehorn it through here.

- **The fun body is the _only_ text.** When defaulting, don't append a
  rationale, a summary of the review, or attribution. The emoji or short
  phrase stands alone — that's the bit the user asked for.

- **Don't re-run the review.** Approval assumes the review already
  happened (usually a prior `panel-review`). This skill doesn't read the
  diff or re-evaluate the code — it just stamps. If the user hasn't
  actually reviewed and wants confidence first, point them at
  `panel-review` before approving.

- **An approval is outward-facing.** It notifies the PR author and other
  watchers and can unblock a merge. Since the user invoked this skill to
  approve, that's authorization — but still surface the PR (step 1)
  first so a wrong auto-detect is caught before the notification goes
  out.
