#!/usr/bin/env pwsh
#
# build-order.ps1: derive the shared-file `after` edges and the Wave lines from
# a candidate set (PowerShell twin of build-order.sh).
#
# Invocation (identical on both twins):
#   scripts/build-order.ps1 <input.json>      path relative to the CWD
#
# The input shape, output shape, exit codes (0 ok, 1 cycle, 2 bad input or
# usage) and the assigned order (tag length, then ordinal compare) are
# documented in build-order.sh's header; this twin prints the same bytes.
#
# stdout and stderr go through Write with an explicit "`n": WriteLine would
# append CRLF on Windows and break byte-identity with the bash twin.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-Out {
    param([string]$Text)
    [Console]::Out.Write($Text + "`n")
}

function Stop-Run {
    param([int]$Code, [string]$Message)
    [Console]::Error.Write($Message + "`n")
    exit $Code
}

function Stop-Bad {
    param([string]$Message)
    Stop-Run 2 "build-order: $Message"
}

function New-Map {
    [System.Collections.Hashtable]::new([System.StringComparer]::Ordinal)
}

function Get-Prop {
    param($Obj, [string]$Name)
    foreach ($p in $Obj.PSObject.Properties) {
        if ($p.Name -ceq $Name) { return , $p.Value }
    }
    return , $null
}

function Test-StrArray {
    param($V)
    if ($V -isnot [object[]]) { return $false }
    foreach ($x in $V) { if ($x -isnot [string]) { return $false } }
    return $true
}

$tagRe = '\A#[A-Za-z0-9_-]+\z'
$edgeRe = '\A(#[A-Za-z0-9_-]+) depends_on (#[A-Za-z0-9_-]+)(?: - .*)?\z'

if ($args.Count -ne 1) {
    Stop-Run 2 'usage: build-order <input.json>'
}
$path = [string]$args[0]
if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    Stop-Bad "cannot read input file: $path"
}
try {
    $raw = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $path).ProviderPath)
} catch {
    Stop-Bad "cannot read input file: $path"
}

$d = $null
try { $d = $raw | ConvertFrom-Json -DateKind String } catch { $d = $null }
if ($d -isnot [pscustomobject]) { Stop-Bad 'malformed input: not a JSON object' }

$cands = Get-Prop $d 'candidates'
if ($cands -isnot [object[]]) { Stop-Bad 'malformed input: candidates must be an array' }

foreach ($c in $cands) {
    $ok = $false
    if ($c -is [pscustomobject]) {
        $t = Get-Prop $c 'tag'
        if ($t -is [string] -and $t -cmatch $tagRe) { $ok = $true }
    }
    if (-not $ok) { Stop-Bad 'malformed input: candidate tag must match #[A-Za-z0-9_-]+' }
}
foreach ($c in $cands) {
    $e = Get-Prop $c 'edits'
    if ($null -ne $e -and -not (Test-StrArray $e)) {
        Stop-Bad "malformed input: edits of $(Get-Prop $c 'tag') must be an array of strings"
    }
}
$seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($c in $cands) {
    $t = [string](Get-Prop $c 'tag')
    if (-not $seen.Add($t)) { Stop-Bad "malformed input: duplicate tag $t" }
}
$edgesRaw = Get-Prop $d 'edges'
if ($null -ne $edgesRaw -and -not (Test-StrArray $edgesRaw)) {
    Stop-Bad 'malformed input: edges must be an array of strings'
}
$edges = if ($null -eq $edgesRaw) { @() } else { @($edgesRaw) }
foreach ($e in $edges) {
    if ($e -cnotmatch $edgeRe) { Stop-Bad "malformed input: edge is not a depends_on edge: $e" }
}
$depPairs = [System.Collections.Generic.List[object]]::new()
$pairSeen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($e in $edges) {
    $m = [regex]::Match($e, $edgeRe)
    foreach ($side in 1, 2) {
        if (-not $seen.Contains($m.Groups[$side].Value)) {
            Stop-Bad "edge names a tag absent from candidates: $($m.Groups[$side].Value)"
        }
    }
    if ($pairSeen.Add($m.Groups[1].Value + ' ' + $m.Groups[2].Value)) {
        $depPairs.Add(@($m.Groups[1].Value, $m.Groups[2].Value))
    }
}

$tags = [System.Collections.Generic.List[string]]::new()
foreach ($c in $cands) { $tags.Add([string](Get-Prop $c 'tag')) }
$tags.Sort([Comparison[string]] {
    param($a, $b)
    if ($a.Length -ne $b.Length) { return $a.Length - $b.Length }
    return [string]::CompareOrdinal($a, $b)
})
if ($tags.Count -eq 0) { exit 0 }

$rank = New-Map
for ($i = 0; $i -lt $tags.Count; $i++) { $rank[$tags[$i]] = $i }

$ed = New-Map
foreach ($c in $cands) {
    $list = [System.Collections.Generic.List[string]]::new()
    $e = Get-Prop $c 'edits'
    if ($null -ne $e) { foreach ($p in $e) { if (-not $list.Contains($p)) { $list.Add($p) } } }
    $ed[[string](Get-Prop $c 'tag')] = $list
}

function Get-Preds {
    param($Pairs)
    $pm = New-Map
    foreach ($p in $Pairs) {
        if (-not $pm.ContainsKey($p[0])) { $pm[$p[0]] = [System.Collections.Generic.List[string]]::new() }
        if (-not $pm[$p[0]].Contains($p[1])) { $pm[$p[0]].Add($p[1]) }
    }
    return $pm
}

function Get-Layers {
    param($Preds)
    $lvl = New-Map
    $rem = [System.Collections.Generic.List[string]]::new($tags)
    $k = 0
    while ($rem.Count -gt 0) {
        $ready = [System.Collections.Generic.List[string]]::new()
        foreach ($x in $rem) {
            $ok = $true
            if ($Preds.ContainsKey($x)) {
                foreach ($p in $Preds[$x]) { if ($rem.Contains($p)) { $ok = $false; break } }
            }
            if ($ok) { $ready.Add($x) }
        }
        if ($ready.Count -eq 0) { break }
        $k++
        foreach ($x in $ready) { $lvl[$x] = $k; [void]$rem.Remove($x) }
    }
    return @{ lvl = $lvl; rem = $rem }
}

$l1 = Get-Layers (Get-Preds $depPairs)
if ($l1.rem.Count -gt 0) {
    $r = [System.Collections.Generic.List[string]]::new($l1.rem)
    do {
        $keep = [System.Collections.Generic.List[string]]::new()
        foreach ($y in $r) {
            foreach ($p in $depPairs) {
                if ($p[1] -ceq $y -and $r.Contains($p[0])) { $keep.Add($y); break }
            }
        }
        $changed = $keep.Count -ne $r.Count
        $r = $keep
    } while ($changed)
    Stop-Run 1 ('build-order: cycle: ' + ($r -join ', '))
}

$related = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($p in $depPairs) { [void]$related.Add($p[0] + ' ' + $p[1]); [void]$related.Add($p[1] + ' ' + $p[0]) }

$after = [System.Collections.Generic.List[object]]::new()
for ($i = 0; $i -lt $tags.Count; $i++) {
    for ($j = $i + 1; $j -lt $tags.Count; $j++) {
        $a = $tags[$i]; $b = $tags[$j]
        if ($related.Contains("$a $b")) { continue }
        $shared = @($ed[$a] | Where-Object { $ed[$b].Contains($_) })
        if ($shared.Count -eq 0) { continue }
        if ($l1.lvl[$a] -ne $l1.lvl[$b]) { $aFirst = $l1.lvl[$a] -lt $l1.lvl[$b] }
        elseif ($ed[$a].Count -ne $ed[$b].Count) { $aFirst = $ed[$a].Count -lt $ed[$b].Count }
        else { $aFirst = $true }
        $first = if ($aFirst) { $a } else { $b }
        $later = if ($aFirst) { $b } else { $a }
        $paths = @($ed[$first] | Where-Object { $ed[$later].Contains($_) })
        $after.Add(@{ f = $first; l = $later; p = $paths })
    }
}
$after.Sort([Comparison[object]] {
    param($x, $y)
    if ($rank[$x.l] -ne $rank[$y.l]) { return $rank[$x.l] - $rank[$y.l] }
    return $rank[$x.f] - $rank[$y.f]
})

$allPairs = [System.Collections.Generic.List[object]]::new($depPairs)
foreach ($a in $after) { $allPairs.Add(@($a.l, $a.f)) }
$pm = Get-Preds $allPairs
$l2 = Get-Layers $pm

foreach ($a in $after) { Write-Out "$($a.l) after $($a.f) - edits: $($a.p -join ', ')" }
$maxk = 0
foreach ($t in $tags) { if ($l2.lvl[$t] -gt $maxk) { $maxk = $l2.lvl[$t] } }
for ($k = 1; $k -le $maxk; $k++) {
    $parts = [System.Collections.Generic.List[string]]::new()
    foreach ($t in $tags) {
        if ($l2.lvl[$t] -ne $k) { continue }
        if ($k -ge 2) {
            $ps = [System.Collections.Generic.List[string]]::new($pm[$t])
            $ps.Sort([Comparison[string]] { param($x, $y) $rank[$x] - $rank[$y] })
            $parts.Add("$t (depends on $($ps -join ', '))")
        } else {
            $parts.Add($t)
        }
    }
    $marker = if ($parts.Count -ge 2) { ' (parallel)' } else { '' }
    Write-Out "- Wave $k${marker}: $($parts -join ', ')"
}
