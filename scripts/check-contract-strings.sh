#!/usr/bin/env bash
#
# check-contract-strings.sh — the contract-strings gate.
#
# What this checks, in plain terms:
#   Two checks run in order: a DRIFT scan over the whole live surface, then a
#   per-file PRESENCE assertion. Both must be clean for exit 0.
#
#   Check 1 (drift).
#   Two prompt strings are contract-declared byte-exact, em dash and all.
#   A prose pass can quietly swap that em dash for a hyphen, en dash, colon,
#   comma, or drop the separator entirely — the words survive, only the
#   canonical punctuation drifts, and nothing else notices (issue #369: a
#   prose sweep did exactly this and both existing CI gates stayed green).
#   This script does NOT assert the strings are present anywhere — most files
#   never mention them, and a presence-anywhere scan can't fail closed with a
#   real file:line either way. Instead it scans the live, committed surface
#   for DRIFTED VARIANTS of the two strings and fails the moment one turns
#   up. A variant hit is, by construction, a real occurrence of the phrase
#   with corrupted punctuation, so it inherently names its own file and line
#   — no separate canonical-location table to keep in sync.
#
#   Check 2 (presence).
#   Four load-bearing clauses of the two authoring agents are pinned by a
#   literal prose fragment plus the ONE file that fragment must live in. Check
#   1 deliberately asserts nothing about presence, for the reason just given;
#   check 2 can, precisely because every row names a specific file. That turns
#   "absent somewhere in the repo" (unfailable) into "absent from this exact
#   path" (failable, with a real path to print). It exists because a prose
#   pass has already silently deleted clauses of this kind: v0.13.2 (commit
#   59c0aff) compressed the authoring agents and dropped three, with every CI
#   gate then in place staying green. The presence table is at PRESENCE_ROWS
#   below; each row is verified with fixed-string matching, not regex.
#
# The two contract strings (canonical form, em dash U+2014):
#   implied — review / trim / augment
#   this is a starting set for YOUR app — what's missing?
#
# Authoritative definition (do not widen without updating these anchors):
#   Both strings are declared verbatim at skills/plan/SKILL.md ("Surface the
#   implied-surfaces review prompt"), specified at docs/plan-file-contract.md
#   ("Plan-file output template"), and asserted byte-exact by
#   tests/scenarios/12-implied-surfaces/expected.grader.md and
#   tests/scenarios/12b-implied-surfaces-control/expected.grader.md.
#   Excluded: CHANGELOG.md (historical entries legitimately quote older
#   forms, and the v0.13.2 entry discusses this exact drift) and the
#   tests/**/*observed-*.md scenario run records (historical, same reason —
#   the pathspec's leading `*` covers both the `observed-*.md` files and the
#   `needs-product-input-observed-*.md` sibling that a plain `observed-*.md`
#   glob would miss). Not excluded: scripts/ and .github/. Unlike
#   scripts/check-vocabulary.sh, whose pattern is a bare literal alternation
#   that self-matches its own source, this gate's pattern is built by
#   shell-variable interpolation (see SEP below), so the drifted-variant
#   regex never appears literally anywhere in this file, including this
#   header's own canonical em-dash quotes — verified by scanning this file
#   with no scripts/ or .github/ exclusion: zero hits.
#
# Why `git grep`:
#   Same reasoning as scripts/check-vocabulary.sh: the "live surface" is
#   exactly what is committed, `git grep` enumerates tracked files itself (no
#   ARG_MAX ceiling, no bash `mapfile`), behaves identically on macOS and
#   Linux, honours pathspec excludes by path reliably, and returns clean
#   three-state exit codes (0 match / 1 no-match / >1 error) so the gate can
#   FAIL CLOSED on a scan error instead of silently passing.
#
# Run it locally from the repo root:  ./scripts/check-contract-strings.sh
# Exit 0 = both checks clean. Exit 1 = a drifted variant found (check 1,
# file:line:match printed), or a pinned fragment missing from its named file
# (check 2, fragment and file printed), or a named file missing from disk.
# Exit 2 = a scan itself failed (treated as a failure, never as "clean").

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# --- check 1: drifted variants of the two contract strings -------------------

# Match the two contract strings with anything OTHER than the canonical em
# dash (U+2014) in the separator position: an ASCII hyphen, an en dash
# (U+2013), a colon, a comma, or nothing at all (just whitespace). Case-
# insensitive via -i below, same as check-vocabulary.sh.
#
# [[:space:]]* on both sides of an optional single-character separator group
# means: if the separator is the em dash, the group can't consume it (it's
# not one of the four alternatives) and the following [[:space:]]* can't
# consume it either (it isn't whitespace) — so the canonical form can never
# match. Any of the four drifted punctuation marks, or no punctuation mark
# at all, matches cleanly.
SEP='[[:space:]]*(-|–|:|,)?[[:space:]]*'
PATTERN="implied${SEP}review / trim / augment|this is a starting set for YOUR app${SEP}what's missing\\?"

# Scan tracked files minus the historical records (this gate's own machinery
# does not need excluding — see above). Capture the exit status explicitly
# so a grep *error* can't masquerade as a clean tree. Do not discard
# stderr — a real failure should be visible.
set +e
MATCHES="$(git grep -EIinH "${PATTERN}" -- \
  ':!:CHANGELOG.md' ':!:tests/**/*observed-*.md')"
status=$?
set -e

case "${status}" in
  0)
    echo "FAIL: a contract string drifted from its canonical em-dash form." >&2
    echo "      Canonical (em dash U+2014):" >&2
    echo "        implied — review / trim / augment" >&2
    echo "        this is a starting set for YOUR app — what's missing?" >&2
    echo >&2
    echo "${MATCHES}" >&2
    exit 1
    ;;
  1)
    # No drifted variant anywhere. Check 1 is clean; fall through to check 2.
    # The PASS message covering BOTH checks prints at the end of the script.
    ;;
  *)
    echo "ERROR: 'git grep' failed (exit ${status}) — scan unreliable; failing closed." >&2
    exit 2
    ;;
esac

# --- check 2: per-file presence of pinned contract clauses -------------------
#
# Rows are `<file>|<fragment>`: the ONE file the clause must live in, and a
# literal prose fragment unique enough to pin it. Matched with `grep -F`
# (fixed strings, no regex) because these are literal prose, not patterns.
#
# Self-match is structurally impossible here, so no interpolation trick is
# needed (contrast the SEP-built pattern check 1 requires). Each grep is
# scoped to the single file its own row names, and this script is not one of
# those files, so the table can carry every fragment verbatim without ever
# scanning itself.
#
# A row whose file is MISSING from disk FAILS; it never silently passes. That
# mirrors scripts/validate-plugin-structure.py's size-budget loop, which
# iterates SKILL_WORD_CEILINGS itself rather than a glob so a renamed or
# deleted governed file cannot quietly drop out of its gate. Same reason the
# loop below iterates PRESENCE_ROWS rather than discovering files.
#
# Every row is checked before the script reports, so one run names every miss
# rather than only the first.
#
# A fragment must occur EXACTLY ONCE in its named file, or the gate is blind: a
# second occurrence elsewhere keeps the grep green after the load-bearing clause
# is deleted. "30 rows per page" fails that test (it appears both in the clause
# at `agents/issue-author.md (The pointer names where the values live)` and as an
# illustrative example inside the concision guardrail), so that row pins the
# clause's unique tail instead.
PRESENCE_ROWS=(
  "agents/architect.md|reuse is not grounds to absorb"
  "agents/architect.md|never both"
  "agents/issue-author.md|weakening it to \"a sensible page size\" is a failure"
  "agents/issue-author.md|concision cuts prose, never content"
)

presence_failures=0

for row in "${PRESENCE_ROWS[@]}"; do
  file="${row%%|*}"
  fragment="${row#*|}"

  if [ ! -f "${file}" ]; then
    echo "FAIL: a file named in the presence table is missing from disk." >&2
    echo "      file:     ${file}" >&2
    echo "      fragment: ${fragment}" >&2
    echo "      A renamed or deleted governed file must update PRESENCE_ROWS" >&2
    echo "      in the same change, not silently drop out of this gate." >&2
    presence_failures=$((presence_failures + 1))
    continue
  fi

  # Capture the status explicitly so a grep *error* (exit >1) can't masquerade
  # as either a hit or a clean miss. 0 = present, 1 = absent, >1 = scan error.
  set +e
  grep -Fq -e "${fragment}" -- "${file}"
  grep_status=$?
  set -e

  case "${grep_status}" in
    0)
      ;;
    1)
      echo "FAIL: a pinned contract clause is missing from its file." >&2
      echo "      file:     ${file}" >&2
      echo "      fragment: ${fragment}" >&2
      echo "      This clause is load-bearing and was dropped by a prose pass" >&2
      echo "      once already (v0.13.2). Restore it, or if the removal is" >&2
      echo "      deliberate, record the decision and update PRESENCE_ROWS in" >&2
      echo "      this script in the same change." >&2
      presence_failures=$((presence_failures + 1))
      ;;
    *)
      echo "ERROR: 'grep' failed (exit ${grep_status}) on ${file} — scan unreliable; failing closed." >&2
      exit 2
      ;;
  esac
done

if [ "${presence_failures}" -gt 0 ]; then
  exit 1
fi

echo "PASS: both contract-string checks are clean."
echo "      drift:    both contract strings intact wherever they appear"
echo "                (the implied-surfaces marker and anti-fixation prompt)"
echo "      presence: all ${#PRESENCE_ROWS[@]} pinned clauses found in their named files"
exit 0
