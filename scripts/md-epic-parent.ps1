#!/usr/bin/env pwsh
#
# md-epic-parent.ps1: create's Step 1R md-epic parent-issue pass and its
# sub-issue-linking pass (PowerShell 7+ twin of md-epic-parent.sh).
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
#   scripts/md-epic-parent.ps1 <subcommand> [args]
#   Positional `$args` rather than a `param()` block, deliberately: the two
#   twins take the SAME argv, so a call site documents one invocation.
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
#            through the SIBLING twin, `deploy-write-sequence.ps1
#            find-milestone <title>` (`Invoke-FindMilestone`), taking the FIRST
#            row's number field. That primitive owns the quote-safe `env.t`
#            milestones query; this script never re-derives it.
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
#     note   The fence lines are built here, from SINGLE-quoted strings,
#            because a run of three backticks is hazardous inside a
#            double-quoted string in BOTH shells: PowerShell reads a backtick
#            as its escape character, so backtick-backtick collapses to one
#            literal backtick and the third, followed by a non-escape letter,
#            is dropped (Microsoft Learn `about_Quoting_Rules`), and bash reads
#            backticks as old-style command substitution (so an intro-adjacent
#            fence could RUN text). A backtick inside a single-quoted string is
#            literal in both, which is why the assembly lives in a script
#            rather than in an inline shell string.
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
# Parity with the bash twin (the emitted bytes are the contract):
#   Every row is written through [Console]::Out with an explicit "`n", so the
#   rows this twin prints are LF-terminated on Windows too and a caller's own
#   parsing reads them unchanged. Label matching and row-kind dispatch are
#   ORDINAL and CASE-SENSITIVE (`-ccontains`, `-cmatch`, and a case-sensitive
#   `switch`), matching the bash twin's `grep -qx` and `case`, the same reason
#   hooks/no-source-edit.ps1 reaches for -cnotcontains and -clike. Files are
#   written through UTF8Encoding($false): no BOM, LF endings, and Set-Content
#   is deliberately NOT used for the manifest, because it joins with
#   [Environment]::NewLine and would rewrite the whole manifest to CRLF on
#   Windows as a side effect of one receipt line. The console encoding is
#   forced to UTF-8 once at the top, in its own try/catch, so a non-ASCII
#   milestone title survives a default Windows codepage.
#
# Working directory:
#   Every path an argument names is relative to the CURRENT working directory,
#   the consumer's repo root, where the calling skill already stands. The one
#   path resolved next to this script is its SIBLING twin,
#   deploy-write-sequence.ps1, whose `find-milestone` primitive owns the
#   exact-title milestone query (the same $PSScriptRoot resolve
#   emit-notice.ps1 uses for its data file). It runs as a CHILD pwsh process
#   rather than through the call operator: that twin writes its rows through
#   [Console]::Out, which an in-process call would send straight to the console
#   instead of into a variable this script can read.
#
# Why no jq:
#   Every JSON read here goes through `gh --jq`, `gh`'s own embedded filter, so
#   this script adds no standalone-jq dependency (the bash twin uses the same
#   `gh --jq` forms for the same reason).
#
# Failure philosophy:
#   The two passes differ deliberately, and this script preserves the
#   difference. The parent-issue pass makes LOAD-BEARING writes: a failure is
#   reported through the exit status and one stderr line (the one exception,
#   `write-receipt`, is documented above with its reason). The
#   sub-issue-linking pass is fail-open throughout: its failures are ROWS, and
#   its exit status stays 0, because by then the deploy it follows has already
#   succeeded. Nothing here ever deletes or closes an issue, and nothing ever
#   unlinks one.
#
# Run it locally from a consumer repo root:
#   <plugin>/scripts/md-epic-parent.ps1 gather-numbers .milestone-feeder/roadmap-<slug>.md

try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {}

# Set by Get-MilestoneNumber when the exact-title LOOKUP itself could not run,
# which is a different outcome from "this milestone has no number": the caller
# reports it as a `gh`/sibling failure, not as an unresolved milestone.
$script:LookupFailed = $false

function Write-Err {
    param([string]$Message)
    [Console]::Error.WriteLine("md-epic-parent: $Message")
}

function Write-Row {
    param([string]$Text)
    [Console]::Out.Write($Text + "`n")
}

function Show-Usage {
    $lines = @(
        'usage: md-epic-parent.ps1 <subcommand> [args]',
        '  gather-numbers <manifest>',
        '  render-body <intro> <number> [<number> ...]',
        '  resolve-or-create <manifest> <parent-title> <body-file>',
        '  write-receipt <manifest> <number>',
        '  link-sub-issues <manifest> <parent> <number> [<number> ...]'
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

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, [System.Text.UTF8Encoding]::new($false))
}

# Flattens a captured error to ONE line, so a multi-line `gh` message can never
# split a TAB row in two.
function ConvertTo-OneLine {
    param($Value)
    $text = (@($Value) | ForEach-Object { [string]$_ }) -join ' '
    return ($text -replace "[`r`n`t]", ' ')
}

# The first (or last) captured line, normalized. A [string] cast of an EMPTY
# PIPELINE is $null rather than '', which would throw on the next method call,
# so the null is answered here once for every capture site.
function Get-FirstLine {
    param($Value)
    $v = @($Value) | Select-Object -First 1
    if ($null -eq $v) { return '' }
    return ([string]$v).TrimEnd("`r").Trim()
}

function Get-LastLine {
    param($Value)
    $v = @($Value) | Select-Object -Last 1
    if ($null -eq $v) { return '' }
    return ([string]$v).TrimEnd("`r").Trim()
}

function Get-FileLines {
    param([string]$Path)
    $raw = [System.IO.File]::ReadAllText($Path)
    if ($raw -eq '') { return @() }
    $split = @($raw -split "`r`n|`n")
    if ($split[$split.Count - 1] -eq '') {
        if ($split.Count -le 1) { return @() }
        return @($split[0..($split.Count - 2)])
    }
    return $split
}

# --- the manifest walk -------------------------------------------------------
#
# Returns one object per milestone entry, in file order (build order), each
# carrying its Position and its PlanFile. An entry with no `Plan file:` line
# still returns a row, with an empty PlanFile, so a pending entry surfaces as an
# unresolved milestone rather than silently vanishing from the walk.
function Get-ManifestEntries {
    param([string]$Path)
    $out = @()
    $inMiles = $false
    $pos = ''
    $pf = ''
    foreach ($line in (Get-FileLines $Path)) {
        if ($line -cmatch '^## Milestones \(in build order\)') { $inMiles = $true; continue }
        if (-not $inMiles) { continue }
        if ($line -cmatch '^## ') {
            if ($pos -ne '') { $out += [pscustomobject]@{ Position = $pos; PlanFile = $pf }; $pos = '' }
            $inMiles = $false
            continue
        }
        if ($line -cmatch '^### ([0-9]+)\.') {
            if ($pos -ne '') { $out += [pscustomobject]@{ Position = $pos; PlanFile = $pf } }
            $pos = $Matches[1]
            $pf = ''
            continue
        }
        if ($pos -ne '' -and $pf -eq '' -and $line -cmatch '^- Plan file: *(.*)$') { $pf = $Matches[1] }
    }
    if ($pos -ne '') { $out += [pscustomobject]@{ Position = $pos; PlanFile = $pf } }
    return @($out)
}

# The FIRST line carrying the named prefix, whether or not it then matches the
# value pattern, mirroring the bash twin's `grep -m1` plus `sed`: a malformed
# first line resolves to empty rather than skipping ahead to a later well-formed
# one, so both twins fall through to the same fallback branch.
function Get-FirstFieldValue {
    param([string]$Path, [string]$Prefix, [string]$Pattern)
    if (-not ($Path -and (Test-Path -LiteralPath $Path -PathType Leaf))) { return '' }
    foreach ($line in (Get-FileLines $Path)) {
        if ($line -cmatch $Prefix) {
            if ($line -cmatch $Pattern) { return $Matches[1] }
            return ''
        }
    }
    return ''
}

function Get-MilestoneTitle {
    param([string]$PlanFile)
    return (Get-FirstFieldValue $PlanFile '^Milestone title \(exact\):' '^Milestone title \(exact\): *(.+)$')
}

# The two-tier number read: this milestone's own receipt, else the sibling
# twin's exact-title lookup. Returns the number, or '' when neither resolved.
# Sets $script:LookupFailed when the lookup itself could not run.
function Get-MilestoneNumber {
    param([string]$PlanFile)
    if (-not ($PlanFile -and (Test-Path -LiteralPath $PlanFile -PathType Leaf))) { return '' }
    $n = Get-FirstFieldValue $PlanFile '^Milestone number \(GitHub\):' '^Milestone number \(GitHub\): *([0-9]+)'
    if ($n -match '^[0-9]+$') { return $n }
    $title = Get-MilestoneTitle $PlanFile
    if (-not $title) { return '' }
    $sibling = Join-Path $PSScriptRoot 'deploy-write-sequence.ps1'
    if (-not (Test-Path -LiteralPath $sibling -PathType Leaf)) {
        Write-Err "the sibling twin is missing: $sibling; the exact-title fallback cannot run"
        $script:LookupFailed = $true
        return ''
    }
    # A CHILD pwsh process, not the call operator: the sibling twin writes its
    # rows through [Console]::Out (its own parity contract), which an in-process
    # call sends straight to the console instead of into a capturable variable.
    # A child process makes those rows this script's to read, and mirrors what
    # the bash twin does when it runs its own sibling.
    $pwshExe = if ($IsWindows) { Join-Path $PSHOME 'pwsh.exe' } else { Join-Path $PSHOME 'pwsh' }
    $rows = & $pwshExe -NoProfile -File $sibling find-milestone $title 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "the exact-title milestone lookup failed for: $title (via deploy-write-sequence.ps1 find-milestone)"
        $script:LookupFailed = $true
        return ''
    }
    $n = ((Get-FirstLine $rows) -split "`t")[0]
    if ($n -match '^[0-9]+$') { return $n }
    return ''
}

# --- the md-epic parent-issue pass -------------------------------------------

function Invoke-GatherNumbers {
    param([string]$Manifest)
    if (-not $Manifest) { Show-Usage; return 2 }
    if (-not (Test-InputFile $Manifest)) { return 2 }
    $entries = @(Get-ManifestEntries $Manifest)
    if ($entries.Count -eq 0) {
        Write-Err "the manifest lists no milestone entries: $Manifest"
        return 2
    }
    $numbers = @()
    foreach ($entry in $entries) {
        $script:LookupFailed = $false
        $n = Get-MilestoneNumber $entry.PlanFile
        if ($script:LookupFailed) { return 3 }
        if (-not $n) {
            $shown = if ($entry.PlanFile) { $entry.PlanFile } else { '<none>' }
            Write-Err "could not resolve a milestone number for build-order position $($entry.Position) (plan file: $shown); the parent issue was not touched"
            return 4
        }
        $numbers += $n
    }
    # Printed only once every milestone resolved, so a partial list can never
    # be rendered into a parent body.
    foreach ($n in $numbers) { Write-Row $n }
    return 0
}

function Invoke-RenderBody {
    param([string]$Intro, [string[]]$Numbers)
    if (-not $Intro) { Show-Usage; return 2 }
    # An empty variadic tail binds as $null, not as an empty array, and
    # @($null) counts ONE: test for the null explicitly or a numberless call
    # renders an empty block instead of failing the way the bash twin does.
    if ($null -eq $Numbers -or @($Numbers).Count -eq 0) { Show-Usage; return 2 }
    foreach ($n in $Numbers) {
        if ($n -notmatch '^[0-9]+$') {
            Write-Err "not a milestone number: $n"
            return 2
        }
    }
    # Single-quoted fence strings: a backtick is literal in both shells there.
    $lines = @($Intro, '', '```md-epic-order')
    foreach ($n in $Numbers) { $lines += "number: $n" }
    $lines += '```'
    [Console]::Out.Write((($lines -join "`n") + "`n"))
    return 0
}

function Invoke-ResolveOrCreate {
    param([string]$Manifest, [string]$Title, [string]$BodyFile)
    if (-not $Manifest -or -not $Title -or -not $BodyFile) { Show-Usage; return 2 }
    if (-not (Test-InputFile $Manifest)) { return 2 }
    if (-not (Test-InputFile $BodyFile)) { return 2 }
    if (-not (Test-Gh)) { return 3 }

    # (a) the manifest's own receipt
    $n = Get-FirstFieldValue $Manifest '^Parent issue \(GitHub\):' '^Parent issue \(GitHub\): *#?([0-9]+)'
    if ($n -notmatch '^[0-9]+$') { $n = '' }

    # (b) an OPEN md-epic-labeled issue carrying the exact title
    if (-not $n) {
        $rows = $null
        $code = 0
        $env:t = $Title
        try {
            $rows = gh issue list --label "md-epic" --state open --json number,title --jq '.[] | select(.title==env.t) | .number' 2>$null
            $code = $LASTEXITCODE
        } finally {
            Remove-Item Env:\t -ErrorAction SilentlyContinue
        }
        if ($code -ne 0) {
            Write-Err 'could not search for an existing md-epic parent issue by title'
            return 3
        }
        $n = Get-FirstLine $rows
        if ($n -notmatch '^[0-9]+$') { $n = '' }
    }

    # (c) no match: create it
    if (-not $n) {
        $url = gh issue create --title $Title --body-file $BodyFile --label "md-epic" 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Err "could not create the md-epic parent issue: $Title"
            return 3
        }
        $n = (Get-LastLine $url) -replace '.*/', ''
        if ($n -notmatch '^[0-9]+$') {
            Write-Err "gh issue create returned no issue number for the md-epic parent: $Title"
            return 3
        }
        Write-Row "$n`tcreated"
        return 0
    }

    # adopted: the row first, then the REPLACE-form body write
    Write-Row "$n`tadopted"
    gh issue edit $n --body-file $BodyFile *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Err "could not replace the md-epic parent issue's body on #$n"
        return 3
    }
    return 0
}

# The manifest receipt back-write, in the recorded idempotent four-branch form.
#
# FIRST-match only in every branch, matching the bash twin's awk `!done` guards:
# a manifest that somehow carries two receipt lines has its FIRST rewritten and
# the rest left alone, and one with two anchors gets exactly ONE inserted line.
# A whole-array `-replace` and an unguarded ForEach-Object would each act on
# EVERY match, so a degenerate manifest would converge differently on the two
# twins.
function Invoke-WriteReceipt {
    param([string]$Manifest, [string]$Number)
    if ($Number -notmatch '^[0-9]+$') { Show-Usage; return 2 }
    $notice = "create: deployed the md-epic parent #$Number but could not write the receipt to $Manifest; re-run to record it"
    $receipt = "Parent issue (GitHub): #$Number"
    try {
        $lines = Get-FileLines $Manifest
        $out = @()
        $done = $false
        if (@($lines) -cmatch '^Parent issue \(GitHub\):') {
            foreach ($line in $lines) {
                if (-not $done -and $line -cmatch '^Parent issue \(GitHub\):') {
                    $out += $receipt
                    $done = $true
                } else {
                    $out += $line
                }
            }
        } elseif (@($lines) -cmatch '^Parent intro:') {
            foreach ($line in $lines) {
                $out += $line
                if (-not $done -and $line -cmatch '^Parent intro:') {
                    $out += $receipt
                    $done = $true
                }
            }
        } elseif (@($lines) -cmatch '^Build order:') {
            foreach ($line in $lines) {
                $out += $line
                if (-not $done -and $line -cmatch '^Build order:') {
                    $out += $receipt
                    $done = $true
                }
            }
        } else {
            # neither anchor (malformed/hand-edited manifest): degrade VISIBLY by
            # appending at EOF (the present branch finds it on the next run)
            $out = @($lines) + $receipt
        }
        Write-Utf8NoBom $Manifest (($out -join "`n") + "`n")
    } catch {
        Write-Row $notice
    }
    return 0
}

# --- the sub-issue-linking pass ----------------------------------------------

function Invoke-LinkSubIssues {
    param([string]$Manifest, [string]$Parent, [string[]]$Numbers)
    if (-not $Manifest) { Show-Usage; return 2 }
    if ($Parent -notmatch '^[0-9]+$') { Show-Usage; return 2 }
    if ($null -eq $Numbers -or @($Numbers).Count -eq 0) { Show-Usage; return 2 }
    if (-not (Test-InputFile $Manifest)) { return 2 }
    if (-not (Test-Gh)) { return 3 }

    $entries = @(Get-ManifestEntries $Manifest)
    if ($entries.Count -ne @($Numbers).Count) {
        Write-Err "one number per manifest entry is required: the manifest lists $($entries.Count), and $(@($Numbers).Count) were passed; pass gather-numbers' output, in build order"
        return 2
    }

    # 1. the parent's already-linked sub-issues, once for the whole pass
    $raw = gh api "repos/{owner}/{repo}/issues/$Parent/sub_issues?per_page=100" --paginate --jq '.[].number' 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Row "skip-pass`t$(ConvertTo-OneLine $raw)"
        return 0
    }
    # An Ordinal hashtable, matching the bash twin's substring membership test:
    # a PowerShell hashtable is case-INSENSITIVE by default, which is the wrong
    # comparer for a key set the two twins have to agree on.
    $linked = [System.Collections.Hashtable]::new([System.StringComparer]::Ordinal)
    $total = 0
    # One scratch file for the whole pass, not one per child: step 4c's id
    # capture parks stderr here so it can read stdout alone, the same shape the
    # bash twin uses.
    $errFile = [System.IO.Path]::GetTempFileName()
    foreach ($c in @($raw)) {
        $key = ([string]$c).TrimEnd("`r")
        if ($key -notmatch '^[0-9]+$') { continue }
        if ($linked.ContainsKey($key)) { continue }
        $linked[$key] = $true
        $total++
    }

    for ($i = 0; $i -lt $entries.Count; $i++) {
        $entry = $entries[$i]
        $number = $Numbers[$i]
        $title = Get-MilestoneTitle $entry.PlanFile

        # 2. this milestone's Wave-ordered surviving issues, from its LIVE description
        $desc = gh api "repos/{owner}/{repo}/milestones/$number" --jq '.description' 2>$null
        $desc = (@($desc) | ForEach-Object { [string]$_ }) -join "`n"
        $children = @()
        foreach ($m in [regex]::Matches($desc, '#([0-9]+)')) {
            $value = $m.Groups[1].Value
            if ($children -ccontains $value) { continue }
            $children += $value
        }
        if ($children.Count -eq 0) { continue }

        # 3. nested-epic refusal, before linking any of this milestone's issues.
        # Skipped entirely once the cap is full: there is no reason to spend a
        # `gh` call checking a label on an issue that will not be linked
        # regardless.
        $refused = ''
        if ($total -lt 100) {
            foreach ($c in $children) {
                $labels = gh issue view $c --json labels --jq '.labels[].name' 2>$null
                $names = @(@($labels) | ForEach-Object { ([string]$_).TrimEnd("`r") })
                if ($names -ccontains 'md-epic') {
                    $refused = $c
                    break
                }
            }
        }
        if ($refused) {
            Write-Row "refused`t$number`t$title`t$refused"
            foreach ($c in $children) { Write-Row "skipped`t$c`tnested-epic" }
            continue
        }

        # 4. per child, in Wave order
        foreach ($c in $children) {
            if ($linked.ContainsKey($c)) {
                Write-Row "skipped`t$c`talready-linked"
                continue
            }
            if ($total -ge 100) {
                Write-Row "skipped`t$c`tcap"
                continue
            }
            # `-F` sends sub_issue_id as an integer (gh CLI's typed-field flag:
            # gh api --help, "-F/--field has magic type conversion ... integer
            # numbers get converted to appropriate JSON types"). The sub_issues
            # endpoint needs the numeric database id, never the issue number
            # (confirmed against docs.github.com/en/rest/issues/sub-issues, and
            # live by this pass's own probe run).
            #
            # The id capture takes STDOUT ONLY, with stderr parked in $errFile
            # and read back only on a failure, matching the bash twin: a `gh`
            # call that succeeds while also printing a stderr notice would
            # otherwise fold that notice into the id and POST garbage. The two
            # calls below can merge streams safely, because their stdout is not
            # parsed.
            $childId = gh api "repos/{owner}/{repo}/issues/$c" --jq '.id' 2>$errFile
            if ($LASTEXITCODE -ne 0) {
                $idErr = if (Test-Path -LiteralPath $errFile) { [System.IO.File]::ReadAllText($errFile) } else { '' }
                # stderr is where `gh` reports; a failure that said nothing there
                # falls back to whatever it left on stdout, so the row is never
                # blank when the tool did explain itself.
                if (-not $idErr.Trim()) { $idErr = ConvertTo-OneLine $childId }
                Write-Row "failed`t$c`tid-resolve`t$(ConvertTo-OneLine $idErr)"
                continue
            }
            $childId = Get-LastLine $childId
            $linkErr = gh api --method POST "repos/{owner}/{repo}/issues/$Parent/sub_issues" -F "sub_issue_id=$childId" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Row "failed`t$c`tlink`t$(ConvertTo-OneLine $linkErr)"
                continue
            }
            $linked[$c] = $true
            $total++
            $reassertErr = gh issue edit $c --milestone $title 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Row "failed`t$c`treassert`t$(ConvertTo-OneLine $reassertErr)"
            } else {
                Write-Row "linked`t$c"
            }
        }
    }

    Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
    Write-Row "total`t$total"
    return 0
}

# --- dispatch ----------------------------------------------------------------
#
# Case-SENSITIVE, matching the bash twin's `case`. Every handler returns its
# exit code as its only output value; `Select-Object -Last 1` keeps a stray
# emitted object from ever turning that code into an array.

# Each argument is read out of $args by INDEX, and each variadic tail is rebuilt
# with @(). Slicing into a bare variable would not survive the assignment:
# PowerShell unrolls a one-element array back to a scalar, and the next index
# would then read the first CHARACTER of it.
$argv = @($args)
$sub = if ($argv.Count -ge 1) { [string]$argv[0] } else { '' }
$a0 = if ($argv.Count -ge 2) { [string]$argv[1] } else { '' }
$a1 = if ($argv.Count -ge 3) { [string]$argv[2] } else { '' }
$a2 = if ($argv.Count -ge 4) { [string]$argv[3] } else { '' }
$tailFrom2 = if ($argv.Count -gt 2) { @($argv[2..($argv.Count - 1)] | ForEach-Object { [string]$_ }) } else { @() }
$tailFrom3 = if ($argv.Count -gt 3) { @($argv[3..($argv.Count - 1)] | ForEach-Object { [string]$_ }) } else { @() }

switch -CaseSensitive ($sub) {
    'gather-numbers' { $result = Invoke-GatherNumbers $a0 }
    'render-body' { $result = Invoke-RenderBody $a0 $tailFrom2 }
    'resolve-or-create' { $result = Invoke-ResolveOrCreate $a0 $a1 $a2 }
    'write-receipt' { $result = Invoke-WriteReceipt $a0 $a1 }
    'link-sub-issues' { $result = Invoke-LinkSubIssues $a0 $a1 $tailFrom3 }
    default { Show-Usage; $result = 2 }
}

exit ([int](@($result) | Select-Object -Last 1))
