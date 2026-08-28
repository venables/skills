---
name: write-pull-request
description: Write and open a GitHub pull request for the current work. The title is one plain-language imperative line; the body is one a reviewer can scan (a one-line overview, Why, a short Changes list, Decisions, How to verify, and Risk), derived from the real diff and commits, not from memory of the conversation. Use whenever the user says "open a PR", "PR this", "write the PR", "raise a pull request", "ship this as a PR", "rewrite this PR description", or the work is committed and it is time to open one. Auto-detects the base branch, honors a repo's `.github/pull_request_template.md`, gates the title and body through `scripts/pr-lint.sh` before `gh pr create`, and updates the existing PR with `gh pr edit` when the branch already has one. The procedure the `ship` playbook delegates to; use it directly for a PR without the whole build-and-ship loop. Do NOT use to answer review comments on an existing PR (`pr-comment-handler`), to get a PR mergeable (`babysit-pr`), or to review a diff (`panel-review`).
---

# write-pull-request

Write one pull request that a reviewer can scan under the worst conditions: tired, on a phone, months later, with no author to ask. The diff is the *how*. The title and body hold what the diff cannot: the change in one line, the reason, the decisions, the proof that it works, and the risk. In as few words as that takes.

Language contract: [references/language.md](references/language.md). Before and after: [references/examples.md](references/examples.md). Mechanical gate: `scripts/pr-lint.sh`.

**These are requirements, not preferences.** A title or body that breaks one gets rewritten, not shipped.

## Operating order

### 1. Confirm the branch

```bash
git branch --show-current
git status --short
```

- **On `main`/`master`:** stop. Create a branch first (`git switch -c <type>/<short-slug>`) or ask which branch to use. Never push work to the default branch to open a PR.
- **Uncommitted work you intend to include:** commit it first, in logical commits. If the tree carries work that should not ship, stop and ask rather than sweeping it in.
- **Someone else's branch:** do not push to it without explicit approval.

### 2. Read the diff, then the commits

```bash
base=$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)
git log --oneline "origin/$base..HEAD"
git diff "origin/$base...HEAD" --stat
git diff "origin/$base...HEAD"
```

Derive everything from the real work. A body written from memory of the conversation drifts from what shipped. If you cannot state *why* the change exists after reading the diff, you do not understand it yet. Read it again; do not write a longer body.

### 3. Push

```bash
git push -u origin HEAD
```

A plain `git push` is enough when the branch already exists on the remote. Never `--force` a branch that has a PR with reviewers on it.

### 4. Check for a PR template

```bash
ls .github/pull_request_template.md .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null
```

When the repo ships a template, its sections win over the body shape in step 6. The title rules and the language contract still apply. Never let a template placeholder or HTML comment survive into the published body.

### 5. Write the title

One line that tells someone scanning a list of PRs what changed, without opening it.

- Keep the repo's conventional-commit prefix when it uses one (`feat:`, `fix:`, `refactor:`, ...). The text after the prefix reads like a sentence a person would say.
- Test it: **"If applied, this PR will ___."** If the sentence breaks, the title is wrong.
- Target 50 characters after the prefix. Hard limit 72 for the whole line; a squash merge makes it the commit subject.
- Say what changed and, where it fits, the effect. Do not describe the implementation.
- Banned: a trailing period, emoji, `[tags]`, and a ticket ID, codename, or file path carrying the meaning.
- Banned first words: `Added`, `Adds`, `Fixed`, `Fixes`, `Updated`, `Updates`, `Changes`, `WIP`, `Misc`, `Various`, `Cleanup`.

| Instead of                       | Write                                                  |
| -------------------------------- | ------------------------------------------------------ |
| `fix: CHK-1042`                  | `fix: stop double-charging cards on retried checkouts` |
| `fix: patch the retry handler`   | `fix: stop double-charging cards on retried checkouts` |
| `refactor: update auth.ts`       | `refactor: move session checks into one middleware`    |
| `feat: wire up the new endpoint` | `feat: let admins export a team's invoices as CSV`     |

### 6. Write the body

One overview line, then the sections. The whole body fits on one screen: a reviewer scans it, then reads the diff.

```markdown
Changes <X> so that <Y>.

## Why

<Two or three short sentences. **Bold the key phrase** in each.>

## Changes

- <One short line per change, under ten words>

## Decisions

- **<X over Y>**: <the reason, one line>

## How to verify

1. <One action.>
2. <One action, then the concrete expected result.>

## Risk

<What breaks if this is wrong. How to roll back.>

Closes ABC-123
```

- **The overview line.** The first line of the body, above every heading. `Changes X so that Y` (`Adds X so that Y` for a net-new feature): the change and the payoff, nothing else. A stacked PR also names its base branch here.
- **Why.** The problem or the goal, the reason for this solution, the cost. Two or three short sentences with the **key phrase in bold**. Never a file list, a restatement of the diff, or a log of your working session.
- **Changes.** Three to seven lines, top-level changes only. Under ten words each; lead with the thing that changed, not "Added" or "Updated". Roll small related edits into one line; the diff already holds the file list. No paragraphs, no nested bullets.
- **Decisions.** Only when the work forced a real call: a tradeoff, a rejected alternative, a judgment a reviewer might question. One bullet per decision, the choice in bold, the reason after the colon. No decisions, no section.
- **How to verify.** Numbered steps, one action each, with the concrete expected result. Name what you actually ran. Screenshots for UI states, with alt text, using the repo's screenshot convention when one exists.
- **Risk.** The failure mode if this is wrong and the rollback, in one or two sentences. When there is none, say so: `Risk: none, docs only.`
- No long paragraphs anywhere. Three sentences max per paragraph, and **bold the key phrases** so the body scans.
- Delete a heading rather than leave it empty.
- Reference the tracker ticket (Linear, etc.) when one exists. Fold a written plan's findings into `Why` and `Decisions`; never commit a `plans/` folder.

### 7. Lint before you open

Write the body to a file, then gate it. Pass `--repo-template` when step 4 found a template.

```bash
bash scripts/pr-lint.sh "<title>" body.md
```

Exit non-zero means fix the title or body. Do not run `gh pr create` on a failing message.

### 8. Open the PR, or update the one that exists

```bash
gh pr view --json url -q .url 2>/dev/null
```

- **No PR yet:** `gh pr create --base <base> --head "$(git branch --show-current)" --title "<title>" --body-file body.md`. Add `--draft` when the user asked for a draft or the work is not ready for review.
- **A PR exists for this branch:** `gh pr edit --title "<title>" --body-file body.md`. Never open a second PR for the same branch.
- One PR per independent change. A branch that carries several unrelated changes is a sign to split them, not to write one omnibus PR.

### 9. Report

Give the user the PR URL and a one-line summary. If CI runs on the repo, note that checks have started. Do not merge; the author merges manually unless they say otherwise.

## Non-negotiables

1. Read the diff before you write one word. Memory of the conversation is not a source.
2. The title passes the imperative test and fits 72 characters.
3. The body opens with the overview line and fits on one screen. Cut before you bold.
4. `Why` states the problem or goal and the reason for this solution. A PR with no why is not ready.
5. `How to verify` names what you ran and what a reviewer should see. Unverified work is not a contribution.
6. Never let a template heading survive with placeholder text under it.
7. Pass the body with `--body-file` or a heredoc, never inline, so the formatting survives.

## Common mistakes

| Mistake                                     | Reality                                                              |
| ------------------------------------------- | -------------------------------------------------------------------- |
| Writing the body from memory                | Read the diff and commits; memory drifts from what shipped           |
| Opening the PR from `main`                  | Stop and branch first; never push to the default branch to open a PR |
| Title names a ticket or file                | Say what changed and its effect in plain language                    |
| Body opens with a heading                   | The first line is the overview: `Changes X so that Y`                |
| A 20-line `Changes` list                    | Three to seven top-level lines; roll the small edits up              |
| A `Changes` list of long paragraphs         | One short line per change; the prose belongs in `Why`                |
| Long unformatted paragraphs                 | Three sentences max, **key phrases in bold**                         |
| `Why` that lists files                      | `git show --stat` already does that; state the problem and reason    |
| A `Decisions` section with no decision      | Real tradeoffs only; delete the empty section                        |
| `Testing: works locally`                    | Numbered steps with the concrete expected result                     |
| Ignoring `.github/pull_request_template.md` | The repo's template wins over this skill's default structure         |
| A second PR for a branch that has one       | `gh pr edit` the existing PR                                         |
| One omnibus PR for unrelated changes        | Split into one PR per independent change                             |
| Force-pushing a branch with an open PR      | Append only; never rewrite history reviewers can see                 |
