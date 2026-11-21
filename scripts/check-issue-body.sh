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
# Stages, in run order: check_sections, check_invariants, check_citations,
# check_sites_searched, check_vocabulary, check_platform_source.
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
add_finding() { FINDINGS[${#FINDINGS[@]}]=$1; }
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
    [ "$found" = 1 ] || add_finding "section: expected heading \"$h\", found none"
    j=$((j + 1))
  done
}

check_invariants() {
  local count i v
  [ "$HAVE_INV" = 1 ] || return 0
  count=$(jq -r '.|length' "$INV_FILE" | tr -d '\r')
  i=0
  while [ "$i" -lt "$count" ]; do
    # The trailing x keeps $(...) from trimming a value's final newlines. One
    # trailing CR is dropped (a Windows jq ends its output with CRLF), never a
    # CR inside the value.
    v=$(jq -j --argjson i "$i" '.[$i].value' "$INV_FILE"; printf x)
    v=${v%x}
    v=${v%"$CR"}
    case "$BODY_TEXT" in
      *"$v"*) ;;
      *) add_finding "invariant: expected value \"$v\", found none" ;;
    esac
    i=$((i + 1))
  done
}

# Sets SPANS to the line's single-backtick spans, in order.
line_spans() {
  local rest=$1
  SPANS=()
  while :; do
    case "$rest" in *'`'*) ;; *) break ;; esac
    rest=${rest#*'`'}
    case "$rest" in *'`'*) ;; *) break ;; esac
    SPANS[${#SPANS[@]}]=${rest%%'`'*}
    rest=${rest#*'`'}
  done
}

# A span is a citation candidate only when it ends with ")" and holds " (".
# Heading forms (a "#" or "§" in the head), a head holding neither "/" nor ".",
# an empty head or anchor, and "new" are skipped without a finding. The
# dotless, slashless head skips prose naming the form itself, "path (anchor)".
resolve_citation() {
  local span=$1 head anchor file hits=0 i=0 n
  case "$span" in *')') ;; *) return 0 ;; esac
  case "$span" in *' ('*) ;; *) return 0 ;; esac
  head=${span%%' ('*}
  case "$head" in ''|*'#'*|*'§'*) return 0 ;; esac
  case "$head" in */*|*.*) ;; *) return 0 ;; esac
  anchor=${span#*' ('}
  anchor=${anchor%')'}
  case "$anchor" in ''|new) return 0 ;; esac
  file="$REPO_ROOT/$head"
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    add_finding "citation: expected 1 line matching \"$anchor\" in $head, found 0 (no readable file)"
    return 0
  fi
  read_file_lines "$file"
  n=${#RL[@]}
  while [ "$i" -lt "$n" ]; do
    case "${RL[$i]}" in *"$anchor"*) hits=$((hits + 1)) ;; esac
    i=$((i + 1))
  done
  [ "$hits" = 1 ] || add_finding "citation: expected 1 line matching \"$anchor\" in $head, found $hits"
}

check_citations() {
  local n i j
  n=${#LINES[@]}
  i=0
  while [ "$i" -lt "$n" ]; do
    if [ "${IN_FENCE[$i]}" = 0 ]; then
      line_spans "${LINES[$i]}"
      j=0
      while [ "$j" -lt "${#SPANS[@]}" ]; do
        resolve_citation "${SPANS[$j]}"
        j=$((j + 1))
      done
    fi
    i=$((i + 1))
  done
}

# Returns 1 when the pattern holds a token outside the ERE subset that POSIX
# and .NET read the same way: a "{" not opening a well-formed {m}, {m,} or
# {m,n}, or a quantifier (* + ? {) with no atom before it (pattern start, after
# "(" or "|") or right after another quantifier. qok is 1 when an atom has just
# ended.
pattern_in_subset() {
  local p=$1 n=${#1} i=0 c j d qok=0
  while [ "$i" -lt "$n" ]; do
    c=${p:i:1}
    case "$c" in
      '\')
        case "${p:i+1:1}" in
          '.'|'['|']'|'('|')'|'*'|'+'|'?'|'{'|'}'|'|'|'^'|'$'|'\') ;;
          *) return 1 ;;
        esac
        i=$((i + 2))
        qok=1
        ;;
      '(')
        [ "${p:i+1:1}" = '?' ] && return 1
        i=$((i + 1))
        qok=0
        ;;
      '|')
        i=$((i + 1))
        qok=0
        ;;
      '*'|'+'|'?')
        [ "$qok" = 1 ] || return 1
        i=$((i + 1))
        qok=0
        ;;
      '{')
        [ "$qok" = 1 ] || return 1
        j=$((i + 1))
        d=0
        while :; do
          case "${p:j:1}" in [0-9]) j=$((j + 1)); d=$((d + 1)) ;; *) break ;; esac
        done
        [ "$d" -gt 0 ] || return 1
        if [ "${p:j:1}" = ',' ]; then
          j=$((j + 1))
          while :; do
            case "${p:j:1}" in [0-9]) j=$((j + 1)) ;; *) break ;; esac
          done
        fi
        [ "${p:j:1}" = '}' ] || return 1
        i=$((j + 1))
        qok=0
        ;;
      '[')
        i=$((i + 1))
        [ "${p:i:1}" = '^' ] && i=$((i + 1))
        [ "${p:i:1}" = ']' ] && i=$((i + 1))
        while [ "$i" -lt "$n" ]; do
          c=${p:i:1}
          [ "$c" = ']' ] && break
          [ "$c" = '\' ] && return 1
          if [ "$c" = '[' ]; then
            case "${p:i+1:1}" in ':'|'='|'.') return 1 ;; esac
          fi
          i=$((i + 1))
        done
        i=$((i + 1))
        qok=1
        ;;
      *)
        i=$((i + 1))
        qok=1
        ;;
    esac
  done
  return 0
}

# One finding at most per command, first failing rule wins. The command text is
# never evaluated: the grep argument vector is built here. grep -l -a with a NUL
# post-filter gives the file set; -r skips symlinks met while recursing, and a
# command-line symlink is dropped by the -L test.
sites_one() {
  local cmd=$1 rest pattern after rem tok p out f bad=""
  local prefix="grep -rnE '"
  local form="sites searched: expected grep -rnE '<pattern>' <path>..., found \"$cmd\""
  local paths=() clean=()
  case "$cmd" in
    "$prefix"*) rest=${cmd#"$prefix"} ;;
    *) add_finding "$form"; return 0 ;;
  esac
  case "$rest" in
    *"'"*) ;;
    *) add_finding "$form"; return 0 ;;
  esac
  pattern=${rest%%"'"*}
  after=${rest#*"'"}
  case "$after" in
    ' '*) rem=${after#?} ;;
    *) add_finding "$form"; return 0 ;;
  esac
  while :; do
    tok=${rem%%' '*}
    if [ -z "$tok" ]; then bad=1; break; fi
    paths[${#paths[@]}]=$tok
    case "$rem" in *' '*) rem=${rem#*' '} ;; *) break ;; esac
  done
  if [ -n "$bad" ]; then add_finding "$form"; return 0; fi
  for p in "${paths[@]}"; do
    case "$p" in
      /*|'~'*|*..*|*'\'*|*:*)
        add_finding "sites searched: expected a path inside the repo root, found \"$p\""
        return 0
        ;;
    esac
  done
  for p in "${paths[@]}"; do
    while [ "${p%/}" != "$p" ]; do p=${p%/}; done
    if [ ! -e "$REPO_ROOT/$p" ]; then
      add_finding "sites searched: expected an existing path, found \"$p\""
      return 0
    fi
    clean[${#clean[@]}]=$p
  done
  if ! pattern_in_subset "$pattern"; then
    add_finding "sites searched: expected a pattern in the shared ERE subset, found \"$pattern\""
    return 0
  fi
  grep -E -e "$pattern" </dev/null >/dev/null 2>&1
  if [ $? -eq 2 ]; then
    add_finding "sites searched: expected a valid pattern, found \"$pattern\""
    return 0
  fi
  out=$(CDPATH= cd -- "$REPO_ROOT" 2>/dev/null && grep -r -l -a -E -e "$pattern" -- "${clean[@]}" 2>/dev/null | sed 's,^\./,,' | sort -u)
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ -L "$REPO_ROOT/$f" ] && continue
    tr -d '\000' < "$REPO_ROOT/$f" | cmp -s - "$REPO_ROOT/$f" || continue
    case "$BODY_TEXT" in
      *"$f"*) ;;
      *) add_finding "sites searched: expected \"$f\" in the body, found none" ;;
    esac
  done <<EOF
$out
EOF
}

# Sets LABEL to the line minus leading whitespace and one "- " or "* " bullet.
line_label() {
  local ws=' 	'
  LABEL=$1
  LABEL=${LABEL#"${LABEL%%[!$ws]*}"}
  case "$LABEL" in
    '- '*|'* '*) LABEL=${LABEL#??} ;;
  esac
}

check_sites_searched() {
  local n i cmd
  n=${#LINES[@]}
  i=0
  while [ "$i" -lt "$n" ]; do
    if [ "${IN_FENCE[$i]}" = 0 ]; then
      line_label "${LINES[$i]}"
      case "$LABEL" in
        'Sites searched:'*)
          line_spans "${LINES[$i]}"
          cmd=""
          [ "${#SPANS[@]}" -gt 0 ] && cmd=${SPANS[0]}
          sites_one "$cmd"
          ;;
      esac
    fi
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
          add_finding "vocabulary: expected no \"${words[$j]}\", found it on line $((i + 1))"
        fi
        j=$((j + 1))
      done
    fi
    i=$((i + 1))
  done
  shopt -u nocasematch
}

check_platform_source() {
  local n i
  [ "$MODE" = bug ] || return 0
  n=${#LINES[@]}
  i=0
  while [ "$i" -lt "$n" ]; do
    if [ "${IN_FENCE[$i]}" = 0 ]; then
      line_label "${LINES[$i]}"
      case "$LABEL" in
        'Platform source:'*) return 0 ;;
      esac
    fi
    i=$((i + 1))
  done
  add_finding 'platform source: expected a "Platform source:" line, found none'
}

main() {
  local i
  parse_args "$@" || { say_err "$USAGE"; return 2; }
  validate_inputs || return 2
  load_body
  check_sections
  check_invariants
  check_citations
  check_sites_searched
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
