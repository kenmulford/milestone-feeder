#!/usr/bin/env bash
#
# update-reconcile-parent.sh: update's Step 1R roadmap parent-reconcile
# mechanics (bash twin of update-reconcile-parent.ps1).
#
# What this does, in plain terms:
#   docs/update-reconcile-parent.md records the pass that keeps a roadmap's
#   single `md-epic` parent issue in sync on a re-plan. Five of its seven steps
#   are `create`'s own mechanics, reused by reference through the sibling twin
#   pair (scripts/md-epic-parent.sh / .ps1). This script performs the three that
#   are `update`'s OWN: the preliminary receipt read, the diff-gated body write,
#   and the removed-milestone detection. It holds NO judgment. The human-facing
#   diff review, the flag-never-close reporting, and the roadmap-manifest gate
#   itself stay in the calling skill's prose (skills/update/SKILL.md Step 1R):
#   this script prints rows and values, and the caller decides what to say about
#   them and whether to call it at all.
#
# Invocation (one form, identical on both twins, so a caller documents one):
#   scripts/update-reconcile-parent.sh <subcommand> [args]
#
# Entry points. Each is SEPARATELY INVOKABLE, so the calling skill runs the one
# its step needs and skips the ones its branch does not reach (the
# reuse-by-reference discipline at .project/design-philosophy.md (## What we
# optimize for)).
#
#   read-receipt <manifest>
#     args   The roadmap manifest path.
#     does   Reads the manifest's FIRST `Parent issue (GitHub): #<n>` header
#            line (docs/roadmap-manifest-format.md). A plain, side-effect-free
#            read: it never resolves, never creates, and never writes. The
#            resolve-or-create in step 3 re-examines this same line as its own
#            first branch, so this read never substitutes for that resolution;
#            it only tells the caller whether a live parent body already exists
#            to compare against, which is what gates steps 3, 4, and 5.
#     out    The parent issue number, on one line, when the manifest carries a
#            well-formed receipt. NOTHING otherwise: no receipt line at all (a
#            brand-new roadmap, or one `create` has not deployed the parent
#            for), and a malformed or non-numeric value (a hand-edited
#            manifest) both come back empty, the same absent-means-absent guard
#            `update`'s own Step 3.0 milestone-receipt read uses.
#     exit   0, whether or not a number was found; 2 on a usage problem or an
#            unreadable manifest.
#
#   diff-gate <parent> <body-file> <live-body-file>
#     args   The resolved parent issue number; the body file `render-body`
#            produced on THIS run; the path to WRITE the parent's live body to,
#            so `detect-removed` reads the SAME bytes this comparison used and
#            the pass spends exactly one live-body fetch.
#     does   Fetches the parent's live body, saves it, and compares it to the
#            freshly rendered body. Identical: writes NOTHING, no PATCH, so an
#            unchanged roadmap costs zero parent-body writes. Differ: PATCHes
#            with the REPLACE-form `gh issue edit --body-file`. The caller
#            invokes this ONLY when the preliminary receipt was present; on a
#            brand-new parent there is nothing to diff against and step 3's
#            create/adopt already wrote the correct body.
#     out    Two TAB rows, in this order:
#              compare<TAB>same|differ      the comparison outcome
#              patch<TAB>skipped|patched    what the gate then did
#            The `compare` row is printed BEFORE the PATCH is attempted, so a
#            failed write still leaves the caller the decision its report has to
#            name.
#     exit   0; 2 on a usage problem, a missing body file, or a live-body file
#            that could not be written; 3 when `gh` is unavailable or a `gh`
#            call failed, naming which one on stderr. These are LOAD-BEARING
#            writes: the caller STOPS the pass on a non-zero, reports what
#            completed and what remains, and deletes nothing. A re-run resumes
#            by re-reading the receipt and re-comparing fresh. Nothing here ever
#            deletes, closes, or unlinks anything.
#
#   detect-removed <live-body-file> <number> [<number> ...]
#     args   The live-body file `diff-gate` saved (the parent's `md-epic-order`
#            block as it stood BEFORE this run); every number `gather-numbers`
#            printed on this run, in build order.
#     does   Reads the OLD block's `number: <n>` lines and diffs them against
#            the current set. A number in the OLD block that the current set no
#            longer carries was dropped by the re-plan. Detection only: no
#            unlink call, no close call, and no delete call exists here or
#            anywhere in this pass. The caller invokes this ONLY when the
#            preliminary receipt was present; a brand-new parent has no prior
#            state, so nothing can have been removed from it.
#     out    One TAB row per dropped milestone, in the order the OLD block
#            listed them: dropped<TAB><number>. Nothing when none was dropped.
#            The flag text and the report format are the caller's
#            (skills/update/SKILL.md Step 1R).
#     exit   0; 2 on a usage problem, a missing live-body file, or a value that
#            is not a number.
#
# Body comparison (the same normalization on both twins):
#   Both sides have every carriage return stripped and their trailing newlines
#   removed before the comparison, and the live-body file is SAVED in that
#   normalized form, so the two twins compare the same bytes and save the same
#   bytes for a given parent. Stripping is the only way to hold that parity: a
#   native command's output reaches PowerShell already split into lines, with
#   its line terminators gone, so a raw byte-for-byte compare cannot be written
#   on that side. The gate can only skip a PATCH this way, never add one, and a
#   body that differs only in line endings carries identical content.
#
# Working directory:
#   Every path an argument names is relative to the CURRENT working directory,
#   the consumer's repo root, where the calling skill already stands. This
#   script resolves nothing next to itself: its three entry points call `gh` and
#   read files, and the five reused steps are the SIBLING twin's
#   (scripts/md-epic-parent.sh), invoked by the skill directly, never wrapped
#   here.
#
# Why no jq:
#   Every JSON read here goes through `gh --jq`, `gh`'s own embedded filter, so
#   this script adds no standalone-jq dependency (the PowerShell twin uses the
#   same `gh --jq` form for the same reason).
#
# Failure philosophy:
#   `read-receipt` and `detect-removed` are reads: they report emptiness rather
#   than failing on it. `diff-gate` makes a LOAD-BEARING write, so its failures
#   are an exit status plus one stderr line and the caller stops the pass there.
#   `set -e` is deliberately NOT set: each entry point decides for itself where
#   a failure stops it.
#
# Run it locally from a consumer repo root:
#   <plugin>/scripts/update-reconcile-parent.sh read-receipt .milestone-feeder/roadmap-<slug>.md

usage() {
  cat >&2 <<'USAGE'
usage: update-reconcile-parent.sh <subcommand> [args]
  read-receipt <manifest>
  diff-gate <parent> <body-file> <live-body-file>
  detect-removed <live-body-file> <number> [<number> ...]
USAGE
}

say_err() {
  echo "update-reconcile-parent: $1" >&2
}

require_gh() {
  command -v gh >/dev/null 2>&1 && return 0
  say_err "gh (GitHub CLI) is not on PATH; no GitHub call attempted"
  return 3
}

require_file() {
  [ -f "$1" ] && return 0
  say_err "file not found: $1"
  return 2
}

# Flattens a captured error to ONE line, so a multi-line `gh` message can never
# split a stderr line in two.
one_line() {
  printf '%s' "$1" | tr '\n\r\t' '   '
}

# The comparison form both twins use: no carriage returns, no trailing
# newlines. The command substitution at every call site strips the trailing
# newlines; this strips the CRs.
normalize_body() {
  printf '%s' "$1" | tr -d '\r'
}

# --- the preliminary receipt read --------------------------------------------

cmd_read_receipt() {
  local manifest="$1" n
  [ -n "$manifest" ] || { usage; return 2; }
  require_file "$manifest" || return 2
  # Same first-match-only read the sibling twin's resolve-or-create branch (a)
  # performs against this line, so both agree on a degenerate manifest: a
  # malformed FIRST line resolves to empty rather than skipping ahead to a later
  # well-formed one.
  n="$(grep -m1 '^Parent issue (GitHub):' "$manifest" 2>/dev/null | sed -E 's/^Parent issue \(GitHub\): *#?([0-9]+).*/\1/' | tr -d '\r')"
  case "$n" in '' | *[!0-9]*) return 0 ;; esac
  printf '%s\n' "$n"
  return 0
}

# --- the diff-gated body write -----------------------------------------------

cmd_diff_gate() {
  local parent="$1" bodyfile="$2" livefile="$3" errfile live rendered msg err
  case "$parent" in '' | *[!0-9]*) usage; return 2 ;; esac
  [ -n "$bodyfile" ] && [ -n "$livefile" ] || { usage; return 2; }
  require_file "$bodyfile" || return 2
  require_gh || return 3

  # The live-body capture takes STDOUT ONLY, with stderr parked in $errfile and
  # read back only on a failure: a `gh` call that succeeds while also printing a
  # stderr notice would otherwise fold that notice into the body, and the
  # comparison would report a difference that does not exist and PATCH over a
  # correct body. Same discipline the sibling twin's id capture follows
  # (scripts/md-epic-parent.sh, its step 4c note).
  errfile="$(mktemp 2>/dev/null)" || errfile="/dev/null"
  if ! live="$(gh issue view "$parent" --json body --jq '.body' </dev/null 2>"$errfile")"; then
    msg="$(cat "$errfile" 2>/dev/null)"
    [ -n "$msg" ] || msg="$live"
    [ "$errfile" = "/dev/null" ] || rm -f "$errfile" 2>/dev/null
    say_err "could not read the parent issue's live body on #$parent: $(one_line "$msg")"
    return 3
  fi
  [ "$errfile" = "/dev/null" ] || rm -f "$errfile" 2>/dev/null

  live="$(normalize_body "$live")"
  rendered="$(normalize_body "$(cat "$bodyfile")")"

  # Saved in the normalized form, so detect-removed reads the same bytes on
  # either twin and this pass spends exactly one live-body fetch.
  if ! { printf '%s\n' "$live" > "$livefile"; } 2>/dev/null; then
    say_err "could not write the live parent body to $livefile"
    return 2
  fi

  if [ "$live" = "$rendered" ]; then
    printf 'compare\t%s\n' "same"
    printf 'patch\t%s\n' "skipped"
    return 0
  fi

  printf 'compare\t%s\n' "differ"
  if ! err="$(gh issue edit "$parent" --body-file "$bodyfile" </dev/null 2>&1)"; then
    say_err "could not PATCH the parent issue's body on #$parent: $(one_line "$err")"
    return 3
  fi
  printf 'patch\t%s\n' "patched"
  return 0
}

# --- the removed-milestone detection -----------------------------------------

cmd_detect_removed() {
  local livefile="$1" old c m found
  [ -n "$livefile" ] || { usage; return 2; }
  shift
  [ $# -gt 0 ] || { usage; return 2; }
  require_file "$livefile" || return 2
  for m in "$@"; do
    case "$m" in '' | *[!0-9]*)
      say_err "not a milestone number: $m"
      return 2
      ;;
    esac
  done

  # The OLD block, as the parent carried it BEFORE this run. The CR strip keeps
  # the whole-line anchors matching on a body that arrived with CRLF endings.
  old="$(tr -d '\r' < "$livefile" | grep -oE '^number: [0-9]+$' | grep -oE '[0-9]+')"
  while IFS= read -r c; do
    [ -n "$c" ] || continue
    found=0
    for m in "$@"; do
      if [ "$c" = "$m" ]; then
        found=1
        break
      fi
    done
    [ "$found" = "0" ] && printf 'dropped\t%s\n' "$c"
  done <<EOF
$old
EOF
  return 0
}

# --- dispatch ----------------------------------------------------------------

sub="${1:-}"
[ $# -gt 0 ] && shift

case "$sub" in
  read-receipt)   cmd_read_receipt "$@" ;;
  diff-gate)      cmd_diff_gate "$@" ;;
  detect-removed) cmd_detect_removed "$@" ;;
  *)              usage; exit 2 ;;
esac

exit $?
