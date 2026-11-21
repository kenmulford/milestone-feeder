#!/usr/bin/env bash
#
# Runs every fixture directory beside this file against
# scripts/validate-plugin-structure.py --paths-file. Run it as `bash run.sh`
# or `/bin/bash run.sh` (bash 3.2).

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/../../.." && pwd)
SCRIPT="$ROOT/scripts/validate-plugin-structure.py"
failed=0

if ! command -v python3 >/dev/null 2>&1; then
  echo "FAIL python3: not on PATH"
  exit 1
fi

WORK=$(mktemp -d)
trap 'rm -f "$WORK/out" "$WORK/err"; rmdir "$WORK"' EXIT

for d in "$HERE"/*/; do
  d=${d%/}
  name=$(basename "$d")
  want_code=$(tr -d '\r' < "$d/expected.exit")
  python3 "$SCRIPT" --paths-file "$d/paths.txt" > "$WORK/out" 2> "$WORK/err"
  code=$?
  diffs=""
  [ "$code" = "$want_code" ] || diffs=" exit $code, expected $want_code"
  if [ -f "$d/expected.err" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      line=${line%$'\r'}
      [ -n "$line" ] || continue
      grep -qF -- "$line" "$WORK/err" || diffs="$diffs missing stderr line: $line;"
    done < "$d/expected.err"
  fi
  if [ -z "$diffs" ]; then
    echo "PASS $name"
  else
    echo "FAIL $name:$diffs"
    failed=1
  fi
done

exit "$failed"
