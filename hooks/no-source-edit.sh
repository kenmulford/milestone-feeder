#!/usr/bin/env bash
# milestone-feeder — no-source-edit gate (Claude PreToolUse: Write|Edit|MultiEdit|NotebookEdit)
#
# Bash parity of no-source-edit.ps1. Blocks edits to the feeder's own source
# globs — the feeder reads code and authors issue text, it never writes source.
# The deny applies to the feeder's OWN actors (the main thread and the feeder's
# own subagents); a positively-identified non-feeder subagent (e.g. the driver's
# implementer building the feeder) is allowed through. Requires `jq`.
#
# Actor gate (PreToolUse hooks carry no skill/plugin identity, only the agent
# fields below — code.claude.com/docs/en/hooks.md):
#   - agent_id is non-empty ONLY inside a subagent call; absent or empty => main
#     thread (matches ps1's $hasAgentId test).
#   - agent_type is the subagent's BARE frontmatter `name` (NOT namespaced); for
#     custom subagents it is "the `name` field from the agent's frontmatter, not
#     the filename".
# Decision (only when the target matches a source glob):
#   BLOCK  when there is no (or empty) agent_id (main thread) OR agent_type is one
#          of the feeder's OWN agents (FEEDER_OWN_AGENTS below) — fail-closed: an
#          unknown/empty agent_type with an agent_id present also blocks.
#   ALLOW  when agent_id is non-empty AND agent_type is a positively-identified
#          non-feeder subagent.
#
# Deny mechanism: exit 2 + stderr. Escape hatch: CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT=1
# Fail-open: missing jq / parse errors / unresolved sourceGlobs exit 0 so a hook
# bug never bricks editing.

# The feeder's OWN agent names (bare frontmatter `name`, NOT namespaced). This is
# a SECURITY control, so the set is HARDCODED here inside the protected hooks/**
# boundary rather than read from feeder.json. It MUST stay in sync with the
# `name:` of every agents/*.md — enforced by the CI drift-guard in
# scripts/validate-plugin-structure.py. Machine-parseable literal (one
# space-separated set on the next line; keep that exact shape for the guard):
# FEEDER_OWN_AGENTS: architect issue-author roadmap-splitter
FEEDER_OWN_AGENTS="architect issue-author roadmap-splitter"

[ "${CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT:-}" = "1" ] && exit 0

input="$(cat)"
[ -z "$input" ] && exit 0
command -v jq >/dev/null 2>&1 || exit 0

file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty' 2>/dev/null)"
[ -z "$file_path" ] && exit 0
norm="${file_path//\\//}"

# Actor identity (see header). An absent OR empty-string agent_id is the main
# thread (BLOCK on a source path) — matching ps1's `$hasAgentId` test; `// empty`
# collapses both to "", so a non-empty agent_id positively marks a subagent.
# agent_type stays a plain string so a missing/empty value compares unequal to
# every name in FEEDER_OWN_AGENTS.
agent_id="$(printf '%s' "$input" | jq -r '.agent_id // empty' 2>/dev/null)"
agent_type="$(printf '%s' "$input" | jq -r '.agent_type // empty' 2>/dev/null)"

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
    # Source-glob match. Apply the actor gate: ALLOW only a positively-identified
    # non-feeder subagent (a non-empty agent_id AND a non-empty agent_type that is
    # not one of the feeder's own agents). The main thread (absent OR empty
    # agent_id), the feeder's own subagents, and any ambiguous actor (agent_id
    # present but empty agent_type) all fall through and are BLOCKED — fail-closed.
    if [ -n "$agent_id" ] && [ -n "$agent_type" ]; then
      is_own_agent=0
      for own in $FEEDER_OWN_AGENTS; do
        [ "$agent_type" = "$own" ] && is_own_agent=1 && break
      done
      [ "$is_own_agent" = "0" ] && exit 0   # positively-identified non-feeder subagent
    fi
    echo "milestone-feeder: edits to source ('$rel') are blocked — the feeder authors no code. Set CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT=1 to override." >&2
    exit 2
  fi
done <<EOF
$globs
EOF

exit 0
