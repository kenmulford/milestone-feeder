#!/usr/bin/env pwsh
#
# check-issue-body.ps1: deterministic checks over one authored issue body
# (PowerShell 7+ twin of check-issue-body.sh).
#
# Invocation (identical on both twins):
#   scripts/check-issue-body.ps1 <body-file> <repo-root>
#     [--invariants <file>] [--sections <file>] [--mode plan|bug]
#     [--edges <file>]
#   Positional `$args` rather than a `param()` block, deliberately: the twins
#   take the SAME argv, `--flag` spelling included.
#
# Stages, in run order: Test-Sections, Test-Invariants, Test-Citations,
# Test-SitesSearched, Test-Vocabulary, Test-PlatformSource, Test-Edges.
#
# Output: one finding per line on stdout, in check order, then input order.
# Exit: 0 pass (no output), 1 findings, 2 usage or unreadable input (no check
# runs; one stderr line).
#
# Comparisons are ordinal and case-sensitive except the vocabulary check,
# which folds A-Z only, as the bash twin does under LC_ALL=C. Invariants are
# parsed with JsonDocument because ConvertFrom-Json turns a date-shaped string
# value into DateTime.

try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new() } catch {}

$argv = @($args)
$script:Usage = 'usage: check-issue-body <body-file> <repo-root> [--invariants <file>] [--sections <file>] [--mode plan|bug] [--edges <file>]'
$script:BodyFile = ''
$script:RepoRoot = ''
$script:InvFile = ''
$script:SecFile = ''
$script:Mode = 'plan'
$script:HaveInv = $false
$script:HaveSec = $false
$script:HaveMode = $false
$script:Lines = @()
$script:InFence = @()
$script:BodyText = ''
$script:Findings = [System.Collections.Generic.List[string]]::new()
$script:InvValues = @()
$script:BodyArg = ''
$script:RepoArg = ''
$script:InvArg = ''
$script:SecArg = ''
$script:EdgesFile = ''
$script:HaveEdges = $false
$script:EdgesArg = ''
$script:EdgeTags = @()

function Write-Err {
    param([string]$Message)
    [Console]::Error.Write("check-issue-body: $Message`n")
}
function Write-Row {
    param([string]$Text)
    [Console]::Out.Write($Text + "`n")
}

function Read-Arguments {
    param([string[]]$Argv)
    $npos = 0
    $sawFlag = $false
    $i = 0
    while ($i -lt $Argv.Count) {
        $a = $Argv[$i]
        if ($a -ceq '--invariants' -or $a -ceq '--sections' -or $a -ceq '--mode' -or $a -ceq '--edges') {
            if ($i + 1 -ge $Argv.Count) { return 2 }
            $sawFlag = $true
            $v = $Argv[$i + 1]
            if ($a -ceq '--invariants') { if ($script:HaveInv) { return 2 }; $script:HaveInv = $true; $script:InvFile = $v }
            elseif ($a -ceq '--sections') { if ($script:HaveSec) { return 2 }; $script:HaveSec = $true; $script:SecFile = $v }
            elseif ($a -ceq '--edges') { if ($script:HaveEdges) { return 2 }; $script:HaveEdges = $true; $script:EdgesFile = $v }
            else { if ($script:HaveMode) { return 2 }; $script:HaveMode = $true; $script:Mode = $v }
            $i += 2
        }
        elseif ($a.StartsWith('--', [StringComparison]::Ordinal)) { return 2 }
        else {
            if ($sawFlag) { return 2 }
            $npos++
            if ($npos -eq 1) { $script:BodyFile = $a }
            elseif ($npos -eq 2) { $script:RepoRoot = $a }
            else { return 2 }
            $i++
        }
    }
    if ($npos -ne 2) { return 2 }
    return 0
}

# .NET calls resolve a relative path against the process directory, which
# Set-Location does not move, so every path is made absolute against $PWD once,
# before any .NET call. The *Arg variables keep the text the caller typed for
# messages.
function Resolve-Arguments {
    $session = $ExecutionContext.SessionState.Path
    $script:BodyArg = $script:BodyFile
    $script:RepoArg = $script:RepoRoot
    $script:InvArg = $script:InvFile
    $script:SecArg = $script:SecFile
    $script:EdgesArg = $script:EdgesFile
    if ($script:BodyFile.Length -gt 0) { $script:BodyFile = $session.GetUnresolvedProviderPathFromPSPath($script:BodyFile) }
    if ($script:RepoRoot.Length -gt 0) { $script:RepoRoot = $session.GetUnresolvedProviderPathFromPSPath($script:RepoRoot) }
    if ($script:InvFile.Length -gt 0) { $script:InvFile = $session.GetUnresolvedProviderPathFromPSPath($script:InvFile) }
    if ($script:SecFile.Length -gt 0) { $script:SecFile = $session.GetUnresolvedProviderPathFromPSPath($script:SecFile) }
    if ($script:EdgesFile.Length -gt 0) { $script:EdgesFile = $session.GetUnresolvedProviderPathFromPSPath($script:EdgesFile) }
}

function Test-ReadableFile {
    param([string]$Path)
    if (-not [System.IO.File]::Exists($Path)) { return $false }
    try { $s = [System.IO.File]::OpenRead($Path); $s.Dispose(); return $true } catch { return $false }
}

function Test-Inputs {
    if ($script:Mode -cne 'plan' -and $script:Mode -cne 'bug') {
        Write-Err "--mode must be plan or bug, got: $($script:Mode)"; return 2
    }
    if (-not (Test-ReadableFile $script:BodyFile)) { Write-Err "body file not found: $($script:BodyArg)"; return 2 }
    if (-not [System.IO.Directory]::Exists($script:RepoRoot)) { Write-Err "repo root is not a directory: $($script:RepoArg)"; return 2 }
    if ($script:HaveInv) {
        if (-not (Test-ReadableFile $script:InvFile)) { Write-Err "invariants file not found: $($script:InvArg)"; return 2 }
        $values = [System.Collections.Generic.List[string]]::new()
        $ok = $false
        try {
            $doc = [System.Text.Json.JsonDocument]::Parse([System.IO.File]::ReadAllText($script:InvFile))
            try {
                if ($doc.RootElement.ValueKind -eq [System.Text.Json.JsonValueKind]::Array) {
                    $ok = $true
                    foreach ($entry in $doc.RootElement.EnumerateArray()) {
                        if ($entry.ValueKind -ne [System.Text.Json.JsonValueKind]::Object) { $ok = $false; break }
                        $prop = $null
                        foreach ($member in $entry.EnumerateObject()) {
                            if ($member.Name -ceq 'value') { $prop = $member.Value }
                        }
                        if ($null -eq $prop -or $prop.ValueKind -ne [System.Text.Json.JsonValueKind]::String) { $ok = $false; break }
                        $values.Add($prop.GetString())
                    }
                }
            } finally { $doc.Dispose() }
        } catch { $ok = $false }
        if (-not $ok) { Write-Err "invariants file is not a JSON array of entries carrying a string value: $($script:InvArg)"; return 2 }
        $script:InvValues = $values
    }
    if ($script:HaveSec) {
        if (-not (Test-ReadableFile $script:SecFile)) { Write-Err "sections file not found: $($script:SecArg)"; return 2 }
    }
    if ($script:HaveEdges) {
        if (-not (Test-ReadableFile $script:EdgesFile)) { Write-Err "edges file not found: $($script:EdgesArg)"; return 2 }
        $tags = [System.Collections.Generic.List[string]]::new()
        foreach ($l in (Get-FileLines $script:EdgesFile)) {
            if ($l.Length -eq 0) { continue }
            if (-not [regex]::IsMatch($l, '^#[A-Za-z0-9]+$', [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)) {
                Write-Err "edges file holds a line that is not a tag: $l"; return 2
            }
            $tags.Add($l.Substring(1))
        }
        $script:EdgeTags = $tags
    }
    return 0
}

function Get-FileLines {
    param([string]$Path)
    $text = [System.Text.UTF8Encoding]::new($false).GetString([System.IO.File]::ReadAllBytes($Path))
    $out = [System.Collections.Generic.List[string]]::new()
    if ($text.Length -eq 0) { return , $out }
    $parts = $text.Split("`n")
    $count = $parts.Count
    if ($text.EndsWith("`n", [StringComparison]::Ordinal)) { $count-- }
    for ($i = 0; $i -lt $count; $i++) {
        $line = $parts[$i]
        if ($line.EndsWith("`r", [StringComparison]::Ordinal)) { $line = $line.Substring(0, $line.Length - 1) }
        if ($i -eq 0 -and $line.Length -gt 0 -and $line[0] -eq [char]0xFEFF) { $line = $line.Substring(1) }
        $out.Add($line)
    }
    return , $out
}

function Read-Body {
    $lines = Get-FileLines $script:BodyFile
    $script:Lines = $lines.ToArray()
    $script:BodyText = [string]::Join("`n", $script:Lines)
    $fence = ''
    $flags = [System.Collections.Generic.List[bool]]::new()
    foreach ($raw in $script:Lines) {
        $s = $raw.TrimStart(' ', "`t")
        $ch = ''
        $run = 0
        $rest = ''
        if ($s.StartsWith('```', [StringComparison]::Ordinal)) { $ch = '`' }
        elseif ($s.StartsWith('~~~', [StringComparison]::Ordinal)) { $ch = '~' }
        if ($ch) {
            while ($run -lt $s.Length -and $s[$run] -eq $ch[0]) { $run++ }
            $rest = $s.Substring($run)
            if ($ch -ceq '`' -and $rest.Contains('`')) { $ch = '' }
        }
        if ($fence) {
            $flags.Add($true)
            if ($ch -and $ch -ceq $fence[0] -and $run -ge $fence.Length -and $rest.Trim(' ', "`t").Length -eq 0) { $fence = '' }
        }
        elseif ($ch) {
            $flags.Add($true)
            $fence = $ch * $run
        }
        else { $flags.Add($false) }
    }
    $script:InFence = $flags.ToArray()
}

function Test-Sections {
    if ($script:HaveSec) {
        $secLines = Get-FileLines $script:SecFile
        $want = @($secLines | Where-Object { $_.Length -gt 0 })
    }
    else {
        $want = @('## Summary', '## Acceptance criteria', '## Design (recorded, consistent)', '## Dependencies')
    }
    foreach ($h in $want) {
        $found = $false
        for ($i = 0; $i -lt $script:Lines.Count; $i++) {
            if (-not $script:InFence[$i] -and $script:Lines[$i] -ceq $h) { $found = $true; break }
        }
        if (-not $found) { $script:Findings.Add("section: expected heading `"$h`", found none") }
    }
}

# Returns @(start, end): the first line outside a fence equal to the heading, -1
# when none, and the next "## " line outside a fence after it, else the line
# count. The section is the lines start+1 up to end, an empty range when there
# is no heading.
function Get-SectionBounds {
    param([string]$Heading)
    $start = -1
    $end = 0
    for ($i = 0; $i -lt $script:Lines.Count; $i++) {
        if ($script:InFence[$i]) { continue }
        if ($start -lt 0) {
            if ($script:Lines[$i] -ceq $Heading) { $start = $i; $end = $script:Lines.Count }
        }
        elseif ($script:Lines[$i].StartsWith('## ', [StringComparison]::Ordinal)) { $end = $i; break }
    }
    return @($start, $end)
}

function Test-Invariants {
    if (-not $script:HaveInv) { return }
    $start, $end = Get-SectionBounds '## Acceptance criteria'
    $haystack = $script:BodyText
    $where = ''
    if ($start -ge 0) {
        $section = [System.Collections.Generic.List[string]]::new()
        for ($i = $start + 1; $i -lt $end; $i++) { $section.Add($script:Lines[$i]) }
        $haystack = [string]::Join("`n", $section)
        $where = ' under "## Acceptance criteria"'
    }
    foreach ($v in $script:InvValues) {
        if ($haystack.IndexOf($v, [StringComparison]::Ordinal) -lt 0) {
            $script:Findings.Add("invariant: expected value `"$v`"$where, found none")
        }
    }
}

function ConvertTo-AsciiLower {
    param([string]$Text)
    $sb = [System.Text.StringBuilder]::new($Text.Length)
    foreach ($c in $Text.ToCharArray()) {
        if ($c -ge [char]'A' -and $c -le [char]'Z') { [void]$sb.Append([char]([int]$c + 32)) } else { [void]$sb.Append($c) }
    }
    return $sb.ToString()
}

function Get-LineSpans {
    param([string]$Line)
    $spans = [System.Collections.Generic.List[string]]::new()
    $pos = 0
    while ($true) {
        $open = $Line.IndexOf('`', $pos, [StringComparison]::Ordinal)
        if ($open -lt 0) { break }
        $close = $Line.IndexOf('`', $open + 1, [StringComparison]::Ordinal)
        if ($close -lt 0) { break }
        $spans.Add($Line.Substring($open + 1, $close - $open - 1))
        $pos = $close + 1
    }
    return , $spans
}

# A span is a citation candidate only when it ends with ")" and holds " (".
# Heading forms (a "#" or section sign in the head), a head holding neither "/"
# nor ".", an empty head or anchor, and "new" are skipped without a finding. The
# dotless, slashless head skips prose naming the form itself, "path (anchor)".
function Resolve-Citation {
    param([string]$Span)
    if (-not $Span.EndsWith(')', [StringComparison]::Ordinal)) { return }
    $cut = $Span.IndexOf(' (', [StringComparison]::Ordinal)
    if ($cut -lt 0) { return }
    $head = $Span.Substring(0, $cut)
    if ($head.Length -eq 0 -or $head.Contains('#') -or $head.Contains([string][char]0x00A7)) { return }
    if (-not ($head.Contains('/') -or $head.Contains('.'))) { return }
    $anchor = $Span.Substring($cut + 2)
    $anchor = $anchor.Substring(0, $anchor.Length - 1)
    if ($anchor.Length -eq 0 -or $anchor -ceq 'new') { return }
    $file = $script:RepoRoot + '/' + $head
    if (-not (Test-ReadableFile $file)) {
        $script:Findings.Add("citation: expected 1 line matching `"$anchor`" in $head, found 0 (no readable file)")
        return
    }
    $hits = 0
    foreach ($l in (Get-FileLines $file)) {
        if ($l.IndexOf($anchor, [StringComparison]::Ordinal) -ge 0) { $hits++ }
    }
    if ($hits -ne 1) { $script:Findings.Add("citation: expected 1 line matching `"$anchor`" in $head, found $hits") }
}

function Test-Citations {
    for ($i = 0; $i -lt $script:Lines.Count; $i++) {
        if ($script:InFence[$i]) { continue }
        foreach ($span in (Get-LineSpans $script:Lines[$i])) { Resolve-Citation $span }
    }
}

# Returns $false when the pattern holds a token outside the ERE subset that
# POSIX and .NET read the same way: a "{" not opening a well-formed {m}, {m,} or
# {m,n}, or a quantifier (* + ? {) with no atom before it (pattern start, after
# "(" or "|") or right after another quantifier. $qok is $true when an atom has
# just ended.
function Test-PatternSubset {
    param([string]$P)
    $n = $P.Length
    $i = 0
    $qok = $false
    while ($i -lt $n) {
        $c = $P[$i]
        if ($c -eq '\') {
            if ($i + 1 -ge $n) { return $false }
            if ('.[]()*+?{}|^$\'.IndexOf($P[$i + 1]) -lt 0) { return $false }
            $i += 2
            $qok = $true
        }
        elseif ($c -eq '(') {
            if ($i + 1 -lt $n -and $P[$i + 1] -eq '?') { return $false }
            $i++
            $qok = $false
        }
        elseif ($c -eq '|') {
            $i++
            $qok = $false
        }
        elseif ($c -eq '*' -or $c -eq '+' -or $c -eq '?') {
            if (-not $qok) { return $false }
            $i++
            $qok = $false
        }
        elseif ($c -eq '{') {
            if (-not $qok) { return $false }
            $j = $i + 1
            $d = 0
            while ($j -lt $n -and $P[$j] -ge [char]'0' -and $P[$j] -le [char]'9') { $j++; $d++ }
            if ($d -eq 0) { return $false }
            if ($j -lt $n -and $P[$j] -eq ',') {
                $j++
                while ($j -lt $n -and $P[$j] -ge [char]'0' -and $P[$j] -le [char]'9') { $j++ }
            }
            if ($j -ge $n -or $P[$j] -ne '}') { return $false }
            $i = $j + 1
            $qok = $false
        }
        elseif ($c -eq '[') {
            $i++
            if ($i -lt $n -and $P[$i] -eq '^') { $i++ }
            if ($i -lt $n -and $P[$i] -eq ']') { $i++ }
            while ($i -lt $n) {
                $c = $P[$i]
                if ($c -eq ']') { break }
                if ($c -eq '\') { return $false }
                if ($c -eq '[' -and $i + 1 -lt $n -and ':=.'.IndexOf($P[$i + 1]) -ge 0) { return $false }
                $i++
            }
            $i++
            $qok = $true
        }
        else { $i++; $qok = $true }
    }
    return $true
}

# Walks one path the way grep -r -l -a does, minus symlinks and NUL files.
function Get-SiteMatches {
    param([string]$Root, [string]$Path, [regex]$Re, [System.Collections.Generic.HashSet[string]]$Into)
    $full = $Root + '/' + $Path
    if ([System.IO.File]::Exists($full)) { $files = @(Get-Item -LiteralPath $full -Force) }
    else { $files = @(Get-ChildItem -LiteralPath $full -Recurse -File -Force) }
    $rootFull = [System.IO.Path]::GetFullPath($Root)
    foreach ($f in $files) {
        if ($f.LinkType -or ($f.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) { continue }
        try { $bytes = [System.IO.File]::ReadAllBytes($f.FullName) } catch { continue }
        if ([Array]::IndexOf($bytes, [byte]0) -ge 0) { continue }
        $text = [System.Text.Encoding]::Latin1.GetString($bytes)
        $parts = $text.Split("`n")
        $count = $parts.Count
        if ($text.Length -eq 0) { continue }
        if ($text.EndsWith("`n", [StringComparison]::Ordinal)) { $count-- }
        for ($k = 0; $k -lt $count; $k++) {
            if ($Re.IsMatch($parts[$k])) {
                [void]$Into.Add([System.IO.Path]::GetRelativePath($rootFull, $f.FullName).Replace('\', '/'))
                break
            }
        }
    }
}

# One finding at most per command, first failing rule wins. The command text is
# never evaluated and no external grep runs: the host may have no bash.
function Test-SiteCommand {
    param([string]$Cmd)
    $prefix = "grep -rnE '"
    $form = "sites searched: expected grep -rnE '<pattern>' <path>..., found `"$Cmd`""
    if (-not $Cmd.StartsWith($prefix, [StringComparison]::Ordinal)) { $script:Findings.Add($form); return }
    $rest = $Cmd.Substring($prefix.Length)
    $q = $rest.IndexOf("'", [StringComparison]::Ordinal)
    if ($q -lt 0) { $script:Findings.Add($form); return }
    $pattern = $rest.Substring(0, $q)
    $after = $rest.Substring($q + 1)
    if (-not $after.StartsWith(' ', [StringComparison]::Ordinal)) { $script:Findings.Add($form); return }
    $paths = $after.Substring(1).Split(' ')
    foreach ($p in $paths) { if ($p.Length -eq 0) { $script:Findings.Add($form); return } }
    foreach ($p in $paths) {
        if ($p.StartsWith('/', [StringComparison]::Ordinal) -or $p.StartsWith('~', [StringComparison]::Ordinal) -or $p.Contains('..') -or $p.Contains('\') -or $p.Contains(':')) {
            $script:Findings.Add("sites searched: expected a path inside the repo root, found `"$p`""); return
        }
    }
    $clean = [System.Collections.Generic.List[string]]::new()
    foreach ($p in $paths) {
        $q2 = $p.TrimEnd('/')
        $full = $script:RepoRoot + '/' + $q2
        if (-not ([System.IO.File]::Exists($full) -or [System.IO.Directory]::Exists($full))) {
            $script:Findings.Add("sites searched: expected an existing path, found `"$q2`""); return
        }
        $clean.Add($q2)
    }
    if (-not (Test-PatternSubset $pattern)) {
        $script:Findings.Add("sites searched: expected a pattern in the shared ERE subset, found `"$pattern`""); return
    }
    $asLatin1 = [System.Text.Encoding]::Latin1.GetString([System.Text.Encoding]::UTF8.GetBytes($pattern))
    try { $re = [regex]::new($asLatin1, [System.Text.RegularExpressions.RegexOptions]::CultureInvariant) }
    catch { $script:Findings.Add("sites searched: expected a valid pattern, found `"$pattern`""); return }
    $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($p in $clean) { Get-SiteMatches $script:RepoRoot $p $re $set }
    $sorted = [string[]]@($set)
    [Array]::Sort($sorted, [StringComparer]::Ordinal)
    foreach ($f in $sorted) {
        if ($script:BodyText.IndexOf($f, [StringComparison]::Ordinal) -lt 0) {
            $script:Findings.Add("sites searched: expected `"$f`" in the body, found none")
        }
    }
}

function Get-LineLabel {
    param([string]$Line)
    $s = $Line.TrimStart(' ', "`t")
    if ($s.StartsWith('- ', [StringComparison]::Ordinal) -or $s.StartsWith('* ', [StringComparison]::Ordinal)) { $s = $s.Substring(2) }
    return $s
}

function Test-SitesSearched {
    for ($i = 0; $i -lt $script:Lines.Count; $i++) {
        if ($script:InFence[$i]) { continue }
        $s = Get-LineLabel $script:Lines[$i]
        if (-not $s.StartsWith('Sites searched:', [StringComparison]::Ordinal)) { continue }
        $spans = Get-LineSpans $script:Lines[$i]
        $cmd = ''
        if ($spans.Count -gt 0) { $cmd = $spans[0] }
        Test-SiteCommand $cmd
    }
}

function Test-Vocabulary {
    $words = @('comprehensive', 'robust', 'seamless', 'leverage', 'ensure that', 'in order to', 'it is important to note', 'should ideally', 'as appropriate')
    for ($i = 0; $i -lt $script:Lines.Count; $i++) {
        if ($script:InFence[$i]) { continue }
        $folded = ConvertTo-AsciiLower $script:Lines[$i]
        foreach ($w in $words) {
            if ($folded.IndexOf($w, [StringComparison]::Ordinal) -ge 0) {
                $script:Findings.Add("vocabulary: expected no `"$w`", found it on line $($i + 1)")
            }
        }
    }
}

function Test-PlatformSource {
    if ($script:Mode -cne 'bug') { return }
    for ($i = 0; $i -lt $script:Lines.Count; $i++) {
        if ($script:InFence[$i]) { continue }
        $s = Get-LineLabel $script:Lines[$i]
        if ($s.StartsWith('Platform source:', [StringComparison]::Ordinal)) { return }
    }
    $script:Findings.Add('platform source: expected a "Platform source:" line, found none')
}

function Test-Edges {
    if (-not $script:HaveEdges) { return }
    $start, $end = Get-SectionBounds '## Dependencies'
    $entries = [System.Collections.Generic.List[object]]::new()
    $opts = [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    for ($i = $start + 1; $i -lt $end; $i++) {
        if ($script:InFence[$i]) { continue }
        $label = Get-LineLabel $script:Lines[$i]
        $kind = 'D'
        $m = [regex]::Match($label, '^Depends on #([A-Za-z0-9]+)', $opts)
        if (-not $m.Success) {
            $kind = 'S'
            $m = [regex]::Match($label, '#([A-Za-z0-9]+)', $opts)
        }
        if ($m.Success) { $entries.Add(@{ Kind = $kind; Tag = $m.Groups[1].Value; Line = $i + 1 }) }
    }
    $listed = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($tag in $script:EdgeTags) {
        if (-not $listed.Add($tag)) { continue }
        $seen = $false
        foreach ($en in $entries) { if ($en.Kind -ceq 'D' -and $en.Tag -ceq $tag) { $seen = $true } }
        if (-not $seen) { $script:Findings.Add("edges: expected a `"Depends on #$tag`" line under `"## Dependencies`", found none") }
    }
    foreach ($en in $entries) {
        if ($en.Kind -ceq 'D') {
            if (-not $listed.Contains($en.Tag)) { $script:Findings.Add("edges: expected no `"Depends on #$($en.Tag)`" line under `"## Dependencies`", found one") }
        }
        else {
            $script:Findings.Add("edges: expected no `"#$($en.Tag)`" under `"## Dependencies`" outside a `"Depends on`" line, found it on line $($en.Line)")
        }
    }
}

function Invoke-Main {
    if ((Read-Arguments $argv) -ne 0) { Write-Err $script:Usage; return 2 }
    Resolve-Arguments
    $code = [int](@(Test-Inputs) | Select-Object -Last 1)
    if ($code -ne 0) { return 2 }
    Read-Body
    Test-Sections
    Test-Invariants
    Test-Citations
    Test-SitesSearched
    Test-Vocabulary
    Test-PlatformSource
    Test-Edges
    foreach ($f in $script:Findings) { Write-Row $f }
    if ($script:Findings.Count -eq 0) { return 0 }
    return 1
}

$result = Invoke-Main
exit ([int](@($result) | Select-Object -Last 1))
