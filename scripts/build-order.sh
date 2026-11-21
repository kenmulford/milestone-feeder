#!/usr/bin/env bash
#
# build-order.sh: derive the shared-file `after` edges and the Wave lines from
# a candidate set (bash twin of build-order.ps1).
#
# Invocation (identical on both twins):
#   scripts/build-order.sh <input.json>      path relative to the CWD
#
# Input: one JSON object {"candidates":[{"tag","edits"}],"edges":[...]}. Each
# edge is a string in the architect's `#X depends_on #Y - <reason>` form
# (`#X depends_on #Y` means Y builds before X). An absent or null `edits` or
# `edges` reads as an empty list.
#
# Output, LF-terminated lines, no blank line, nothing for an empty
# `candidates`: first every shared-file edge `#B after #A - edits: <paths>`
# (agents/architect.md clause 11), then the Wave lines in the SPEC.md
# milestone-template shape.
#
# Exit: 0 ok; 1 cycle in the depends_on edges (tags named on stderr, stdout
# empty); 2 bad input or usage (one stderr line naming the problem).
#
# Order: the "assigned order" is tag length, then ordinal compare, so `#Z`
# sorts before `#AA` and `#99` before `#100`. It orders Wave tags, `depends on`
# lists, tie-breaks and edge emit order.
#
# All graph work is one jq program: macOS bash 3.2 has no associative arrays.
# The program's first output line is the exit code, the rest is stdout or the
# stderr message; `tr -d '\r'` strips the CR a native jq.exe adds on Windows.

set -u

if [ "$#" -ne 1 ]; then
    printf 'usage: build-order <input.json>\n' >&2
    exit 2
fi
f=$1
if [ ! -f "$f" ] || [ ! -r "$f" ]; then
    printf 'build-order: cannot read input file: %s\n' "$f" >&2
    exit 2
fi
if ! command -v jq >/dev/null 2>&1; then
    printf 'build-order: jq is required\n' >&2
    exit 2
fi

prog='
def tagok: type == "string" and test("\\A#[A-Za-z0-9_-]+\\z");
def strarr: type == "array" and all(.[]; type == "string");
def inn($a): . as $x | any($a[]; . == $x);
def edgere: "\\A(?<l>#[A-Za-z0-9_-]+) depends_on (?<r>#[A-Za-z0-9_-]+)(?: - .*)?\\z";
def err($m): ["2", "build-order: " + $m];

. as $raw
| ((try ($raw | fromjson) catch null) // null) as $d
| (if ($d | type) == "object" and ($d.edges != null) and (($d.edges | type) == "array")
   then $d.edges else [] end) as $E
| (if ($d | type) == "object" and (($d.candidates | type) == "array") then $d.candidates else [] end) as $C
| (
    if ($d | type) != "object" then "malformed input: not a JSON object"
    elif ($d.candidates | type) != "array" then "malformed input: candidates must be an array"
    elif any($C[]; ((type == "object") and (.tag | tagok)) | not) then "malformed input: candidate tag must match #[A-Za-z0-9_-]+"
    else
      ([$C[] | select(.edits != null and (.edits | strarr | not)) | .tag] | first) as $be
      | if $be != null then "malformed input: edits of \($be) must be an array of strings"
        else
          ([$C | map(.tag) | . as $t | range(0; length) as $i | select($t[$i] as $v | any($t[:$i][]; . == $v)) | $t[$i]] | first) as $dup
          | if $dup != null then "malformed input: duplicate tag \($dup)"
            elif ($d.edges != null) and (($d.edges | strarr) | not) then "malformed input: edges must be an array of strings"
            else
              ([$E[] | select(test(edgere) | not)] | first) as $be2
              | if $be2 != null then "malformed input: edge is not a depends_on edge: \($be2)"
                else
                  ($C | map(.tag)) as $tg
                  | ([$E[] | capture(edgere) | .l, .r] | map(select(inn($tg) | not)) | first) as $bad
                  | if $bad != null then "edge names a tag absent from candidates: \($bad)" else null end
                end
            end
        end
    end
  ) as $msg
| if $msg != null then err($msg) else
    ($C | map(.tag) | sort_by([length, .])) as $tags
    | ($tags | to_entries | map({key: .value, value: .key}) | from_entries) as $rank
    | ($C | map({key: .tag, value: ((.edits // []) | reduce .[] as $p ([]; if (. as $acc | $p | inn($acc)) then . else . + [$p] end))}) | from_entries) as $ed
    | ([$E[] | capture(edgere) | [.l, .r]] | unique) as $D
    | def preds($pairs): reduce $pairs[] as $p ({}; .[$p[0]] += [$p[1]]);
      def layers($preds):
        {rem: $tags, lvl: {}, k: 0, stop: false}
        | until(.stop;
            . as $s
            | [$s.rem[] | select(. as $x | all(($preds[$x] // [])[]; . as $p | ($p | inn($s.rem)) | not))] as $ready
            | if ($ready | length) == 0 then .stop = true
              else .k += 1
                | .rem = ($s.rem - $ready)
                | .lvl = ($s.lvl + ($ready | map({key: ., value: ($s.k + 1)}) | from_entries))
              end);
      def keep($r): [$r[] | select(. as $y | any($D[]; .[1] == $y and (.[0] | inn($r))))];
      (layers(preds($D))) as $L1
      | if ($L1.rem | length) > 0 then
          ($L1.rem | until(. as $r | keep($r) == $r; . as $r | keep($r))) as $cyc
          | ["1", "build-order: cycle: " + ($cyc | join(", "))]
        else
          [range(0; ($tags | length)) as $i | range($i + 1; ($tags | length)) as $j
            | $tags[$i] as $a | $tags[$j] as $b
            | ($ed[$a] | map(select(inn($ed[$b])))) as $sh
            | select(($sh | length) > 0 and (any($D[]; . == [$a, $b] or . == [$b, $a]) | not))
            | (if $L1.lvl[$a] != $L1.lvl[$b] then ($L1.lvl[$a] < $L1.lvl[$b])
               elif ($ed[$a] | length) != ($ed[$b] | length) then (($ed[$a] | length) < ($ed[$b] | length))
               else true end) as $aFirst
            | (if $aFirst then {f: $a, l: $b} else {f: $b, l: $a} end)
            | . as $o | . + {p: ($ed[$o.f] | map(select(inn($ed[$o.l]))))}
          ] | sort_by([$rank[.l], $rank[.f]]) as $A
          | ($D + ($A | map([.l, .f]))) as $P
          | preds($P) as $pm
          | layers($pm) as $L2
          | ($tags | map($L2.lvl[.]) | max) as $maxk
          | ["0"]
            + ($A | map("\(.l) after \(.f) - edits: \(.p | join(", "))"))
            + [range(1; $maxk + 1) as $k
                | [$tags[] | select($L2.lvl[.] == $k)] as $ws
                | "- Wave \($k)" + (if ($ws | length) >= 2 then " (parallel)" else "" end) + ": "
                  + ($ws | map(. + (if $k >= 2 then " (depends on \(($pm[.] | sort_by($rank[.])) | join(", ")))" else "" end)) | join(", "))]
        end
  end
| .[]
'

res=$(jq -r -R -s "$prog" < "$f" | tr -d '\r')
code=${res%%$'\n'*}
if [ "$code" = "$res" ]; then
    body=''
else
    body=${res#*$'\n'}
fi
case $code in
    0)
        if [ -n "$body" ]; then printf '%s\n' "$body"; fi
        exit 0
        ;;
    1 | 2)
        printf '%s\n' "$body" >&2
        exit "$code"
        ;;
esac
printf 'build-order: malformed input: not a JSON object\n' >&2
exit 2
