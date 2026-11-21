#!/usr/bin/env pwsh
#
# check-issue-body.ps1: deterministic checks over one authored issue body
# (PowerShell 7+ twin of check-issue-body.sh).
#
# Invocation (identical on both twins):
#   scripts/check-issue-body.ps1 <body-file> <repo-root>
#     [--invariants <file>] [--sections <file>] [--mode plan|bug]
#   Positional `$args` rather than a `param()` block, deliberately: the twins
#   take the SAME argv, `--flag` spelling included.
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
$script:Usage = 'usage: check-issue-body <body-file> <repo-root> [--invariants <file>] [--sections <file>] [--mode plan|bug]'
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

function Write-Err {
    param([string]$Message)
    [Console]::Error.WriteLine("check-issue-body: $Message")
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
        if ($a -ceq '--invariants' -or $a -ceq '--sections' -or $a -ceq '--mode') {
            if ($i + 1 -ge $Argv.Count) { return 2 }
            $sawFlag = $true
            $v = $Argv[$i + 1]
            if ($a -ceq '--invariants') { if ($script:HaveInv) { return 2 }; $script:HaveInv = $true; $script:InvFile = $v }
            elseif ($a -ceq '--sections') { if ($script:HaveSec) { return 2 }; $script:HaveSec = $true; $script:SecFile = $v }
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

function Test-ReadableFile {
    param([string]$Path)
    if (-not [System.IO.File]::Exists($Path)) { return $false }
    try { $s = [System.IO.File]::OpenRead($Path); $s.Dispose(); return $true } catch { return $false }
}

function Test-Inputs {
    if ($script:Mode -cne 'plan' -and $script:Mode -cne 'bug') {
        Write-Err "--mode must be plan or bug, got: $($script:Mode)"; return 2
    }
    if (-not (Test-ReadableFile $script:BodyFile)) { Write-Err "body file not found: $($script:BodyFile)"; return 2 }
    if (-not [System.IO.Directory]::Exists($script:RepoRoot)) { Write-Err "repo root is not a directory: $($script:RepoRoot)"; return 2 }
    if ($script:HaveInv) {
        if (-not (Test-ReadableFile $script:InvFile)) { Write-Err "invariants file not found: $($script:InvFile)"; return 2 }
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
        if (-not $ok) { Write-Err "invariants file is not a JSON array of entries carrying a string value: $($script:InvFile)"; return 2 }
        $script:InvValues = $values
    }
    if ($script:HaveSec) {
        if (-not (Test-ReadableFile $script:SecFile)) { Write-Err "sections file not found: $($script:SecFile)"; return 2 }
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

function Test-Invariants {
    if (-not $script:HaveInv) { return }
    foreach ($v in $script:InvValues) {
        if ($script:BodyText.IndexOf($v, [StringComparison]::Ordinal) -lt 0) {
            $script:Findings.Add("invariant: expected value `"$v`", found none")
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
        $s = $script:Lines[$i].TrimStart(' ', "`t")
        if ($s.StartsWith('- ', [StringComparison]::Ordinal) -or $s.StartsWith('* ', [StringComparison]::Ordinal)) { $s = $s.Substring(2) }
        if ($s.StartsWith('Platform source:', [StringComparison]::Ordinal)) { return }
    }
    $script:Findings.Add('platform source: expected a "Platform source:" line, found none')
}

function Invoke-Main {
    if ((Read-Arguments $argv) -ne 0) { Write-Err $script:Usage; return 2 }
    $code = [int](@(Test-Inputs) | Select-Object -Last 1)
    if ($code -ne 0) { return 2 }
    Read-Body
    Test-Sections
    Test-Invariants
    Test-Vocabulary
    Test-PlatformSource
    foreach ($f in $script:Findings) { Write-Row $f }
    if ($script:Findings.Count -eq 0) { return 0 }
    return 1
}

$result = Invoke-Main
exit ([int](@($result) | Select-Object -Last 1))
