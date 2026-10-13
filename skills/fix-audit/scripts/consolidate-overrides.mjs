#!/usr/bin/env node
/*
 * Find dependency overrides that another override already covers.
 *
 * `pnpm audit --fix` adds one override for each advisory and never removes an
 * old one, so a package collects entries such as:
 *
 *   "package@<10": "10.1"
 *   "package@<=10.1": "10.2"
 *
 * The second entry matches every version the first one matches, and its target
 * is newer. The first entry is dead weight. This script reports it.
 *
 * An entry is removed only when another entry for the same package (and the
 * same parent path):
 *
 *   - has a selector that contains its selector,
 *   - has a target that starts at the same version or a newer one, and
 *   - stays on the same release line, unless the removed target was open-ended
 *     (`>=x`) and so accepted any newer line already.
 *
 * Entries that overlap but do not meet all three stay, with an `overlap`
 * warning. Entries it cannot read (`-`, `$ref`, `npm:`, `catalog:`, `||`) are
 * left alone and listed in `skipped`. The script never writes a file.
 *
 * Usage:
 *   node consolidate-overrides.mjs --file pnpm-workspace.yaml
 *   node consolidate-overrides.mjs --file package.json
 *   node consolidate-overrides.mjs --input overrides.json   (a flat JSON map)
 *
 * Prints: { sources: [{ source, overrides, removed, warnings, skipped }] }
 */

import { readFileSync } from "node:fs";
import { parseArgs } from "node:util";

const INFINITE = [Infinity, 0, 0];
const ZERO = [0, 0, 0];
const NAME = String.raw`(?:@[a-z0-9~][a-z0-9._~-]*\/)?[a-z0-9~][a-z0-9._~-]*`;
const SELECTOR_PATTERN = new RegExp(String.raw`^(?:(.*[^@\s])>)?(${NAME})(?:@(.+))?$`, "i");
const COMPARATOR_PATTERN = /^(<=|>=|<|>|=|\^|~)?v?(\d+)(?:\.(\d+|x|\*))?(?:\.(\d+|x|\*))?$/i;

const fail = (message) => {
  process.stderr.write(`consolidate-overrides: ${message}\n`);
  process.exit(1);
};

const compare = (a, b) => a.map((n, i) => n - b[i]).find((d) => d !== 0 && !Number.isNaN(d)) ?? 0;
const maxOf = (a, b) => (compare(a, b) >= 0 ? a : b);
const minOf = (a, b) => (compare(a, b) <= 0 ? a : b);

const toNumber = (part) => (part === undefined || /^[x*]$/i.test(part) ? null : Number(part));

/* The first version after every version that `[major, minor, patch]` names. */
const next = ([major, minor, patch]) =>
  patch !== null ? [major, minor, patch + 1] : minor !== null ? [major, minor + 1, 0] : [major + 1, 0, 0];

const fill = ([major, minor, patch]) => [major, minor ?? 0, patch ?? 0];

const caretEnd = ([major, minor, patch]) => {
  if (major > 0 || minor === null) return [major + 1, 0, 0];
  if (minor > 0 || patch === null) return [0, minor + 1, 0];
  return [0, 0, patch + 1];
};

const tildeEnd = ([major, minor]) => (minor === null ? [major + 1, 0, 0] : [major, minor + 1, 0]);

/* One comparator as a half-open interval: `lo` inclusive, `hi` exclusive. */
const comparatorInterval = (token) => {
  const match = COMPARATOR_PATTERN.exec(token);
  if (!match) return null;
  const [, operator = "=", major, minor, patch] = match;
  const parts = [Number(major), toNumber(minor), toNumber(patch)];
  const intervals = {
    "<": { lo: ZERO, hi: fill(parts) },
    "<=": { lo: ZERO, hi: next(parts) },
    ">": { lo: next(parts), hi: INFINITE },
    ">=": { lo: fill(parts), hi: INFINITE },
    "=": { lo: fill(parts), hi: next(parts) },
    "^": { lo: fill(parts), hi: caretEnd(parts) },
    "~": { lo: fill(parts), hi: tildeEnd(parts) },
  };
  return intervals[operator];
};

const rangeInterval = (range) => {
  const tokens = range
    .trim()
    .replace(/([<>=~^]+)\s+/g, "$1")
    .split(/\s+/);
  const intervals = tokens.map(comparatorInterval);
  if (intervals.some((interval) => interval === null)) return null;
  return intervals.reduce(
    (acc, interval) => ({ lo: maxOf(acc.lo, interval.lo), hi: minOf(acc.hi, interval.hi) }),
    { lo: ZERO, hi: INFINITE },
  );
};

const releaseLine = ([major, minor]) => (major === 0 ? `0.${minor}` : `${major}`);

const parseEntry = ([key, value], index) => {
  const skip = (reason) => ({ key, value, index, skipped: reason });
  if (typeof value !== "string") return skip("value is not a string");

  const selectorMatch = SELECTOR_PATTERN.exec(key);
  if (!selectorMatch) return skip("selector not understood");
  const [, parent = "", name, range] = selectorMatch;

  const selector = range === undefined ? { lo: ZERO, hi: INFINITE } : rangeInterval(range);
  if (!selector) return skip("selector range not understood");

  const target = rangeInterval(value);
  if (!target) return skip("target not understood");

  return {
    key,
    value,
    index,
    group: `${parent}>${name}`,
    selector,
    floor: target.lo,
    open: compare(target.hi, INFINITE) === 0,
  };
};

const contains = (outer, inner) => compare(outer.lo, inner.lo) <= 0 && compare(inner.hi, outer.hi) <= 0;

const overlaps = (a, b) => compare(a.lo, b.hi) < 0 && compare(b.lo, a.hi) < 0;

const covers = (winner, loser) =>
  winner.group === loser.group &&
  contains(winner.selector, loser.selector) &&
  compare(winner.floor, loser.floor) >= 0 &&
  (loser.open || releaseLine(winner.floor) === releaseLine(loser.floor));

/* When two entries cover each other, the later one wins. */
const beats = (winner, loser) =>
  winner !== loser && covers(winner, loser) && (!covers(loser, winner) || winner.index > loser.index);

const consolidate = (map) => {
  const parsed = Object.entries(map).map(parseEntry);
  const readable = parsed.filter((entry) => !entry.skipped);

  const isKept = (entry) => !readable.some((other) => beats(other, entry) && isKept(other));
  const kept = readable.filter(isKept);
  const removed = readable
    .filter((entry) => !kept.includes(entry))
    .map((entry) => ({
      key: entry.key,
      value: entry.value,
      coveredBy: kept.find((other) => beats(other, entry)).key,
    }));
  const removedKeys = removed.map(({ key }) => key);

  const selfMatches = kept
    .filter(({ selector, floor }) => compare(selector.lo, floor) <= 0 && compare(floor, selector.hi) < 0)
    .map(({ key, value }) => ({
      type: "self-match",
      keys: [key],
      message: `${key} still matches its own target ${value}; the override does not leave the vulnerable range`,
    }));

  const overlapWarnings = kept.flatMap((a, i) =>
    kept
      .slice(i + 1)
      .filter((b) => a.group === b.group && overlaps(a.selector, b.selector))
      .map((b) => ({
        type: "overlap",
        keys: [a.key, b.key],
        message: `${a.key} and ${b.key} match some of the same versions but neither covers the other; decide by hand`,
      })),
  );

  return {
    overrides: Object.fromEntries(Object.entries(map).filter(([key]) => !removedKeys.includes(key))),
    removed,
    warnings: [...selfMatches, ...overlapWarnings],
    skipped: parsed.filter((entry) => entry.skipped).map(({ key, value, skipped }) => ({ key, value, reason: skipped })),
  };
};

const YAML_ENTRY_PATTERN =
  /^\s+(?:"([^"]+)"|'([^']+)'|([^\s:#'"][^:]*?))\s*:\s+(?:"([^"]*)"|'([^']*)'|([^\s#'"][^#]*?))\s*(?:#.*)?$/;

/* Reads the flat `overrides:` block only. Any line it cannot read is an error. */
const readYamlOverrides = (text, path) => {
  const lines = text.split(/\r?\n/);
  if (lines.some((line) => /^overrides:\s*[^\s#{]|^overrides:\s*\{\s*\S[^}]*\}/.test(line))) {
    fail(`${path}: overrides is not a plain block map; pass the map with --input instead`);
  }
  const start = lines.findIndex((line) => /^overrides:\s*(#.*)?$/.test(line));
  if (start === -1) return {};
  const rest = lines.slice(start + 1);
  const end = rest.findIndex((line) => /^\S/.test(line) && !line.startsWith("#"));
  const block = end === -1 ? rest : rest.slice(0, end);

  return Object.fromEntries(
    block
      .map((line, offset) => ({ line, number: start + offset + 2 }))
      .filter(({ line }) => line.trim() !== "" && !line.trim().startsWith("#"))
      .map(({ line, number }) => {
        const match = YAML_ENTRY_PATTERN.exec(line);
        if (!match) fail(`${path}:${number}: cannot read this overrides line; pass the map with --input instead`);
        const [, doubleKey, singleKey, plainKey, doubleValue, singleValue, plainValue] = match;
        return [doubleKey ?? singleKey ?? plainKey, doubleValue ?? singleValue ?? plainValue];
      }),
  );
};

const readPackageJsonSources = (text) => {
  const manifest = JSON.parse(text);
  return [
    ["pnpm.overrides", manifest.pnpm?.overrides],
    ["overrides", manifest.overrides],
    ["resolutions", manifest.resolutions],
  ].filter(([, map]) => map !== undefined);
};

const readSources = ({ file, input }) => {
  if (input) return [["input", JSON.parse(readFileSync(input, "utf8"))]];
  const text = readFileSync(file, "utf8");
  return file.endsWith(".json") ? readPackageJsonSources(text) : [["overrides", readYamlOverrides(text, file)]];
};

const { values } = parseArgs({
  options: {
    file: { type: "string" },
    input: { type: "string" },
  },
});

if (!values.file && !values.input) fail("pass --file <pnpm-workspace.yaml | package.json> or --input <map.json>");

const sources = readSources(values).map(([source, map]) => ({ source, ...consolidate(map) }));

process.stdout.write(`${JSON.stringify({ sources }, null, 2)}\n`);
