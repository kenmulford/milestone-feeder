#!/usr/bin/env bash
#
# check-contract-strings.sh — the contract-strings gate.
#
# What this checks, in plain terms:
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
# Exit 0 = clean. Exit 1 = a drifted variant found (file:line:match printed).
# Exit 2 = the scan itself failed (treated as a failure, never as "clean").

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

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
    echo "PASS: both contract strings are intact wherever they appear."
    echo "      (checked: the implied-surfaces marker and anti-fixation prompt)"
    exit 0
    ;;
  *)
    echo "ERROR: 'git grep' failed (exit ${status}) — scan unreliable; failing closed." >&2
    exit 2
    ;;
esac
