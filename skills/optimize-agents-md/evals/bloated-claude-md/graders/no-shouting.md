---
type: regex
target: { source: file, path: AGENTS.md }
pattern: '\bIMPORTANT\b|\bCRITICAL\b'
match: not_contains
---
