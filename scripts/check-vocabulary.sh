#!/usr/bin/env bash
#
# check-vocabulary.sh: the vocabulary-purge and em-dash gate.
#
# What this checks, in plain terms:
#   Two categories ride one `git grep` over the live, committed consumer
#   surface, so a pull request that reintroduces either one fails.
#
#   Category 1, retired vocabulary. v0.3.0 renamed the plugin's whole surface
#   (docs/specs/v0.3.0-humanize-the-surface.md (## 11. Verification)). The old
#   words must never reappear in anything a user types, reads, or that the
#   plugin loads.
#
#   Category 2, the em dash (U+2014). .project/conventions.md (## Em-dash ban)
#   bans the character outright and names the closed set of marks that replace
#   it. This gate is that ban's backstop: it fails the moment a stray U+2014
#   reaches the scanned surface. It does not police WHICH replacement an author
#   picked, because the ban's construction table and rank are a human call.
#
# Authoritative definition:
#   Category 1 is SPEC-owned. Tokens (case-insensitive): decompose,
#   substrateDir, selfCheck, --apply. Do not widen that token list without
#   updating docs/specs/v0.3.0-humanize-the-surface.md (## 12. Vocabulary table
#   (the backbone)). `refine` is intentionally NOT included: the spec's own
#   grep does not list it, and the spec is authoritative over any informal
#   token list.
#
#   Category 2 is owned HERE, by this header. Root SPEC.md has no section 11
#   (its headings run `## 1. Purpose & scope` through `## 10. Resolved during
#   build`), so there is no spec section to defer to. This gate self-hosts its
#   own definition the way scripts/check-contract-strings.sh (Authoritative
#   definition) hosts the two contract strings. Widening it is a change to this
#   header and to .project/conventions.md (## Em-dash ban) together.
#
#   This file names the character in prose as "em dash (U+2014)" and never
#   reproduces the glyph, so it carries no U+2014 byte of its own, whatever the
#   scripts/ exclusion allows. PATTERN builds the character at run time.
#
#   Excluded pathspecs (five), for two DIFFERENT reasons. Which reason applies
#   decides what the exclusion asks of an author:
#     The gate cannot scan its own machinery: scripts/, .github/. A gate must
#     hold the banned strings in order to test for them. Authors stay fully
#     bound by both categories there. The exclusion is mechanical, never a
#     licence.
#     Recasting the record is itself the defect: docs/specs/** (frozen specs,
#     which the migration spec legitimately discusses the purge in),
#     CHANGELOG.md (the v0.3.0 entry names the renames), and
#     tests/**/*observed-*.md (a scenario run record is evidence of what a run
#     emitted). Rewriting one makes it a misquote or falsifies the record. The
#     leading `*` in that last glob covers both the `observed-*.md` files and
#     the `needs-product-input-observed-*.md` sibling a plain `observed-*.md`
#     would miss, mirroring scripts/check-contract-strings.sh (Authoritative
#     definition).
#   For the first four, the v0.3.0 spec asked for docs/specs/** and
#   CHANGELOG.md; scripts/ and .github/ are a strict superset that removes
#   nothing the spec asked to protect.
#
#   Sanctioned quotes are carved out by matched SPAN, not by a sixth pathspec:
#   see ALLOWLIST_ROWS below.
#
# Why `git grep`:
#   The "live surface" is exactly what is committed: what a consumer installs
#   and what a CI checkout contains. `git grep` scans tracked files directly.
#   It enumerates them internally (no ARG_MAX ceiling, no bash `mapfile`),
#   behaves identically on macOS and Linux (it is git's own matcher, not BSD
#   vs GNU grep), honours pathspec excludes by path reliably, and returns clean
#   three-state exit codes (0 match / 1 no-match / >1 error) so the gate can
#   FAIL CLOSED on a scan error instead of silently passing.
#
# Run it locally from the repo root:  ./scripts/check-vocabulary.sh
# Exit 0 = clean. Exit 1 = a retired term or an em dash reached the surface
# (file:line:match printed), or the allowlist below has rotted.
# Exit 2 = the scan itself failed (treated as a failure, never as "clean").

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# The banned character, built at run time from its UTF-8 bytes.
#
# Do NOT write this as an ANSI-C `$'...'` escape naming the codepoint. Bash
# 3.2, the shell `/usr/bin/env bash` resolves to on a stock macOS, has no `\u`
# escape: it yields the six literal characters instead of the character, so the
# gate would scan for a string that never occurs and print PASS on a
# developer's machine while CI (ubuntu-latest, bash 5) enforced correctly. The
# cost is local-versus-CI signal divergence, not an undetected hole, and it is
# still a hole in the only signal an author sees before pushing. Verified on
# 3.2.57 and 5.3.15: the escape form emits 5c7532303134 on 3.2 and e28094 on 5,
# this printf form emits e28094 on both.
EMDASH="$(printf '\xe2\x80\x94')"

# Retired tokens as an ERE alternation (case-insensitive via -i below). The
# pattern starts with a letter, so the embedded `--apply` is a literal part of
# the regex, never parsed as a grep flag. Kept as its own variable because the
# per-line re-test below has to tell the two categories apart.
VOCAB_PATTERN='decompose|substrateDir|selfCheck|--apply'

# One alternation for one scan. The banned character is appended last, after
# `--apply`, so the pattern still begins with a letter.
PATTERN="${VOCAB_PATTERN}|${EMDASH}"

# --- the allowlist: sanctioned quotes, carved out by span --------------------
#
# Rows are `<file>|<span>`: the ONE file the span must live in, and the
# byte-exact quoted text including its banned character. Row shape mirrors
# scripts/check-contract-strings.sh (PRESENCE_ROWS).
#
# Every row quotes a source this ban cannot reach, so recasting it would turn
# the quote into a misquote:
#   rows 1 and 2  docs/specs/v0.3.1-driver-handoff.md, an excluded pathspec.
#   rows 3 and 4  the milestone-driver plugin's
#                 skills/solve-milestone/trello-sync.md (Conv 7's checklist
#                 item format and Conv 1's failure-log format). A separate
#                 repo, carrying no em-dash ban, so neither source will ever
#                 follow a recast.
# Recorded as carve-out 3 at .project/conventions.md (## Em-dash ban).
#
# By SPAN, never by line and never by file. A sixth pathspec exclusion would be
# one line cheaper and would permanently blind docs/create-deploy-sequence.md,
# the repo's largest governed prose file, to this ratchet. Per span, a second
# banned character anywhere else on an allowlisted line still fails.
ALLOWLIST_ROWS=(
  "docs/create-deploy-sequence.md|The deploy receipt ${EMDASH} a stable handle for rename"
  "docs/create-deploy-sequence.md|\`<n>\` ${EMDASH} the deploy receipt"
  "docs/create-deploy-sequence.md|#<n> ${EMDASH} <issue title>"
  "docs/create-deploy-sequence.md|Trello: <operation> skipped ${EMDASH} <error>"
)

# --- check 1: the allowlist itself has not rotted ---------------------------
#
# Runs BEFORE the scan. A row naming a file that no longer exists, or a span
# whose text has drifted, silently voids or widens the carve-out, so the scan
# below cannot be trusted until the table is known good. Same reason
# scripts/check-contract-strings.sh iterates PRESENCE_ROWS and
# scripts/validate-plugin-structure.py iterates FILE_WORD_CEILINGS rather than
# a glob: a table that rots silently becomes a permanent blind spot.
#
# Every row is checked before the script reports, so one run names every miss
# rather than only the first.
allowlist_failures=0

for row in "${ALLOWLIST_ROWS[@]}"; do
  file="${row%%|*}"
  span="${row#*|}"

  if [ ! -f "${file}" ]; then
    echo "FAIL: a file named in the allowlist is missing from disk." >&2
    echo "      file: ${file}" >&2
    echo "      span: ${span}" >&2
    echo "      A renamed or deleted file must update ALLOWLIST_ROWS in this" >&2
    echo "      script in the same change, not silently drop out of this gate." >&2
    allowlist_failures=$((allowlist_failures + 1))
    continue
  fi

  # Fixed-string matching: these are literal prose quotes, not patterns.
  # Capture the status explicitly so a grep *error* (exit >1) can't masquerade
  # as either a hit or a clean miss. 0 = present, 1 = absent, >1 = scan error.
  set +e
  grep -Fq -e "${span}" -- "${file}"
  grep_status=$?
  set -e

  case "${grep_status}" in
    0)
      ;;
    1)
      echo "FAIL: an allowlisted span is missing from the file it names." >&2
      echo "      file: ${file}" >&2
      echo "      span: ${span}" >&2
      echo "      This span quotes a source the em-dash ban cannot reach. If the" >&2
      echo "      quote was deliberately removed or reworded, update" >&2
      echo "      ALLOWLIST_ROWS in this script in the same change, so the" >&2
      echo "      carve-out cannot rot into a permanent blind spot." >&2
      allowlist_failures=$((allowlist_failures + 1))
      ;;
    *)
      echo "ERROR: 'grep' failed (exit ${grep_status}) on ${file}. Scan unreliable; failing closed." >&2
      exit 2
      ;;
  esac
done

if [ "${allowlist_failures}" -gt 0 ]; then
  exit 1
fi

# --- check 2: scan the live surface -----------------------------------------
#
# Capture the exit status explicitly so a grep *error* can't masquerade as a
# clean tree. Do not discard stderr: a real failure should be visible.
set +e
MATCHES="$(git grep -EIinH "${PATTERN}" -- \
  ':!:docs/specs/**' ':!:CHANGELOG.md' ':!:scripts/**' ':!:.github/**' \
  ':!:tests/**/*observed-*.md')"
status=$?
set -e

case "${status}" in
  0)
    # Raw matches. Filter the allowlisted spans out of them below.
    ;;
  1)
    # Nothing matched anywhere. The filter loop is a no-op and the single PASS
    # report at the end fires.
    MATCHES=""
    ;;
  *)
    echo "ERROR: 'git grep' failed (exit ${status}). Scan unreliable; failing closed." >&2
    exit 2
    ;;
esac

# --- filter: a raw match is not yet a violation ------------------------------
#
# A matched line may hold nothing but an allowlisted span. For each match,
# strip every occurrence of every row span whose file is THIS file, then
# re-test what SURVIVES. A second banned character elsewhere on an allowlisted
# line survives the strip and fails, which is exactly the case a whole-line
# allowlist would wrongly pass.
#
# The strip pattern is quoted INSIDE the expansion (`${survivor//"${span}"/}`)
# so bash matches it literally rather than as a pathname pattern. An unquoted
# pattern would treat a future span's `*`, `?`, or `[` as a wildcard and strip
# far more than itself. Verified literal on 3.2.57 and 5.3.15.
#
# `git grep -H -n` emits `file:line:content`; the two leading fields are peeled
# off by prefix removal. A tracked path containing a colon would confuse that,
# and this repo has none.
vocab_hits=""
mark_hits=""

while IFS= read -r match; do
  [ -n "${match}" ] || continue

  file="${match%%:*}"
  rest="${match#*:}"
  survivor="${rest#*:}"

  for row in "${ALLOWLIST_ROWS[@]}"; do
    [ "${row%%|*}" = "${file}" ] || continue
    span="${row#*|}"
    survivor="${survivor//"${span}"/}"
  done

  case "${survivor}" in
    *"${EMDASH}"*)
      mark_hits="${mark_hits}${match}
"
      ;;
  esac

  if printf '%s' "${survivor}" | grep -Eiq -e "${VOCAB_PATTERN}"; then
    vocab_hits="${vocab_hits}${match}
"
  fi
done <<< "${MATCHES}"

# --- report -----------------------------------------------------------------

if [ -z "${vocab_hits}" ] && [ -z "${mark_hits}" ]; then
  echo "PASS: no retired v0.3.0 vocabulary and no em dash on the live plugin surface."
  echo "      (tokens checked: decompose, substrateDir, selfCheck, --apply)"
  echo "      (character checked: em dash U+2014; ${#ALLOWLIST_ROWS[@]} quoted spans allowlisted)"
  exit 0
fi

# Each category prints its own block, so a tree carrying both gets both.
if [ -n "${vocab_hits}" ]; then
  echo "FAIL: retired v0.3.0 vocabulary found on the live plugin surface." >&2
  echo "      Use the v0.3.0 words (docs/specs/v0.3.0-humanize-the-surface.md," >&2
  echo "      ## 12. Vocabulary table):" >&2
  echo "        decompose -> plan / architect    --apply -> create" >&2
  echo "        substrateDir -> projectDocs       selfCheck -> reviewer" >&2
  echo >&2
  printf '%s' "${vocab_hits}" >&2
  echo >&2
fi

if [ -n "${mark_hits}" ]; then
  echo "FAIL: an em dash (U+2014) reached the live plugin surface." >&2
  echo "      Recast it. The replacement comes from this closed set, strongest" >&2
  echo "      first: PERIOD > SEMICOLON > PAREN PAIR > COLON > COMMA." >&2
  echo "      A bare hyphen between two spaces is not in the set. Pick the mark" >&2
  echo "      by construction first and break ties by rank:" >&2
  echo "      .project/conventions.md (## Em-dash ban)." >&2
  echo "      Quoting a source that ban cannot reach? Add the span to" >&2
  echo "      ALLOWLIST_ROWS in this script and record it as a carve-out in" >&2
  echo "      that same convention, in the same change." >&2
  echo >&2
  printf '%s' "${mark_hits}" >&2
  echo >&2
fi

exit 1
