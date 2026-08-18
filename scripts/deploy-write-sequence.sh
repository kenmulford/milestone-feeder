#!/usr/bin/env bash
#
# deploy-write-sequence.sh: create's Step 3 write-sequence, passes a to d
# (bash twin of deploy-write-sequence.ps1).
#
# What this does, in plain terms:
#   docs/create-deploy-sequence.md (## Step 3: deploy write-sequence (passes
#   a-d)) records what `create` writes to GitHub once it has read the plan
#   file: the four labels (pass a), the milestone (pass b), one issue per
#   surviving plan entry (pass c), and the second pass that rewrites every
#   local slug to its real issue number (pass d). This script performs those
#   calls. It holds NO judgment. Every create-or-adopt decision, every notice,
#   and every report stays in the calling skill's prose, which is why pass b is
#   split into a search that surfaces EVERY match and three separate actions
#   the caller picks between: the doc's create-or-adopt table decides, this
#   script executes.
#
# Invocation (one form, identical on both twins, so a caller documents one):
#   scripts/deploy-write-sequence.sh <subcommand> [args]
#
# Entry points, one per pass step. Each is SEPARATELY INVOKABLE, so a sibling
# skill reusing one of create's write primitives calls the primitive it needs
# BY REFERENCE rather than re-inlining the `gh` form (the reuse-by-reference
# discipline at .project/design-philosophy.md (## What we optimize for), which
# skills/update/SKILL.md already follows against create's passes).
#
#   PASS A
#   labels
#     args   none.
#     does   Upserts the four canonical labels (`gh label create --force`), in
#            the recorded order, BEFORE any issue exists to reference them.
#            `--force` upserts, so a re-run produces no duplicate.
#     out    Nothing.
#     exit   0 when all four upserted; 3 on the first failure (named on stderr).
#
#   PASS B, split three ways because the decision is the caller's
#   find-milestone <title>
#     args   The exact `Milestone title (exact)` line from the plan file.
#     does   The paginated all-state title-match query. The title is passed
#            through the ENVIRONMENT as `env.t` and is never interpolated into
#            the jq filter: `gh api` has no `--arg` flag, and a title holding a
#            double quote would break an inlined filter and yield a spurious
#            no-match, which deploys a DUPLICATE milestone.
#     out    One TAB row per match, in API order: <number><TAB><state>.
#            Zero matches prints nothing. EVERY match is printed and this
#            script never picks one: the multiple-title-match row of the doc's
#            create-or-adopt table adopts the first and logs a notice, and that
#            is the caller's call to make and to log.
#     exit   0, including the zero-match case; 3 when the read itself failed.
#     note   A consumer needing a different PROJECTION of this read adds a
#            documented flag HERE rather than re-inlining the query
#            (skills/update/SKILL.md resolves the same milestone but also wants
#            its `description`): one definition of the quote-safe resolve,
#            never two.
#
#   create-milestone <title> <description-file>
#     args   The exact title; a file holding the description to post. The
#            description is a placeholder at this point: pass d rewrites it
#            once the slug map exists.
#     out    The new milestone number, one line.
#     exit   0; 2 on a missing file; 3 when the POST failed.
#
#   reopen-milestone <number>
#     args   The adopted milestone's number.
#     does   PATCHes `state=open`. NEVER deletes the milestone or its issues.
#     out    Nothing.
#     exit   0; 3 when the PATCH failed.
#
#   write-receipt <plan-file> <number>
#     args   The plan file Step 1 resolved; the number pass b resolved.
#     does   The deploy receipt back-write: rewrites the single
#            `Milestone number (GitHub):` line in place when present, inserts
#            it after `Source brief:` when absent, and appends it at EOF when
#            the plan file carries neither (a malformed or hand-edited plan
#            degrades VISIBLY). Both branches act on the FIRST match only, so a
#            plan file that somehow carries two receipt lines or two
#            `Source brief:` lines still converges on exactly one receipt line
#            carrying the current number, and a re-run never grows the line
#            count. The file is rewritten with LF line endings on either twin.
#     out    Nothing on success; on failure the recorded notice line,
#            byte-identical to the one docs/create-deploy-sequence.md records.
#     exit   0 ALWAYS. This is the one entry point here that never reports a
#            failure through its status, because the recorded semantics are
#            "report, don't block": by this point the GitHub deploy already
#            succeeded and the plan file is gitignored per-run scratch.
#
#   PASS C
#   create-issues <job-file>
#     args   The job file (schema below).
#     does   Creates ONLY the surviving issues the job file lists, in job
#            order, which is the plan file's Wave order. On the adopt path it
#            first lists the milestone's OPEN issues (`--json number,title`)
#            and reuses an exact title match rather than creating a duplicate.
#            An empty `issues` array, and an `issues` that is MISSING or null,
#            are the SAME case on both twins: zero surviving issues, `gh` not
#            called at all, no map row, exit 0 in silence.
#     out    The slug map: one TAB row per issue, in job order,
#            <slug><TAB><number><TAB>created|reused. Rows are printed as they
#            resolve, so a mid-loop failure still leaves the caller the partial
#            map the recorded partial-failure path reports.
#     exit   0 when every issue resolved; 2 on a usage or job-file problem;
#            3 when `gh`/`jq` is unavailable or the adopt-path listing failed
#            (nothing was created); 4 when a `gh issue create` failed MID-LOOP,
#            in which case the final stdout row is `#INCOMPLETE<TAB><slug>` and
#            the failing candidate is named on stderr.
#
#   PASS D
#   rewrite-slugs <map-file> <text-file>
#     args   A slug map (the stdout of `create-issues`); the text to rewrite.
#     does   The substring-safe slug rewrite, and nothing else. Exposed as its
#            own entry point because it is the load-bearing mechanic and it
#            touches no network: a caller can rewrite any text through it.
#     out    The rewritten text.
#     exit   0; 2 on a missing file; 5 when the map is INCOMPLETE.
#
#   apply-bodies <job-file> <map-file>
#     does   For each map row marked `created`, rewrites that issue's body file
#            through the same rule and applies it with `gh issue edit`. Rows
#            marked `reused` are SKIPPED: an adopted issue's body is preserved
#            as-is, which is the recorded body policy, not a gap. A body the
#            rewrite does not change is not edited at all.
#     out    One TAB row per created issue: <slug><TAB><number><TAB>edited or
#            <slug><TAB><number><TAB>unchanged.
#     exit   0; 2 on a usage problem; 3 when at least one edit failed (every
#            failure is named on stderr and the loop still finishes, so one bad
#            body never strands the rest); 5 when the map is INCOMPLETE.
#
#   patch-description <number> <map-file> <description-file>
#     does   Rewrites the Wave-order description through the same rule and
#            PATCHes it onto the milestone (the REPLACE form: the PATCH
#            overwrites, so re-running it is idempotent).
#     out    Nothing.
#     exit   0; 2 on a missing file; 3 when the PATCH failed; 5 when the map is
#            INCOMPLETE.
#
# The job file (pass c and pass d read it; the CALLER writes it):
#   The calling skill has already parsed the plan file (its own Step 2, which
#   is where the plan-file contract and its separator tolerance live). It hands
#   that parse over as one JSON file rather than having this script re-parse
#   the plan file, so the plan-file contract keeps exactly one reader.
#
#     {
#       "milestoneTitle": "<the exact Milestone title (exact) line>",
#       "adopt": true,
#       "issues": [
#         { "slug": "#A",
#           "title": "<the issue title>",
#           "bodyFile": ".milestone-feeder/body-A.md",
#           "labels": ["logic", "risk:heavy"] }
#       ]
#     }
#
#   `adopt` true runs the list-and-match-by-title step first (the milestone
#   already existed); false skips it (the milestone was just created, so it has
#   no issues to match). `bodyFile` holds the plan file's §4 ISSUE_BODY
#   VERBATIM, still carrying its local slugs; passing the body as a FILE, not
#   as a JSON string, keeps a multi-line markdown body out of any escaping
#   path. `labels` is applied in order, one `--label` each: the `ui`/`logic`
#   label is always present, and the `risk:*` label appears only when the plan
#   file records one (the recorded absent-risk branch), so a one-element array
#   deploys that label alone. An empty entry is skipped: never a `--label` with
#   no value. Scratch files belong under `.milestone-feeder/`, which already
#   self-ignores.
#
# The substring-safe rewrite, and why this implementation satisfies it:
#   The recorded rule has two clauses: replace in DESCENDING slug-length order
#   (every double-letter tag before any single-letter tag), and match each
#   `#<tag>` only at a TOKEN BOUNDARY, so `#A` never matches inside `#AB` or
#   inside a word. Both twins implement it as a single left-to-right MAXIMAL
#   MUNCH scan: at each `#`, take the LONGEST following run of letters as the
#   tag, then look that whole tag up. A maximal run is never a prefix of a
#   longer tag and is always followed by a non-tag character, so the token
#   boundary holds by construction and the result no longer depends on
#   replacement order at all. A `#` sitting immediately after a LETTER or a
#   DIGIT is left alone, which is the rule's "never a substring inside a word"
#   clause: `word#AB` and `docs.md#A` keep their text. On the RIGHT a DIGIT is
#   a boundary rather than part of the tag, because the recorded test there is
#   "not another tag-letter" and a digit is not one: `#AB2` rewrites to
#   `#<n>2`, on both twins. `#42` is untouched (no
#   letter follows the `#`), an unmapped tag is left exactly as written, and the
#   lookup is CASE-SENSITIVE, matching jq's `==` and the PowerShell twin's
#   ordinal comparer.
#
#   Line handling is the twins' shared contract: the rewritten text is emitted
#   as the input's lines, each terminated by a newline, so a text file with no
#   final newline gains one and an empty file stays empty. Both twins do this,
#   which is what keeps a body written on Windows and one written on macOS
#   byte-identical on GitHub.
#
# Working directory:
#   Every path an argument names is relative to the CURRENT working directory,
#   the consumer's repo root, where the calling skill already stands. This
#   script resolves nothing next to itself: unlike the notice emitter it reads
#   no bundled data file.
#
# Why jq, and what it is not asked to do:
#   jq is the approved bash-path JSON parser (.project/library-manifest.md
#   (## Approved libraries (by purpose)); the PowerShell twin uses native
#   ConvertFrom-Json). Each issue's four fields are read in ONE jq call per
#   issue that prints them one per line, rather than as a single joined row:
#   an issue TITLE is arbitrary human text, and a row separator would have to
#   be escaped back out of it. A title cannot contain a newline (it is one
#   markdown heading), so line-per-field is exact here.
#
# Failure philosophy:
#   These are GitHub WRITES, not notices, so a failure is reported through the
#   exit status and one stderr line rather than swallowed (the one exception,
#   `write-receipt`, is documented above with its reason). Nothing here ever
#   deletes a milestone or an issue. `set -e` is deliberately NOT set: the pass
#   c and pass d loops decide for themselves where a failure stops the walk and
#   where it lets the remaining items finish.
#
# Run it locally from a consumer repo root:
#   <plugin>/scripts/deploy-write-sequence.sh labels

TAB="$(printf '\t')"

usage() {
  cat >&2 <<'USAGE'
usage: deploy-write-sequence.sh <subcommand> [args]
  labels
  find-milestone <title>
  create-milestone <title> <description-file>
  reopen-milestone <number>
  write-receipt <plan-file> <number>
  create-issues <job-file>
  rewrite-slugs <map-file> <text-file>
  apply-bodies <job-file> <map-file>
  patch-description <number> <map-file> <description-file>
USAGE
}

say_err() {
  echo "deploy-write-sequence: $1" >&2
}

require_gh() {
  command -v gh >/dev/null 2>&1 && return 0
  say_err "gh (GitHub CLI) is not on PATH; no GitHub call attempted"
  return 3
}

require_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  say_err "jq is not on PATH; the job file cannot be read"
  return 3
}

require_file() {
  [ -f "$1" ] && return 0
  say_err "file not found: $1"
  return 2
}

# --- the slug map ------------------------------------------------------------
#
# MAPSTR is the map flattened to "|#A=42|#AB=7|", so a lookup is one bash or
# awk substring test and no associative array is needed (bash 3.2, which macOS
# still ships, has none). A map carrying the pass-c abort marker is REFUSED
# here, which is what makes "a create failure aborts the rewrite" mechanical in
# this script rather than a rule the caller has to remember.
MAPSTR=""

load_map() {
  local file="$1" slug number rest
  require_file "$file" || return 2
  if grep -q '^#INCOMPLETE' "$file" 2>/dev/null; then
    say_err "the slug map is INCOMPLETE (pass c aborted mid-loop); the slug rewrite is NOT run against a partial map"
    return 5
  fi
  MAPSTR="|"
  while IFS="$TAB" read -r slug number rest; do
    # A map file written by the PowerShell twin on Windows can carry a CR.
    number="${number%$'\r'}"
    case "$slug" in '#'[A-Za-z]*) ;; *) continue ;; esac
    case "$number" in '' | *[!0-9]*) continue ;; esac
    MAPSTR="${MAPSTR}${slug}=${number}|"
  done < "$file"
  return 0
}

# Rewrites $1 (a text file) to stdout through the maximal-munch scan.
rewrite_text() {
  awk -v mapstr="$MAPSTR" '
    function lookup(tag,   s, v) {
      s = index(mapstr, "|" tag "=")
      if (s == 0) return ""
      v = substr(mapstr, s + length(tag) + 2)
      sub(/\|.*/, "", v)
      return v
    }
    {
      line = $0
      out = ""
      prev = ""
      while (match(line, /#[A-Za-z]+/)) {
        pre = substr(line, 1, RSTART - 1)
        tag = substr(line, RSTART, RLENGTH)
        line = substr(line, RSTART + RLENGTH)
        if (RSTART > 1) prev = substr(pre, length(pre), 1)
        n = (prev ~ /[A-Za-z0-9]/) ? "" : lookup(tag)
        out = out pre (n == "" ? tag : "#" n)
        prev = substr(tag, length(tag), 1)
      }
      print out line
    }
  ' "$1"
}

# --- pass a ------------------------------------------------------------------

cmd_labels() {
  require_gh || return 3
  gh label create "ui"          --color 5319E7 --description "UI-surface issue (design review applies)" --force </dev/null >/dev/null 2>&1 \
    || { say_err "could not upsert the label: ui"; return 3; }
  gh label create "logic"       --color 0E8A16 --description "Logic / non-UI issue" --force </dev/null >/dev/null 2>&1 \
    || { say_err "could not upsert the label: logic"; return 3; }
  gh label create "risk:light"  --color C2E0C6 --description "Reduced-ceremony build profile (driver override)" --force </dev/null >/dev/null 2>&1 \
    || { say_err "could not upsert the label: risk:light"; return 3; }
  gh label create "risk:heavy"  --color B60205 --description "Full-ceremony build profile (driver override)" --force </dev/null >/dev/null 2>&1 \
    || { say_err "could not upsert the label: risk:heavy"; return 3; }
  return 0
}

# --- pass b ------------------------------------------------------------------

cmd_find_milestone() {
  local title="$1"
  [ -n "$title" ] || { usage; return 2; }
  require_gh || return 3
  t="$title" gh api "repos/{owner}/{repo}/milestones?state=all&per_page=100" --paginate \
    --jq '.[] | select(.title==env.t) | [(.number|tostring), .state] | @tsv' </dev/null 2>/dev/null \
    || { say_err "could not read the repository's milestones"; return 3; }
  return 0
}

cmd_create_milestone() {
  local title="$1" descfile="$2" desc number
  [ -n "$title" ] && [ -n "$descfile" ] || { usage; return 2; }
  require_file "$descfile" || return 2
  require_gh || return 3
  desc="$(cat "$descfile")"
  number="$(gh api --method POST "repos/{owner}/{repo}/milestones" \
    -f "title=$title" -f "description=$desc" --jq '.number' </dev/null 2>/dev/null)" \
    || { say_err "could not create the milestone: $title"; return 3; }
  case "$number" in '' | *[!0-9]*)
    say_err "the milestone POST returned no number: $title"
    return 3
    ;;
  esac
  printf '%s\n' "$number"
  return 0
}

cmd_reopen_milestone() {
  local number="$1"
  case "$number" in '' | *[!0-9]*) usage; return 2 ;; esac
  require_gh || return 3
  gh api --method PATCH "repos/{owner}/{repo}/milestones/$number" -f state=open </dev/null >/dev/null 2>&1 \
    || { say_err "could not reopen the milestone: #$number"; return 3; }
  return 0
}

# The receipt back-write. Uses awk (portable across BSD/macOS and GNU sed/awk);
# avoids GNU-sed-only `a`, which exits 1 on BSD/macOS sed.
cmd_write_receipt() {
  local plan="$1" n="$2" notice tmp
  case "$n" in '' | *[!0-9]*) usage; return 2 ;; esac
  notice="create: deployed milestone #$n but could not write the receipt to $plan; re-run to record it"
  if [ ! -f "$plan" ]; then
    echo "$notice"
    return 0
  fi
  tmp="$(mktemp)" || { echo "$notice"; return 0; }
  if grep -q '^Milestone number (GitHub):' "$plan"; then
    # present: rewrite the FIRST receipt line in place (exactly one line; never a duplicate)
    awk -v n="$n" '!done && /^Milestone number \(GitHub\):/ { print "Milestone number (GitHub): " n; done=1; next } { print }' "$plan" > "$tmp" \
      && mv "$tmp" "$plan" || echo "$notice"
  elif grep -q '^Source brief:' "$plan"; then
    # absent, anchor present: insert exactly once after the Source brief header line
    awk -v n="$n" '{ print } !done && /^Source brief:/ { print "Milestone number (GitHub): " n; done=1 }' "$plan" > "$tmp" \
      && mv "$tmp" "$plan" || echo "$notice"
  else
    # absent AND no anchor (malformed/hand-edited plan): degrade VISIBLY by
    # appending at EOF (still exactly one line; the present branch finds it next run)
    awk -v n="$n" '{ print } END { print "Milestone number (GitHub): " n }' "$plan" > "$tmp" \
      && mv "$tmp" "$plan" || echo "$notice"
  fi
  rm -f "$tmp" 2>/dev/null
  return 0
}

# --- pass c ------------------------------------------------------------------

cmd_create_issues() {
  local job="$1" mtitle adopt count adoptlist i fields slug title bodyfile labels
  local number action url l old_ifs status
  [ -n "$job" ] || { usage; return 2; }
  require_file "$job" || return 2
  require_jq || return 3

  mtitle="$(jq -r '.milestoneTitle // ""' "$job" 2>/dev/null)"
  [ -n "$mtitle" ] || { say_err "the job file records no milestoneTitle: $job"; return 2; }

  count="$(jq -r '(.issues // []) | length' "$job" 2>/dev/null)"
  case "$count" in '' | *[!0-9]*) say_err "the job file records no issues array: $job"; return 2 ;; esac
  # Zero surviving issues: create nothing, list nothing, print no map row. Pass
  # d then finds no slug occurrence to rewrite. Parked and dropped issues never
  # reach this script at all.
  [ "$count" -gt 0 ] || return 0

  require_gh || return 3

  adoptlist=""
  adopt="$(jq -r 'if .adopt == true then "yes" else "no" end' "$job" 2>/dev/null)"
  if [ "$adopt" = "yes" ]; then
    adoptlist="$(mktemp)" || { say_err "could not create a temporary file"; return 3; }
    if ! gh issue list --milestone "$mtitle" --state open --json number,title </dev/null > "$adoptlist" 2>/dev/null; then
      rm -f "$adoptlist" 2>/dev/null
      say_err "could not list the milestone's open issues; nothing was created"
      return 3
    fi
  fi

  status=0
  i=0
  while [ "$i" -lt "$count" ]; do
    fields="$(jq -r --argjson i "$i" '
      .issues[$i]
      | [ (.slug // ""),
          (.title // ""),
          (.bodyFile // ""),
          ((.labels // []) | map(select(type == "string")) | join(",")) ]
      | .[]' "$job" 2>/dev/null)"
    { IFS= read -r slug; IFS= read -r title; IFS= read -r bodyfile; IFS= read -r labels; } <<EOF
$fields
EOF

    if [ -z "$slug" ] || [ -z "$title" ]; then
      printf '#INCOMPLETE\t%s\n' "${slug:-<no slug>}"
      say_err "issue entry $i records no slug or no title; nothing further was created"
      status=4
      break
    fi

    number=""
    action=""
    if [ -n "$adoptlist" ]; then
      number="$(jq -r --arg t "$title" 'map(select(.title == $t)) | if length > 0 then (.[0].number | tostring) else "" end' "$adoptlist" 2>/dev/null)"
      case "$number" in *[!0-9]*) number="" ;; esac
    fi

    if [ -n "$number" ]; then
      action="reused"
    else
      if [ ! -f "$bodyfile" ]; then
        printf '#INCOMPLETE\t%s\n' "$slug"
        say_err "the body file for $slug is missing: ${bodyfile:-<none>}; nothing further was created"
        status=4
        break
      fi
      old_ifs="$IFS"
      IFS=,
      set --
      for l in $labels; do
        [ -n "$l" ] && set -- "$@" --label "$l"
      done
      IFS="$old_ifs"
      url="$(gh issue create --title "$title" --body-file "$bodyfile" --milestone "$mtitle" "$@" </dev/null 2>/dev/null)"
      if [ $? -ne 0 ]; then
        printf '#INCOMPLETE\t%s\n' "$slug"
        say_err "gh issue create failed for $slug \"$title\"; the issues above were created, the rest were not"
        status=4
        break
      fi
      number="$(printf '%s\n' "$url" | tail -1)"
      number="${number##*/}"
      case "$number" in '' | *[!0-9]*)
        printf '#INCOMPLETE\t%s\n' "$slug"
        say_err "gh issue create returned no issue number for $slug \"$title\""
        status=4
        break
        ;;
      esac
      action="created"
    fi

    printf '%s\t%s\t%s\n' "$slug" "$number" "$action"
    i=$((i + 1))
  done

  [ -n "$adoptlist" ] && rm -f "$adoptlist" 2>/dev/null
  return $status
}

# --- pass d ------------------------------------------------------------------

cmd_rewrite_slugs() {
  local mapfile="$1" textfile="$2" rc
  [ -n "$mapfile" ] && [ -n "$textfile" ] || { usage; return 2; }
  require_file "$textfile" || return 2
  load_map "$mapfile"
  rc=$?
  [ $rc -eq 0 ] || return $rc
  rewrite_text "$textfile"
  return 0
}

cmd_apply_bodies() {
  local job="$1" mapfile="$2" rc slug number action bodyfile tmp status
  [ -n "$job" ] && [ -n "$mapfile" ] || { usage; return 2; }
  require_file "$job" || return 2
  require_jq || return 3
  require_gh || return 3
  load_map "$mapfile"
  rc=$?
  [ $rc -eq 0 ] || return $rc

  status=0
  while IFS="$TAB" read -r slug number action; do
    action="${action%$'\r'}"
    case "$slug" in '#'[A-Za-z]*) ;; *) continue ;; esac
    # Adopted issues are NOT body-rewritten: their bodies are preserved as-is.
    [ "$action" = "created" ] || continue
    bodyfile="$(jq -r --arg s "$slug" 'first((.issues // [])[] | select(.slug == $s) | .bodyFile) // ""' "$job" 2>/dev/null)"
    if [ ! -f "$bodyfile" ]; then
      say_err "the body file for $slug is missing: ${bodyfile:-<none>}; #$number still carries its local slugs"
      status=3
      continue
    fi
    tmp="$(mktemp)" || { say_err "could not create a temporary file"; status=3; continue; }
    rewrite_text "$bodyfile" > "$tmp"
    if cmp -s "$tmp" "$bodyfile"; then
      # A created issue whose full body carries no slug reference needs no edit.
      printf '%s\t%s\tunchanged\n' "$slug" "$number"
      rm -f "$tmp" 2>/dev/null
      continue
    fi
    if gh issue edit "$number" --body-file "$tmp" </dev/null >/dev/null 2>&1; then
      printf '%s\t%s\tedited\n' "$slug" "$number"
    else
      say_err "gh issue edit failed for $slug (#$number); that issue still carries its local slugs"
      status=3
    fi
    rm -f "$tmp" 2>/dev/null
  done < "$mapfile"
  return $status
}

cmd_patch_description() {
  local number="$1" mapfile="$2" descfile="$3" rc tmp desc
  case "$number" in '' | *[!0-9]*) usage; return 2 ;; esac
  [ -n "$mapfile" ] && [ -n "$descfile" ] || { usage; return 2; }
  require_file "$descfile" || return 2
  require_gh || return 3
  load_map "$mapfile"
  rc=$?
  [ $rc -eq 0 ] || return $rc
  tmp="$(mktemp)" || { say_err "could not create a temporary file"; return 3; }
  rewrite_text "$descfile" > "$tmp"
  desc="$(cat "$tmp")"
  rm -f "$tmp" 2>/dev/null
  gh api --method PATCH "repos/{owner}/{repo}/milestones/$number" -f "description=$desc" </dev/null >/dev/null 2>&1 \
    || { say_err "could not PATCH the description onto milestone #$number"; return 3; }
  return 0
}

# --- dispatch ----------------------------------------------------------------

sub="${1:-}"
[ $# -gt 0 ] && shift

case "$sub" in
  labels)            cmd_labels "$@" ;;
  find-milestone)    cmd_find_milestone "$@" ;;
  create-milestone)  cmd_create_milestone "$@" ;;
  reopen-milestone)  cmd_reopen_milestone "$@" ;;
  write-receipt)     cmd_write_receipt "$@" ;;
  create-issues)     cmd_create_issues "$@" ;;
  rewrite-slugs)     cmd_rewrite_slugs "$@" ;;
  apply-bodies)      cmd_apply_bodies "$@" ;;
  patch-description) cmd_patch_description "$@" ;;
  *)                 usage; exit 2 ;;
esac

exit $?
