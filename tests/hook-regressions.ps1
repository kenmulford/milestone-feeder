#!/usr/bin/env pwsh
param(
    [Parameter(Mandatory)][ValidateSet('ps1', 'sh')][string]$Leg,
    [string]$BashPath,
    [string]$Repository = (Split-Path $PSScriptRoot -Parent)
)
$ErrorActionPreference = 'Stop'
if (-not $BashPath) {
    $BashPath = if ($IsWindows) { 'C:/Program Files/Git/bin/bash.exe' } else { (Get-Command bash).Source }
}
if (-not (Test-Path $BashPath)) { throw "Bash not found: $BashPath" }
$pwsh = (Get-Command pwsh).Source
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('feeder-hook-tests-' + [guid]::NewGuid().ToString('N'))
$failures = [Collections.Generic.List[string]]::new()
$script:checks = 0
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
function Check([string]$Name, [int]$Expected, [hashtable]$Result) {
    $script:checks++
    if ($Result.Code -ne $Expected) {
        $failures.Add("${Name}: expected $Expected, got $($Result.Code); $($Result.Error.Trim())")
        Write-Host "FAIL $Name"
    } elseif ($Expected -eq 2 -and $Result.Error -notmatch 'milestone-feeder: edits to source') {
        $failures.Add("${Name}: exit 2 lacked the policy diagnostic: $($Result.Error.Trim())")
        Write-Host "FAIL $Name"
    } else { Write-Host "PASS $Name" }
}
function Gate([string]$Name, [hashtable]$ToolInput, [int]$Expected = 2, [hashtable]$Actor = @{}) {
    $payload = @{ cwd = $scratch; tool_name = 'apply_patch'; tool_input = $ToolInput }
    foreach ($key in $Actor.Keys) { $payload[$key] = $Actor[$key] }
    $json = ConvertTo-Json -Depth 10 -Compress $payload
    $arguments = if ($Leg -eq 'ps1') { @('-NoProfile', '-File', "$Repository/hooks/no-source-edit.ps1") } else { @("$Repository/hooks/no-source-edit.sh") }
    Check $Name $Expected (Run-Process $(if ($Leg -eq 'ps1') { $pwsh } else { $BashPath }) $arguments $json)
}
# Real Codex 0.163.0 PreToolUse payloads (tests/fixtures). Codex fails open on
# exit 2, so a Codex deny is stdout permissionDecision JSON with exit 0.
function Codex-Gate([string]$Name, [string]$Fixture, [string]$Command, [string]$Expected, [hashtable]$Override = @{}, [switch]$AsciiOnly) {
    $payload = Get-Content "$Repository/tests/fixtures/$Fixture" -Raw | ConvertFrom-Json -AsHashtable
    $payload.cwd = $scratch
    $payload.tool_input.command = $Command
    foreach ($key in $Override.Keys) { $payload[$key] = $Override[$key] }
    $arguments = if ($Leg -eq 'ps1') { @('-NoProfile', '-File', "$Repository/hooks/no-source-edit.ps1") } else { @("$Repository/hooks/no-source-edit.sh") }
    $result = Run-Process $(if ($Leg -eq 'ps1') { $pwsh } else { $BashPath }) $arguments (ConvertTo-Json -Depth 10 -Compress $payload)
    $script:checks++
    $decision = $null
    try { $decision = ($result.Out | ConvertFrom-Json -ErrorAction Stop).hookSpecificOutput } catch { }
    $ok = if ($Expected -eq 'deny') {
        $result.Code -eq 0 -and $decision.hookEventName -eq 'PreToolUse' -and $decision.permissionDecision -eq 'deny' -and $decision.permissionDecisionReason -match 'milestone-feeder: edits to source'
    } else { $result.Code -eq 0 -and -not $result.Out.Trim() }
    # Codex on Windows reads hook stdout in the console code page; non-ASCII breaks the JSON.
    # The escaped path must still decode to the non-ASCII original, so the input survived.
    if ($AsciiOnly -and ($result.Out -cnotmatch '^[\x00-\x7F]*$' -or -not "$($decision.permissionDecisionReason)".Contains("caf$([char]0xE9)"))) { $ok = $false }
    if ($ok) { Write-Host "PASS $Name" }
    else { $failures.Add("${Name}: expected $Expected, got exit $($result.Code), stdout [$($result.Out.Trim())], stderr [$($result.Error.Trim())]"); Write-Host "FAIL $Name" }
}function Patch([string]$Text) { return @{ command = "*** Begin Patch`n$Text`n*** End Patch" } }
function Write-Config([string]$File, [string]$Json) { [IO.File]::WriteAllText((Join-Path $scratch $File), $Json) }
function Check-NormalizedPath([string]$Name, [string]$Path, [string]$Base, [string]$Expected) {
    # Execute the shipped normalizer alone so UNC fixtures never touch a share.
    $fixture = Join-Path $scratch "normalize.$Leg"
    if ($Leg -eq 'ps1') {
        [IO.File]::WriteAllText($fixture, 'param($Target, $Base)' + "`n. '$Repository/hooks/patch-input.ps1'`nConvertTo-HookPath " + '$Target $Base')
        $result = Run-Process $pwsh @('-NoProfile', '-File', $fixture, $Path, $Base)
    } else {
        [IO.File]::WriteAllText($fixture, ". '$Repository/hooks/patch-input.sh'`n" + 'normalize_hook_path "$1" "$2"' + "`n")
        $result = Run-Process $BashPath @($fixture, $Path, $Base)
    }
    $script:checks++
    if ($result.Code -eq 0 -and $result.Out.TrimEnd("`r", "`n") -ceq $Expected) { Write-Host "PASS $Name" }
    else { $failures.Add("${Name}: expected [$Expected], got [$($result.Out.TrimEnd())], exit $($result.Code); $($result.Error)"); Write-Host "FAIL $Name" }
}
try {
    New-Item -ItemType Directory -Path "$scratch/.milestone-config", "$scratch/launcher" -Force | Out-Null
    Check-NormalizedPath 'UNC root preserved' '//server/share/repo/..' '/local' '//server/share'
    Check-NormalizedPath 'backslash UNC root preserved' '\\server\share\repo\..' '/local' '//server/share'
    Check-NormalizedPath 'relative source under UNC base preserved' 'docs/../app/a.rb' '//server/share/repo' '//server/share/repo/app/a.rb'
    Write-Config '.milestone-config/feeder.json' '{"sourceGlobs":["app/**","hooks/**","agents/**"]}'
    Write-Config '.milestone-config/driver.json' '{"sourceGlobs":["driver-only/**"]}'
    Gate 'main patch add blocked' (Patch "*** Add File: app/new.rb`n+x")
    foreach ($actor in @('architect', 'issue-author', 'roadmap-splitter', 'remediator')) {
        Gate "feeder $actor blocked" (Patch "*** Update File: app/a.rb`n@@`n-x`n+y") 2 @{ agent_id = 'child'; agent_type = $actor }
    }
    Gate 'identified non-feeder child allowed' (Patch '*** Delete File: app/a.rb') 0 @{ agent_id = 'child'; agent_type = 'implementer' }
    Gate 'child without type blocked' (Patch '*** Delete File: app/a.rb') 2 @{ agent_id = 'child' }
    Gate 'child with empty type blocked' (Patch '*** Delete File: app/a.rb') 2 @{ agent_id = 'child'; agent_type = '' }
    Gate 'type without child id blocked' (Patch '*** Delete File: app/a.rb') 2 @{ agent_type = 'implementer' }
    foreach ($operation in @('Add', 'Update', 'Delete')) {
        $body = if ($operation -eq 'Add') { "`n+x" } elseif ($operation -eq 'Update') { "`n@@`n-x`n+y" } else { '' }
        Gate "docs first then $operation source blocked" (Patch "*** Add File: docs/ok.md`n+ok`n*** ${operation} File: app/a.rb$body")
    }
    Gate 'docs first then hooks source blocked' (Patch "*** Add File: docs/ok.md`n+ok`n*** Update File: hooks/gate.sh`n@@`n-a`n+b")
    Gate 'move into source blocked' (Patch "*** Update File: docs/ok.md`n*** Move to: app/a.rb`n@@`n-a`n+b")
    Gate 'move out of source blocked' (Patch "*** Update File: app/a.rb`n*** Move to: docs/ok.md`n@@`n-a`n+b")
    Gate 'all exempt patch allowed' (Patch "*** Add File: docs/a.md`n+x`n*** Update File: .claude/settings.json`n@@`n-a`n+b`n*** Delete File: Obsidian/a.md") 0
    Gate 'source-looking added content ignored' (Patch "*** Add File: docs/a.md`n+*** Add File: app/fake.rb`n+*** Move to: hooks/fake.sh") 0
    Gate 'source-looking removed and context content ignored' (Patch "*** Update File: docs/a.md`n@@`n-*** Delete File: app/fake.rb`n *** Update File: hooks/fake.sh`n+safe") 0
    foreach ($path in @('./app/a.rb', 'docs/../app/a.rb', 'docs/nested/../../hooks/a.sh', 'docs\..\app\a.rb', 'app//nested/../a.rb', "$scratch/docs/../app/a.rb")) {
        Gate "normalized source $path" (Patch "*** Add File: $path`n+x")
    }
    Gate 'normalized move destination blocked' (Patch "*** Update File: docs/a.md`n*** Move to: docs/../hooks/a.sh`n@@`n-a`n+b")
    Gate 'normalized exempt path allowed' (Patch "*** Add File: app/../docs/a.md`n+x") 0
    Gate 'UNC protected target cannot use docs exemption' (Patch "*** Add File: //server/share/repo/docs/../app/a.rb`n+x")
    Gate 'CRLF patch blocked' @{ command = "*** Begin Patch`r`n*** Add File: app/a.rb`r`n+x`r`n*** End Patch`r`n" }
    Gate 'path with spaces blocked' (Patch "*** Add File: app/folder with spaces/a.rb`n+x")
    Gate 'source glob still covers markdown' (Patch "*** Add File: agents/new.md`n+x")
    $codexSource = "*** Begin Patch`n*** Add File: app/a.rb`n+x`n*** End Patch"
    Codex-Gate 'codex main thread source denied' 'codex-pretooluse-main.json' $codexSource 'deny'
    Codex-Gate 'codex main thread docs allowed' 'codex-pretooluse-main.json' "*** Begin Patch`n*** Add File: docs/a.md`n+x`n*** End Patch" 'allow'
    # Codex guards the main thread only: any child with an agent_id passes.
    foreach ($builtin in @('default', 'worker', 'explorer')) {
        Codex-Gate "codex $builtin child source allowed" 'codex-pretooluse-child.json' $codexSource 'allow' @{ agent_type = $builtin }
    }
    Codex-Gate 'codex child without agent_id denied' 'codex-pretooluse-child.json' $codexSource 'deny' @{ agent_id = '' }
    Codex-Gate 'codex child docs allowed' 'codex-pretooluse-child.json' "*** Begin Patch`n*** Add File: docs/a.md`n+x`n*** End Patch" 'allow'
    Codex-Gate 'codex named non-feeder child allowed' 'codex-pretooluse-child.json' $codexSource 'allow' @{ agent_type = 'implementer' }
    Codex-Gate 'codex named feeder child denied' 'codex-pretooluse-child.json' $codexSource 'deny' @{ agent_type = 'architect' }
    Codex-Gate 'codex non-ascii path deny is ascii json' 'codex-pretooluse-main.json' "*** Begin Patch`n*** Add File: app/caf$([char]0xE9).rb`n+x`n*** End Patch" 'deny' -AsciiOnly
    Codex-Gate 'codex delete of hooks source denied' 'codex-pretooluse-main.json' "*** Begin Patch`n*** Delete File: hooks/gate.sh`n*** End Patch" 'deny'
    foreach ($key in @('file_path', 'notebook_path')) {
        Gate "legacy $key blocked" @{ $key = "$scratch/app/a.rb" }
        Gate "legacy $key docs allowed" @{ $key = "$scratch/docs/a.md" } 0
        Gate "legacy $key normalization blocked" @{ $key = 'docs/../app/a.rb' }
        Gate "legacy $key absolute exemption bypass blocked" @{ $key = "$scratch/docs/../app/a.rb" }
    }
    Gate 'feeder profile precedence' (Patch "*** Add File: driver-only/a.rb`n+x") 0
    Write-Config '.milestone-config/feeder.json' '{"sourceGlobs":[]}'
    Gate 'driver profile fallback blocked' (Patch '*** Delete File: driver-only/a.rb')
    Write-Config '.milestone-config/driver.json' '{bad'
    Write-Config 'milestone-driver.json' '{"sourceGlobs":["root-only/**"]}'
    Gate 'malformed driver profile falls back to root' (Patch '*** Delete File: root-only/a.rb')
    Write-Config 'milestone-driver.json' '{}'
    Gate 'no globs fail open' (Patch '*** Delete File: app/a.rb') 0
    Remove-Item -LiteralPath "$scratch/.milestone-config/feeder.json", "$scratch/.milestone-config/driver.json", "$scratch/milestone-driver.json"
    Gate 'missing profiles fail open' (Patch '*** Delete File: app/a.rb') 0
    Write-Config '.milestone-config/feeder.json' '{"sourceGlobs":["app/**"]}'
    Gate 'missing tool paths fail open' @{} 0
    Gate 'shell command ignored' @{ command = 'echo hello > app/a.rb' } 0
    $bash = @{ cwd = $scratch; tool_name = 'Bash'; tool_input = @{ command = 'git status' } }
    Check 'codex Bash non-matching command passes' 0 (Run-Process $(if ($Leg -eq 'ps1') { $pwsh } else { $BashPath }) $(if ($Leg -eq 'ps1') { @('-NoProfile', '-File', "$Repository/hooks/no-source-edit.ps1") } else { @("$Repository/hooks/no-source-edit.sh") }) (ConvertTo-Json -Compress $bash))
    Gate 'patch after leading text blocked' @{ command = "apply_patch <<'EOF'`n*** Begin Patch`n*** Add File: app/a.rb`n+x`n*** End Patch`nEOF" }
    Gate 'operations after End Patch ignored' @{ command = "*** Begin Patch`n*** Add File: docs/a.md`n+x`n*** End Patch`n*** Add File: app/a.rb" } 0
    Gate 'move outside update ignored' (Patch "*** Add File: docs/a.md`n*** Move to: app/a.rb`n+x") 0
    Gate 'trailing whitespace target blocked' (Patch "*** Delete File: app/a.rb   ")
    $env:CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT = '1'
    Gate 'escape hatch' (Patch '*** Delete File: app/a.rb') 0
    Remove-Item Env:CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT
    $exe = if ($Leg -eq 'ps1') { $pwsh } else { $BashPath }
    $gateArgs = if ($Leg -eq 'ps1') { @('-NoProfile', '-File', "$Repository/hooks/no-source-edit.ps1") } else { @("$Repository/hooks/no-source-edit.sh") }
    Check 'empty stdin fail open' 0 (Run-Process $exe $gateArgs '')
    Check 'invalid json fail open' 0 (Run-Process $exe $gateArgs '{')
    Copy-Item "$Repository/hooks/run-hook.cmd" "$scratch/launcher/run-hook.cmd"
    foreach ($code in @(0, 2, 7)) {
        [IO.File]::WriteAllText("$scratch/launcher/status.sh", "#!/usr/bin/env bash`nexit $code`n")
        [IO.File]::WriteAllText("$scratch/launcher/status.ps1", "exit $code`n")
        # Check launcher exits directly; its children intentionally have no policy message.
        foreach ($platform in @('unix', 'windows')) {
            if ($platform -eq 'windows' -and -not $IsWindows) { continue }
            $result = if ($platform -eq 'unix') { Run-Process $BashPath @("$scratch/launcher/run-hook.cmd", 'status') } else { Run-Process $env:ComSpec @('/d', '/c', "$scratch/launcher/run-hook.cmd", 'status') }
            $script:checks++
            if ($result.Code -ne $code) { $failures.Add("launcher $platform status ${code}: expected $code, got $($result.Code); $($result.Error)"); Write-Host "FAIL launcher $platform $code" } else { Write-Host "PASS launcher $platform $code" }
        }
    }
} finally {
    Remove-Item Env:CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT -ErrorAction SilentlyContinue
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar)
    $resolvedScratch = [IO.Path]::GetFullPath($scratch)
    if ($resolvedScratch.StartsWith($tempRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase) -and
        [IO.Path]::GetFileName($resolvedScratch) -match '^feeder-hook-tests-[a-f0-9]{32}$') {
        Remove-Item -LiteralPath $resolvedScratch -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Write-Host "$Leg`: $($checks - $failures.Count)/$checks passed"
if ($failures.Count) { $failures | ForEach-Object { Write-Host $_ }; exit 1 }
exit 0
