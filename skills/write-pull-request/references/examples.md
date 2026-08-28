# Examples

Every "before" is a real shape you will produce if you skip the skill.

## 1. Title

| Before                                                        | Why it fails                                         | After                                                    |
| ------------------------------------------------------------- | ---------------------------------------------------- | -------------------------------------------------------- |
| `fixed the bug where users couldnt login sometimes`           | past tense, 49 chars of vagueness, no cause          | `fix: stop login retries failing on expired tokens`      |
| `fix: CHK-1042`                                               | the ticket carries the meaning; says nothing offline | `fix: stop double-charging cards on retried checkouts`   |
| `Updates to the auth module.`                                 | not imperative, trailing period, names no change     | `refactor: move token refresh into the auth client`      |
| `WIP`                                                         | says nothing, survives forever in history            | `test: add a failing test for the null-session path`     |
| `refactor(api): restructure the response serialization layer` | 58 chars, noun cluster of 4                          | `refactor: extract the response serializer from the API` |
| `feat: wire up the new endpoint`                              | describes the implementation, not the effect         | `feat: let admins export a team's invoices as CSV`       |
| `Fix flaky auth test race condition handling`                 | five-word noun cluster wearing a verb                | `fix: the race between login and token refresh`          |

Test each one: "If applied, this PR will **stop double-charging cards on retried checkouts**." The sentence holds.

## 2. Overview line

The first line of the body, above every heading. The change and the payoff, nothing else.

| Before                                                       | After                                                                         |
| ------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| `## Description` (body opens with a heading)                 | `Changes the flag fetch to one shared context so that /settings loads once.` |
| `This PR refactors how the settings page loads its flags...` | `Changes the flag fetch to one shared context so that /settings loads once.` |
| A three-sentence opening paragraph                           | One sentence; the detail lives in `Why`                                       |

## 3. Body

### Before

```markdown
## Description
This PR does some cleanup of the settings page and also fixes a couple of
bugs we found. Should be pretty straightforward to review!

## Testing
Tested locally, works fine.
```

Failures: no overview line, pre-announcing, `we`, "some" and "a couple", two unrelated changes, no why, no risk, an unverifiable testing claim, no ticket.

### After

```markdown
Changes the settings page to read feature flags from the shared `flags`
context so that opening it fires one request instead of seven.

## Why

Each section fetched its own flag: **seven identical requests** and a
**random render order**. The dashboard's `flags` context already exists,
so this change **reuses it**.

## Changes

- Settings page reads feature flags from the `flags` context
- One `/api/flags` request on mount instead of seven
- Sections render in a stable order

## Decisions

- **Shared context over a per-page cache**: a cache would be a second
  source of truth for the same flags.

## How to verify

1. Open `/settings` with the network tab recording. One request hits `/api/flags`, not seven.
2. Toggle **Beta features** off. Every section hides in the same frame.
3. Run `pnpm test settings`. The new `renders sections in order` test passes.

## Risk

A stale context leaves the **whole page** on old flags, not one section;
the context refetches on focus. Roll back by reverting this PR.

Closes ABC-472
```

The unrelated bug fixes became their own PR.

## 4. A net-new feature

Nothing was broken, so the overview and `Why` state the goal, not a manufactured problem.

```markdown
Adds a CSV export of a team's invoices so that admins stop copying them
out of the UI by hand.

## Why

Finance asks admins for invoice history **every quarter**. This change
gives them **one download**. Cost: the route holds a database cursor
open for the length of the download.

## Changes

- Admins can export a team's invoices as CSV
- New `GET /teams/:id/invoices.csv` route
- Export button on the team billing page

## Decisions

- **Stream rows over a background job**: the largest team has 40k
  invoices, which streams fine; an emailed link is the right shape past
  a few hundred thousand rows.

## How to verify

1. Sign in as a team admin and open **Billing**.
2. Click **Export CSV**. The browser downloads `invoices-<team>.csv`.
3. Open the file. The row count matches the invoice count on the page.

## Risk

A non-admin who guesses the URL gets a **403**; the route reuses the
billing page's guard. Roll back by reverting this PR.

Closes BIL-88
```

## 5. Changes list

Three to seven top-level lines. Roll small related edits into one line; the diff already holds the file list.

| Before                                                                                                 | After                                            |
| ------------------------------------------------------------------------------------------------------ | ------------------------------------------------ |
| `- Added a new deduplication step inside charge() that checks the idempotency key before calling out` | `- charge() deduplicates on the idempotency key` |
| `- Updated tests`                                                                                      | `- Regression test for the retry path`           |
| `- src/checkout/charge.ts, src/checkout/retry.ts`                                                      | `- Retried checkouts no longer double-charge`    |
| Twenty lines, one per file touched                                                                     | Five lines, one per change a reader cares about  |
