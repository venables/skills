# Report template

Give the answer first. Leave out a section that has no entries. Use one table
per section, so the user can scan it.

```markdown
Updated <N> dependencies in <M> commits on `chore/update-deps-<date>`.
<K> upgrades need your decision. Age gate: <value> (from <source>).

## Updated

| Package                     | From    | To      | Bump  | Where    | Small fixes                   |
| --------------------------- | ------- | ------- | ----- | -------- | ----------------------------- |
| vitest, @vitest/coverage-v8 | 3.2.4   | 4.0.6   | major | catalog  | renamed `coverage.all` option |
| zod                         | 3.25.76 | 3.25.80 | patch | apps/api | none                          |

## Needs your decision

| Package     | From   | To     | What breaks                            | Scope     | Recommendation      |
| ----------- | ------ | ------ | -------------------------------------- | --------- | ------------------- |
| tailwindcss | 3.4.17 | 4.1.14 | config moves to CSS; utilities renamed | ~40 files | do it as its own PR |

Links: <migration guide per row>

## Held back by the age gate

| Package | Installed | Newest | Eligible on |
| ------- | --------- | ------ | ----------- |
| react   | 19.1.0    | 19.2.1 | 2026-10-12  |

## Skipped by project rules

| Package | Rule                              |
| ------- | --------------------------------- |
| next    | Renovate `allowedVersions: "<16"` |

## Blocked

| Package    | Target | Reason                                 |
| ---------- | ------ | -------------------------------------- |
| typescript | 7.0.2  | `typescript-eslint` peer range is `<7` |

## Checks

- Baseline failures (there before this run): <list or "none">.
- Final: install, typecheck, lint, test, build all at baseline.
- Audit: <new advisories, or "no new advisories">.
- Not touched: <workspace:/link:/git specifiers, overrides that look unneeded>.
```

After the report, ask about the flagged upgrades with `AskUserQuestion`.
