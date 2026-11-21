#!/usr/bin/env pwsh
# scripts/build-order.sh and scripts/build-order.ps1 must print byte-identical
# stdout, stderr and exit code on every case under tests/fixtures/build-order/,
# each equal to the case's expected.stdout, expected.stderr and expected.exit.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$bashBin = if ($IsWindows) { 'C:\Program Files\Git\bin\bash.exe' } else { (Get-Command bash).Source }
$pwshBin = (Get-Command pwsh).Source
$pass = 0; $fail = 0

function Invoke-Child([string]$Exe, [string[]]$Argv) {
    $psi = [Diagnostics.ProcessStartInfo]::new($Exe)
    foreach ($a in $Argv) { $psi.ArgumentList.Add($a) }
    $psi.WorkingDirectory = $repo
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $p = [Diagnostics.Process]::Start($psi)
    $p.StandardInput.Close()
    $errTask = $p.StandardError.ReadToEndAsync()
    $out = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    [pscustomobject]@{ rc = $p.ExitCode; out = $out; err = $errTask.Result }
}

function Test-Leg([string]$Case, [string]$Leg, [string]$InPath, [string]$WantOut, [string]$WantErr, [int]$WantRc) {
    $r = if ($Leg -eq 'sh') { Invoke-Child $bashBin @('scripts/build-order.sh', $InPath) }
         else { Invoke-Child $pwshBin @('-NoProfile', '-File', 'scripts/build-order.ps1', $InPath) }
    if ($r.out -ceq $WantOut -and $r.err -ceq $WantErr -and $r.rc -eq $WantRc) { $script:pass++ }
    else {
        $script:fail++
        Write-Host "FAIL $Case ($Leg): rc=$($r.rc) want=$WantRc out=[$($r.out)] want=[$WantOut] err=[$($r.err)] want=[$WantErr]"
    }
}

$fixtures = Join-Path $repo 'tests/fixtures/build-order'
foreach ($dir in (Get-ChildItem -LiteralPath $fixtures -Directory | Sort-Object -Property Name -CaseSensitive)) {
    $wantOut = [IO.File]::ReadAllText((Join-Path $dir.FullName 'expected.stdout'))
    $wantErr = [IO.File]::ReadAllText((Join-Path $dir.FullName 'expected.stderr'))
    $wantRc = [int]([IO.File]::ReadAllText((Join-Path $dir.FullName 'expected.exit'))).Trim()
    $inPath = "tests/fixtures/build-order/$($dir.Name)/input.json"
    foreach ($leg in 'sh', 'ps1') { Test-Leg $dir.Name $leg $inPath $wantOut $wantErr $wantRc }
}

$absent = 'tests/fixtures/build-order/absent.json'
foreach ($leg in 'sh', 'ps1') {
    Test-Leg 'absent' $leg $absent '' "build-order: cannot read input file: $absent`n" 2
}

Write-Host "build-order: $pass passed, $fail failed"
if ($fail) { exit 1 }
