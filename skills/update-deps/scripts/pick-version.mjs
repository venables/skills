#!/usr/bin/env node
/*
 * Pick the version a dependency upgrade should target.
 *
 * Runs `npm view <pkg> time dist-tags --json` (so `.npmrc` registries apply)
 * and prints JSON:
 *
 *   { current, latest, target, bump, heldBack }
 *
 *   latest    the `latest` dist-tag
 *   target    the newest stable version above `current`, at or below `latest`,
 *             published at least `--min-age-minutes` ago; null when none is
 *   bump      "major" | "minor" | "patch" | null (a 0.x minor bump is major)
 *   heldBack  { version, eligibleAt } for the newest candidate the age gate
 *             blocks; null when the gate blocks nothing
 *
 * Usage:
 *   node pick-version.mjs zod --current 3.23.8 --min-age-minutes 4320
 *
 * `--input <file>` reads saved `npm view` output instead of the registry.
 */

import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { parseArgs } from "node:util";

const MS_PER_MINUTE = 60_000;
const VERSION_PATTERN = /^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+.*)?$/;

const parseVersion = (raw) => {
  const match = VERSION_PATTERN.exec(raw);
  if (!match) return null;
  const [, major, minor, patch, prerelease] = match;
  return {
    raw,
    core: [Number(major), Number(minor), Number(patch)],
    prerelease: prerelease ? prerelease.split(".") : [],
  };
};

const compareIdentifiers = (a, b) => {
  const aNumeric = /^\d+$/.test(a);
  const bNumeric = /^\d+$/.test(b);
  if (aNumeric && bNumeric) return Number(a) - Number(b);
  if (aNumeric) return -1;
  if (bNumeric) return 1;
  return a < b ? -1 : a > b ? 1 : 0;
};

const comparePrerelease = (a, b) => {
  if (a.length === 0 || b.length === 0) return b.length - a.length;
  const length = Math.max(a.length, b.length);
  const diff = Array.from({ length }, (_, i) =>
    a[i] === undefined ? -1 : b[i] === undefined ? 1 : compareIdentifiers(a[i], b[i]),
  ).find((d) => d !== 0);
  return diff ?? 0;
};

const compareVersions = (a, b) => {
  const coreDiff = a.core.map((n, i) => n - b.core[i]).find((d) => d !== 0);
  return coreDiff ?? comparePrerelease(a.prerelease, b.prerelease);
};

const classifyBump = (from, to) => {
  const [fromMajor, fromMinor] = from.core;
  const [toMajor, toMinor] = to.core;
  if (toMajor !== fromMajor) return "major";
  if (toMinor !== fromMinor) return fromMajor === 0 ? "major" : "minor";
  if (fromMajor === 0 && fromMinor === 0 && to.core[2] !== from.core[2]) return "major";
  return "patch";
};

const fail = (message) => {
  process.stderr.write(`pick-version: ${message}\n`);
  process.exit(1);
};

const readRegistry = (name, input) =>
  input
    ? readFileSync(input, "utf8")
    : execFileSync("npm", ["view", name, "time", "dist-tags", "--json"], { encoding: "utf8" });

const parseRegistry = (text) => {
  try {
    return JSON.parse(text);
  } catch {
    return fail("registry data is not valid JSON; expected `npm view <pkg> time dist-tags --json`");
  }
};

const toCandidates = (time, current, latest) =>
  Object.entries(time)
    .map(([raw, publishedAt]) => ({ version: parseVersion(raw), publishedAt: Date.parse(publishedAt) }))
    .filter(({ version }) => version && version.prerelease.length === 0)
    .filter(({ version }) => compareVersions(version, current) > 0)
    .filter(({ version }) => compareVersions(version, latest) <= 0)
    .toSorted((a, b) => compareVersions(b.version, a.version));

const pick = ({ registry, current, minAgeMinutes, now }) => {
  const latestRaw = registry["dist-tags"]?.latest;
  const latest = latestRaw ? parseVersion(latestRaw) : null;
  if (!registry.time || !latest) fail("registry JSON needs `time` and `dist-tags.latest`");

  const gateMs = minAgeMinutes * MS_PER_MINUTE;
  const candidates = toCandidates(registry.time, current, latest);
  const isOldEnough = ({ publishedAt }) => now - publishedAt >= gateMs;
  const chosen = candidates.find(isOldEnough) ?? null;
  const blocked = candidates[0] && !isOldEnough(candidates[0]) ? candidates[0] : null;

  return {
    current: current.raw,
    latest: latest.raw,
    target: chosen?.version.raw ?? null,
    bump: chosen ? classifyBump(current, chosen.version) : null,
    heldBack: blocked
      ? {
          version: blocked.version.raw,
          eligibleAt: new Date(blocked.publishedAt + gateMs).toISOString(),
        }
      : null,
  };
};

const { values, positionals } = parseArgs({
  allowPositionals: true,
  options: {
    current: { type: "string" },
    "min-age-minutes": { type: "string", default: "0" },
    now: { type: "string" },
    input: { type: "string" },
  },
});

const [name] = positionals;
if (!name && !values.input) fail("pass a package name, or --input <file>");

const current = values.current ? parseVersion(values.current) : null;
if (!current) fail("--current <exact installed version> is required");

const minAgeMinutes = Number(values["min-age-minutes"]);
if (!Number.isFinite(minAgeMinutes) || minAgeMinutes < 0) fail("--min-age-minutes must be >= 0");

const now = values.now ? Date.parse(values.now) : Date.now();
const registry = parseRegistry(readRegistry(name, values.input));

process.stdout.write(`${JSON.stringify(pick({ registry, current, minAgeMinutes, now }))}\n`);
