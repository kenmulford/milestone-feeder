#!/usr/bin/env pwsh
# milestone-feeder — no-source-edit gate (Claude PreToolUse: Write|Edit|MultiEdit|NotebookEdit)
#
# Unconditionally blocks edits to the feeder's own source globs. The feeder
# reads code and authors issue text — it never writes source — so the deny
# applies in ANY context (no subagent carve-out). The orchestrator keeps
# /docs/, /.claude/, and /Obsidian/ paths (plus any file outside sourceGlobs)
# editable; files matching sourceGlobs are gated even when markdown.
#
# Deny mechanism: exit 2 + stderr (stable across current Claude Code).
# Deny globs: <repo>/.milestone-config/feeder.json first, then the resolved
#   driver config (.milestone-config/driver.json -> root milestone-driver.json).
#   First file with a non-empty sourceGlobs wins; none -> fail-open.
# Escape hatch: CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT=1
#
# Fail-open: any parse/IO error exits 0 so a hook bug never bricks editing.

if ($env:CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT -eq '1') { exit 0 }

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
try { $hook = $raw | ConvertFrom-Json -ErrorAction Stop } catch { exit 0 }

# Target file (Edit/Write/MultiEdit use file_path; NotebookEdit uses notebook_path).
$filePath = $hook.tool_input.file_path
if (-not $filePath) { $filePath = $hook.tool_input.notebook_path }
if (-not $filePath) { exit 0 }
$norm = ([string]$filePath) -replace '\\', '/'

# Always-exempt: docs, .claude config, Obsidian vaults. Source globs are gated even when markdown.
if ($norm -match '/docs/')    { exit 0 }
if ($norm -match '/\.claude/'){ exit 0 }
if ($norm -match '/Obsidian/'){ exit 0 }

# Resolve project dir.
$projectDir = $hook.cwd
if (-not $projectDir) { $projectDir = $env:CLAUDE_PROJECT_DIR }
if (-not $projectDir) { $projectDir = (Get-Location).Path }
$projectDir = ([string]$projectDir) -replace '\\', '/'

# Resolve the deny globs: feeder.json first (self-protection of the feeder's own
# repo), then the resolved driver config. First file with a non-empty
# sourceGlobs wins; none -> fail-open.
$globs = $null
foreach ($cfg in @(
    (Join-Path $projectDir '.milestone-config' 'feeder.json'),
    (Join-Path $projectDir '.milestone-config' 'driver.json'),
    (Join-Path $projectDir 'milestone-driver.json'))) {
    if (-not (Test-Path $cfg)) { continue }
    try { $parsed = Get-Content $cfg -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop } catch { continue }
    if ($parsed.sourceGlobs) { $globs = $parsed.sourceGlobs; break }
}
if (-not $globs) { exit 0 }

# Repo-relative path for matching.
$rel = $norm
if ($norm.StartsWith("$projectDir/")) { $rel = $norm.Substring($projectDir.Length + 1) }

foreach ($g in $globs) {
    $pattern = ([string]$g) -replace '\\', '/'
    $pattern = $pattern -replace '\*\*', '*'   # ** -> * ; PowerShell -like '*' already crosses '/'
    if (($rel -like $pattern) -or ($norm -like "*/$pattern")) {
        [Console]::Error.WriteLine("milestone-feeder: edits to source ('$rel') are blocked — the feeder authors no code. Set CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT=1 to override.")
        exit 2
    }
}

exit 0
