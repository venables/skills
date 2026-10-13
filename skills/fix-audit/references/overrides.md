# Overrides

How to write one override, and how to keep the list short.

## Where overrides live

Use the place the project already uses. Do not make a second one.

| Manager               | Location                                                | Selector forms                                                       |
| --------------------- | ------------------------------------------------------- | -------------------------------------------------------------------- |
| pnpm 10+              | `overrides` in `pnpm-workspace.yaml`                    | `name`, `name@<range>`, `parent>name`, `parent@<range>>name@<range>` |
| pnpm (older projects) | `pnpm.overrides` in the root `package.json`             | the same                                                             |
| Bun                   | `overrides` or `resolutions` in the root `package.json` | `name` only                                                          |

If a pnpm project has overrides in both files, tell the user. Do not move
them yourself.

## Write a pnpm override

Write one entry for each vulnerable release line of a package.

- **Selector:** the vulnerable range from the advisory, on the package name.
  `<1.2.3` becomes `name@<1.2.3`. `>=2.0.0 <2.4.1` becomes
  `name@>=2.0.0 <2.4.1`.
- **Target:** a patched version on the same release line, written in the
  range style of the project. Find the style with
  `references/range-style.md` in the `update-deps` skill.
  - Exact style: one full version. Use the newest version on that release
    line that the age gate allows
    (`pick-version.mjs --same-line`). It must not be lower than the first
    patched version.
  - Caret style: `^` and the first patched version.
  - Tilde style: `~` and the first patched version.
  - Never `>=1.2.3`, in any style. An open-ended target can give a dependent
    a new major that it does not support.
- **Age gate:** the patched version must be old enough. If it is not, flag
  it.
- Always put the selector in quotes in YAML. It contains `@`, `<`, and `>`.

A project that installs exact versions:

```yaml
overrides:
  "tar@<6.2.1": "6.2.1"
  "vite@>=5.0.0 <5.4.12": "5.4.21"
  "vite@>=6.0.0 <6.0.9": "6.4.1"
```

A project that uses carets:

```yaml
overrides:
  "tar@<6.2.1": "^6.2.1"
  "vite@>=5.0.0 <5.4.12": "^5.4.12"
  "vite@>=6.0.0 <6.0.9": "^6.0.9"
```

An exact target does not move by itself. A later advisory on the same release
line changes that entry (see the next section). It does not add a line.

Do not add a parent path (`parent>name`) unless only one dependent can accept
the patched version. Do not write a bare `name` key. It forces every release
line of the package to one range.

## Merge with the entries that are there

Before you add an entry, read every entry for the same package. Then:

1. A new advisory on a release line that already has an entry: **change that
   entry**. Make the selector wide enough for both advisories, and move the
   target to the newer patched version. Do not add a second line.

   ```yaml
   # before, and a new advisory says <=10.1 is vulnerable, fixed in 10.2
   "package@<10": "10.1"

   # after, exact style
   "package@<=10.1": "10.2.0"

   # after, caret style
   "package@<=10.1": "^10.2.0"
   ```

2. A new advisory on a different release line: add an entry. The two
   selectors must not overlap.
3. Run `consolidate-overrides.mjs`. Delete every entry in `removed`. Correct
   every `self-match`. Resolve every `overlap` from the advisories, or report
   it.

## What the script decides

`consolidate-overrides.mjs` reports an entry as covered only when another
entry for the same package and the same parent path:

- has a selector that contains its selector,
- has a target that starts at the same version or a newer one, and
- stays on the same release line (the same major, or the same minor for
  `0.x`), unless the covered target was open-ended (`>=x`).

When two entries mean the same thing, it keeps the later one. It leaves the
rest for you, with a warning:

| Output               | Meaning                                                                              | Action                                                        |
| -------------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------------- |
| `removed`            | Another entry does the same work                                                     | Delete the entry                                              |
| `overlap` warning    | Two entries match some of the same versions, with targets on different release lines | Make the selectors separate (one for each line), or report it |
| `self-match` warning | The target is inside the range that the selector matches                             | Move the target to the first patched version                  |
| `skipped`            | `-`, `$name`, `npm:`, `catalog:`, `link:`, `workspace:`, `\|\|`, or a prerelease     | Do not change it                                              |

The script reads the flat `overrides:` block of `pnpm-workspace.yaml`, or
`pnpm.overrides` / `overrides` / `resolutions` in a `package.json`. If it
cannot read a line, it stops with the line number. Then write the map to a
JSON file and pass `--input <file>`.

## Unused entries

An entry is unused when no version that the tree resolves **without it** is
in its selector range. This occurs after a dependent is upgraded and no
longer asks for the old range.

Test it by deletion: delete the entry, install, and list the installed
versions (`pnpm why -r <name>`). The procedure is in step 1 of `SKILL.md`. A
clean audit is not the test, because an entry can have a purpose that is not
a security advisory.

## Bun

Bun overrides apply to **every** copy of the package in the tree. There are
no range selectors and no parent paths.

- Before you add one, run `bun why <name>`. Every dependent must accept the
  version you force. If two dependents need different majors, you cannot use
  an override. Flag it.
- Write the target in the range style of the project: an exact patched
  version, or a caret range that starts at the first patched version.
- Duplication in Bun is the same package in both `overrides` and
  `resolutions`. Keep one key, in the block the project already uses.
- To find an unused entry: delete it, run `bun install`, and run
  `bun why <name>`. If every installed version is at or above the patched
  version, leave it deleted.
