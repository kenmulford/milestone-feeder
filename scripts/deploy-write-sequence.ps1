#!/usr/bin/env pwsh
#
# deploy-write-sequence.ps1: create's Step 3 write-sequence, passes a to d
# (PowerShell 7+ twin of deploy-write-sequence.sh).
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
#   scripts/deploy-write-sequence.ps1 <subcommand> [args]
#   Positional `$args` rather than a `param()` block, deliberately: the two
#   twins take the SAME argv, so a call site documents one invocation.
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
#            3 when `gh` is unavailable or the adopt-path listing failed
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
#   DIGIT is left alone (a negative lookbehind here, a one-character look-back
#   in the bash twin's awk scan), which is the rule's "never a substring inside
#   a word" clause: `word#AB` and `docs.md#A` keep their text. On the RIGHT a
#   DIGIT is a boundary rather than part of the tag, because the recorded test
#   there is "not another tag-letter" and a digit is not one: `#AB2` rewrites to
#   `#<n>2`, on both twins. `#42` is untouched (no letter follows the `#`), an
#   unmapped tag is left exactly as written, and the lookup is CASE-SENSITIVE.
#
#   Line handling is the twins' shared contract: the rewritten text is emitted
#   as the input's lines, each terminated by a newline, so a text file with no
#   final newline gains one and an empty file stays empty. Both twins do this,
#   which is what keeps a body written on Windows and one written on macOS
#   byte-identical on GitHub.
#
# Parity with the bash twin (the emitted bytes are the contract):
#   Every data row is written through [Console]::Out with an explicit "`n", so
#   a map file this twin produces is LF-terminated on Windows too and the bash
#   twin's awk reads it unchanged. Lookups and title matching are ORDINAL and
#   CASE-SENSITIVE (a StringComparer.Ordinal hashtable, `-ceq`, and a
#   case-sensitive `switch`), matching jq's `==` and bash's `case`, the same
#   reason hooks/no-source-edit.ps1 reaches for -cnotcontains and -clike. A
#   PowerShell hashtable is case-INSENSITIVE by default, which would silently
#   map `#a` onto `#A` here and match nothing in the bash twin. Files are
#   written through UTF8Encoding($false): no BOM, LF endings. The console
#   encoding is forced to UTF-8 once at the top, in its own try/catch, so a
#   non-ASCII issue title survives a default Windows codepage.
#
# Working directory:
#   Every path an argument names is relative to the CURRENT working directory,
#   the consumer's repo root, where the calling skill already stands. This
#   script resolves nothing next to itself: unlike the notice emitter it reads
#   no bundled data file.
#
# Failure philosophy:
#   These are GitHub WRITES, not notices, so a failure is reported through the
#   exit status and one stderr line rather than swallowed (the one exception,
#   `write-receipt`, is documented above with its reason). Nothing here ever
#   deletes a milestone or an issue. The pass c and pass d loops decide for
#   themselves where a failure stops the walk and where it lets the remaining
#   items finish.
#
# Run it locally from a consumer repo root:
#   <plugin>/scripts/deploy-write-sequence.ps1 labels

try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {}

$script:SlugMap = $null

function Write-Err {
    param([string]$Message)
    [Console]::Error.WriteLine("deploy-write-sequence: $Message")
}

function Write-Row {
    param([string]$Text)
    [Console]::Out.Write($Text + "`n")
}

function Show-Usage {
    $lines = @(
        'usage: deploy-write-sequence.ps1 <subcommand> [args]',
        '  labels',
        '  find-milestone <title>',
        '  create-milestone <title> <description-file>',
        '  reopen-milestone <number>',
        '  write-receipt <plan-file> <number>',
        '  create-issues <job-file>',
        '  rewrite-slugs <map-file> <text-file>',
        '  apply-bodies <job-file> <map-file>',
        '  patch-description <number> <map-file> <description-file>'
    )
    foreach ($l in $lines) { [Console]::Error.WriteLine($l) }
}

function Test-Gh {
    if (Get-Command gh -ErrorAction SilentlyContinue) { return $true }
    Write-Err 'gh (GitHub CLI) is not on PATH; no GitHub call attempted'
    return $false
}

function Test-InputFile {
    param([string]$Path)
    if ($Path -and (Test-Path -LiteralPath $Path -PathType Leaf)) { return $true }
    Write-Err "file not found: $Path"
    return $false
}

# --- the slug map ------------------------------------------------------------
#
# A map carrying the pass-c abort marker is REFUSED here, which is what makes
# "a create failure aborts the rewrite" mechanical in this script rather than a
# rule the caller has to remember.
function Import-SlugMap {
    param([string]$Path)
    if (-not (Test-InputFile $Path)) { return 2 }
    $raw = [System.IO.File]::ReadAllText($Path)
    if ($raw -cmatch '(?m)^#INCOMPLETE') {
        Write-Err 'the slug map is INCOMPLETE (pass c aborted mid-loop); the slug rewrite is NOT run against a partial map'
        return 5
    }
    $map = [System.Collections.Hashtable]::new([System.StringComparer]::Ordinal)
    foreach ($line in ($raw -split "`n")) {
        $fields = ($line.TrimEnd("`r")) -split "`t"
        if ($fields.Count -lt 2) { continue }
        if ($fields[0] -cnotmatch '^#[A-Za-z]') { continue }
        if ($fields[1] -notmatch '^[0-9]+$') { continue }
        $map[$fields[0]] = $fields[1]
    }
    $script:SlugMap = $map
    return 0
}

function Convert-Slug {
    param([string]$Text)
    if ($null -eq $Text -or $Text -eq '') { return '' }
    $lines = $Text -split "`n"
    if ($lines[$lines.Count - 1] -eq '') {
        if ($lines.Count -le 1) { $lines = @() } else { $lines = $lines[0..($lines.Count - 2)] }
    }
    if ($lines.Count -eq 0) { return '' }
    $rewritten = foreach ($line in $lines) {
        [regex]::Replace($line, '(?<![A-Za-z0-9])#[A-Za-z]+', {
                param($m)
                if ($script:SlugMap.ContainsKey($m.Value)) { '#' + $script:SlugMap[$m.Value] } else { $m.Value }
            })
    }
    return (($rewritten -join "`n") + "`n")
}

function Convert-SlugFile {
    param([string]$Path)
    return (Convert-Slug ([System.IO.File]::ReadAllText($Path)))
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

# Trailing newlines are stripped from a value sent as a `-f` field, matching the
# bash twin, where `$(cat file)` strips them.
function Get-FieldValue {
    param([string]$Path)
    $raw = [System.IO.File]::ReadAllText($Path)
    return ($raw -replace "(`r?`n)+$", '')
}

# --- pass a ------------------------------------------------------------------

function Invoke-Labels {
    if (-not (Test-Gh)) { return 3 }
    # The same four canonical labels, in the same order, as the bash twin: the
    # taxonomy `setup` provisions. The two lists move together or not at all.
    $four = @(
        @('ui', '5319E7', 'UI-surface issue (design review applies)'),
        @('logic', '0E8A16', 'Logic / non-UI issue'),
        @('risk:light', 'C2E0C6', 'Reduced-ceremony build profile (driver override)'),
        @('risk:heavy', 'B60205', 'Full-ceremony build profile (driver override)')
    )
    foreach ($label in $four) {
        gh label create $label[0] --color $label[1] --description $label[2] --force *> $null
        if ($LASTEXITCODE -ne 0) {
            Write-Err "could not upsert the label: $($label[0])"
            return 3
        }
    }
    return 0
}

# --- pass b ------------------------------------------------------------------

function Invoke-FindMilestone {
    param([string]$Title)
    if (-not $Title) { Show-Usage; return 2 }
    if (-not (Test-Gh)) { return 3 }
    $rows = $null
    $code = 0
    $env:t = $Title
    try {
        $rows = gh api 'repos/{owner}/{repo}/milestones?state=all&per_page=100' --paginate --jq '.[] | select(.title==env.t) | [(.number|tostring), .state] | @tsv' 2>$null
        $code = $LASTEXITCODE
    } finally {
        Remove-Item Env:\t -ErrorAction SilentlyContinue
    }
    if ($code -ne 0) {
        Write-Err 'could not read the repository''s milestones'
        return 3
    }
    foreach ($row in @($rows)) {
        $text = ([string]$row).TrimEnd("`r")
        if ($text -ne '') { Write-Row $text }
    }
    return 0
}

function Invoke-CreateMilestone {
    param([string]$Title, [string]$DescFile)
    if (-not $Title -or -not $DescFile) { Show-Usage; return 2 }
    if (-not (Test-InputFile $DescFile)) { return 2 }
    if (-not (Test-Gh)) { return 3 }
    $desc = Get-FieldValue $DescFile
    $number = gh api --method POST 'repos/{owner}/{repo}/milestones' -f "title=$Title" -f "description=$desc" --jq '.number' 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "could not create the milestone: $Title"
        return 3
    }
    $number = ([string]($number | Select-Object -Last 1)).Trim()
    if ($number -notmatch '^[0-9]+$') {
        Write-Err "the milestone POST returned no number: $Title"
        return 3
    }
    Write-Row $number
    return 0
}

function Invoke-ReopenMilestone {
    param([string]$Number)
    if ($Number -notmatch '^[0-9]+$') { Show-Usage; return 2 }
    if (-not (Test-Gh)) { return 3 }
    gh api --method PATCH "repos/{owner}/{repo}/milestones/$Number" -f state=open *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "could not reopen the milestone: #$Number"
        return 3
    }
    return 0
}

# The receipt back-write, in the recorded idempotent rewrite-or-insert form.
#
# FIRST-match only in both branches, matching the bash twin's awk `!done`
# guards: a plan file that somehow carries two receipt lines has its FIRST
# rewritten and the rest left alone, and a plan file with two `Source brief:`
# lines gets exactly ONE inserted line. A whole-array `-replace` and an
# unguarded ForEach-Object would each act on EVERY match, so a degenerate plan
# file would converge differently on the two twins.
#
# Records are split off the RAW text (LF or CRLF) and rejoined with LF, so the
# file this writes is LF-terminated on every platform, which is what the bash
# twin's awk emits and what `plan` writes in the first place. Set-Content is
# deliberately NOT used: it joins with [Environment]::NewLine, so on Windows it
# would rewrite the whole plan file to CRLF as a side effect of one receipt.
function Invoke-WriteReceipt {
    param([string]$Plan, [string]$Number)
    if ($Number -notmatch '^[0-9]+$') { Show-Usage; return 2 }
    $notice = "create: deployed milestone #$Number but could not write the receipt to $Plan; re-run to record it"
    $receipt = "Milestone number (GitHub): $Number"
    try {
        $raw = [System.IO.File]::ReadAllText($Plan)
        $lines = @()
        if ($raw -ne '') {
            $split = @($raw -split "`r`n|`n")
            # Drop the empty record the final newline produces, so a rejoin does
            # not grow the file by one blank line per run.
            if ($split[$split.Count - 1] -eq '') {
                if ($split.Count -le 1) { $split = @() } else { $split = @($split[0..($split.Count - 2)]) }
            }
            $lines = $split
        }

        $out = @()
        $done = $false
        if (@($lines) -cmatch '^Milestone number \(GitHub\):') {
            # present: rewrite the FIRST receipt line in place (exactly one line; never a duplicate)
            foreach ($line in $lines) {
                if (-not $done -and $line -cmatch '^Milestone number \(GitHub\):') {
                    $out += $receipt
                    $done = $true
                } else {
                    $out += $line
                }
            }
        } elseif (@($lines) -cmatch '^Source brief:') {
            # absent, anchor present: insert exactly once after the Source brief header line
            foreach ($line in $lines) {
                $out += $line
                if (-not $done -and $line -cmatch '^Source brief:') {
                    $out += $receipt
                    $done = $true
                }
            }
        } else {
            # absent AND no anchor (malformed/hand-edited plan): degrade VISIBLY by
            # appending at EOF (still exactly one line; the present branch finds it next run)
            $out = @($lines) + $receipt
        }
        Write-Utf8NoBom $Plan (($out -join "`n") + "`n")
    } catch {
        Write-Row $notice
    }
    return 0
}

# --- pass c ------------------------------------------------------------------

function Invoke-CreateIssues {
    param([string]$JobFile)
    if (-not $JobFile) { Show-Usage; return 2 }
    if (-not (Test-InputFile $JobFile)) { return 2 }

    try {
        $job = [System.IO.File]::ReadAllText($JobFile) | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Err "the job file is not readable JSON: $JobFile"
        return 2
    }

    $mtitle = [string]$job.milestoneTitle
    if (-not $mtitle) {
        Write-Err "the job file records no milestoneTitle: $JobFile"
        return 2
    }
    # Zero surviving issues: create nothing, list nothing, print no map row.
    # Pass d then finds no slug occurrence to rewrite. Parked and dropped
    # issues never reach this script at all. A MISSING or null `issues` is that
    # same case, tested BEFORE the @() wrap: @($null) is a one-element array
    # holding $null, which would otherwise walk one phantom entry and abort the
    # pass, where the bash twin's `(.issues // []) | length` exits 0 in silence.
    if ($null -eq $job.issues) { return 0 }
    $issues = @($job.issues)
    if ($issues.Count -eq 0) { return 0 }

    if (-not (Test-Gh)) { return 3 }

    $adoptList = @()
    if ($job.adopt -eq $true) {
        $listed = gh issue list --milestone $mtitle --state open --json number,title 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Err 'could not list the milestone''s open issues; nothing was created'
            return 3
        }
        try {
            $adoptList = @(($listed | Out-String) | ConvertFrom-Json)
        } catch {
            $adoptList = @()
        }
    }

    # The index is carried because the bash twin names it in the malformed-entry
    # message ("issue entry $i"), and the two stderr lines are pinned identical.
    $index = 0
    foreach ($issue in $issues) {
        $slug = [string]$issue.slug
        $title = [string]$issue.title
        $bodyFile = [string]$issue.bodyFile
        $labels = @(@($issue.labels) | Where-Object { $_ -is [string] -and $_ -ne '' })

        if (-not $slug -or -not $title) {
            $shown = if ($slug) { $slug } else { '<no slug>' }
            Write-Row "#INCOMPLETE`t$shown"
            Write-Err "issue entry $index records no slug or no title; nothing further was created"
            return 4
        }

        $number = ''
        $action = ''
        $match = $adoptList | Where-Object { ([string]$_.title) -ceq $title } | Select-Object -First 1
        if ($match) {
            $number = [string]$match.number
            $action = 'reused'
        } else {
            if (-not ($bodyFile -and (Test-Path -LiteralPath $bodyFile -PathType Leaf))) {
                Write-Row "#INCOMPLETE`t$slug"
                Write-Err "the body file for $slug is missing: $(if ($bodyFile) { $bodyFile } else { '<none>' }); nothing further was created"
                return 4
            }
            $labelArgs = @()
            foreach ($label in $labels) { $labelArgs += '--label'; $labelArgs += $label }
            $url = gh issue create --title $title --body-file $bodyFile --milestone $mtitle @labelArgs 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Row "#INCOMPLETE`t$slug"
                Write-Err "gh issue create failed for $slug ""$title""; the issues above were created, the rest were not"
                return 4
            }
            $number = ([string](@($url) | Select-Object -Last 1)).Trim() -replace '.*/', ''
            if ($number -notmatch '^[0-9]+$') {
                Write-Row "#INCOMPLETE`t$slug"
                Write-Err "gh issue create returned no issue number for $slug ""$title"""
                return 4
            }
            $action = 'created'
        }

        Write-Row "$slug`t$number`t$action"
        $index++
    }
    return 0
}

# --- pass d ------------------------------------------------------------------

function Invoke-RewriteSlugs {
    param([string]$MapFile, [string]$TextFile)
    if (-not $MapFile -or -not $TextFile) { Show-Usage; return 2 }
    if (-not (Test-InputFile $TextFile)) { return 2 }
    $code = Import-SlugMap $MapFile
    if ($code -ne 0) { return $code }
    [Console]::Out.Write((Convert-SlugFile $TextFile))
    return 0
}

function Invoke-ApplyBodies {
    param([string]$JobFile, [string]$MapFile)
    if (-not $JobFile -or -not $MapFile) { Show-Usage; return 2 }
    if (-not (Test-InputFile $JobFile)) { return 2 }
    if (-not (Test-Gh)) { return 3 }
    $code = Import-SlugMap $MapFile
    if ($code -ne 0) { return $code }

    try {
        $job = [System.IO.File]::ReadAllText($JobFile) | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Err "the job file is not readable JSON: $JobFile"
        return 2
    }

    $status = 0
    foreach ($line in ([System.IO.File]::ReadAllText($MapFile) -split "`n")) {
        $fields = ($line.TrimEnd("`r")) -split "`t"
        if ($fields.Count -lt 3) { continue }
        $slug = $fields[0]
        $number = $fields[1]
        # Adopted issues are NOT body-rewritten: their bodies are preserved as-is.
        if ($fields[2] -cne 'created') { continue }
        # An entry with no `bodyFile` leaves the pipeline empty, and a [string]
        # cast of an EMPTY PIPELINE is $null rather than '', which Test-Path
        # rejects at parameter binding instead of answering false. Normalize
        # first, then guard the empty string the way Test-InputFile does, so
        # this path reports the same one line the bash twin does.
        $bodyFile = @($job.issues) | Where-Object { ([string]$_.slug) -ceq $slug } | Select-Object -First 1 -ExpandProperty bodyFile -ErrorAction SilentlyContinue
        $bodyFile = if ($null -eq $bodyFile) { '' } else { [string]$bodyFile }
        if (-not ($bodyFile -and (Test-Path -LiteralPath $bodyFile -PathType Leaf))) {
            Write-Err "the body file for $slug is missing: $(if ($bodyFile) { $bodyFile } else { '<none>' }); #$number still carries its local slugs"
            $status = 3
            continue
        }
        $original = [System.IO.File]::ReadAllText($bodyFile)
        $rewritten = Convert-Slug $original
        if ($rewritten -ceq $original) {
            # A created issue whose full body carries no slug reference needs no edit.
            Write-Row "$slug`t$number`tunchanged"
            continue
        }
        $tmp = [System.IO.Path]::GetTempFileName()
        try {
            Write-Utf8NoBom $tmp $rewritten
            gh issue edit $number --body-file $tmp *> $null
            if ($LASTEXITCODE -eq 0) {
                Write-Row "$slug`t$number`tedited"
            } else {
                Write-Err "gh issue edit failed for $slug (#$number); that issue still carries its local slugs"
                $status = 3
            }
        } finally {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
    }
    return $status
}

function Invoke-PatchDescription {
    param([string]$Number, [string]$MapFile, [string]$DescFile)
    if ($Number -notmatch '^[0-9]+$') { Show-Usage; return 2 }
    if (-not $MapFile -or -not $DescFile) { Show-Usage; return 2 }
    if (-not (Test-InputFile $DescFile)) { return 2 }
    if (-not (Test-Gh)) { return 3 }
    $code = Import-SlugMap $MapFile
    if ($code -ne 0) { return $code }
    $desc = (Convert-SlugFile $DescFile) -replace "(`r?`n)+$", ''
    gh api --method PATCH "repos/{owner}/{repo}/milestones/$Number" -f "description=$desc" *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "could not PATCH the description onto milestone #$Number"
        return 3
    }
    return 0
}

# --- dispatch ----------------------------------------------------------------
#
# Case-SENSITIVE, matching the bash twin's `case`. Every handler returns its
# exit code as its only output value; `Select-Object -Last 1` keeps a stray
# emitted object from ever turning that code into an array.

# Each argument is read out of $args by INDEX. Slicing into a `$rest` array
# would not survive the assignment: PowerShell unrolls a one-element array back
# to a scalar, and the next index would then read the first CHARACTER of it.
$argv = @($args)
$sub = if ($argv.Count -ge 1) { [string]$argv[0] } else { '' }
$a0 = if ($argv.Count -ge 2) { [string]$argv[1] } else { '' }
$a1 = if ($argv.Count -ge 3) { [string]$argv[2] } else { '' }
$a2 = if ($argv.Count -ge 4) { [string]$argv[3] } else { '' }

switch -CaseSensitive ($sub) {
    'labels' { $result = Invoke-Labels }
    'find-milestone' { $result = Invoke-FindMilestone $a0 }
    'create-milestone' { $result = Invoke-CreateMilestone $a0 $a1 }
    'reopen-milestone' { $result = Invoke-ReopenMilestone $a0 }
    'write-receipt' { $result = Invoke-WriteReceipt $a0 $a1 }
    'create-issues' { $result = Invoke-CreateIssues $a0 }
    'rewrite-slugs' { $result = Invoke-RewriteSlugs $a0 $a1 }
    'apply-bodies' { $result = Invoke-ApplyBodies $a0 $a1 }
    'patch-description' { $result = Invoke-PatchDescription $a0 $a1 $a2 }
    default { Show-Usage; $result = 2 }
}

exit ([int](@($result) | Select-Object -Last 1))
