#!/usr/bin/env bash
#
# check-contract-strings.sh — the contract-strings gate.
#
# What this checks, in plain terms:
#   Three checks run in order: a DRIFT scan over the whole live surface, a
#   per-file PRESENCE assertion, then a POINTER scan over agents/. All three
#   must be clean for exit 0.
#
#   Check 1 (drift).
#   Two prompt strings are contract-declared byte-exact, separator and all.
#   A prose pass can quietly swap that hyphen for an em dash, en dash, colon,
#   comma, or drop the separator entirely. The words survive, only the
#   canonical punctuation drifts, and nothing else notices (issue #369: a
#   prose sweep drifted this separator and both existing CI gates stayed
#   green; it ran in the opposite direction, before the hyphen was canonical).
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
#   Check 3 (pointer).
#   Four agent briefs used to close their citation rule with a pointer to
#   milestone-driver/skills/citation-format.md. That path is on no consumer
#   disk and in no feeder install, so an agent reading its own brief took it
#   for a file to open and searched the machine for it: in one 2026-08-24
#   plan run three issue-authors each escalated to a filesystem-root `find`
#   and ran for over an hour apiece (issue #483). Every one of those sites
#   already states the citation forms inline, so the pointer bought nothing
#   and cost that. This check fails the moment the literal path turns up in
#   any file under agents/. Self-match is structurally impossible, for the
#   same reason check 2's is: the pathspec is agents/ and this script lives
#   in scripts/, so the literal can sit here verbatim (POINTER below) and
#   never be scanned. The scope is agents/ and ONLY agents/. docs/file-map.md
#   and docs/plan-file-contract.md keep their references on purpose; a human
#   reads those, and no agent loads them as its own instructions.
#
# The two contract strings (canonical form, ASCII hyphen U+002D):
#   implied - review / trim / augment
#   this is a starting set for YOUR app - what's missing?
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
#   glob would miss), and docs/specs/** (frozen historical specs, which quote
#   whichever form was canonical when they were written; scripts/check-
#   vocabulary.sh carves out the same path, there because spec §11 mandates it,
#   here because a frozen spec must keep the form it shipped with. Both of
#   v0.7.0's quotes wrap mid-phrase, so this pathspec is inert against today's
#   tree and stands for the next one). Not excluded: scripts/ and .github/.
#   Unlike
#   scripts/check-vocabulary.sh, whose pattern is a bare literal alternation
#   that self-matches its own source, this gate's pattern is built by
#   shell-variable interpolation (see SEP below), so the drifted-variant
#   regex never appears literally anywhere in this file. That includes this
#   header's own canonical hyphen quotes, which the pattern structurally
#   cannot match; verified by scanning this file with no scripts/ or .github/
#   exclusion: zero hits.
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
# Exit 0 = all three checks clean. Exit 1 = a drifted variant found (check 1,
# file:line:match printed), or a pinned fragment missing from its named file
# (check 2, fragment and file printed), or a named file missing from disk, or
# the retired cross-repo pointer found under agents/ (check 3,
# file:line:match printed). Exit 2 = a scan itself failed (treated as a
# failure, never as "clean").

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# --- check 1: drifted variants of the two contract strings -------------------

# Match the two contract strings with anything OTHER than the canonical ASCII
# hyphen in the separator position: an em dash (U+2014), an en dash (U+2013),
# every mark in the em-dash ban's closed replacement set (a period, a
# semicolon, an opening paren, a colon, a comma), or nothing at all (just
# whitespace). Case-insensitive via -i below, same as check-vocabulary.sh.
#
# [[:space:]]* on both sides of an optional single-character separator group
# means: if the separator is the hyphen, the group can't consume it (the
# hyphen is not one of the alternatives) and the following [[:space:]]* can't
# consume it either (it isn't whitespace). The canonical form can never match.
# Any listed drifted mark, or no punctuation mark at all, matches cleanly.
#
# The period and the opening paren are backslash-escaped. Unescaped, `.` is the
# ERE any-character metacharacter: it would match the canonical hyphen itself
# and fire this gate on the one form it exists to protect.
#
# The paren case is matched by its OPENING paren alone. A paren-pair recast
# puts that paren in the separator position, which already decides the drift;
# the closing paren rides past the end of the phrase, so pinning it would add
# nothing. This comment states that shape rather than spelling a drifted
# variant out, and deliberately so: the self-match invariant recorded in the
# header (no drifted variant appears literally anywhere in this file) now
# covers the period, the semicolon, and the paren too, so an illustrative
# example would fire this gate on its own source.
#
# GAP CLOSED by issue #399. #398 left this alternation carrying only the colon
# and the comma out of the five marks .project/conventions.md (## Em-dash ban)
# prescribes, so a sweeper FOLLOWING that ban wrote a PERIOD, a SEMICOLON, or a
# PAREN PAIR and passed both gates clean: scripts/check-vocabulary.sh found no
# em dash, and this gate did not recognise the substitution. All five are
# listed now, so the pattern holds these two strings itself rather than leaning
# on the ban's carve-out 2 alone.
SEP='[[:space:]]*(—|–|\.|;|\(|:|,)?[[:space:]]*'
PATTERN="implied${SEP}review / trim / augment|this is a starting set for YOUR app${SEP}what's missing\\?"

# Scan tracked files minus the historical records (this gate's own machinery
# does not need excluding — see above). Capture the exit status explicitly
# so a grep *error* can't masquerade as a clean tree. Do not discard
# stderr — a real failure should be visible.
set +e
MATCHES="$(git grep -EIinH "${PATTERN}" -- \
  ':!:CHANGELOG.md' ':!:tests/**/*observed-*.md' ':!:docs/specs/**')"
status=$?
set -e

case "${status}" in
  0)
    echo "FAIL: a contract string drifted from its canonical hyphen form." >&2
    echo "      Canonical (ASCII hyphen U+002D):" >&2
    echo "        implied - review / trim / augment" >&2
    echo "        this is a starting set for YOUR app - what's missing?" >&2
    echo >&2
    echo "${MATCHES}" >&2
    exit 1
    ;;
  1)
    # No drifted variant anywhere. Check 1 is clean; fall through to checks 2
    # and 3. The PASS message covering ALL THREE prints at the end of the
    # script.
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
# iterates FILE_WORD_CEILINGS itself rather than a glob so a renamed or
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

# --- check 3: the retired cross-repo pointer under agents/ -------------------

POINTER='milestone-driver/skills/citation-format.md'

# Same three-state discipline as check 1: capture the status explicitly so a
# scan *error* can't masquerade as a clean tree. Fixed-string matching (-F),
# because this is a literal path and not a pattern. The pathspec is agents/
# alone: docs/ and SPEC.md are out of its reach by design (see the header), and
# scoping it this way is also what makes this script unable to match itself.
set +e
POINTER_HITS="$(git grep -FInH -e "${POINTER}" -- 'agents/')"
pointer_status=$?
set -e

case "${pointer_status}" in
  0)
    echo "FAIL: an agent brief points at a path that is on no disk." >&2
    echo "      path: ${POINTER}" >&2
    echo "      An agent reading this takes it for a file to open and searches" >&2
    echo "      the machine for it (issue #483). Delete the pointer and add no" >&2
    echo "      replacement text: every site that carried it already states the" >&2
    echo "      citation forms inline." >&2
    echo >&2
    echo "${POINTER_HITS}" >&2
    exit 1
    ;;
  1)
    # No agent brief names the path. Check 3 is clean.
    ;;
  *)
    echo "ERROR: 'git grep' failed (exit ${pointer_status}) on agents/. Scan unreliable; failing closed." >&2
    exit 2
    ;;
esac

echo "PASS: all three contract-string checks are clean."
echo "      drift:    both contract strings intact wherever they appear"
echo "                (the implied-surfaces marker and anti-fixation prompt)"
echo "      presence: all ${#PRESENCE_ROWS[@]} pinned clauses found in their named files"
echo "      pointer:  no file under agents/ names the cross-repo citation-format path"
exit 0
