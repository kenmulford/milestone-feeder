#!/usr/bin/env bash
#
# md-epic-parent.sh: create's Step 1R md-epic parent-issue pass and its
# sub-issue-linking pass (bash twin of md-epic-parent.ps1).
#
# What this does, in plain terms:
#   docs/create-deploy-sequence.md (Step 1R) records the two passes that run
#   once per ROADMAP deploy, after the outer loop has deployed all N
#   milestones: the pass that renders and resolves the roadmap's single
#   `md-epic` parent issue, and the pass that links every deployed milestone's
#   surviving issues to it as native GitHub sub-issues. This script performs
#   those calls. It holds NO judgment. Every create-or-adopt decision, every
#   notice, every warning line, and the end-of-pass report stay in the calling
#   skill's prose: this script prints rows and values, and the caller decides
#   what to say about them.
#
# Invocation (one form, identical on both twins, so a caller documents one):
#   scripts/md-epic-parent.sh <subcommand> [args]
#
# Entry points, one per pass step. Each is SEPARATELY INVOKABLE, so a sibling
# skill reusing one of these mechanics calls the one it needs BY REFERENCE
# rather than re-inlining the `gh` form (the reuse-by-reference discipline at
# .project/design-philosophy.md (## What we optimize for), which
# docs/update-reconcile-parent.md already follows against this pass).
#
#   THE MD-EPIC PARENT-ISSUE PASS
#   gather-numbers <manifest>
#     args   The roadmap manifest path.
#     does   Walks the manifest's `## Milestones (in build order)` entries in
#            the order they appear and resolves each milestone's real number:
#            that entry's `Plan file:` path, then that plan file's own
#            `Milestone number (GitHub): <n>` receipt; when the receipt is
#            absent (pass b's receipt write is itself report-don't-block, so a
#            prior run may have deployed the milestone and failed to record
#            it), the plan file's `Milestone title (exact):` line is re-resolved
#            through the SIBLING twin, `deploy-write-sequence.sh find-milestone
#            <title>`, taking the FIRST row's number field. That primitive owns
#            the quote-safe `env.t` milestones query; this script never
#            re-derives it.
#     out    One number per line, in build order, on success ONLY. A run that
#            cannot resolve every milestone prints NOTHING, so a partial list
#            can never be rendered into a parent body.
#     exit   0; 2 on a usage problem or an unreadable manifest; 3 when `gh` or
#            the sibling twin is unavailable, or the milestones read failed;
#            4 when some milestone's number could not be resolved at all (the
#            position and its plan file are named on stderr, and the caller
#            STOPS the pass without touching the parent issue).
#
#   render-body <intro> <number> [<number> ...]
#     args   The manifest's `Parent intro:` text; every number gather-numbers
#            printed, in build order.
#     does   Assembles the parent issue's body: the intro verbatim, a blank
#            line, then the ordered block, opening with a fence that is exactly
#            three backticks followed by `md-epic-order` and closing with a
#            bare three-backtick line, carrying one `number: <n>` line per
#            milestone, never `#<n>` (the read-contract at
#            docs/specs/v0.11.0-md-epic-parent-issue.md).
#     out    The rendered body. The caller redirects it into a file and hands
#            that path to `resolve-or-create`.
#     exit   0; 2 when the intro is empty, no number was passed, or a value is
#            not a number.
#     note   The fence lines are built here, from single-quoted `printf`
#            formats, because a run of three backticks is hazardous inside a
#            double-quoted string in BOTH shells: bash reads backticks as
#            old-style command substitution (so an intro-adjacent fence could
#            RUN text), and PowerShell reads a backtick as its escape character
#            (so two of the three are silently eaten). Single quotes make a
#            backtick literal in both, which is why the assembly lives in a
#            script rather than in an inline shell string.
#
#   resolve-or-create <manifest> <parent-title> <body-file>
#     args   The roadmap manifest; the manifest's exact `Parent title:` text;
#            the body file `render-body` produced on THIS run.
#     does   Resolves the parent in the recorded order and acts: the manifest's
#            own `Parent issue (GitHub): #<n>` receipt, else an OPEN issue
#            carrying the `md-epic` label whose title matches EXACTLY, else a
#            create (`--label "md-epic"`, no `--milestone`, no other label). On
#            either adopt branch it then REPLACES the whole body with the body
#            file, never appends, so a re-run leaves exactly one
#            `md-epic-order` block. The adopt-by-title search is this pass's
#            OWN entry point against the ISSUES endpoint, not pass (b)'s
#            milestones primitive, and it passes the title through the
#            ENVIRONMENT as `env.t` for the same reason pass (b) does: `gh api`
#            has no `--arg` flag, and a title holding a double quote would
#            break an inlined jq filter and yield a spurious no-match, which
#            would duplicate the parent issue.
#     out    One TAB row: <number><TAB>created|adopted. The row is printed as
#            soon as the number is known, BEFORE the adopt-path body replace,
#            so a failed body write still leaves the caller the number its
#            report has to name.
#     exit   0; 2 on a usage problem or a missing file; 3 when a `gh` call
#            failed, naming which step on stderr. These are LOAD-BEARING
#            writes: the caller STOPS the pass on a non-zero. Nothing here ever
#            deletes an issue.
#
#   write-receipt <manifest> <number>
#     args   The roadmap manifest; the parent number resolve-or-create printed.
#     does   The manifest receipt back-write, `Parent issue (GitHub): #<n>`,
#            in the recorded four-branch order: rewrite the line in place when
#            present, else insert after `Parent intro:`, else insert after
#            `Build order:` (a hand-edited manifest, or one written before
#            docs/roadmap-manifest-format.md reserved `Parent intro:`), else
#            append at EOF so a malformed manifest degrades VISIBLY. Every
#            branch acts on the FIRST match only, so a manifest that somehow
#            carries two receipt lines or two anchors still converges on
#            exactly one receipt line and a re-run never grows the line count.
#            The file is rewritten with LF line endings on either twin.
#     out    Nothing on success; on failure the recorded notice line,
#            byte-identical to the one docs/create-deploy-sequence.md records.
#     exit   0 ALWAYS. The recorded semantics are "report, don't block": by the
#            time this runs the parent issue already exists carrying its
#            correct body, and the next run re-derives the same number from the
#            adopt-by-title branch and rewrites the receipt.
#
#   THE SUB-ISSUE-LINKING PASS
#   link-sub-issues <manifest> <parent> <number> [<number> ...]
#     args   The roadmap manifest; the resolved parent number; the SAME numbers
#            gather-numbers printed, in build order, one per manifest entry and
#            positionally aligned with them (they are reused here, never
#            re-derived). A count mismatch is a usage error.
#     does   Fetches the parent's already-linked sub-issues ONCE for the whole
#            pass (paginated: a parent carries up to 100 sub-issues and the
#            endpoint's default page is 30), then walks the milestones in build
#            order. Per milestone it reads that milestone's exact title from
#            its plan file (needed for the re-assert flag) and pulls every
#            `#<n>` token out of its LIVE, already-PATCHed description in
#            first-appearance order, deduped: a milestone description carries
#            `#<n>` references only inside its `## Waves` block, so that IS
#            its surviving-issue list in Wave order. A milestone whose
#            description yields no token contributes nothing and drives zero
#            iterations, which is not an error. Before linking any of a
#            milestone's children it checks each one for the `md-epic` label
#            and REFUSES the whole milestone on the first hit (nested epics).
#            Per child, in order: already linked, then the 100-sub-issue cap,
#            then the link itself (resolve the child's numeric database id,
#            POST it to the parent's `sub_issues` endpoint with `-F` so the id
#            rides as a JSON integer, then re-assert the child's own
#            milestone). Each of those three is caught per child: a failure
#            stops THAT child only and the walk continues.
#     out    One TAB row per outcome, in the order they occur. First field is
#            the row kind:
#              skip-pass<TAB><error>                     the once-per-parent
#                                                        listing failed; the
#                                                        pass is skipped for
#                                                        this run only
#              refused<TAB><milestone><TAB><title><TAB><child>
#              linked<TAB><child>
#              failed<TAB><child><TAB>id-resolve|link|reassert<TAB><error>
#              skipped<TAB><child><TAB>already-linked|cap|nested-epic
#              total<TAB><count>                         the parent's resulting
#                                                        sub-issue total
#            Every error text is flattened to one line, so a row is always one
#            line. What each row PRINTS is the caller's call:
#            docs/create-deploy-sequence.md holds the notice, the warning, and
#            the report formats.
#     exit   0, including the fail-open listing failure and every per-child
#            failure: this pass never fails the deploy that already succeeded
#            (.project/design-philosophy.md (## Error & failure philosophy));
#            2 on a usage problem or a count mismatch; 3 when `gh` is
#            unavailable.
#
# The manifest walk (shared by gather-numbers and link-sub-issues):
#   Entries are read ONLY between the manifest's `## Milestones (in build
#   order)` heading and the next `## ` heading, in the order they appear, which
#   is build order. The gate is load-bearing rather than cosmetic: the
#   manifest also persists the FULL original brief verbatim
#   (docs/roadmap-manifest-format.md), and that brief can carry `### ` headings
#   of its own that an ungated walk would read as milestone entries.
#
# Working directory:
#   Every path an argument names is relative to the CURRENT working directory,
#   the consumer's repo root, where the calling skill already stands. The one
#   path resolved next to this script is its SIBLING twin,
#   deploy-write-sequence.sh, whose `find-milestone` primitive owns the
#   exact-title milestone query (the same self-relative resolve emit-notice.sh
#   uses for its data file).
#
# Why no jq:
#   Every JSON read here goes through `gh --jq`, `gh`'s own embedded filter,
#   so this script adds no standalone-jq dependency (the PowerShell twin uses
#   the same `gh --jq` forms for the same reason). `.project/library-manifest.md
#   (## Approved libraries (by purpose))` approves jq for the bash path where a
#   local JSON file has to be parsed; nothing here parses one.
#
# Failure philosophy:
#   The two passes differ deliberately, and this script preserves the
#   difference. The parent-issue pass makes LOAD-BEARING writes: a failure is
#   reported through the exit status and one stderr line (the one exception,
#   `write-receipt`, is documented above with its reason). The
#   sub-issue-linking pass is fail-open throughout: its failures are ROWS, and
#   its exit status stays 0, because by then the deploy it follows has already
#   succeeded. Nothing here ever deletes or closes an issue, and nothing ever
#   unlinks one. `set -e` is deliberately NOT set: each walk decides for itself
#   where a failure stops it and where it lets the remaining items finish.
#
# Run it locally from a consumer repo root:
#   <plugin>/scripts/md-epic-parent.sh gather-numbers .milestone-feeder/roadmap-<slug>.md

TAB="$(printf '\t')"
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"

usage() {
  cat >&2 <<'USAGE'
usage: md-epic-parent.sh <subcommand> [args]
  gather-numbers <manifest>
  render-body <intro> <number> [<number> ...]
  resolve-or-create <manifest> <parent-title> <body-file>
  write-receipt <manifest> <number>
  link-sub-issues <manifest> <parent> <number> [<number> ...]
USAGE
}

say_err() {
  echo "md-epic-parent: $1" >&2
}

require_gh() {
  command -v gh >/dev/null 2>&1 && return 0
  say_err "gh (GitHub CLI) is not on PATH; no GitHub call attempted"
  return 3
}

require_file() {
  [ -f "$1" ] && return 0
  say_err "file not found: $1"
  return 2
}

# Flattens a captured error to ONE line, so a multi-line `gh` message can never
# split a TAB row in two.
one_line() {
  printf '%s' "$1" | tr '\n\r\t' '   '
}

# --- the manifest walk -------------------------------------------------------
#
# Prints <position>TAB<plan-file> per milestone entry, in file order (build
# order). An entry with no `Plan file:` line still prints its row, with an
# empty second field, so a pending entry surfaces as an unresolved milestone
# rather than silently vanishing from the walk.
manifest_entries() {
  awk '
    /^## Milestones \(in build order\)/ { inmiles = 1; next }
    inmiles && /^## / {
      if (pos != "") { print pos "\t" pf; pos = "" }
      inmiles = 0
    }
    inmiles && /^### [0-9]+\./ {
      if (pos != "") { print pos "\t" pf }
      line = $0
      sub(/\r$/, "", line)
      sub(/^### /, "", line)
      sub(/\..*$/, "", line)
      pos = line
      pf = ""
      next
    }
    inmiles && pos != "" && pf == "" && /^- Plan file:/ {
      line = $0
      sub(/\r$/, "", line)
      sub(/^- Plan file: */, "", line)
      pf = line
    }
    END { if (pos != "") print pos "\t" pf }
  ' "$1" 2>/dev/null
}

read_title() {
  [ -n "$1" ] && [ -f "$1" ] || return 0
  grep -m1 '^Milestone title (exact):' "$1" 2>/dev/null | sed -E 's/^Milestone title \(exact\): *//' | tr -d '\r'
}

# The two-tier number read: this milestone's own receipt, else the sibling
# twin's exact-title lookup. Prints the number, or nothing when neither
# resolved. Returns 3 when the lookup itself could not run.
read_number() {
  local planfile="$1" n title rows
  [ -n "$planfile" ] && [ -f "$planfile" ] || return 0
  n="$(grep -m1 '^Milestone number (GitHub):' "$planfile" 2>/dev/null | sed -E 's/^Milestone number \(GitHub\): *([0-9]+).*/\1/' | tr -d '\r')"
  case "$n" in '' | *[!0-9]*) n="" ;; esac
  if [ -z "$n" ]; then
    title="$(read_title "$planfile")"
    [ -n "$title" ] || return 0
    [ -f "$SCRIPT_DIR/deploy-write-sequence.sh" ] || {
      say_err "the sibling twin is missing: $SCRIPT_DIR/deploy-write-sequence.sh; the exact-title fallback cannot run"
      return 3
    }
    rows="$("$SCRIPT_DIR/deploy-write-sequence.sh" find-milestone "$title" </dev/null 2>/dev/null)" || {
      say_err "the exact-title milestone lookup failed for: $title (via deploy-write-sequence.sh find-milestone)"
      return 3
    }
    n="$(printf '%s\n' "$rows" | head -1 | cut -f1)"
    case "$n" in '' | *[!0-9]*) n="" ;; esac
  fi
  printf '%s' "$n"
  return 0
}

# --- the md-epic parent-issue pass -------------------------------------------

cmd_gather_numbers() {
  local manifest="$1" entries pos planfile n rc out
  [ -n "$manifest" ] || { usage; return 2; }
  require_file "$manifest" || return 2
  entries="$(manifest_entries "$manifest")"
  if [ -z "$entries" ]; then
    say_err "the manifest lists no milestone entries: $manifest"
    return 2
  fi
  out=""
  while IFS="$TAB" read -r pos planfile; do
    [ -n "$pos" ] || continue
    n="$(read_number "$planfile")"
    rc=$?
    [ $rc -eq 0 ] || return $rc
    if [ -z "$n" ]; then
      say_err "could not resolve a milestone number for build-order position $pos (plan file: ${planfile:-<none>}); the parent issue was not touched"
      return 4
    fi
    out="${out}${n}
"
  done <<EOF
$entries
EOF
  printf '%s' "$out"
  return 0
}

cmd_render_body() {
  local intro="$1" n
  [ -n "$intro" ] || { usage; return 2; }
  shift
  [ $# -gt 0 ] || { usage; return 2; }
  for n in "$@"; do
    case "$n" in '' | *[!0-9]*)
      say_err "not a milestone number: $n"
      return 2
      ;;
    esac
  done
  printf '%s\n\n' "$intro"
  printf '```md-epic-order\n'
  for n in "$@"; do printf 'number: %s\n' "$n"; done
  printf '```\n'
  return 0
}

cmd_resolve_or_create() {
  local manifest="$1" title="$2" bodyfile="$3" n rows url
  [ -n "$manifest" ] && [ -n "$title" ] && [ -n "$bodyfile" ] || { usage; return 2; }
  require_file "$manifest" || return 2
  require_file "$bodyfile" || return 2
  require_gh || return 3

  # (a) the manifest's own receipt
  n="$(grep -m1 '^Parent issue (GitHub):' "$manifest" 2>/dev/null | sed -E 's/^Parent issue \(GitHub\): *#?([0-9]+).*/\1/' | tr -d '\r')"
  case "$n" in '' | *[!0-9]*) n="" ;; esac

  # (b) an OPEN md-epic-labeled issue carrying the exact title
  if [ -z "$n" ]; then
    rows="$(t="$title" gh issue list --label "md-epic" --state open --json number,title \
      --jq '.[] | select(.title==env.t) | .number' </dev/null 2>/dev/null)" \
      || { say_err "could not search for an existing md-epic parent issue by title"; return 3; }
    n="$(printf '%s\n' "$rows" | head -1 | tr -d '\r')"
    case "$n" in '' | *[!0-9]*) n="" ;; esac
  fi

  # (c) no match: create it
  if [ -z "$n" ]; then
    url="$(gh issue create --title "$title" --body-file "$bodyfile" --label "md-epic" </dev/null 2>/dev/null)" \
      || { say_err "could not create the md-epic parent issue: $title"; return 3; }
    n="$(printf '%s\n' "$url" | tail -1)"
    n="${n##*/}"
    case "$n" in '' | *[!0-9]*)
      say_err "gh issue create returned no issue number for the md-epic parent: $title"
      return 3
      ;;
    esac
    printf '%s\t%s\n' "$n" "created"
    return 0
  fi

  # adopted: the row first, then the REPLACE-form body write
  printf '%s\t%s\n' "$n" "adopted"
  gh issue edit "$n" --body-file "$bodyfile" </dev/null >/dev/null 2>&1 \
    || { say_err "could not replace the md-epic parent issue's body on #$n"; return 3; }
  return 0
}

# The manifest receipt back-write. Uses awk (portable across BSD/macOS and GNU
# sed/awk); avoids GNU-sed-only `a`, which exits 1 on BSD/macOS sed.
#
# Every branch strips a trailing CR from EVERY line it prints, not only from the
# receipt line it writes, so a manifest that arrived with CRLF endings leaves
# here fully LF, which is what the twins' recorded contract promises and what
# the PowerShell twin already does (it splits on either ending and rejoins with
# LF). Without the strip the two twins would converge on different bytes for the
# same CRLF input.
cmd_write_receipt() {
  local manifest="$1" n="$2" notice tmp
  case "$n" in '' | *[!0-9]*) usage; return 2 ;; esac
  notice="create: deployed the md-epic parent #$n but could not write the receipt to $manifest; re-run to record it"
  if [ ! -f "$manifest" ]; then
    echo "$notice"
    return 0
  fi
  tmp="$(mktemp)" || { echo "$notice"; return 0; }
  if grep -q '^Parent issue (GitHub):' "$manifest"; then
    # present: rewrite the FIRST receipt line in place (exactly one line; never a duplicate)
    awk -v n="$n" '{ sub(/\r$/, "") } !done && /^Parent issue \(GitHub\):/ { print "Parent issue (GitHub): #" n; done=1; next } { print }' "$manifest" > "$tmp" \
      && mv "$tmp" "$manifest" || echo "$notice"
  elif grep -q '^Parent intro:' "$manifest"; then
    awk -v n="$n" '{ sub(/\r$/, ""); print } !done && /^Parent intro:/ { print "Parent issue (GitHub): #" n; done=1 }' "$manifest" > "$tmp" \
      && mv "$tmp" "$manifest" || echo "$notice"
  elif grep -q '^Build order:' "$manifest"; then
    awk -v n="$n" '{ sub(/\r$/, ""); print } !done && /^Build order:/ { print "Parent issue (GitHub): #" n; done=1 }' "$manifest" > "$tmp" \
      && mv "$tmp" "$manifest" || echo "$notice"
  else
    # neither anchor (malformed/hand-edited manifest): degrade VISIBLY by
    # appending at EOF (the present branch finds it on the next run)
    awk -v n="$n" '{ sub(/\r$/, ""); print } END { print "Parent issue (GitHub): #" n }' "$manifest" > "$tmp" \
      && mv "$tmp" "$manifest" || echo "$notice"
  fi
  rm -f "$tmp" 2>/dev/null
  return 0
}

# --- the sub-issue-linking pass ----------------------------------------------

cmd_link_sub_issues() {
  local manifest="$1" parent="$2" entries ecount raw c linked total errfile
  local pos planfile number title desc children refused child_id link_err reassert_err msg
  [ $# -ge 3 ] || { usage; return 2; }
  [ -n "$manifest" ] || { usage; return 2; }
  case "$parent" in '' | *[!0-9]*) usage; return 2 ;; esac
  shift 2
  require_file "$manifest" || return 2
  require_gh || return 3

  entries="$(manifest_entries "$manifest")"
  ecount="$(printf '%s' "$entries" | grep -c . 2>/dev/null)"
  if [ "$ecount" -ne $# ]; then
    say_err "one number per manifest entry is required: the manifest lists $ecount, and $# were passed; pass gather-numbers' output, in build order"
    return 2
  fi

  # 1. the parent's already-linked sub-issues, once for the whole pass
  if ! raw="$(gh api "repos/{owner}/{repo}/issues/$parent/sub_issues?per_page=100" --paginate --jq '.[].number' </dev/null 2>&1)"; then
    printf 'skip-pass\t%s\n' "$(one_line "$raw")"
    return 0
  fi
  # `linked` is the membership set flattened to "|7|42|", so a lookup is one
  # substring test and no associative array is needed (bash 3.2, which macOS
  # still ships, has none).
  linked="|"
  total=0
  # One scratch file for the whole pass, not one per child: step 4c's id capture
  # parks stderr here so it can read stdout alone. A host with no usable mktemp
  # degrades to /dev/null, which costs the id-resolve row its message and
  # nothing else.
  errfile="$(mktemp 2>/dev/null)" || errfile="/dev/null"
  while IFS= read -r c; do
    c="$(printf '%s' "$c" | tr -d '\r')"
    case "$c" in '' | *[!0-9]*) continue ;; esac
    case "$linked" in *"|$c|"*) continue ;; esac
    linked="$linked$c|"
    total=$((total + 1))
  done <<EOF
$raw
EOF

  while IFS="$TAB" read -r pos planfile; do
    [ -n "$pos" ] || continue
    number="$1"
    shift
    title="$(read_title "$planfile")"

    # 2. this milestone's Wave-ordered surviving issues, from its LIVE description
    desc="$(gh api "repos/{owner}/{repo}/milestones/$number" --jq '.description' </dev/null 2>/dev/null)"
    children="$(printf '%s\n' "$desc" | grep -oE '#[0-9]+' | tr -d '#' | awk '!seen[$0]++')"
    [ -n "$children" ] || continue

    # 3. nested-epic refusal, before linking any of this milestone's issues.
    # Skipped entirely once the cap is full: there is no reason to spend a `gh`
    # call checking a label on an issue that will not be linked regardless.
    refused=""
    if [ "$total" -lt 100 ]; then
      while IFS= read -r c; do
        [ -n "$c" ] || continue
        if gh issue view "$c" --json labels --jq '.labels[].name' </dev/null 2>/dev/null | grep -qx 'md-epic'; then
          refused="$c"
          break
        fi
      done <<EOF
$children
EOF
    fi
    if [ -n "$refused" ]; then
      printf 'refused\t%s\t%s\t%s\n' "$number" "$title" "$refused"
      while IFS= read -r c; do
        [ -n "$c" ] && printf 'skipped\t%s\tnested-epic\n' "$c"
      done <<EOF
$children
EOF
      continue
    fi

    # 4. per child, in Wave order
    while IFS= read -r c; do
      [ -n "$c" ] || continue
      case "$linked" in *"|$c|"*)
        printf 'skipped\t%s\talready-linked\n' "$c"
        continue
        ;;
      esac
      if [ "$total" -ge 100 ]; then
        printf 'skipped\t%s\tcap\n' "$c"
        continue
      fi
      # `-F` sends sub_issue_id as an integer (gh CLI's typed-field flag: gh api
      # --help, "-F/--field has magic type conversion ... integer numbers get
      # converted to appropriate JSON types"). The sub_issues endpoint needs the
      # numeric database id, never the issue number (confirmed against
      # docs.github.com/en/rest/issues/sub-issues, and live by this pass's own
      # probe run).
      #
      # The id capture takes STDOUT ONLY, with stderr parked in $errfile and read
      # back only on a failure: a `gh` call that succeeds while also printing a
      # stderr notice would otherwise fold that notice into the id and POST
      # garbage. Same discipline the deploy checkpoint's live read already
      # follows (scripts/roadmap-deploy.sh, its `stdout only (2>/dev/null)`
      # note), and the reason this one keeps its message where the other two
      # calls below can merge streams safely: their stdout is not parsed.
      : > "$errfile" 2>/dev/null
      if ! child_id="$(gh api "repos/{owner}/{repo}/issues/$c" --jq '.id' </dev/null 2>"$errfile")"; then
        msg="$(cat "$errfile" 2>/dev/null)"
        # stderr is where `gh` reports; a failure that said nothing there falls
        # back to whatever it left on stdout, so the row is never blank when the
        # tool did explain itself.
        [ -n "$msg" ] || msg="$child_id"
        printf 'failed\t%s\tid-resolve\t%s\n' "$c" "$(one_line "$msg")"
        continue
      fi
      if ! link_err="$(gh api --method POST "repos/{owner}/{repo}/issues/$parent/sub_issues" -F sub_issue_id="$child_id" </dev/null 2>&1)"; then
        printf 'failed\t%s\tlink\t%s\n' "$c" "$(one_line "$link_err")"
        continue
      fi
      linked="$linked$c|"
      total=$((total + 1))
      if ! reassert_err="$(gh issue edit "$c" --milestone "$title" </dev/null 2>&1)"; then
        printf 'failed\t%s\treassert\t%s\n' "$c" "$(one_line "$reassert_err")"
      else
        printf 'linked\t%s\n' "$c"
      fi
    done <<EOF
$children
EOF
  done <<EOF
$entries
EOF

  [ "$errfile" = "/dev/null" ] || rm -f "$errfile" 2>/dev/null
  printf 'total\t%s\n' "$total"
  return 0
}

# --- dispatch ----------------------------------------------------------------

sub="${1:-}"
[ $# -gt 0 ] && shift

case "$sub" in
  gather-numbers)    cmd_gather_numbers "$@" ;;
  render-body)       cmd_render_body "$@" ;;
  resolve-or-create) cmd_resolve_or_create "$@" ;;
  write-receipt)     cmd_write_receipt "$@" ;;
  link-sub-issues)   cmd_link_sub_issues "$@" ;;
  *)                 usage; exit 2 ;;
esac

exit $?
