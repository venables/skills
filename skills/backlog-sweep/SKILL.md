---
name: backlog-sweep
description: >
  Automated Linear backlog hygiene and triage. Inventories every open ticket,
  cross-references git history and GitHub PRs to find shipped-but-open work and
  state mismatches, verifies "maybe already fixed" claims against the code,
  detects duplicate clusters, moves aging tickets to Icebox, then triages the
  Triage queue (duping each new ticket against the full backlog first). Applies
  hard-evidence actions automatically and batches judgment calls into one final
  human checkpoint, skipped when empty. Use whenever the user asks to sweep,
  groom, triage, or clean up the Linear backlog, close stale or shipped tickets,
  find duplicate tickets, move tickets to Icebox, or asks "which tickets can we
  close" — even if they don't say "sweep". Not for implementing tickets (that is
  find-work).
---

# Backlog sweep

Keep the team's Linear board truthful: every ticket's state should match reality
in the repo. The sweep finds where they diverge and fixes it with an evidence
trail. The team key (ticket prefix, e.g. `ENG`) may be passed as an argument;
otherwise infer it from ticket IDs in merged commit subjects of the current
repo, and ask if that is ambiguous.

Modes (from args): `full` (default, everything below), `triage` (Phase 7 only,
still requires Phases 1-2 for dup-checking), `dry-run` (produce the full
disposition report, write nothing to Linear).

Read `references/dispositions.md` before Phase 3 — it defines the disposition
catalog, Icebox policy, confidence tiers, and comment templates used everywhere
below.

## Phase 1 — Inventory

Load Linear MCP tools via ToolSearch (`list_issues`, `get_issue`, `save_issue`,
`save_comment`, `list_issue_statuses`, `list_projects`).

Fetch all open issues per state type: `triage`, `backlog` (covers Backlog +
Icebox), `unstarted`, `started`, with `includeArchived: false`, limit 250.

The raw results usually exceed the tool-result token limit and get saved to
files under the session `tool-results/` directory. That is expected — do not
retry with smaller limits. Distill each saved file into one shared TSV:

```bash
jq -r '.issues[] | [.id, .status, (.priority.name // "None"),
  (.project // "-"), (.assignee // "-"), (.labels|join(",")),
  .createdAt[:10], .updatedAt[:10], .title] | @tsv' <saved-file>
```

Concatenate, `sort -u`, save as `inventory.tsv` in the scratchpad. Keep the
saved raw files — Phase 5 reads full descriptions from them with jq instead of
re-fetching tickets one by one.

## Phase 2 — Evidence

Run the bundled script (always fetches `origin/main` first — the local checkout
being behind has produced wrong verdicts before):

```bash
<skill-dir>/scripts/gather-evidence.sh <TEAM_KEY> <scratchpad-dir>
```

It writes: `shipped-ids.txt` (ticket IDs referenced by merged commits or merged
PRs, including branch names), `open-pr-ids.txt`, `merged-prs.tsv`,
`open-prs.tsv`. Cross-reference:

```bash
comm -12 <(cut -f1 inventory.tsv | sort -u) shipped-ids.txt   # shipped-but-open candidates
comm -12 <(cut -f1 inventory.tsv | sort -u) open-pr-ids.txt   # legitimately in flight
```

## Phase 3 — Classify state mismatches

Work through these signals. Every classification here is a _candidate_ until
Phase 4 verifies it.

- **Shipped-but-open**: open ticket whose ID appears in `shipped-ids.txt`.
  Beware false positives — a PR body may mention a ticket in passing ("follow-up
  tracked in ENG-123") without implementing it. Read the matching PR title/body
  line in `merged-prs.tsv` and confirm the PR actually delivers the ticket
  before treating it as shipped.
- **Fixed under a different ID**: a merged PR whose title/body describes an open
  ticket's problem but references a sibling ticket (e.g. the fix for ENG-88
  landed tagged ENG-91). Scan `merged-prs.tsv` titles against open bug titles.
  Resolution: mark the open ticket Duplicate of the shipped one, or Done with
  the PR linked.
- **Started but stalled**: In Progress / In Review with no open PR in
  `open-prs.tsv` (match by ID _and_ by title keywords — many PRs omit the ID;
  e.g. "Rate-limit the login endpoint" ↔ its same-named ticket). Exclude tickets
  created within the last few days: teams often file tickets to track an
  already-open PR stack, and those are healthy. Genuinely stalled → demote to
  Todo/Backlog, or close if Phase 4 says the work shipped anyway.
- **Backlog/Todo with an open PR**: promote to In Review and link the PR.
- **Open tickets in completed projects**: flag; usually they should move out of
  the project or get re-evaluated.

## Phase 4 — Code verification

For every candidate whose truth lives in the code ("shipped?", "bug still
exists?", "obsolete after refactor X?"), batch them into Explore subagents,
10-12 items per agent, run in parallel. Each item in the prompt gets: ticket ID,
the claim to check, and _specific places to look_ (files, functions, commit
hashes from Phase 2). Require this return format per item:

```
<TEAM_KEY>-NNNN — <claim> — IMPLEMENTED | NOT IMPLEMENTED | PARTIAL
<1-2 lines of evidence: file:line or commit hash>
```

Tell agents to check against `origin/main`, not local main. PARTIAL verdicts
never auto-close — they go to the checkpoint with the evidence attached.

## Phase 5 — Duplicate clusters

Two passes over `inventory.tsv`:

1. **Title scan**: read all titles in one sitting and list clusters that
   describe the same problem or feature (same symptom, same subsystem, same
   ask). Include cross-state clusters — a Backlog ticket duplicating an In
   Review one is the common case worth catching.
2. **Description confirmation**: for each cluster, pull full descriptions from
   the Phase 1 saved files with jq and decide: duplicate (same fix resolves
   both) vs related (same area, different fixes).

Canonical-ticket rule: keep the one with momentum (open PR, assignee, project)
or the most concrete diagnosis; when equal, keep the newer one and mark the
older Duplicate. Distinct-but-adjacent tickets get `relatedTo` links, not
merges. Families of subtasks under a stated parent ("Parent issue to...") get
`parentId` wiring instead.

## Phase 6 — Icebox

Apply the Icebox policy from `references/dispositions.md` to Backlog tickets.
The policy is deliberately mechanical (age + no priority + no project + no
momentum) with explicit exclusions for security, money correctness, and data
integrity — those stay visible in Backlog no matter how old. Tickets matching
the policy move to Icebox automatically; anything borderline goes to the
checkpoint.

## Phase 7 — Triage queue

For each ticket in Triage, in this order:

1. **Dup check first**: compare against `inventory.tsv` titles (and Phase 5
   clusters). A triage ticket duplicating existing work gets merged immediately
   — no further analysis.
2. **Verify-first**: if it claims a behavior ("X is broken"), confirm the
   behavior still exists on `origin/main` (grep git history for the ticket ID
   too — it may already be fixed).
3. **Disposition** per the rubric: Accept (priority + state + project), Blocked
   (Backlog + blocking relation), Discuss (design items get a comment proposing
   the conversation, never sit in Triage), or Decline/merge.

Every triage ticket leaves the queue with a dated comment explaining the call
and the evidence.

## Phase 8 — Apply and report

Split all proposed actions by confidence tier (defined in
`references/dispositions.md`):

- **Tier 1 (auto-apply)**: verified-shipped closures, exact duplicates, state
  promotions/demotions backed by PR links, relations/parenting, policy-matching
  Icebox moves, triage dispositions with hard evidence. Apply immediately; every
  mutated ticket gets a dated evidence comment.
- **Tier 2 (checkpoint)**: PARTIAL verdicts, soft-evidence closures, ambiguous
  canonical choices, borderline Icebox, anything touching money movement or
  security semantics. Present as one compact table via a single AskUserQuestion
  (batch options: apply all / pick / skip). If Tier 2 is empty, skip the
  checkpoint entirely.

In `dry-run` mode, both tiers go into the report and nothing is written.

Finish with the report (template in `references/dispositions.md`): counts per
action, the full disposition table, and anything deliberately left alone. Lead
with the headline numbers (closed / merged / iceboxed / promoted).

## Pitfalls learned the hard way

- `git fetch origin main` before any code verdict; a stale checkout showed a
  "producer still exists" that was already deleted upstream.
- Oversized MCP results are normal at this scale; jq the saved files, never page
  through with repeated smaller calls.
- A PR mentioning a ticket is not a PR implementing it.
- The same bug often has one ticket per reporter; search titles by symptom, not
  just by ID.
- Don't file or modify priorities beyond what the rubric prescribes; the
  rubric's priority mapping is a team agreement, not your call to change.
