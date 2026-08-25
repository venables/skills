#!/usr/bin/env bash
#
# Validate every skill in ./skills against the Agent Skills specification.
#
#   spec:      https://agentskills.io/specification
#   validator: https://github.com/agentskills/agentskills/tree/main/skills-ref
#
# The reference validator ships to PyPI as `skills-ref`, but installs a binary
# named `agentskills`. Install it first:
#
#   pip install skills-ref==0.1.1

set -euo pipefail

# Skills that deviate from the spec on purpose. Each one needs a reason here.
#
#   bro  Sets `disable-model-invocation: true`, a Claude Code field that keeps
#        the skill slash-command-only. The spec does not list that field, so
#        the reference validator rejects it. Removing it would let the model
#        trigger `bro` on its own, which defeats the point of the skill.
is_documented_exception() {
  case $1 in
    bro) return 0 ;;
    *) return 1 ;;
  esac
}

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
skills_dir=$repo_root/skills

if ! command -v agentskills >/dev/null 2>&1; then
  echo "error: 'agentskills' is not on PATH. Install it with:" >&2
  echo "  pip install skills-ref==0.1.1" >&2
  exit 127
fi

shopt -s nullglob
skills=("$skills_dir"/*/)

if ((${#skills[@]} == 0)); then
  echo "error: no skills found in $skills_dir" >&2
  exit 1
fi

skipped=0
failed=()

for skill in "${skills[@]}"; do
  name=$(basename "$skill")

  if is_documented_exception "$name"; then
    skipped=$((skipped + 1))
    printf 'skip  %s (documented spec exception)\n' "$name"
    continue
  fi

  if output=$(agentskills validate "$skill" 2>&1); then
    printf 'ok    %s\n' "$name"
  else
    failed+=("$name")
    printf 'FAIL  %s\n' "$name"
    printf '%s\n' "$output" | sed 's/^/      /'
  fi
done

printf '\n%d skills checked, %d skipped, %d failed\n' \
  "${#skills[@]}" "$skipped" "${#failed[@]}"

if ((${#failed[@]} > 0)); then
  exit 1
fi
