---
type: regex
target: { source: file, path: AGENTS.md }
pattern:
  "double-check|senior (staff )?engineer|ALWAYS run|be (extremely
  )?thorough|READ FIRST|READ LAST"
flags: i
match: not_contains
---
