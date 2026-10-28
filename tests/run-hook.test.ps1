#!/usr/bin/env pwsh
# hooks/run-hook.cmd must return its gate's exit code (0, 2, 7) through every
# interpreter branch: Windows git64, git32, PATH bash, PATH pwsh, none (exit 0),
# and the Unix sh half. A launcher that drops exit 2 makes every gate fail open.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$source = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '../hooks/run-hook.cmd'))
$bashBin = if ($IsWindows) { 'C:\Program Files\Git\bin\bash.exe' } else { (Get-Command bash).Source }
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$tmp = Join-Path $tempRoot ('milestone-feeder-launcher-' + [guid]::NewGuid().ToString())
$utf8 = [Text.UTF8Encoding]::new($false)
$pass = 0; $fail = 0

function Invoke-Child([string]$Exe, [string[]]$Argv, [hashtable]$Env) {
    $psi = [Diagnostics.ProcessStartInfo]::new($Exe)
    foreach ($a in $Argv) { $psi.ArgumentList.Add($a) }
    $psi.WorkingDirectory = $tmp
    $psi.RedirectStandardInput = $true; $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    foreach ($k in $Env.Keys) { $psi.Environment[$k] = $Env[$k] }
    $p = [Diagnostics.Process]::Start($psi)
    $p.StandardInput.Close()
    $errTask = $p.StandardError.ReadToEndAsync()
    $out = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    [pscustomobject]@{ rc = $p.ExitCode; out = $out.Trim(); err = $errTask.Result.Trim() }
}

New-Item -ItemType Directory -Path $tmp | Out-Null
try {
    if ($IsWindows) {
        $pwshDir = Split-Path (Get-Command pwsh).Source -Parent
        Copy-Item -LiteralPath "$env:SystemRoot/System32/where.exe" -Destination $tmp
        foreach ($branch in @('git64', 'git32', 'path-bash', 'path-pwsh', 'none')) {
            # Repoint the fixed Git paths in an isolated copy; the interpreters stay real.
            $first = if ($branch -eq 'git64') { $bashBin } else { Join-Path $tmp 'missing64.exe' }
            $second = if ($branch -eq 'git32') { $bashBin } else { Join-Path $tmp 'missing32.exe' }
            $launcher = $source.Replace('C:\Program Files\Git\bin\bash.exe', $first).Replace('C:\Program Files (x86)\Git\bin\bash.exe', $second)
            [IO.File]::WriteAllText("$tmp/run-hook.cmd", $launcher, $utf8)
            $pathValue = switch ($branch) { 'path-bash' { "$(Split-Path $bashBin -Parent);$tmp" } 'path-pwsh' { "$pwshDir;$tmp" } default { $tmp } }
            foreach ($code in @(0, 2, 7)) {
                [IO.File]::WriteAllText("$tmp/fixture.sh", "printf bash`nexit $code`n", $utf8)
                [IO.File]::WriteAllText("$tmp/fixture.ps1", "[Console]::Write('pwsh'); exit $code`n", $utf8)
                $r = Invoke-Child $env:ComSpec @('/d', '/c', (Join-Path $tmp 'run-hook.cmd'), 'fixture') @{ PATH = $pathValue }
                $want = if ($branch -eq 'none') { 0 } else { $code }
                $wantOut = switch ($branch) { 'none' { '' } 'path-pwsh' { 'pwsh' } default { 'bash' } }
                if ($r.rc -eq $want -and $r.out -eq $wantOut) { $pass++ }
                else { $fail++; Write-Host "FAIL $branch exit $code : rc=$($r.rc) want=$want out=[$($r.out)] err=[$($r.err)]" }
            }
        }
    }
    foreach ($code in @(0, 2, 7)) {
        [IO.File]::WriteAllText("$tmp/run-hook.cmd", $source, $utf8)
        [IO.File]::WriteAllText("$tmp/fixture.sh", "exit $code`n", $utf8)
        $r = Invoke-Child $bashBin @("$tmp/run-hook.cmd", 'fixture') @{}
        if ($r.rc -eq $code) { $pass++ } else { $fail++; Write-Host "FAIL unix exit $code : rc=$($r.rc) err=[$($r.err)]" }
    }
} finally {
    $resolved = [IO.Path]::GetFullPath($tmp)
    if ([IO.Path]::GetDirectoryName($resolved) -ne $tempRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) -or [IO.Path]::GetFileName($resolved) -notmatch '^milestone-feeder-launcher-[0-9a-f-]{36}$') { throw "Unsafe fixture cleanup path: $resolved" }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
Write-Host "run-hook: $pass passed, $fail failed"
if ($fail) { exit 1 }
