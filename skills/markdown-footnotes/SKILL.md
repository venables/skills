---
name: markdown-footnotes
description: >
  Convert inline markdown links to footnote-style references. Use when the user
  asks to convert, refactor, or clean up links in a .md file, or mentions
  "footnote links", "reference-style links", "inline to footnote", or wants to
  declutter a link-heavy markdown document. Also use when the user says things
  like "make these links cleaner", "move links to the bottom", or "citation
  style". Do NOT use for HTML link conversion or non-markdown files.
---

# Markdown Inline Links to Footnotes

Converts `[text](url)` to `[^N]` with a collected `[^N]: url` footnote section
at the end of the file. The link text is dropped — this is designed for
citation-style links where the text is just a source name.

## Usage

```bash
node convert.mjs <input.md> [output.md]
```

If no output path is given, writes to stdout.

## Behavior

- Deduplicates URLs — same URL reuses the same reference number
- Skips image links (`![alt](url)`) — these stay inline by default
- Skips links inside fenced code blocks (triple-backtick) and inline code spans
- Appends footnote block after two blank lines at end of file

## When to use the script vs. doing it inline

- **< 5 links**: just do it by hand in the response, no need to run the script
- **≥ 5 links or user wants a file back**: run the script

## Edge cases to watch

- **Nested parens in URLs** (e.g. wikipedia): script doesn't handle these — fix
  manually if encountered
- **Existing reference-style links**: script doesn't touch these, they pass
  through
- **Links in inline code** (single backtick): script skips these, they pass
  through unchanged

## Steps

1. Identify the target markdown file (ask if ambiguous)
2. Run `node convert.mjs <input.md> /tmp/converted.md`
3. Review output for edge case issues above
4. Copy the converted file back to the original location or return it
