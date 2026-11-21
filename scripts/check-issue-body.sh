#!/usr/bin/env bash
#
# check-issue-body.sh: deterministic checks over one authored issue body
# (bash twin of check-issue-body.ps1).
#
# Invocation (identical on both twins):
#   scripts/check-issue-body.sh <body-file> <repo-root>
#     [--invariants <file>] [--sections <file>] [--mode plan|bug]
#   Positionals first, flags in any order, each flag at most once.
#
# Output: one finding per line on stdout, in check order, then input order.
# Exit: 0 pass (no output), 1 findings, 2 usage or unreadable input (no check
# runs; one stderr line).
#
# Stages: check_sections, check_invariants, check_vocabulary,
# check_platform_source. The stages that need a repo read (citations, sites
# searched) are added after check_invariants.
#
# LC_ALL=C makes every comparison bytewise, so "ASCII case-insensitive" means
# A-Z only and matches the PowerShell twin's folding. `set -e` is not set: a
# failed stage must still reach the exit-status line. No `declare -A`, `${v,,}`
# or `mapfile`: macOS ships bash 3.2.

export LC_ALL=C
set -u

USAGE='usage: check-issue-body <body-file> <repo-root> [--invariants <file>] [--sections <file>] [--mode plan|bug]'
BODY_FILE=""
REPO_ROOT=""
INV_FILE=""
SEC_FILE=""
MODE="plan"
HAVE_INV=0
HAVE_SEC=0
HAVE_MODE=0
LINES=()
IN_FENCE=()
BODY_TEXT=""
RL=()
FINDINGS=()
NL=$'\n'
CR=$'\r'
BOM=$'\xef\xbb\xbf'

say_err() {
  echo "check-issue-body: $1" >&2
}

parse_args() {
  local npos=0 sawflag=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --invariants|--sections|--mode)
        [ $# -ge 2 ] || return 2
        sawflag=1
        case "$1" in
          --invariants) [ "$HAVE_INV" = 0 ] || return 2; HAVE_INV=1; INV_FILE="$2" ;;
          --sections) [ "$HAVE_SEC" = 0 ] || return 2; HAVE_SEC=1; SEC_FILE="$2" ;;
          --mode) [ "$HAVE_MODE" = 0 ] || return 2; HAVE_MODE=1; MODE="$2" ;;
        esac
        shift 2
        ;;
      --*) return 2 ;;
      *)
        [ "$sawflag" = 0 ] || return 2
        npos=$((npos + 1))
        case "$npos" in
          1) BODY_FILE="$1" ;;
          2) REPO_ROOT="$1" ;;
          *) return 2 ;;
        esac
        shift
        ;;
    esac
  done
  [ "$npos" = 2 ] || return 2
  return 0
}

validate_inputs() {
  case "$MODE" in
    plan|bug) ;;
    *) say_err "--mode must be plan or bug, got: $MODE"; return 2 ;;
  esac
  [ -f "$BODY_FILE" ] && [ -r "$BODY_FILE" ] \
    || { say_err "body file not found: $BODY_FILE"; return 2; }
  [ -d "$REPO_ROOT" ] \
    || { say_err "repo root is not a directory: $REPO_ROOT"; return 2; }
  if [ "$HAVE_INV" = 1 ]; then
    [ -f "$INV_FILE" ] && [ -r "$INV_FILE" ] \
      || { say_err "invariants file not found: $INV_FILE"; return 2; }
    command -v jq >/dev/null 2>&1 \
      || { say_err "jq is not on PATH"; return 2; }
    jq -se 'length==1 and (.[0]|type=="array") and all(.[0][]; type=="object" and (.value|type)=="string")' "$INV_FILE" >/dev/null 2>&1 \
      || { say_err "invariants file is not a JSON array of entries carrying a string value: $INV_FILE"; return 2; }
  fi
  if [ "$HAVE_SEC" = 1 ]; then
    [ -f "$SEC_FILE" ] && [ -r "$SEC_FILE" ] \
      || { say_err "sections file not found: $SEC_FILE"; return 2; }
  fi
  return 0
}

# Fills RL with the file's lines: split on LF, one trailing CR and a leading
# BOM stripped, a final LF adding no empty line.
read_file_lines() {
  local line first=1
  RL=()
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%"$CR"}
    if [ "$first" = 1 ]; then
      line=${line#"$BOM"}
      first=0
    fi
    RL[${#RL[@]}]=$line
  done < "$1"
}

load_body() {
  local i n s run rest ch fch="" flen=0 ws=' 	'
  read_file_lines "$BODY_FILE"
  n=${#RL[@]}
  LINES=()
  IN_FENCE=()
  BODY_TEXT=""
  i=0
  while [ "$i" -lt "$n" ]; do
    LINES[$i]=${RL[$i]}
    if [ "$i" = 0 ]; then BODY_TEXT=${RL[$i]}; else BODY_TEXT="$BODY_TEXT$NL${RL[$i]}"; fi
    # A fence line: optional leading whitespace, then 3+ backticks with no
    # backtick after the run, or 3+ tildes (validate-plugin-structure.py,
    # EMPHASIS_FENCE_RE). Closing: same character, at least as long, only
    # whitespace after it.
    s=${RL[$i]}
    s=${s#"${s%%[!$ws]*}"}
    ch=""
    run=0
    rest=""
    case "$s" in
      '```'*) ch='`' ;;
      '~~~'*) ch='~' ;;
    esac
    if [ -n "$ch" ]; then
      rest=$s
      while [ "${rest#"$ch"}" != "$rest" ]; do rest=${rest#"$ch"}; run=$((run + 1)); done
      if [ "$ch" = '`' ]; then
        case "$rest" in *'`'*) ch="" ;; esac
      fi
    fi
    if [ -n "$fch" ]; then
      IN_FENCE[$i]=1
      if [ -n "$ch" ] && [ "$ch" = "$fch" ] && [ "$run" -ge "$flen" ] \
        && [ -z "${rest#"${rest%%[!$ws]*}"}" ]; then
        fch=""
      fi
    elif [ -n "$ch" ]; then
      IN_FENCE[$i]=1
      fch=$ch
      flen=$run
    else
      IN_FENCE[$i]=0
    fi
    i=$((i + 1))
  done
}

check_sections() {
  local want=() h i n j m found
  if [ "$HAVE_SEC" = 1 ]; then
    read_file_lines "$SEC_FILE"
    m=${#RL[@]}
    j=0
    while [ "$j" -lt "$m" ]; do
      [ -n "${RL[$j]}" ] && want[${#want[@]}]=${RL[$j]}
      j=$((j + 1))
    done
  else
    want=('## Summary' '## Acceptance criteria' '## Design (recorded, consistent)' '## Dependencies')
  fi
  n=${#LINES[@]}
  j=0
  while [ "$j" -lt "${#want[@]}" ]; do
    h=${want[$j]}
    found=0
    i=0
    while [ "$i" -lt "$n" ]; do
      if [ "${IN_FENCE[$i]}" = 0 ] && [ "${LINES[$i]}" = "$h" ]; then found=1; break; fi
      i=$((i + 1))
    done
    [ "$found" = 1 ] || FINDINGS[${#FINDINGS[@]}]="section: expected heading \"$h\", found none"
    j=$((j + 1))
  done
}

check_invariants() {
  local count i v
  [ "$HAVE_INV" = 1 ] || return 0
  count=$(jq -r '.|length' "$INV_FILE")
  i=0
  while [ "$i" -lt "$count" ]; do
    # The trailing x keeps $(...) from trimming a value's final newlines.
    v=$(jq -j --argjson i "$i" '.[$i].value' "$INV_FILE"; printf x)
    v=${v%x}
    case "$BODY_TEXT" in
      *"$v"*) ;;
      *) FINDINGS[${#FINDINGS[@]}]="invariant: expected value \"$v\", found none" ;;
    esac
    i=$((i + 1))
  done
}

check_vocabulary() {
  local words=('comprehensive' 'robust' 'seamless' 'leverage' 'ensure that' 'in order to' 'it is important to note' 'should ideally' 'as appropriate')
  local n i j
  n=${#LINES[@]}
  shopt -s nocasematch
  i=0
  while [ "$i" -lt "$n" ]; do
    if [ "${IN_FENCE[$i]}" = 0 ]; then
      j=0
      while [ "$j" -lt "${#words[@]}" ]; do
        if [[ ${LINES[$i]} == *"${words[$j]}"* ]]; then
          FINDINGS[${#FINDINGS[@]}]="vocabulary: expected no \"${words[$j]}\", found it on line $((i + 1))"
        fi
        j=$((j + 1))
      done
    fi
    i=$((i + 1))
  done
  shopt -u nocasematch
}

check_platform_source() {
  local n i s ws=' 	'
  [ "$MODE" = bug ] || return 0
  n=${#LINES[@]}
  i=0
  while [ "$i" -lt "$n" ]; do
    if [ "${IN_FENCE[$i]}" = 0 ]; then
      s=${LINES[$i]}
      s=${s#"${s%%[!$ws]*}"}
      case "$s" in
        '- '*|'* '*) s=${s#??} ;;
      esac
      case "$s" in
        'Platform source:'*) return 0 ;;
      esac
    fi
    i=$((i + 1))
  done
  FINDINGS[${#FINDINGS[@]}]='platform source: expected a "Platform source:" line, found none'
}

main() {
  local i
  parse_args "$@" || { say_err "$USAGE"; return 2; }
  validate_inputs || return 2
  load_body
  check_sections
  check_invariants
  check_vocabulary
  check_platform_source
  i=0
  while [ "$i" -lt "${#FINDINGS[@]}" ]; do
    printf '%s\n' "${FINDINGS[$i]}"
    i=$((i + 1))
  done
  [ "${#FINDINGS[@]}" = 0 ] && return 0
  return 1
}

main "$@"
exit $?
