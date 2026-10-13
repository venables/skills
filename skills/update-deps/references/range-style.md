# Range style

Each project has a way to write versions: exact (`1.2.3`), caret (`^1.2.3`),
or tilde (`~1.2.3`). Find it before you write a specifier or an override
target. Then write every new or changed version in that style.

A project that pins every version is common. Its style is exact. That is a
style, not a hold: upgrade the dependency, and write the new version exact.

## Find the style

Use the first source that gives an answer.

1. **Package-manager config.**

   | Manager | Setting                                                                                          | Exact when                             |
   | ------- | ------------------------------------------------------------------------------------------------ | -------------------------------------- |
   | pnpm    | `saveExact` / `savePrefix` in `pnpm-workspace.yaml`, or `save-exact` / `save-prefix` in `.npmrc` | `saveExact: true`, or `savePrefix: ""` |
   | npm     | `save-exact` / `save-prefix` in `.npmrc`                                                         | `save-exact=true`, or `save-prefix=""` |
   | Yarn 2+ | `defaultSemverRangePrefix` in `.yarnrc.yml`                                                      | `defaultSemverRangePrefix: ""`         |
   | Bun     | `exact` in `bunfig.toml` `[install]`                                                             | `exact = true`                         |

   `savePrefix: "~"` (or the equivalent) means tilde.

2. **Renovate or Dependabot config.** Renovate `rangeStrategy: "pin"`, or the
   presets `:pinVersions`, `:pinAllExceptPeerDependencies`, and
   `:pinDependencies` / `:pinDevDependencies`, mean exact (the last two for
   one section only). Dependabot `versioning-strategy: increase` keeps the
   operator that is there.
3. **Project instructions.** `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md` (for
   example, "we install exact versions only").
4. **The manifests.** Read `dependencies` and `devDependencies` in every
   `package.json`, and the catalogs. Look at each group apart, because a
   project can pin `dependencies` and use carets for `devDependencies`, or pin
   in apps and use carets in published packages.
   - Almost all specifiers in a group have the same form: that is the style
     of the group.
   - For an override target, the entries already in `overrides` are the
     nearest evidence. Use their form if they agree.
5. **No clear answer.** Keep the operator of each specifier you change. Write
   a new entry with the package-manager default (caret), and say so in the
   report.

## Apply the style

- **A specifier you change:**
  - The config (sources 1 to 3) sets the style: write the new version in that
    style, also when the old specifier had a different operator. List the
    specifiers whose operator you changed in the report.
  - You found the style from the manifests only (source 4): keep the operator
    that the specifier has.
- **A new entry** (an override target, a new catalog entry): write it in the
  style of the project.
- **Exact style:** write the full version (`10.2.0`, not `10.2`).
- **`peerDependencies` and `engines`** are always ranges. Do not make them
  exact, and do not change their operator.
- **One exact pin in a project that uses ranges** can be a hold. See "Pins" in
  [project-rules.md](project-rules.md).
- Do not change the style setting itself.

## Which version to write

| Style | Specifier of a direct dependency     | Override target                                                                                                    |
| ----- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------ |
| Exact | The `target` from `pick-version.mjs` | The newest version on the same release line that the age gate allows, and not lower than the first patched version |
| Caret | `^` and the `target`                 | `^` and the first patched version                                                                                  |
| Tilde | `~` and the `target`                 | `~` and the first patched version                                                                                  |

For the exact override target, use `pick-version.mjs` with `--same-line`:

```bash
node <update-deps>/scripts/pick-version.mjs tar \
  --current 6.2.0 --min-age-minutes 4320 --same-line
```

`--current` is the installed vulnerable version. If the `target` is lower than
the first patched version, or there is no `target`, the age gate blocks the
fix. Flag it.

Never write an open-ended range (`>=1.2.3`) in any style.
