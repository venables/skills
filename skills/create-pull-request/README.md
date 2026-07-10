# create-pull-request

Open a GitHub pull request that a human can actually skim: a plain-language title, and a body that leads with a short Changes list before the Problem, Solution, and Testing prose. The reusable PR-opening procedure the `ship` playbook delegates to, usable on its own when you just want a PR opened.

## Install

```
npx skills add venables/skills --skill create-pull-request
```

Requires the `gh` CLI, authenticated against the repo.

## How to use it

Ask Claude Code in plain English once the work is committed:

- "open a PR for this"
- "PR this"
- "raise a pull request"
- "put this up as a draft PR"
- "ship this as a PR"

## What it does

- **Confirms the branch first.** Refuses to open a PR from `main`/`master`, and commits or asks about uncommitted work rather than sweeping it in.
- **Derives the title and body from the real work.** Reads the diff and commit messages instead of your memory of the conversation, which drifts from what actually shipped.
- **Writes a plain-language title.** Says what changed and its effect, keeps the repo's conventional-commit prefix, and never lets a ticket ID, codename, or file path carry the meaning.
- **Leads the body with a Changes list.** One short line per change, so a reviewer sees the shape of the diff before reading Problem, Solution, and Testing.
- **Honors the repo's PR template.** When `.github/pull_request_template.md` exists, it fills that in rather than imposing its own structure.
- **Opens the PR and reports the URL.** Supports `--draft`, and never merges for you.

## Gotchas

- **It does not sync with main.** Bringing the branch up to date with `origin/main` is a separate step (see the `sync-main` or `ship` skills). This skill assumes the branch is ready to PR.
- **The repo template wins.** If `.github/pull_request_template.md` is present, its sections take precedence over the Changes / Problem / Solution / Testing default.
- **One PR per independent change.** If a branch carries several unrelated changes, that is a cue to split them, not to write one omnibus PR.
- **It opens, it does not merge.** The author merges manually unless they say otherwise. For getting an open PR mergeable (conflicts, comments, CI), use `babysit-pr`.
