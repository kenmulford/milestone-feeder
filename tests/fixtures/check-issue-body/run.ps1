#!/usr/bin/env pwsh
# Runs every fixture directory beside this file against both twins of
# scripts/check-issue-body.

$ErrorActionPreference = 'Stop'
$Here = $PSScriptRoot
$Root = [System.IO.Path]::GetFullPath((Join-Path $Here '../../..'))
$ShTwin = Join-Path $Root 'scripts/check-issue-body.sh'
$PsTwin = Join-Path $Root 'scripts/check-issue-body.ps1'

$BashPath = if ($IsWindows) { 'C:/Program Files/Git/bin/bash.exe' } else { (Get-Command bash).Source }
$PwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $BashPath -or -not (Test-Path -LiteralPath $BashPath)) { Write-Output 'FAIL bash: not found'; exit 1 }
if (-not $PwshPath) { Write-Output 'FAIL pwsh: not found'; exit 1 }

function Run-Process([string]$Executable, [string[]]$Arguments, [string]$InputText = '') {
    $start = [Diagnostics.ProcessStartInfo]::new($Executable)
    $start.UseShellExecute = $false
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($item in $Arguments) { $start.ArgumentList.Add($item) }
    $process = [Diagnostics.Process]::Start($start)
    $outTask = $process.StandardOutput.ReadToEndAsync()
    $errTask = $process.StandardError.ReadToEndAsync()
    $process.StandardInput.Write($InputText)
    $process.StandardInput.Close()
    $process.WaitForExit()
    $result = @{ Code = $process.ExitCode; Out = $outTask.Result; Error = $errTask.Result }
    $process.Dispose()
    return $result
}

function Read-Expected([string]$Path, [string]$Dir) {
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $text = [System.IO.File]::ReadAllText($Path).Replace("`r", '')
    return $text.Replace('{dir}', $Dir)
}

$CitHere = [System.IO.Path]::GetFullPath((Join-Path $Here '../citations'))
$names = [string[]](Get-ChildItem -LiteralPath $Here -Directory | ForEach-Object { $_.Name })
[Array]::Sort($names, [StringComparer]::Ordinal)
$citNames = [string[]](Get-ChildItem -LiteralPath $CitHere -Directory | ForEach-Object { $_.Name })
[Array]::Sort($citNames, [StringComparer]::Ordinal)
$work = @($names | ForEach-Object { @{ Name = $_; Label = $_; Base = $Here } }) +
    @($citNames | ForEach-Object { @{ Name = $_; Label = "citations/$_"; Base = $CitHere } })
$failed = $false

foreach ($row in $work) {
    $name = $row.Name
    $label = $row.Label
    $base = $row.Base
    $dir = (Join-Path $base $name).Replace('\', '/')
    $argv = [System.Collections.Generic.List[string]]::new()
    $argText = [System.IO.File]::ReadAllText((Join-Path $base "$name/args")).Replace("`r", '')
    if ($argText.Length -gt 0) {
        $rows = $argText.Split("`n")
        $count = $rows.Count
        if ($argText.EndsWith("`n", [StringComparison]::Ordinal)) { $count-- }
        for ($i = 0; $i -lt $count; $i++) { $argv.Add($rows[$i].Replace('{dir}', $dir)) }
    }
    $wantCode = [int]([System.IO.File]::ReadAllText((Join-Path $base "$name/expected.exit")).Trim())
    $wantOut = Read-Expected (Join-Path $base "$name/expected.out") '{dir}'
    $wantErr = Read-Expected (Join-Path $base "$name/expected.err") $dir

    $legs = @(
        @{ Leg = 'sh'; Exe = $BashPath; Args = (@($ShTwin) + $argv.ToArray()) },
        @{ Leg = 'ps1'; Exe = $PwshPath; Args = (@('-NoProfile', '-File', $PsTwin) + $argv.ToArray()) }
    )
    foreach ($leg in $legs) {
        $r = Run-Process $leg.Exe ([string[]]$leg.Args)
        $diffs = @()
        if ($r.Code -ne $wantCode) { $diffs += "exit $($r.Code), expected $wantCode" }
        if ($r.Out.Replace("`r", '') -cne $wantOut) { $diffs += 'stdout differs' }
        if ($r.Error.Replace("`r", '') -cne $wantErr) { $diffs += 'stderr differs' }
        if ($diffs.Count -eq 0) { Write-Output "PASS $label $($leg.Leg)" }
        else { Write-Output "FAIL $label $($leg.Leg): $($diffs -join ', ')"; $failed = $true }
    }
}

if ($failed) { exit 1 }
exit 0
