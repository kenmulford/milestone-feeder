#!/usr/bin/env pwsh
#
# update-reconcile-parent.ps1: update's Step 1R roadmap parent-reconcile
# mechanics (PowerShell 7+ twin of update-reconcile-parent.sh).
#
# What this does, in plain terms:
#   docs/update-reconcile-parent.md records the pass that keeps a roadmap's
#   single `md-epic` parent issue in sync on a re-plan. Five of its seven steps
#   are `create`'s own mechanics, reused by reference through the sibling twin
#   pair (scripts/md-epic-parent.sh / .ps1). This script performs the three that
#   are `update`'s OWN: the preliminary receipt read, the diff-gated body write,
#   and the removed-milestone detection. It holds NO judgment. The human-facing
#   diff review, the flag-never-close reporting, and the roadmap-manifest gate
#   itself stay in the calling skill's prose (skills/update/SKILL.md Step 1R):
#   this script prints rows and values, and the caller decides what to say about
#   them and whether to call it at all.
#
# Invocation (one form, identical on both twins, so a caller documents one):
#   scripts/update-reconcile-parent.ps1 <subcommand> [args]
#   Positional `$args` rather than a `param()` block, deliberately: the two
#   twins take the SAME argv, so a call site documents one invocation.
#
# Entry points. Each is SEPARATELY INVOKABLE, so the calling skill runs the one
# its step needs and skips the ones its branch does not reach (the
# reuse-by-reference discipline at .project/design-philosophy.md (## What we
# optimize for)).
#
#   read-receipt <manifest>
#     args   The roadmap manifest path.
#     does   Reads the manifest's FIRST `Parent issue (GitHub): #<n>` header
#            line (docs/roadmap-manifest-format.md). A plain, side-effect-free
#            read: it never resolves, never creates, and never writes. The
#            resolve-or-create in step 3 re-examines this same line as its own
#            first branch, so this read never substitutes for that resolution;
#            it only tells the caller whether a live parent body already exists
#            to compare against, which is what gates steps 3, 4, and 5.
#     out    The parent issue number, on one line, when the manifest carries a
#            well-formed receipt. NOTHING otherwise: no receipt line at all (a
#            brand-new roadmap, or one `create` has not deployed the parent
#            for), and a malformed or non-numeric value (a hand-edited
#            manifest) both come back empty, the same absent-means-absent guard
#            `update`'s own Step 3.0 milestone-receipt read uses.
#     exit   0, whether or not a number was found; 2 on a usage problem or an
#            unreadable manifest.
#
#   diff-gate <parent> <body-file> <live-body-file>
#     args   The resolved parent issue number; the body file `render-body`
#            produced on THIS run; the path to WRITE the parent's live body to,
#            so `detect-removed` reads the SAME bytes this comparison used and
#            the pass spends exactly one live-body fetch.
#     does   Fetches the parent's live body, saves it, and compares it to the
#            freshly rendered body. Identical: writes NOTHING, no PATCH, so an
#            unchanged roadmap costs zero parent-body writes. Differ: PATCHes
#            with the REPLACE-form `gh issue edit --body-file`. The caller
#            invokes this ONLY when the preliminary receipt was present; on a
#            brand-new parent there is nothing to diff against and step 3's
#            create/adopt already wrote the correct body.
#     out    Two TAB rows, in this order:
#              compare<TAB>same|differ      the comparison outcome
#              patch<TAB>skipped|patched    what the gate then did
#            The `compare` row is printed BEFORE the PATCH is attempted, so a
#            failed write still leaves the caller the decision its report has to
#            name.
#     exit   0; 2 on a usage problem, a missing body file, or a live-body file
#            that could not be written; 3 when `gh` is unavailable or a `gh`
#            call failed, naming which one on stderr. These are LOAD-BEARING
#            writes: the caller STOPS the pass on a non-zero, reports what
#            completed and what remains, and deletes nothing. A re-run resumes
#            by re-reading the receipt and re-comparing fresh. Nothing here ever
#            deletes, closes, or unlinks anything.
#
#   detect-removed <live-body-file> <number> [<number> ...]
#     args   The live-body file `diff-gate` saved (the parent's `md-epic-order`
#            block as it stood BEFORE this run); every number `gather-numbers`
#            printed on this run, in build order.
#     does   Reads the OLD block's `number: <n>` lines and diffs them against
#            the current set. A number in the OLD block that the current set no
#            longer carries was dropped by the re-plan. Detection only: no
#            unlink call, no close call, and no delete call exists here or
#            anywhere in this pass. The caller invokes this ONLY when the
#            preliminary receipt was present; a brand-new parent has no prior
#            state, so nothing can have been removed from it.
#     out    One TAB row per dropped milestone, in the order the OLD block
#            listed them: dropped<TAB><number>. Nothing when none was dropped.
#            The flag text and the report format are the caller's
#            (skills/update/SKILL.md Step 1R).
#     exit   0; 2 on a usage problem, a missing live-body file, or a value that
#            is not a number.
#
# Body comparison (the same normalization on both twins):
#   Both sides have every carriage return stripped and their trailing newlines
#   removed before the comparison, and the live-body file is SAVED in that
#   normalized form, so the two twins compare the same bytes and save the same
#   bytes for a given parent. Stripping is the only way to hold that parity: a
#   native command's output reaches PowerShell already split into lines, with
#   its line terminators gone, so a raw byte-for-byte compare cannot be written
#   on this side. The gate can only skip a PATCH this way, never add one, and a
#   body that differs only in line endings carries identical content.
#
# Parity with the bash twin (the emitted bytes are the contract):
#   Every row is written through [Console]::Out with an explicit "`n", so the
#   rows this twin prints are LF-terminated on Windows too and a caller's own
#   parsing reads them unchanged. Line matching and subcommand dispatch are
#   ORDINAL and CASE-SENSITIVE (`-cmatch`, `-cnotcontains`, and a case-sensitive
#   `switch`), matching the bash twin's `grep -E` and `case`, the same reason
#   hooks/no-source-edit.ps1 reaches for -cnotcontains and -clike. The live-body
#   file is written through UTF8Encoding($false): no BOM, LF endings, and
#   Set-Content is deliberately NOT used, because it joins with
#   [Environment]::NewLine and would save CRLF on Windows where the bash twin
#   saves LF. The console encoding is forced to UTF-8 once at the top, in its
#   own try/catch, so a non-ASCII parent body survives a default Windows
#   codepage.
#
# Working directory:
#   Every path an argument names is relative to the CURRENT working directory,
#   the consumer's repo root, where the calling skill already stands. This
#   script resolves nothing next to itself: its three entry points call `gh` and
#   read files, and the five reused steps are the SIBLING twin's
#   (scripts/md-epic-parent.ps1), invoked by the skill directly, never wrapped
#   here.
#
# Why no jq:
#   Every JSON read here goes through `gh --jq`, `gh`'s own embedded filter, so
#   this script adds no standalone-jq dependency (the bash twin uses the same
#   `gh --jq` form for the same reason).
#
# Failure philosophy:
#   `read-receipt` and `detect-removed` are reads: they report emptiness rather
#   than failing on it. `diff-gate` makes a LOAD-BEARING write, so its failures
#   are an exit status plus one stderr line and the caller stops the pass there.
#
# Run it locally from a consumer repo root:
#   <plugin>/scripts/update-reconcile-parent.ps1 read-receipt .milestone-feeder/roadmap-<slug>.md

try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {}

function Write-Err {
    param([string]$Message)
    [Console]::Error.WriteLine("update-reconcile-parent: $Message")
}

function Write-Row {
    param([string]$Text)
    [Console]::Out.Write($Text + "`n")
}

function Show-Usage {
    $lines = @(
        'usage: update-reconcile-parent.ps1 <subcommand> [args]',
        '  read-receipt <manifest>',
        '  diff-gate <parent> <body-file> <live-body-file>',
        '  detect-removed <live-body-file> <number> [<number> ...]'
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
# split a stderr line in two.
#
# The trailing TrimEnd is what keeps this byte-identical to the bash twin. There
# the value arrives through a `$(...)` capture, which has ALREADY dropped the
# message's trailing newlines before `one_line` converts the remaining ones to
# spaces; here the newline survives into the replace and becomes a trailing
# SPACE, and a `gh` message whose last line is empty leaves the same space via
# the join. TrimEnd removes both. It is deliberately not a full Trim: bash keeps
# a LEADING space (its capture strips trailing newlines only), so trimming the
# front would swap one divergence for another on a message that opens with a
# blank line.
function ConvertTo-OneLine {
    param($Value)
    $text = (@($Value) | ForEach-Object { [string]$_ }) -join ' '
    return ($text -replace "[`r`n`t]", ' ').TrimEnd()
}

# The comparison form both twins use: no carriage returns, no trailing
# newlines. The bash twin gets the trailing-newline strip from its command
# substitutions; here it is explicit.
function ConvertTo-NormalizedBody {
    param($Value)
    $text = (@($Value) | ForEach-Object { [string]$_ }) -join "`n"
    return (($text -replace "`r", '').TrimEnd("`n"))
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

# --- the preliminary receipt read --------------------------------------------

function Invoke-ReadReceipt {
    param([string]$Manifest)
    if (-not $Manifest) { Show-Usage; return 2 }
    if (-not (Test-InputFile $Manifest)) { return 2 }
    # Same first-match-only read the sibling twin's resolve-or-create branch (a)
    # performs against this line, so both agree on a degenerate manifest: a
    # malformed FIRST line resolves to empty rather than skipping ahead to a
    # later well-formed one.
    foreach ($line in (Get-FileLines $Manifest)) {
        if ($line -cmatch '^Parent issue \(GitHub\):') {
            if ($line -cmatch '^Parent issue \(GitHub\): *#?([0-9]+)') {
                Write-Row $Matches[1]
            }
            return 0
        }
    }
    return 0
}

# --- the diff-gated body write -----------------------------------------------

function Invoke-DiffGate {
    param([string]$Parent, [string]$BodyFile, [string]$LiveFile)
    if ($Parent -notmatch '^[0-9]+$') { Show-Usage; return 2 }
    if (-not $BodyFile -or -not $LiveFile) { Show-Usage; return 2 }
    if (-not (Test-InputFile $BodyFile)) { return 2 }
    if (-not (Test-Gh)) { return 3 }

    # The live-body capture takes STDOUT ONLY, with stderr parked in $errFile
    # and read back only on a failure, matching the bash twin: a `gh` call that
    # succeeds while also printing a stderr notice would otherwise fold that
    # notice into the body, and the comparison would report a difference that
    # does not exist and PATCH over a correct body.
    $errFile = [System.IO.Path]::GetTempFileName()
    $live = gh issue view $Parent --json body --jq '.body' 2>$errFile
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        $msg = if (Test-Path -LiteralPath $errFile) { [System.IO.File]::ReadAllText($errFile) } else { '' }
        if (-not $msg.Trim()) { $msg = ConvertTo-OneLine $live }
        Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue
        Write-Err "could not read the parent issue's live body on #${Parent}: $(ConvertTo-OneLine $msg)"
        return 3
    }
    Remove-Item -LiteralPath $errFile -Force -ErrorAction SilentlyContinue

    $liveBody = ConvertTo-NormalizedBody $live
    $renderedBody = ConvertTo-NormalizedBody ([System.IO.File]::ReadAllText($BodyFile))

    # Saved in the normalized form, so detect-removed reads the same bytes on
    # either twin and this pass spends exactly one live-body fetch.
    try {
        Write-Utf8NoBom $LiveFile ($liveBody + "`n")
    } catch {
        Write-Err "could not write the live parent body to $LiveFile"
        return 2
    }

    if ($liveBody -ceq $renderedBody) {
        Write-Row "compare`tsame"
        Write-Row "patch`tskipped"
        return 0
    }

    Write-Row "compare`tdiffer"
    $patchErr = gh issue edit $Parent --body-file $BodyFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "could not PATCH the parent issue's body on #${Parent}: $(ConvertTo-OneLine $patchErr)"
        return 3
    }
    Write-Row "patch`tpatched"
    return 0
}

# --- the removed-milestone detection -----------------------------------------

function Invoke-DetectRemoved {
    param([string]$LiveFile, [string[]]$Numbers)
    if (-not $LiveFile) { Show-Usage; return 2 }
    # An empty variadic tail binds as $null, not as an empty array, and
    # @($null) counts ONE: test for the null explicitly or a numberless call
    # would report every old entry as dropped instead of failing the way the
    # bash twin does.
    if ($null -eq $Numbers -or @($Numbers).Count -eq 0) { Show-Usage; return 2 }
    if (-not (Test-InputFile $LiveFile)) { return 2 }
    foreach ($m in $Numbers) {
        if ($m -notmatch '^[0-9]+$') {
            Write-Err "not a milestone number: $m"
            return 2
        }
    }

    # The OLD block, as the parent carried it BEFORE this run. Get-FileLines
    # splits on either ending, which is where the bash twin's CR strip lands.
    foreach ($line in (Get-FileLines $LiveFile)) {
        if ($line -cmatch '^number: ([0-9]+)$') {
            $c = $Matches[1]
            if ($Numbers -cnotcontains $c) { Write-Row "dropped`t$c" }
        }
    }
    return 0
}

# --- dispatch ----------------------------------------------------------------
#
# Case-SENSITIVE, matching the bash twin's `case`. Every handler returns its
# exit code as its only output value; `Select-Object -Last 1` keeps a stray
# emitted object from ever turning that code into an array.

# Each argument is read out of $args by INDEX, and the variadic tail is rebuilt
# with @(). Slicing into a bare variable would not survive the assignment:
# PowerShell unrolls a one-element array back to a scalar, and the next index
# would then read the first CHARACTER of it.
$argv = @($args)
$sub = if ($argv.Count -ge 1) { [string]$argv[0] } else { '' }
$a0 = if ($argv.Count -ge 2) { [string]$argv[1] } else { '' }
$a1 = if ($argv.Count -ge 3) { [string]$argv[2] } else { '' }
$a2 = if ($argv.Count -ge 4) { [string]$argv[3] } else { '' }
$tailFrom2 = if ($argv.Count -gt 2) { @($argv[2..($argv.Count - 1)] | ForEach-Object { [string]$_ }) } else { @() }

switch -CaseSensitive ($sub) {
    'read-receipt' { $result = Invoke-ReadReceipt $a0 }
    'diff-gate' { $result = Invoke-DiffGate $a0 $a1 $a2 }
    'detect-removed' { $result = Invoke-DetectRemoved $a0 $tailFrom2 }
    default { Show-Usage; $result = 2 }
}

exit ([int](@($result) | Select-Object -Last 1))
