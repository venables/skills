#!/usr/bin/env bash
#
# Lint a pull request title and body against the write-pull-request rules.
#
#   usage: pr-lint.sh [--repo-template] "<title>" [body-file | -]
#
# The body comes from the file, or from stdin when the second argument is "-".
# With no body argument, only the title is checked. Pass --repo-template when
# the repo ships its own pull_request_template.md; the section-shape checks
# (Changes / Why / How to verify / Risk) are skipped, the language checks run.
#
# Exit 0 when every check passes, 1 on any hard failure, 2 on bad usage.
# Warnings never change the exit code.
set -uo pipefail

repo_template=0
if [ "${1:-}" = "--repo-template" ]; then
  repo_template=1
  shift
fi

if [ $# -lt 1 ]; then
  echo 'usage: pr-lint.sh [--repo-template] "<title>" [body-file | -]' >&2
  exit 2
fi

title=$1
body=""
has_body=0
case ${2:-} in
  "") ;;
  -) body=$(cat); has_body=1 ;;
  *) body=$(cat "$2") || exit 2; has_body=1 ;;
esac

fail=0
err()  { printf '  x %s\n' "$*"; fail=1; }
warn() { printf '  ! %s\n' "$*"; }
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# ---------------------------------------------------------------- title --

# Split off an optional conventional-commit prefix: "feat: ", "fix(auth)!: ".
subject=$title
if printf '%s' "$title" | grep -Eq '^[a-z]+(\([^)]+\))?!?: '; then
  subject=${title#*: }
fi

n=${#title}
s=${#subject}
printf 'Title (%d chars): %s\n' "$n" "$title"

[ "$n" -gt 72 ] && err "title is $n chars (hard limit 72)"
if [ "$s" -gt 50 ] && [ "$n" -le 72 ]; then
  if [ "$s" -eq "$n" ]; then warn "title is $n chars (target 50)"
  else warn "text after the prefix is $s chars (target 50)"; fi
fi
[ -z "${subject//[[:space:]]/}" ] && err "title has no text after the prefix"

case $subject in *.) err "title must not end with a period" ;; esac
case $subject in \[*) err "no [bracket] tags in the title" ;; esac

if printf '%s' "$subject" | grep -Eq '^[A-Z][A-Z0-9]+-[0-9]+$'; then
  err "title is only a ticket ID; say what changed"
fi

if printf '%s' "$subject" | grep -Eq '[A-Za-z0-9_-]+\.(ts|tsx|js|jsx|mjs|py|go|rs|rb|sh|md|json|yml|yaml)( |$)'; then
  warn "title names a file; say what changed and its effect instead"
fi

# Emoji: any 4-byte UTF-8 sequence, or the U+2600-27BF symbol block.
if printf '%s' "$title" | LC_ALL=C grep -Eq $'[\xF0-\xF4]|\xE2[\x98-\x9E]'; then
  err "no emoji in the title"
fi

first=$(lower "${subject%% *}")
case $first in
  added|adding|adds|fixed|fixes|fixing|updated|updates|updating|changed|changes| \
  changing|removed|removes|improved|improves|improvements|refactored|refactors| \
  wip|misc|various|cleanup|stuff|minor|tweaks)
    err "'${subject%% *}' is not imperative; test: 'If applied, this PR will ___'" ;;
  *ed|*ing)
    warn "'${subject%% *}' looks past tense or continuous; test: 'If applied, this PR will ___'" ;;
esac

[ "$has_body" -eq 0 ] && { [ "$fail" -eq 0 ] && printf '  ok passes write-pull-request rules\n'; exit "$fail"; }

# ----------------------------------------------------------------- body --

if [ -z "${body//[[:space:]]/}" ]; then
  err "body is empty"
  exit 1
fi

# Prose only: drop fenced blocks and inline code, so quoting a bad example is legal.
prose=$(printf '%s\n' "$body" | awk '/^[ \t]*```/{f=!f; next} !f' | sed 's/`[^`]*`//g')

# Template leftovers.
printf '%s\n' "$prose" | grep -q '<!--' \
  && err "an HTML comment survived from the template"
printf '%s\n' "$prose" | grep -Eq '<[A-Z][^>]*>' \
  && err "a template placeholder survived: $(printf '%s\n' "$prose" | grep -Eo '<[A-Z][^>]*>' | head -1)"

# Empty sections: a heading followed by another heading or the end of the body.
prev_heading=""
while IFS= read -r line || [ -n "$line" ]; do
  case $line in
    "#"*" "*)
      [ -n "$prev_heading" ] && err "empty section: $prev_heading"
      prev_heading=$line ;;
    "") ;;
    *) prev_heading="" ;;
  esac
done <<< "$body"
[ -n "$prev_heading" ] && err "empty section: $prev_heading"

# Banned words and openers.
for w in simply just easily obviously please leverage utilize "in order to" \
         "under the hood" "out of the box" "low-hanging fruit"; do
  printf '%s\n' "$prose" | grep -qiw -- "$w" && err "banned word: '$w'"
done
printf '%s\n' "$prose" | grep -qiw 'we' \
  && err "'we' is banned; make the change the actor: 'this change adds ...'"
printf '%s\n' "$prose" | grep -Eq '^(This|The) PR ' \
  && err "do not pre-announce with 'This PR ...'; say what changed"

# Sentence length: 25 words max. Skip headings, lists, and lines with URLs.
printf '%s\n' "$prose" | awk '
  /^#/ || /^[ \t]*[-*] / || /^[ \t]*[0-9]+\. / || /https?:\/\// { next }
  {
    n = split($0, parts, /[.!?]([ \t]|$)/)
    for (i = 1; i <= n; i++) {
      words = split(parts[i], w, /[ \t]+/)
      if (words > 25) printf "  ! sentence has %d words (max 25): %s...\n", words, substr(parts[i], 1, 60)
    }
  }'

if [ "$repo_template" -eq 0 ]; then
  for h in "## Changes" "## Why" "## How to verify" "## Risk"; do
    printf '%s\n' "$body" | grep -q "^$h\$" || err "missing section: $h"
  done

  # Changes: one short line per change, no nesting, no prose.
  printf '%s\n' "$body" | awk '
    /^## / { in_changes = ($0 == "## Changes"); next }
    in_changes && /^[ \t]+[-*] / { printf "  ! nested bullet in Changes: %s\n", $0; next }
    in_changes && /^[-*] / {
      n = NF - 1
      if (n > 12) printf "  ! Changes line is %d words (keep it under ten): %s\n", n, $0
      next
    }
    in_changes && /^[^ \t#-]/ { printf "  ! prose in Changes; move it to Why: %s\n", substr($0, 1, 60) }'

  # How to verify: numbered steps.
  printf '%s\n' "$body" | awk '
    /^## / { in_verify = ($0 == "## How to verify"); next }
    in_verify && /^[0-9]+\. / { found = 1 }
    END { if (!found) print "  ! How to verify has no numbered steps" }'
fi

[ "$fail" -eq 0 ] && printf '  ok passes write-pull-request rules\n'
exit "$fail"
