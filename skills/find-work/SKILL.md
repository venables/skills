---
name: find-work
description: Sweep the Linear backlog for tickets an agent can act on now. Closes tickets
  that shipped without being marked done (with evidence and PR links), and picks
  up small well-specified tickets end to end — own branch per ticket, frequent
  commits, a review loop, then a PR whose body explains the problem, the
  solution, and how to validate it. Use when asked to "find work", "look through
  Linear for things you can handle", "pick up a ticket", or "what can you knock
  out from the backlog". Not for grooming the board itself (closing stale
  tickets, deduping, iceboxing) — that is backlog-sweep.
---

# Find Work

Sweep Linear for two kinds of tickets, then act on both:

1. **Already solved** — shipped by some PR but never closed. Comment with the
   evidence and close them.
2. **Straightforward** — small, well-specified, unassigned. Implement them, one
   branch per ticket, reviewed, delivered as a PR.

The deliverable is a report: tickets closed (with evidence), PRs opened, and
tickets considered but skipped (with the reason), so the next sweep does not
re-litigate them.

## 1. Sweep

- List Todo tickets for the team that owns the current repo (Linear MCP
  `list_issues`, `state: "Todo"`). If the team is ambiguous, ask before
  sweeping. Read titles and descriptions; `get_issue` the plausible candidates
  for full context.
- Build two shortlists:
  - **Solved-candidates**: tickets describing behavior that recent PRs plausibly
    changed. Cross-check `git log` / merged PRs and the current code. A ticket
    is only "solved" when you can point at the code on `main` doing what the
    ticket asks — not when a related PR merely touched the area.
  - **Actionable**: unassigned, concrete, and small — a copy change, a
    well-scoped bug with a fix sketch, a missing guard with an existing pattern
    to mirror. Prefer tickets whose description names files or has a fix sketch.

## 2. What to skip (say why in the report)

- **Assigned tickets** — someone owns them; do not silently take their work.
- **Decision-shaped tickets** — "explore", "consider", "design", or anything
  where the fix depends on a product choice the ticket does not make.
- **Tickets needing credentials or environments you lack** (prod infra, live
  provider accounts, vendor dashboards).
- **Big tickets** — multi-day scope, schema redesigns, cross-team coordination.
  Finding them is still useful: note anything that blocks a stated milestone.
- **Speculatively-solved tickets** — if you cannot prove it shipped, comment
  with the likely fix and ask the reporter to confirm; do NOT close.

## 3. Close what already shipped

For each proven solved-candidate:

- Verify on current `main` (read the code, run the test if cheap).
- Comment on the ticket: what shipped, the PR number(s), where the behavior
  lives now (file paths), and anything the ticket asked for that did NOT ship.
- Mark the ticket Done (`save_issue` with `state: "Done"`).

## 4. Implement the actionable ones

Per ticket, in this order:

1. **Branch**: use the ticket's `gitBranchName` from Linear (e.g.
   `user/team-1234-slug`) so Linear auto-links the branch and PR. Branch off
   fresh `origin/main`. Never work two tickets on one branch.
2. **Mark it**: assign yourself context by moving the ticket to In Progress.
3. **Read first**: the ticket, its linked issues, and every file it names. Honor
   the repo's own rules (CLAUDE.md / AGENTS.md and any skills they require for
   the surfaces you touch — security review for auth or user-input changes,
   style skills for UI copy, migration policies, and so on).
4. **TDD where the change is behavior**: failing test, then the fix. Copy
   changes get a snapshot of the surrounding test suite instead.
5. **Commit often** — small conventional commits as you go, not one squash at
   the end.
6. **Review loop** when the work is done: run the repo's review process scoped
   to the ticket's diff (the `panel-review-loop` skill if installed, otherwise a
   careful self-review pass). Judge findings honestly — fix what is real, forego
   with recorded reasons, and re-review when fixes were substantive. Do not skip
   this even for small diffs; small diffs are cheap rounds.
7. **PR**: open against `main` with a human-readable body:
   - **Problem** — what was broken or missing, in the reporter's terms; link the
     Linear ticket.
   - **Solution** — what changed, why this approach over alternatives, and how
     it works (the mechanism, not a file list).
   - **Testing** — what automated tests cover it, plus manual steps a reviewer
     can run to see the fix.
   - Call out sensitive surfaces (auth, money, schema) per the repo's policy.
8. **Loop back to Linear**: comment with the PR link and move the ticket to In
   Review (or the team's equivalent). The ticket closes when the PR merges, not
   before.

## 5. Report

End with: tickets closed (and their PRs), PRs opened (ticket → PR), tickets
commented-but-left-open, and the skip list with one-line reasons. The skip list
is the contract with the next sweep — make it specific enough that re-triage is
a read, not an investigation.

## Gotchas

- Ticket descriptions go stale: verify every claimed file:line against current
  `main` before building on it.
- Do not set priorities on Linear tickets you create or update — triage belongs
  to the team.
- If a ticket turns out to be bigger than it looked, stop, comment what you
  learned, and put it back — a half-done branch is worse than an honest skip
  note.
