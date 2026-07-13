# Dispositions, policies, and templates

## Disposition catalog

Every swept ticket gets exactly one of:

| Disposition | Linear action                                                                                                          |
| ----------- | ---------------------------------------------------------------------------------------------------------------------- |
| Accept      | Set priority (mapping below), move Triage → Todo (ready) or Backlog (accepted, unscheduled), set project when one fits |
| Done        | State → Done, comment with commit/PR evidence                                                                          |
| Duplicate   | State → Duplicate + `duplicateOf` the canonical ticket                                                                 |
| Superseded  | Same as Duplicate, pointing at the newer design/ticket that replaced it                                                |
| Blocked     | State → Backlog + `blockedBy` relation, comment naming the unblock condition                                           |
| Promote     | State → In Review + PR link attached                                                                                   |
| Demote      | In Progress/In Review → Todo or Backlog (stalled, no PR)                                                               |
| Icebox      | State → Icebox per policy below                                                                                        |
| Discuss     | Comment proposing the design conversation + move out of Triage to Backlog                                              |
| Decline     | State → Canceled with a reason                                                                                         |

Priority mapping (confirm any deviation with the user; apply only when accepting
a ticket, and never on tickets you merely comment on): money-correctness or
security → Urgent/High; user-visible bug → High/Medium; polish, copy, rename →
Low; internal tooling → Low. Design/discussion items get no priority.

## Icebox policy

Move a Backlog ticket to Icebox when ALL of:

- Created more than 5 weeks ago
- No priority set
- No project
- No assignee, no open PR, no updates in the last 3 weeks
- Not filed by an external stakeholder awaiting a response

Never Icebox (regardless of age): tickets about security hardening, money or
payment correctness, or data-loss / data-integrity risks. Age makes those _more_
urgent, not less. When in doubt whether a ticket is security/money-adjacent, it
is — send it to the checkpoint instead.

Icebox is reversible and non-destructive; its purpose is that Backlog stays a
credible "we intend to do this" list.

## Confidence tiers

**Tier 1 — auto-apply, no human input.** The evidence is a fact, not a judgment:

- Done where a merged PR/commit implements the ticket AND a Phase 4 code check
  returned IMPLEMENTED
- Duplicate where two tickets describe the same symptom and one fix resolves
  both (confirmed from descriptions, not titles alone)
- Promote/Demote backed by the presence/absence of a PR
- Relations (`relatedTo`, `blockedBy`, `parentId`) — additive and safe
- Icebox moves matching every policy criterion
- Triage accepts with verified reproduction and an obvious priority class

**Tier 2 — single batched checkpoint.** Present once, at the end, as a compact
table; skip entirely when empty:

- PARTIAL code-verification verdicts
- Done candidates with only circumstantial evidence (no code check)
- Duplicate clusters where the canonical choice is arguable
- Anything whose closure changes money-movement or security semantics
- Declines (cancelling someone's ticket is a judgment call)
- Borderline Icebox (fails exactly one criterion)

## Comment template

Every mutated ticket gets one comment, same shape as a triage comment:

```
Sweep YYYY-MM-DD: <disposition>, <state/priority change>. <Evidence: commit
hash, PR #, file:line, or duplicate target and why it is canonical.>
```

Keep it to 1-3 sentences. The comment is the audit trail that lets anyone
reverse the call later — write it for the ticket's author, who did not see the
sweep run.

## Final report template

```
# Backlog sweep — YYYY-MM-DD

Closed N · Merged N dups · Iceboxed N · Promoted N · Demoted N · Triaged N
Checkpoint items: N (or "none — fully automatic")

## Closed as Done
| Ticket | Title | Evidence |

## Duplicates merged
| Ticket | → Canonical | Why |

## State corrections
| Ticket | From → To | Evidence |

## Iceboxed
(ticket list, one line each)

## Triage dispositions
| Ticket | Disposition | Evidence |

## Left alone deliberately
(anything examined but unchanged, with the reason)
```
