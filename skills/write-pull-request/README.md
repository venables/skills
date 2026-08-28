# write-pull-request

Write and open a GitHub pull request a reviewer can scan: a plain-language imperative title, a one-line overview, and a short body (Changes, Why, Decisions, How to verify, Risk). The reusable PR-writing procedure the `ship` playbook delegates to, usable on its own when you just want a PR written and opened.

Adapted from the `pr-writing` skill in [tjcages/skills](https://github.com/tjcages/skills/tree/main/pr-writing) (MIT), which merges Tim Pope's and Chris Beams's commit-message essays, ASD-STE100 Simplified Technical English, and the Google developer documentation style guide.

## Install

```
npx skills add venables/skills --skill write-pull-request
```

Requires the `gh` CLI, authenticated against the repo.

## How to use it

Ask Claude Code in plain English once the work is committed:

- "open a PR for this"
- "PR this"
- "write up this PR"
- "raise a pull request"
- "put this up as a draft PR"
- "rewrite this PR description"

## The rules, compressed

Title: imperative (`If applied, this PR will ___`), repo prefix kept, target 50 chars after it, hard limit 72, no period, no emoji, no ticket ID or file path carrying the meaning. Body: an overview line above every heading (`Changes X so that Y`), then `Changes` (three to seven short lines), `Why` (two or three short sentences, **key phrases in bold**), `Decisions` (one bullet per real tradeoff; delete when there were none), `How to verify` (numbered steps with the expected result), `Risk` (failure mode and rollback), `Closes ABC-123`. The whole body fits on one screen. No paragraph runs past three sentences without bold. Active voice, present tense, the change is the actor (never `we`), no `simply` / `just` / `leverage` / `This PR ...`.

Full contract: [`references/language.md`](./references/language.md). Before and after: [`references/examples.md`](./references/examples.md).

## What it does

- **Confirms the branch first.** Refuses to open a PR from `main`/`master`, and commits or asks about uncommitted work rather than sweeping it in.
- **Reads the diff and commits before writing a word.** Never your memory of the conversation, which drifts from what actually shipped.
- **Writes an imperative, plain-language title.** Says what changed and its effect, keeps the repo's conventional-commit prefix, and never lets a ticket ID, codename, or file path carry the meaning.
- **Opens the body with one overview line.** `Changes X so that Y`, then a three-to-seven-line `Changes` list, `Why` (short, bolded), `Decisions` (real tradeoffs only), `How to verify` (numbered steps and what was actually run), and `Risk` (failure mode and rollback). The whole body fits on one screen.
- **Honors the repo's PR template.** When `.github/pull_request_template.md` exists, it fills that in rather than imposing its own structure, and never leaves a placeholder behind.
- **Lints before it opens.** `scripts/pr-lint.sh` gates the title and body; a failing message is rewritten, not shipped.
- **Opens the PR, or updates the one that exists.** `gh pr create` for a new branch, `gh pr edit` when the branch already has a PR. Supports `--draft`, and never merges for you.

## Lint

```bash
bash skills/write-pull-request/scripts/pr-lint.sh "<title>" body.md                    # title and body
bash skills/write-pull-request/scripts/pr-lint.sh "<title>"                            # title only
bash skills/write-pull-request/scripts/pr-lint.sh --repo-template "<title>" body.md    # repo template in use
```

Hard failures (exit 1): a title over 72 characters, a trailing period, emoji, `[tags]`, a bare ticket ID, a non-imperative first word, a body that opens with a heading instead of the overview line, a surviving template placeholder or HTML comment, an empty section, a missing section, a banned word, `we`, or a `This PR ...` opener. Warnings: a title over 50 characters after the prefix, a title naming a file, a `Changes` list over seven lines, a long or nested `Changes` line, a paragraph over three sentences with no bold, a sentence over 25 words, and unnumbered verification steps.

## Gotchas

- **It does not sync with main.** Bringing the branch up to date with `origin/main` is a separate step (see the `sync-main` or `ship` skills). This skill assumes the branch is ready to PR.
- **The repo template wins.** If `.github/pull_request_template.md` is present, its sections take precedence over the overview / Changes / Why / Decisions / How to verify / Risk default. The title rules and language contract still apply.
- **One PR per independent change.** If a branch carries several unrelated changes, that is a cue to split them, not to write one omnibus PR.
- **It opens, it does not merge.** The author merges manually unless they say otherwise. For getting an open PR mergeable (conflicts, comments, CI), use `babysit-pr`.
