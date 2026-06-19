#!/usr/bin/env bash
#
# check-vocabulary.sh — the §11 vocabulary-purge gate.
#
# What this checks, in plain terms:
#   v0.3.0 renamed the plugin's whole surface (see
#   docs/specs/v0.3.0-humanize-the-surface.md §11). The old words must never
#   reappear in anything a user types, reads, or that the plugin loads. This
#   script greps the live, committed consumer surface for those retired words
#   and exits non-zero if it finds any — so a pull request that reintroduces
#   one fails.
#
# Authoritative definition (do not widen without updating the spec):
#   Tokens (case-insensitive): decompose, substrateDir, selfCheck, --apply.
#   `refine` is intentionally NOT included — spec §11's grep does not list it,
#   and the spec is authoritative over any informal token list.
#   Excluded by the spec: docs/specs/** (the migration spec legitimately
#   discusses the purge) and CHANGELOG.md (the v0.3.0 entry names the renames).
#   Also excluded: the gate's own machinery (scripts/, .github/), which must
#   contain the token strings in order to test for them — a strict superset
#   that removes nothing the spec asked to protect.
#
# Why `git grep`:
#   The "live surface" is exactly what is committed — what a consumer installs
#   and what a CI checkout contains. `git grep` scans tracked files directly:
#   it enumerates them internally (no ARG_MAX ceiling, no bash `mapfile`),
#   behaves identically on macOS and Linux (it is git's own matcher, not BSD
#   vs GNU grep), honours pathspec excludes by path reliably, and returns clean
#   three-state exit codes (0 match / 1 no-match / >1 error) so the gate can
#   FAIL CLOSED on a scan error instead of silently passing.
#
# Run it locally from the repo root:  ./scripts/check-vocabulary.sh
# Exit 0 = clean. Exit 1 = a retired term reappeared (file:line:match printed).
# Exit 2 = the scan itself failed (treated as a failure, never as "clean").

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

# Retired tokens as an ERE alternation (case-insensitive via -i below). The
# pattern starts with a letter, so the embedded `--apply` is a literal part of
# the regex, never parsed as a grep flag.
PATTERN='decompose|substrateDir|selfCheck|--apply'

# Scan tracked files minus the spec's excludes and the gate's own machinery.
# Capture the exit status explicitly so a grep *error* can't masquerade as a
# clean tree. Do not discard stderr — a real failure should be visible.
set +e
MATCHES="$(git grep -EIinH "${PATTERN}" -- \
  ':!:docs/specs/**' ':!:CHANGELOG.md' ':!:scripts/**' ':!:.github/**')"
status=$?
set -e

case "${status}" in
  0)
    echo "FAIL: retired v0.3.0 vocabulary found on the live plugin surface." >&2
    echo "      Use the v0.3.0 words (see spec §12):" >&2
    echo "        decompose -> plan / architect    --apply -> create" >&2
    echo "        substrateDir -> projectDocs       selfCheck -> reviewer" >&2
    echo >&2
    echo "${MATCHES}" >&2
    exit 1
    ;;
  1)
    echo "PASS: no retired v0.3.0 vocabulary on the live plugin surface."
    echo "      (tokens checked: decompose, substrateDir, selfCheck, --apply)"
    exit 0
    ;;
  *)
    echo "ERROR: 'git grep' failed (exit ${status}) — scan unreliable; failing closed." >&2
    exit 2
    ;;
esac
