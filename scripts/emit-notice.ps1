#!/usr/bin/env pwsh
#
# emit-notice.ps1: the one-time-notice emitter (PowerShell 7+ twin of
# emit-notice.sh).
#
# What this does, in plain terms:
#   docs/one-time-notices.md defines seven Step-0 units shared across `plan`,
#   `create`, and `update`: one self-heal that writes a file, and six notices
#   that print at most once per clone. This script runs them. It holds none of
#   their text. Every unit's printed lines and the self-heal's file body live
#   in scripts/emit-notice.json, once, so this script and its bash twin cannot
#   drift from each other or from the doc.
#
# Invocation (one form, identical on both twins, so a caller documents one):
#   scripts/emit-notice.ps1 <plan|create|update>
#     Caller mode. Walks the units in file order, keeps every unit whose
#     `skills` list contains the caller's own name, and runs each one.
#   scripts/emit-notice.ps1 --section <section-id>
#     Explicit-section mode. Runs exactly the one unit whose `id` matches,
#     WHATEVER its `skills` list says. This is the mode for a caller that is
#     not one of the three verbs (`setup`, which runs the self-heal and the
#     legacy-blanket notice). Only the skills filter is bypassed: the unit's
#     marker gate and its trigger still decide whether it fires.
#     `--section` rather than a `-Section` parameter, deliberately: the two
#     twins take the SAME argv, so a call site documents one invocation and
#     `param()` would fork that into two.
#
# What running one unit means, in order:
#   1. Marker gate. A unit with a `marker` is skipped when that marker file
#      already exists. That is what makes a notice show at most once per clone.
#      A unit with `marker: null` has no gate and re-checks every run (the
#      self-heal's documented exception).
#   2. Trigger. Four kinds, and nothing else is recognised:
#        always             fires whenever the marker gate let it through.
#        file-absent        fires when `trigger.path` is not a file.
#        gitignore-blanket  fires when `trigger.path` carries a blanket line
#                           for .milestone-config that no broad un-ignore
#                           clears.
#        unbootstrapped     fires when the resolved projectDocs tree holds no
#                           file, or .milestone-config/driver.json is missing.
#      An unrecognised kind does not fire, which is how a data file written by
#      a newer version degrades here: silently, one unit at a time.
#   3. Print. The unit's `text` lines, one per line, byte-exact. The single
#      substitution is `{{projectDocs}}`, replaced with the resolved
#      projectDocs path with trailing slashes stripped.
#   4. Write. A unit carrying `writes` creates that file from `writes.lines`.
#   5. Marker. A unit carrying a `marker` writes it, so it stays silent later.
#
# Working directory:
#   Every path a unit names is relative to the CURRENT working directory: the
#   consumer's repo root, where the calling skill already stands. The data file
#   is resolved next to THIS script instead, because the plugin is installed
#   outside the repo it acts on, so a repo-relative path would not find it.
#
# Parity with the bash twin (the emitted bytes are the contract):
#   Text prints as one `-join "`n"` Write-Host call, matching `printf '%s\n'`
#   line for line. `Test-Path -PathType Leaf` matches bash `[ -f ]` rather than
#   bare `Test-Path`, which also answers true for a directory. Files are written
#   through UTF8Encoding($false): no BOM, LF endings, the form the doc's
#   PowerShell self-heal already uses. The console encoding is forced to UTF-8
#   once at the top, in its own try/catch, so the notices' emoji survive a
#   default Windows codepage and a throwing setter never skips a notice.
#
# Best-effort, always:
#   This script never aborts its caller (.project/design-philosophy.md
#   (## Error & failure philosophy)). A missing or malformed data file, an
#   unusable unit, or a failed write is skipped, and the exit status is 0 in
#   every case, including a usage error (which still prints one line to stderr,
#   because a mis-wired call site is a bug worth seeing). Each unit runs inside
#   its own try/catch, so one bad unit costs only that unit.
#
# Run it locally from a consumer repo root:  <plugin>/scripts/emit-notice.ps1 plan
# Exit 0, always.

# UTF-8 console output so the notices' emoji survive a default Windows codepage;
# own catch so a throwing setter never skips a notice.
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {}

# --- arguments ---------------------------------------------------------------
$mode = ''
$sel = ''
if ($args.Count -ge 2 -and [string]$args[0] -eq '--section') {
    $mode = 'section'
    $sel = [string]$args[1]
} elseif ($args.Count -ge 1 -and @('plan', 'create', 'update') -contains [string]$args[0]) {
    $mode = 'caller'
    $sel = [string]$args[0]
}

if (-not $mode -or -not $sel) {
    [Console]::Error.WriteLine('usage: emit-notice.ps1 <plan|create|update> | emit-notice.ps1 --section <section-id>')
    exit 0
}

# --- guards: no data file, malformed JSON, no unit array -> do nothing --------
$dataPath = Join-Path $PSScriptRoot 'emit-notice.json'
try {
    $data = Get-Content -Raw -LiteralPath $dataPath -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
} catch {
    exit 0
}
if ($null -eq $data -or $null -eq $data.units) { exit 0 }
$units = @($data.units)

# --- resolve projectDocs -----------------------------------------------------
#
# Same read and same default as the doc's bootstrap-nudge emitter, so the two
# can't diverge: a non-string projectDocs (number/array), a missing file, or
# malformed JSON all fall back to .project/. ALL trailing slashes are stripped
# for the detect operand; an empty result (e.g. "/") falls back to .project so
# PowerShell and bash agree. The notice text re-adds the single "/", so the
# printed path always ends in one.
$pd = '.project/'
try {
    $pdRaw = (Get-Content -Raw -LiteralPath (Join-Path '.milestone-config' 'feeder.json') -ErrorAction Stop | ConvertFrom-Json).projectDocs
    if ($pdRaw -is [string]) { $pd = $pdRaw }
} catch {}
$pd = $pd -replace '/+$', ''
if (-not $pd) { $pd = '.project' }

# --- trigger kinds -----------------------------------------------------------
#
# Returns $true (fires) or $false. Every unrecognised kind returns $false, so an
# unknown trigger skips its unit rather than firing it blind. The two regexes
# below are the doc's legacy-blanket detect verbatim: a blanket counts as
# present UNLESS a broad un-ignore re-exposes the tracked config.
function Test-NoticeTrigger {
    param($Unit, [string]$ProjectDocs)

    $kind = [string]$Unit.trigger.kind
    $path = [string]$Unit.trigger.path

    switch ($kind) {
        'always' { return $true }
        'file-absent' {
            if (-not $path) { return $false }
            return -not (Test-Path -LiteralPath $path -PathType Leaf)
        }
        'gitignore-blanket' {
            if (-not $path -or -not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
            $lines = Get-Content -LiteralPath $path
            $blanket = $lines | Where-Object { $_ -match '^\s*/?\.milestone-config(/\*?)?\s*$' }
            $unignored = $lines | Where-Object { $_ -match '^\s*!/?\.milestone-config(/\*?)?\s*$' }
            return [bool]($blanket -and -not $unignored)
        }
        'unbootstrapped' {
            $projectEmpty = -not (Test-Path $ProjectDocs) -or -not (Get-ChildItem -LiteralPath $ProjectDocs -File -Recurse -Force -ErrorAction SilentlyContinue | Select-Object -First 1)
            $driverMissing = -not (Test-Path -LiteralPath (Join-Path '.milestone-config' 'driver.json') -PathType Leaf)
            return ($projectEmpty -or $driverMissing)
        }
        default { return $false }
    }
}

# --- run one unit ------------------------------------------------------------
#
# Its own function so an early exit is a `return`, and so the caller can wrap
# each unit in one try/catch.
function Invoke-NoticeUnit {
    param($Unit, [string]$ProjectDocs)

    # 0. shape gate. A unit is usable only when its `text` is an array and,
    #    when it carries `writes`, `writes.lines` is an array too. Anything
    #    else is a MALFORMED unit and is skipped whole: nothing printed, no
    #    file written, and NO MARKER, so a bad entry can never permanently
    #    suppress its own notice. The bash twin applies the same tests inside
    #    its jq selection, so a degenerate data file produces identical silence
    #    on both platforms (.project/conventions.md (## Test patterns), which
    #    makes bash/pwsh parity on degenerate inputs a test obligation).
    #    Without this gate a scalar `text` would be coerced by @() and printed.
    if ($Unit.text -isnot [array]) { return }
    if ($null -ne $Unit.writes -and $Unit.writes.lines -isnot [array]) { return }

    # 1. marker gate
    $marker = [string]$Unit.marker
    if ($marker -and (Test-Path -LiteralPath $marker -PathType Leaf)) { return }

    # 2. trigger
    if (-not (Test-NoticeTrigger -Unit $Unit -ProjectDocs $ProjectDocs)) { return }

    # 3. print the notice text
    $lines = @(@($Unit.text) | ForEach-Object { ([string]$_).Replace('{{projectDocs}}', $ProjectDocs) })
    if ($lines.Count -gt 0) { Write-Host ($lines -join "`n") }

    # 4. write the unit's file, when it has one. The only unit that does is the
    #    self-heal, whose trigger is the absence of exactly this path, so this
    #    can never clobber a user-edited file. The path is resolved against the
    #    session's location, because .NET's own current directory can lag it.
    $writePath = [string]$Unit.writes.path
    $writeLines = @($Unit.writes.lines)
    if ($writePath -and $writeLines.Count -gt 0) {
        $full = if ([System.IO.Path]::IsPathRooted($writePath)) {
            $writePath
        } else {
            Join-Path (Get-Location).Path $writePath
        }
        $dir = Split-Path -Parent $full
        if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
        [System.IO.File]::WriteAllText($full, (($writeLines -join "`n") + "`n"), [System.Text.UTF8Encoding]::new($false))
    }

    # 5. write the marker, so a marker-gated unit stays silent from here on.
    #    LAST, and reached only once the text printed and the file (if any) was
    #    written: a throw at either step unwinds past this into the caller's
    #    per-unit catch, so the notice is still owed on the next run rather than
    #    silently retired unshown. Same ordering as the bash twin.
    if ($marker) {
        $markerDir = Split-Path -Parent $marker
        if ($markerDir) { New-Item -ItemType Directory -Force -Path $markerDir | Out-Null }
        New-Item -ItemType File -Force -Path $marker | Out-Null
    }
}

# --- select the units, in file order, and run them ---------------------------
#
# Case-SENSITIVE (-ccontains, -ceq) to match jq's case-sensitive `index` and
# `==` in the bash twin, the same reason hooks/no-source-edit.ps1 reaches for
# -cnotcontains and -clike. A `skills` that is not an array matches nothing
# here, which is what the bash twin's `if type == "array"` test reproduces:
# jq's `index` would otherwise run as substring matching on a string.
$selected = @($units | Where-Object {
        if ($mode -eq 'caller') { @($_.skills) -ccontains $sel } else { [string]$_.id -ceq $sel }
    })

foreach ($unit in $selected) {
    try { Invoke-NoticeUnit -Unit $unit -ProjectDocs $pd } catch {}
}

exit 0
