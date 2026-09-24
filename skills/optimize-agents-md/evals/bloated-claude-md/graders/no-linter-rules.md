---
type: regex
target: { source: file, path: AGENTS.md }
pattern:
  "semicolon|2-space|indentation|double quotes|trailing comma|line length|100
  characters|sort imports|alphabetical|PascalCase|camelCase"
flags: i
match: not_contains
---
