---
type: regex
target: { source: file, path: AGENTS.md }
pattern:
  "double-check|senior engineer|ALWAYS run|be (extremely )?thorough|READ
  FIRST|READ LAST|think step by step"
flags: i
match: not_contains
---
