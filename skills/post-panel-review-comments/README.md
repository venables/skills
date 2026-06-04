# post-panel-review-comments

Triage findings from a `panel-review` (or any structured review with `file:line` references) via a two-stage select list: first pick which to post as standalone inline PR comments, then pick which of the leftovers to file as Linear tickets. Anything not selected in either stage is dropped.

## Install

```
npx skills add catena-labs/skills --skill post-panel-review-comments
```

## How to use it

After running `panel-review` (or any review that produced findings with `file:line` refs), just ask:

- "post these comments to the PR"
- "post the panel review comments"
- "let me triage these findings"
- "turn these findings into PR comments or Linear tickets"
- "comment these on PR 85"
- "file the LOWs as Linear tickets and post the rest"

The skill prints the full numbered finding list in chat, then walks you through two select stages: **Stage 1** — multi-select which findings to post as standalone PR comments. **Stage 2** (only if the agent can reach Linear from this session) — multi-select which of the _leftovers_ to file as Linear tickets. Anything still unselected is dropped.

## What it does

- Resolves the PR via `gh pr view` (you pass the PR ref explicitly — it does not auto-detect from the current branch).
- Detects whether the calling agent can actually reach Linear from this session (via MCP, CLI, API token — whatever the runtime exposes). If no, Stage 2 is skipped entirely.
- Posts each selected finding as a **standalone inline comment** via `POST /pulls/{N}/comments` — no review wrapper, no "X left a review" timeline entry. The comment body is just the finding (verbatim) plus a `**Possible Solution:**` line when one exists; LOW/polish findings get a `Small / Optional polish:` prefix. **No severity, no priority, no panelist/agent attribution** is written into the comment. Calls are sequenced HIGH → MEDIUM → LOW internally so notifications arrive in priority order.
- Files Linear tickets one-by-one with the title derived from the finding and the PR link + file:line + severity in the description. **No priority is set** — that's the issue owner's call.
- Reports any comments GitHub rejected (e.g., line not in the PR diff) so you can post them manually instead of having them silently dropped.

## What it does NOT do

- **No wording rewrites.** The skill posts findings as the panelist wrote them. If you want softer phrasing on a specific finding, ask the agent to rewrite it before triggering this skill.
- **No review wrapper.** Comments post individually. You get one notification per posted comment, not one batched notification. For large finding lists, route some to Linear or drop them to keep noise down.

## Gotchas

- **GitHub only allows inline comments on lines inside the PR diff hunks.** Findings that point at unchanged context outside a hunk get rejected by the API — the skill surfaces these so you can fall back to a regular issue comment.
- **No PR auto-detection.** Branch state can drift between running the review and posting comments. The skill takes the PR ref from the calling assistant's context (which already knows it from the review's scope) rather than guessing.
- **One notification per comment.** Standalone comments don't batch. For 10+ findings, expect 10+ emails — consider routing some to Linear instead.
- **No priority on Linear tickets.** Severity is recorded in the ticket description but never mapped to a Linear priority — triage priority is for the issue owner, not the review panel.
- **No severity, priority, or provenance on PR comments.** The posted comment is just the finding plus an optional `Possible Solution:` line (and a `Small / Optional polish:` prefix for LOW findings). The panel's grading and panelist attribution stay in the triage transcript and chat, not on the PR.
