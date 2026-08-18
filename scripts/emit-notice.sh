#!/usr/bin/env bash
#
# emit-notice.sh: the one-time-notice emitter (bash twin of emit-notice.ps1).
#
# What this does, in plain terms:
#   docs/one-time-notices.md defines seven Step-0 units shared across `plan`,
#   `create`, and `update`: one self-heal that writes a file, and six notices
#   that print at most once per clone. This script runs them. It holds none of
#   their text. Every unit's printed lines and the self-heal's file body live
#   in scripts/emit-notice.json, once, so this script and its PowerShell twin
#   cannot drift from each other or from the doc.
#
# Invocation (one form, identical on both twins, so a caller documents one):
#   scripts/emit-notice.sh <plan|create|update>
#     Caller mode. Walks the units in file order, keeps every unit whose
#     `skills` list contains the caller's own name, and runs each one.
#   scripts/emit-notice.sh --section <section-id>
#     Explicit-section mode. Runs exactly the one unit whose `id` matches,
#     WHATEVER its `skills` list says. This is the mode for a caller that is
#     not one of the three verbs (`setup`, which runs the self-heal and the
#     legacy-blanket notice). Only the skills filter is bypassed: the unit's
#     marker gate and its trigger still decide whether it fires.
#
# What running one unit means, in order:
#   1. Marker gate. A unit with a `marker` is skipped when that marker file
#      already exists. That is what makes a notice show at most once per clone.
#      A unit with `marker: null` has no gate and re-checks every run (the
#      self-heal's documented exception).
#   2. Trigger. Four kinds, and nothing else is recognised:
#        always             fires whenever the marker gate let it through.
#        file-absent        fires when `trigger.path` is not a file.
#        gitignore-blanket  fires when `trigger.path` carries a blanket line
#                           for .milestone-config that no broad un-ignore
#                           clears.
#        unbootstrapped     fires when the resolved projectDocs tree holds no
#                           file, or .milestone-config/driver.json is missing.
#      An unrecognised kind does not fire, which is how a data file written by
#      a newer version degrades here: silently, one unit at a time.
#   3. Print. The unit's `text` lines, one per line, byte-exact. The single
#      substitution is `{{projectDocs}}`, replaced with the resolved
#      projectDocs path with trailing slashes stripped.
#   4. Write. A unit carrying `writes` creates that file from `writes.lines`.
#   5. Marker. A unit carrying a `marker` writes it, so it stays silent later.
#
# Working directory:
#   Every path a unit names is relative to the CURRENT working directory: the
#   consumer's repo root, where the calling skill already stands. The data file
#   is resolved next to THIS script instead, because the plugin is installed
#   outside the repo it acts on, so a repo-relative path would not find it.
#
# Why jq, and why one call per step:
#   jq is the approved bash-path JSON parser (.project/library-manifest.md
#   (## Approved libraries (by purpose)); the PowerShell twin uses native
#   ConvertFrom-Json). Unit metadata is fetched in ONE call that emits one
#   `|`-joined row per selected unit, and text/body lines in one call each,
#   with `jq -r` writing each array element followed by a newline: byte-for-byte
#   what the `printf '%s\n'` emitters in the doc produce. `|` is safe as the row
#   separator because every field it carries is an id, a kind, or a path, and
#   none may contain that character.
#
# Best-effort, always:
#   This script never aborts its caller (.project/design-philosophy.md
#   (## Error & failure philosophy)). A missing jq, a missing or malformed data
#   file, an unusable unit, or a failed write is skipped, and the exit status is
#   0 in every case, including a usage error (which still prints one line to
#   stderr, because a mis-wired call site is a bug worth seeing). `set -e` is
#   deliberately NOT set: aborting mid-run on a non-zero status is the one
#   behavior this contract forbids.
#
# Run it locally from a consumer repo root:  <plugin>/scripts/emit-notice.sh plan
# Exit 0, always.

DATA="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/emit-notice.json"

# --- guards: no jq, no data file, no unit array -> do nothing ----------------
command -v jq >/dev/null 2>&1 || exit 0
[ -f "$DATA" ] || exit 0
jq -e '(.units | type) == "array"' "$DATA" >/dev/null 2>&1 || exit 0

# --- arguments ---------------------------------------------------------------
mode=""
sel=""
case "${1:-}" in
  --section)
    mode="section"
    sel="${2:-}"
    ;;
  plan|create|update)
    mode="caller"
    sel="$1"
    ;;
esac

if [ -z "$mode" ] || [ -z "$sel" ]; then
  echo "usage: emit-notice.sh <plan|create|update> | emit-notice.sh --section <section-id>" >&2
  exit 0
fi

# --- resolve projectDocs -----------------------------------------------------
#
# Same read and same default as the doc's bootstrap-nudge emitter, so the two
# can't diverge: a non-string projectDocs (number/array), a missing file, or
# malformed JSON all fall back to .project/. ALL trailing slashes are stripped
# for the detect operand; an empty result (e.g. "/") falls back to .project so
# bash and PowerShell agree. The notice text re-adds the single "/", so the
# printed path always ends in one.
pd="$(jq -r 'if (.projectDocs | type) == "string" then .projectDocs else ".project/" end' .milestone-config/feeder.json 2>/dev/null || echo ".project/")"
[ -z "$pd" ] && pd=".project/"
while [ "$pd" != "${pd%/}" ]; do pd="${pd%/}"; done
[ -z "$pd" ] && pd=".project"

# --- trigger kinds -----------------------------------------------------------
#
# Returns 0 (fires) or 1 (does not). Every unrecognised kind returns 1, so an
# unknown trigger skips its unit rather than firing it blind. The two regexes
# below are the doc's legacy-blanket detect verbatim: a blanket counts as
# present UNLESS a broad un-ignore re-exposes the tracked config.
trigger_fires() {
  trigger_kind="$1"
  trigger_path="$2"
  case "$trigger_kind" in
    always)
      return 0
      ;;
    file-absent)
      [ -n "$trigger_path" ] || return 1
      [ ! -f "$trigger_path" ]
      ;;
    gitignore-blanket)
      [ -n "$trigger_path" ] && [ -f "$trigger_path" ] \
        && grep -Eq '^[[:space:]]*/?\.milestone-config(/\*?)?[[:space:]]*$' "$trigger_path" 2>/dev/null \
        && ! grep -Eq '^[[:space:]]*!/?\.milestone-config(/\*?)?[[:space:]]*$' "$trigger_path" 2>/dev/null
      ;;
    unbootstrapped)
      [ -z "$(find -L "$pd" -type f 2>/dev/null | head -1)" ] || [ ! -f ".milestone-config/driver.json" ]
      ;;
    *)
      return 1
      ;;
  esac
}

# --- select the units --------------------------------------------------------
#
# One row per selected unit, in file order:
#   <index>|<marker>|<trigger.kind>|<trigger.path>|<writes.path>|<writes.lines count>
# `index($sel)` yields a number (0 included, which jq treats as truthy) when the
# caller is listed and null when it is not. `try ... catch empty` scopes a bad
# entry to ITSELF: a unit that is not an object, or whose fields are the wrong
# type, contributes no row and the walk continues, which is the same per-unit
# skip the PowerShell twin performs.
#
# Shape gate, ahead of the match: a unit is usable only when it is an object,
# its `text` is an array, and, when it carries `writes`, `writes.lines` is an
# array too. Anything else is a MALFORMED unit and is skipped whole: nothing
# printed, no file written, and NO MARKER, so a bad entry can never permanently
# suppress its own notice. The PowerShell twin applies the same three tests, so
# a degenerate data file produces identical silence on both platforms
# (.project/conventions.md (## Test patterns), which makes bash/pwsh parity on
# degenerate inputs a test obligation).
#
# The caller match tests `skills` for an ARRAY before `index($sel)`. Without
# that test jq's `index` runs as SUBSTRING matching on a string, so a `skills`
# of "replanted" would match the caller `plan` here and match nothing in the
# PowerShell twin's `-contains`.
rows="$(jq -r --arg sel "$sel" --arg mode "$mode" '
  .units
  | to_entries[]
  | try (
      select((.value | type) == "object")
      | select((.value.text | type) == "array")
      | select((.value.writes | type) == "null"
               or (.value.writes.lines | type) == "array")
      | select(if $mode == "caller"
               then (.value.skills | if type == "array" then index($sel) else false end)
               else .value.id == $sel
               end)
      | [ (.key | tostring),
          (.value.marker // ""),
          (.value.trigger.kind // ""),
          (.value.trigger.path // ""),
          (.value.writes.path // ""),
          ((.value.writes.lines // []) | length | tostring),
          (.value.text | length | tostring) ]
      | join("|")
    ) catch empty' "$DATA" 2>/dev/null)"

[ -n "$rows" ] || exit 0

# --- run them ----------------------------------------------------------------
#
# A here-string, not a pipe, so the loop body runs in THIS shell.
#
# The marker is written LAST, and only once the text has printed and the unit's
# file (if it has one) has been written. A failure at either step skips the
# marker, so the notice is still owed on the next run rather than silently
# retired unshown.
#
# Each body is built WHOLE in memory before anything is emitted, so a jq failure
# costs the unit rather than leaving half a notice on screen or a truncated file
# on disk. `EOT` is appended inside jq and stripped back off with `%`, because
# command substitution eats trailing newlines and the emitted bytes are the
# contract: the sentinel keeps the final newline that `printf '%s\n'` produced
# in the doc's emitters.
while IFS='|' read -r idx marker kind tpath wpath wcount tcount; do
  [ -n "$idx" ] || continue

  # 1. marker gate
  if [ -n "$marker" ] && [ -f "$marker" ]; then
    continue
  fi

  # 2. trigger
  trigger_fires "$kind" "$tpath" || continue

  # 3. print the notice text. `tostring` before gsub matches the PowerShell
  #    twin's [string] cast on each element.
  if [ "$tcount" != "0" ]; then
    text_out="$(jq -r --argjson i "$idx" --arg pd "$pd" \
      '[ .units[$i].text[] | tostring | gsub("\\{\\{projectDocs\\}\\}"; $pd) + "\n" ] | join("") + "EOT"' \
      "$DATA" 2>/dev/null)" || continue
    [ -n "$text_out" ] || continue
    printf '%s' "${text_out%EOT}" || continue
  fi

  # 4. write the unit's file, when it has one. The only unit that does is the
  #    self-heal, whose trigger is the absence of exactly this path, so this
  #    can never clobber a user-edited file.
  if [ -n "$wpath" ] && [ "$wcount" != "0" ]; then
    write_body="$(jq -r --argjson i "$idx" \
      '[ .units[$i].writes.lines[] | tostring + "\n" ] | join("") + "EOT"' \
      "$DATA" 2>/dev/null)" || continue
    [ -n "$write_body" ] || continue
    mkdir -p "$(dirname "$wpath")" 2>/dev/null || true
    printf '%s' "${write_body%EOT}" > "$wpath" 2>/dev/null || continue
  fi

  # 5. write the marker, so a marker-gated unit stays silent from here on
  if [ -n "$marker" ]; then
    mkdir -p "$(dirname "$marker")" 2>/dev/null && : > "$marker" 2>/dev/null || true
  fi
done <<< "$rows"

exit 0
