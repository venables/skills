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

## 2. Body

### Before

```markdown
## Description
This PR does some cleanup of the settings page and also fixes a couple of
bugs we found. Should be pretty straightforward to review!

## Testing
Tested locally, works fine.
```

Failures: pre-announcing, `we`, "some" and "a couple", two unrelated changes, no why, no risk, an unverifiable testing claim, no ticket.

### After

```markdown
## Changes

- Settings page reads feature flags from the `flags` context
- One `/api/flags` request on mount instead of seven
- Sections render in a stable order

## Why

Each settings section fetched its own flag, so opening the page fired
seven identical requests and the sections rendered in a random order.

The `flags` context already existed for the dashboard, so this change
reuses it instead of adding a settings-specific cache. A per-page cache
was the alternative; it would be a second source of truth for the same
flags.

Cost: a stale context leaves the whole page on old flags rather than one
section.

## How to verify

1. Open `/settings` with the network tab recording. One request hits `/api/flags`, not seven.
2. Toggle **Beta features** off. Every section hides in the same frame.
3. Run `pnpm test settings`. The new `renders sections in order` test passes.

## Risk

A stale context leaves the whole page on old flags. The context refetches
on focus, so the window is one tab-switch wide. Roll back by reverting
this PR; no migration is involved.

Closes ABC-472
```

The unrelated bug fixes became their own PR.

## 3. A net-new feature

Nothing was broken, so `Why` states the goal, not a manufactured problem.

```markdown
## Changes

- Admins can export a team's invoices as CSV
- New `GET /teams/:id/invoices.csv` route
- Export button on the team billing page

## Why

Finance asks admins for invoice history every quarter, and today an admin
copies it out of the UI by hand. This change gives them one download.

The route streams rows instead of building the file in memory, because
the largest team has 40k invoices. A background job with an emailed link
was the alternative; it is the right shape past a few hundred thousand
rows, and no team is near that.

Cost: the route holds a database cursor open for the length of the
download.

## How to verify

1. Sign in as a team admin and open **Billing**.
2. Click **Export CSV**. The browser downloads `invoices-<team>.csv`.
3. Open the file. The row count matches the invoice count on the page.

## Risk

A non-admin who guesses the URL gets a 403; the route reuses the billing
page's guard. Roll back by reverting this PR.

Closes BIL-88
```

## 4. Changes list

| Before                                                                                                 | After                                            |
| ------------------------------------------------------------------------------------------------------ | ------------------------------------------------ |
| `- Added a new deduplication step inside charge() that checks the idempotency key before calling out` | `- charge() deduplicates on the idempotency key` |
| `- Updated tests`                                                                                      | `- Regression test for the retry path`           |
| `- src/checkout/charge.ts, src/checkout/retry.ts`                                                      | `- Retried checkouts no longer double-charge`    |
