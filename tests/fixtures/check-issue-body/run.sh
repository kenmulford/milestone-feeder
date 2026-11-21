#!/usr/bin/env bash
#
# Runs every fixture directory beside this file against both twins of
# scripts/check-issue-body. Run it as `bash run.sh` or `/bin/bash run.sh`
# (bash 3.2): the sh twin runs under the interpreter that runs this file.

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../.." && pwd)
SH_TWIN="$ROOT/scripts/check-issue-body.sh"
PS_TWIN="$ROOT/scripts/check-issue-body.ps1"
failed=0

if ! command -v pwsh >/dev/null 2>&1; then
  echo "FAIL pwsh: not on PATH"
  exit 1
fi
if ! command -v bash >/dev/null 2>&1; then
  echo "FAIL bash: not on PATH"
  exit 1
fi

WORK=$(mktemp -d)
trap 'rm -f "$WORK/out" "$WORK/err" "$WORK/want.out" "$WORK/want.err"; rmdir "$WORK"' EXIT

# Writes <dest> from <src> with {dir} replaced and CR removed; an absent
# <src> yields an empty <dest>.
expand_file() {
  local line
  : > "$3"
  [ -f "$1" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    printf '%s\n' "${line//\{dir\}/$2}" >> "$3"
  done < "$1"
}

check_leg() {
  local name=$1 leg=$2 code=$3 want_code=$4 diffs=""
  [ "$code" = "$want_code" ] || diffs=" exit $code, expected $want_code"
  if ! cmp -s "$WORK/out" "$WORK/want.out"; then diffs="$diffs stdout differs"; fi
  if ! cmp -s "$WORK/err" "$WORK/want.err"; then diffs="$diffs stderr differs"; fi
  if [ -z "$diffs" ]; then
    echo "PASS $name $leg"
  else
    echo "FAIL $name $leg:$diffs"
    failed=1
  fi
}

CIT=$(cd "$HERE/../citations" && pwd)

for d in "$HERE"/*/ "$CIT"/*/; do
  d=${d%/}
  name=$(basename "$d")
  case "$d" in "$CIT"/*) name="citations/$name" ;; esac
  argv=()
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    argv[${#argv[@]}]=${line//\{dir\}/$d}
  done < "$d/args"
  want_code=$(tr -d '\r' < "$d/expected.exit")
  # expected.out carries no {dir}; expected.err does.
  expand_file "$d/expected.out" "{dir}" "$WORK/want.out"
  expand_file "$d/expected.err" "$d" "$WORK/want.err"

  if [ "${#argv[@]}" -gt 0 ]; then
    "$BASH" "$SH_TWIN" "${argv[@]}" > "$WORK/out" 2> "$WORK/err"
  else
    "$BASH" "$SH_TWIN" > "$WORK/out" 2> "$WORK/err"
  fi
  check_leg "$name" sh $? "$want_code"

  if [ "${#argv[@]}" -gt 0 ]; then
    pwsh -NoProfile -File "$PS_TWIN" "${argv[@]}" > "$WORK/out" 2> "$WORK/err"
  else
    pwsh -NoProfile -File "$PS_TWIN" > "$WORK/out" 2> "$WORK/err"
  fi
  check_leg "$name" ps1 $? "$want_code"
done

exit "$failed"
