# Language contract

Every word that lands on GitHub follows this contract: the title, the body, and any comment added afterwards. It merges ASD-STE100 Simplified Technical English (sentence construction that cannot be misread) with the Google developer documentation style guide (voice, person, tense, formatting).

STE was written so aircraft maintenance manuals could not be misread. The same constraints let a PR body survive a hostile reading.

## Sentences (ASD-STE100)

| Rule                                     | Do                                          | Do not                                                    |
| ---------------------------------------- | ------------------------------------------- | --------------------------------------------------------- |
| One approved meaning per word            | `use`                                       | `use`, `utilize`, `leverage`, `employ` for the same act   |
| One word per thing                       | `session` everywhere                        | `session`, `ctx`, `connection` for one thing              |
| 20 words max per instruction             | `Run the migration before you deploy.`      | a 40-word chain of clauses                                |
| 25 words max per statement               |                                             |                                                           |
| One instruction per sentence             | `Stop the worker. Then drain the queue.`    | `Stop the worker and drain the queue while checking lag.` |
| Active voice                             | `The handler drops the event.`              | `The event is dropped.`                                   |
| Simple present or simple past            | `The cache expires after 60s.`              | `The cache will have expired.`                            |
| Keep the articles                        | `Fix the race in the scheduler`             | `Fix race in scheduler`                                   |
| 3 words max in a noun cluster            | `the handler for account creation failures` | `account creation failure handler config`                 |
| Verbs for actions, not nouns             | `test the parser`                           | `perform testing of the parser`                           |
| 6 sentences max per paragraph, one topic |                                             |                                                           |
| Warnings before the step they apply to   | `This drops the index. Run the migration.`  | `Run the migration. This drops the index.`                |
| No idiom, slang, or metaphor             | `The lock is held for the whole request.`   | `The lock is held under the hood, out of the box.`        |

Titles inherit these rules. `Fix flaky auth test race condition handling` is a five-word noun cluster wearing a verb.

## Voice and format (Google style)

| Rule                      | Applied to PRs                                                                                      |
| ------------------------- | --------------------------------------------------------------------------------------------------- |
| The change is the actor   | `This change adds ...`, never `we added`. Address the reviewer as `you` when you must address them. |
| Active voice, agent named | `The scheduler retries the job.`                                                                    |
| Present tense             | Describe the code as it is after the change. Past tense only for the old behavior.                  |
| Conditions first          | `If the token is expired, the client refreshes it.` Never `Do Y if X`.                              |
| Sentence case headings    | `## How to verify`, never `## How To Verify`.                                                       |
| Serial commas             | `title, body, and footer`                                                                           |
| Code font                 | Identifiers, paths, flags, commands, and literal values.                                            |
| Descriptive link text     | `the retry policy doc`, never `here` or the raw URL.                                                |
| Unambiguous dates         | `2026-08-12`. Never `08/12/26`.                                                                     |
| Do not pre-announce       | Delete `This PR will explain ...`. Explain.                                                         |
| Numbered lists for order  | Verification steps are always numbered. Everything else is bullets.                                 |
| No condescension          | Delete `simply`, `just`, `easily`, `obviously`, `of course`.                                        |
| No `please`               | `Run the migration first.`                                                                          |
| No anthropomorphism       | `The test fails.` Not `The test is unhappy.`                                                        |

## Banned words

`simply`, `just`, `easily`, `obviously`, `please`, `leverage`, `utilize`, `in order to`, `various improvements`, `under the hood`, `out of the box`, `low-hanging fruit`, `we`.

Banned opener: `This PR ...`. Banned first words in a title: `Added`, `Adds`, `Fixed`, `Fixes`, `Updated`, `Updates`, `Changes`, `WIP`, `Misc`, `Various`, `Cleanup`.

`scripts/pr-lint.sh` catches the mechanical half of this contract. Sentence control stays with you.

## Sentence-level rewrites

| Before                                                                                       | Rule broken                              | After                                                              |
| -------------------------------------------------------------------------------------------- | ---------------------------------------- | ------------------------------------------------------------------ |
| `The event is dropped when the buffer is full.`                                              | passive, no agent                        | `The consumer drops the event when the buffer is full.`            |
| `We should probably leverage the existing cache utility in order to avoid duplicating this.` | `we`, `leverage`, `in order to`, hedging | `Use the existing cache utility. It already handles eviction.`     |
| `Simply run the migration and it will just work.`                                            | `simply`, `just`, no expected result     | `Run the migration. The sessions table gains a revoked_at column.` |
| `Run the migration if you are deploying to staging.`                                         | condition after the instruction          | `If you deploy to staging, run the migration first.`               |
| `account creation failure notification handler`                                              | 5-word noun cluster                      | `the handler that notifies on a failed account creation`           |
| `Fix race in scheduler`                                                                      | dropped articles                         | `Fix the race in the scheduler`                                    |
| `The parser is unhappy with trailing commas.`                                                | anthropomorphism                         | `The parser rejects trailing commas.`                              |
| `Stop the worker and drain the queue while watching the lag metric.`                         | three instructions in one sentence       | `Stop the worker. Drain the queue. Watch the lag metric.`          |
| `This was fixed on 08/12/26.`                                                                | ambiguous date, passive                  | `This change fixes it on 2026-08-12.`                              |

## Credit

Adapted from the `pr-writing` skill in [tjcages/skills](https://github.com/tjcages/skills/tree/main/pr-writing) (MIT), which merges Tim Pope's [A Note About Git Commit Messages](https://tbaggery.com/2008/04/19/a-note-about-git-commit-messages.html), Chris Beams's [How to Write a Git Commit Message](https://cbea.ms/git-commit/), ASD-STE100, and the Google developer documentation style guide.
