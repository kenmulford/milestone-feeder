#!/usr/bin/env bash
#
# roadmap-deploy.sh: create's Step 1R roadmap outer-loop mechanics (bash twin of
# roadmap-deploy.ps1).
#
# What this does, in plain terms:
#   docs/create-deploy-sequence.md (Step 1R) describes a roadmap deploy: an
#   outer loop over the manifest's N milestones, each one guarded by a resume
#   checkpoint and each one recording its cross-milestone build-order line. The
#   three mechanical operations behind that prose live here, once, so this
#   script and its PowerShell twin cannot drift from each other or from the
#   doc. The judgment steps (the resolution table, the per-milestone step table,
#   the reporting narrative) stay in the doc and in skills/create/SKILL.md.
#
# Invocation (one form, identical on both twins, so a caller documents one):
#
#   roadmap-deploy.sh checkpoint-read <slug> <position>
#     Row 0. Resolves this milestone's `Plan file:` path out of the roadmap
#     manifest, then consults the deploy checkpoint and runs the one cheap
#     existence check. Prints exactly three `key=value` lines, in this order:
#       planfile=<path>          (empty when the manifest has no entry)
#       short_circuit=<0|1>      (1 = confirmed fully deployed, skip passes a-d)
#       number=<n>               (the confirmed milestone number; empty on 0)
#
#   roadmap-deploy.sh checkpoint-upsert <slug> <position> <planfile> <number> <pass> <status>
#     Upsert-by-position. Rewrites this milestone's checkpoint entry in place,
#     never growing a duplicate. Call it at each pass-start and pass-end site
#     with that site's own <pass>/<status>. <number> is empty until pass (b)
#     resolves it, and is recorded as JSON null while empty.
#
#   roadmap-deploy.sh build-order-line <position> <total> <milestone-number> <goal> <waves>
#     Assembles milestone X's augmented description (the goal, the ONE canonical
#     `build order: milestone X of N` line, the slug-rewritten Waves block) and
#     applies it with pass (d)'s existing REPLACE-form PATCH. No new
#     read-modify-write of the description is added: pass (d) already replaces
#     the whole description every run, so the line is overwritten in place and
#     its count never grows.
#
# Where the state lives:
#   .milestone-feeder/deploy-state-<slug>.json and
#   .milestone-feeder/roadmap-<slug>.md, both relative to the CURRENT working
#   directory: the consumer's repo root, where the calling skill already stands.
#   <slug> is derived by the identical rule the plan file and the roadmap
#   manifest use (skills/plan/SKILL.md Step 7); this script never derives it.
#
# Why jq:
#   jq is the approved bash-path JSON parser (.project/library-manifest.md
#   (## Approved libraries (by purpose)); the PowerShell twin uses native
#   ConvertFrom-Json/ConvertTo-Json and needs no jq at all.
#
# Failure posture, per operation (these differ deliberately):
#   checkpoint-read / checkpoint-upsert are FAIL-OPEN. `set -e` is deliberately
#   NOT set. A missing jq, an absent or 0-byte or unreadable state file, a `gh`
#   error, a title mismatch, a `state != "open"`, or a failed write costs only
#   this milestone's checkpoint, and never the deploy in progress. A missing jq
#   is a SILENT no-op on both operations: nothing is printed, nothing is written.
#   Only an upsert WRITE failure emits a notice. A read that finds nothing simply
#   reports short_circuit=0, so this milestone falls through to its own full
#   deploy. No other milestone's entry is touched or affected.
#   build-order-line is NOT best-effort: it is pass (d)'s load-bearing
#   description write, so it exits with `gh`'s own status and the caller's
#   existing mid-loop failure path handles a non-zero.
#
# Parity with the PowerShell twin (the emitted bytes are the contract):
#   Both twins print the same three `key=value` lines in the same order, the
#   same notice text, and the same assembled description. That description ends
#   at the last line of the Waves block on BOTH twins: command substitution
#   strips the trailing newline this script's printf format emits, and a
#   PowerShell here-string never carries one, so the two payloads agree byte for
#   byte. The twin joins the description with explicit LF escapes rather than a
#   here-string so the payload stays LF on every host.
#
# Run it locally from a consumer repo root:
#   <plugin>/scripts/roadmap-deploy.sh checkpoint-read my-slug 1
#
# Exit codes:
#   0 = the operation ran (a fail-open operation reports 0 even when it skipped)
#   the `gh` exit status, for build-order-line only
#   2 = usage error (an unknown operation, or the wrong argument count)

usage() {
  echo "usage: roadmap-deploy.sh checkpoint-read <slug> <position>" >&2
  echo "       roadmap-deploy.sh checkpoint-upsert <slug> <position> <planfile> <number> <pass> <status>" >&2
  echo "       roadmap-deploy.sh build-order-line <position> <total> <milestone-number> <goal> <waves>" >&2
  exit 2
}

op="${1:-}"
[ -n "$op" ] || usage

case "$op" in

  # --- Row 0: resolve the plan file, consult the checkpoint, one cheap check --
  #
  # cp_pass/cp_status/cp_number are the CHECKPOINT-RECORDED values, deliberately
  # NOT pass/status/number, so they never collide with checkpoint-upsert's
  # caller-supplied parameters of those same names.
  checkpoint-read)
    [ "$#" -eq 3 ] || usage
    slug="$2"
    X="$3"

    short_circuit=0
    number=""
    manifest=".milestone-feeder/roadmap-$slug.md"
    state=".milestone-feeder/deploy-state-$slug.json"

    planfile="$(awk -v x="$X" '
      $0 ~ ("^### " x "\\. ") { infile=1; next }
      /^### / { infile=0 }
      infile && /^- Plan file:/ { sub(/^- Plan file: */, ""); print; exit }
    ' "$manifest" 2>/dev/null)"

    # `-s`, not `-f`: an empty file is treated the same as an absent one, so a
    # corrupted-to-empty state file is never accepted as valid content.
    if command -v jq >/dev/null 2>&1 && [ -s "$state" ]; then
      entry="$(jq -c --argjson x "$X" '(.milestones // [])[] | select(.position == $x)' "$state" 2>/dev/null)"
      if [ -n "$entry" ]; then
        cp_pass="$(printf '%s' "$entry" | jq -r '.pass // empty' 2>/dev/null)"
        cp_status="$(printf '%s' "$entry" | jq -r '.status // empty' 2>/dev/null)"
        cp_number="$(printf '%s' "$entry" | jq -r '.milestoneNumber // empty' 2>/dev/null)"
        if [ "$cp_pass" = "d" ] && [ "$cp_status" = "complete" ] && [ -n "$cp_number" ]; then
          title="$(grep -m1 '^Milestone title (exact):' "$planfile" 2>/dev/null | sed -E 's/^Milestone title \(exact\): *//')"
          # stdout only (2>/dev/null): never merge gh's stderr into the JSON we
          # parse below, so an incidental stderr line on an otherwise-successful
          # call can never masquerade as unparsable JSON and force a false
          # negative.
          if live="$(gh api "repos/{owner}/{repo}/milestones/$cp_number" --jq '{title, state}' 2>/dev/null)"; then
            live_title="$(printf '%s' "$live" | jq -r '.title' 2>/dev/null)"
            live_state="$(printf '%s' "$live" | jq -r '.state' 2>/dev/null)"
            if [ "$live_title" = "$title" ] && [ "$live_state" = "open" ]; then
              short_circuit=1
              number="$cp_number"
            fi
          fi
        fi
      fi
    fi

    printf 'planfile=%s\n' "$planfile"
    printf 'short_circuit=%s\n' "$short_circuit"
    printf 'number=%s\n' "$number"
    exit 0
    ;;

  # --- upsert this milestone's checkpoint entry by position ------------------
  #
  # Fail-open. No jq: silent no-op, nothing printed and nothing written. A write
  # error emits a notice. Either way this returns WITHOUT aborting the deploy in
  # progress. A 0-byte/absent state file is (re)seeded fresh (`-s`, not `-f`, for
  # the reason above); a post-filter `-s "$tmp"` check guards against ever
  # overwriting the real file with an unexpectedly empty filter result (jq exits
  # 0 on empty input with zero output records).
  checkpoint-upsert)
    [ "$#" -eq 7 ] || usage
    slug="$2"
    X="$3"
    planfile="$4"
    number="$5"
    pass="$6"
    status="$7"

    state=".milestone-feeder/deploy-state-$slug.json"
    if command -v jq >/dev/null 2>&1; then
      [ -s "$state" ] || printf '{"slug": "%s", "milestones": []}' "$slug" > "$state" 2>/dev/null
      n_json="${number:-null}"
      tmp="$(mktemp 2>/dev/null)"
      if [ -n "$tmp" ] && jq --argjson x "$X" --arg pf "$planfile" --argjson n "$n_json" --arg p "$pass" --arg st "$status" \
           '.milestones = ((.milestones // []) | map(select(.position != $x))) + [{position: $x, planFile: $pf, milestoneNumber: $n, pass: $p, status: $st}]' \
           "$state" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
        mv "$tmp" "$state" 2>/dev/null || echo "create: could not persist the deploy checkpoint for milestone $X (pass $pass, $status), continuing without it"
      else
        rm -f "$tmp" 2>/dev/null
        echo "create: could not persist the deploy checkpoint for milestone $X (pass $pass, $status), continuing without it"
      fi
    fi
    exit 0
    ;;

  # --- assemble the description, then pass (d)'s REPLACE-form PATCH ----------
  #
  # goal and waves are the two halves of the description pass (d) already builds
  # (slugs rewritten to #n). X = Build-order position; N = the manifest's count.
  build-order-line)
    [ "$#" -eq 6 ] || usage
    X="$2"
    N="$3"
    number="$4"
    goal="$5"
    waves="$6"

    desc="$(printf '%s\n\nbuild order: milestone %s of %s\n\n%s\n' "$goal" "$X" "$N" "$waves")"
    gh api --method PATCH "repos/{owner}/{repo}/milestones/$number" -f "description=$desc"
    exit $?
    ;;

  *)
    usage
    ;;
esac
