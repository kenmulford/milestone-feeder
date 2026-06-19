#!/usr/bin/env bash
# milestone-feeder — no-source-edit gate (Claude PreToolUse: Write|Edit|MultiEdit|NotebookEdit)
#
# Bash parity of no-source-edit.ps1. Unconditionally blocks edits to the
# feeder's own source globs — the feeder reads code and authors issue text, it
# never writes source, so the deny applies in ANY context (no subagent
# carve-out). Requires `jq`.
#
# Deny mechanism: exit 2 + stderr. Escape hatch: CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT=1
# Fail-open: missing jq / parse errors exit 0 so a hook bug never bricks editing.

[ "${CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT:-}" = "1" ] && exit 0

input="$(cat)"
[ -z "$input" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)"
[ -z "$file_path" ] && exit 0
norm="${file_path//\\//}"

# Always-exempt paths. Source globs are gated even when markdown.
case "$norm" in
  */docs/*)      exit 0 ;;
  */.claude/*)   exit 0 ;;
  */Obsidian/*)  exit 0 ;;
esac

project_dir="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[ -z "$project_dir" ] && project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
project_dir="${project_dir//\\//}"

# Resolve the deny globs: feeder.json first (self-protection of the feeder's own
# repo), then the resolved driver config (.milestone-config/driver.json -> root
# milestone-driver.json). First file yielding a non-empty sourceGlobs wins; if
# none does, fail-open (exit 0).
globs=""
for cfg in \
  "$project_dir/.milestone-config/feeder.json" \
  "$project_dir/.milestone-config/driver.json" \
  "$project_dir/milestone-driver.json"; do
  [ -f "$cfg" ] || continue
  globs="$(jq -r '.sourceGlobs[]? // empty' "$cfg" 2>/dev/null)"
  [ -n "$globs" ] && break
done
[ -z "$globs" ] && exit 0

rel="$norm"
case "$norm" in
  "$project_dir"/*) rel="${norm#"$project_dir"/}" ;;
esac

while IFS= read -r g; do
  g="${g%$'\r'}"          # strip trailing CR (jq on Windows/msys emits CRLF)
  [ -z "$g" ] && continue
  pat="${g//\*\*/\*}"     # ** -> * ('*' in a case glob matches across '/')
  blocked=0
  # shellcheck disable=SC2254
  case "$rel"  in $pat)    blocked=1 ;; esac
  # shellcheck disable=SC2254
  case "$norm" in */$pat)  blocked=1 ;; esac
  if [ "$blocked" = "1" ]; then
    echo "milestone-feeder: edits to source ('$rel') are blocked — the feeder authors no code. Set CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT=1 to override." >&2
    exit 2
  fi
done <<EOF
$globs
EOF

exit 0
