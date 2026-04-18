#!/usr/bin/env node

import { readFileSync, writeFileSync } from "node:fs";

const [, , input, output] = process.argv;
if (!input) {
  console.error("usage: node convert.mjs <input.md> [output.md]");
  process.exit(1);
}

const src = readFileSync(input, "utf-8");
const refs = new Map();
let counter = 0;

const convertLinks = (text) =>
  text.replace(
    /(?<!!)\[([^\]]+)\]\(([^)]+)\)/g,
    (_match, _text, url) => {
      if (!refs.has(url)) refs.set(url, ++counter);
      return `[^${refs.get(url)}]`;
    }
  );

const fencedSegments = src.split(/(```[\s\S]*?```)/g);

const converted = fencedSegments
  .map((seg, i) => {
    if (i % 2 === 1) return seg;

    const inlineSegments = seg.split(/(`[^`]+`)/g);
    return inlineSegments
      .map((part, j) => (j % 2 === 1 ? part : convertLinks(part)))
      .join("");
  })
  .join("");

const footnotes = [...refs.entries()]
  .map(([url, n]) => `[^${n}]: ${url}`)
  .join("\n");

const result = converted.trimEnd() + "\n\n" + footnotes + "\n";

if (output) {
  writeFileSync(output, result, "utf-8");
  console.log(`wrote ${output}`);
} else {
  process.stdout.write(result);
}
