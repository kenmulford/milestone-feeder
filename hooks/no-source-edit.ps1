#!/usr/bin/env pwsh
# milestone-feeder: no-source-edit gate (legacy edits and Codex apply_patch)
#
# Blocks edits to the feeder's own source globs. The feeder reads code and
# authors issue text; it never writes source. The deny applies to the feeder's
# OWN actors (the main thread and the feeder's own subagents); a positively-
# identified non-feeder subagent (e.g. the driver's implementer building the
# feeder) is allowed through. The orchestrator keeps /docs/, /.claude/, and
# /Obsidian/ paths (plus any file outside sourceGlobs) editable; files matching
# sourceGlobs are gated even when markdown.
#
# Actor gate (PreToolUse hooks carry no skill/plugin identity, only the agent
# fields below; see code.claude.com/docs/en/hooks.md):
#   - agent_id is present ONLY inside a subagent call; absent => main thread.
#   - agent_type is the subagent's BARE frontmatter `name` (NOT namespaced); for
#     custom subagents it is "the `name` field from the agent's frontmatter, not
#     the filename".
# Decision (only when the target matches a source glob):
#   BLOCK  when there is no agent_id (main thread) OR agent_type is one of the
#          feeder's OWN agents ($FeederOwnAgents below). Fail-closed: an
#          unknown/empty agent_type with an agent_id present also blocks.
#   ALLOW  when agent_id is present AND agent_type is a positively-identified
#          non-feeder subagent.
# Codex limitation: a payload carrying turn_id is Codex, and Codex gives every
# spawn_agent child a built-in agent_type, so a feeder agent and the driver's
# implementer look alike. The gate therefore guards only the main thread on
# Codex: any child with an agent_id passes, and the feeder's agents stay
# read-only by the instruction in each agent body.
#
# Deny mechanism: exit 2 + stderr on Claude Code. Codex fails open on exit 2, so
# a Codex payload gets stdout permissionDecision "deny" JSON and exit 0 instead.
# Deny globs: <repo>/.milestone-config/feeder.json first, then the resolved
#   driver config (.milestone-config/driver.json -> root milestone-driver.json).
#   First file with a non-empty sourceGlobs wins; none -> fail-open.
# Escape hatch: CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT=1
#
# Fail-open: any parse/IO error / unresolved sourceGlobs exits 0 so a hook bug
# never bricks editing.

# The feeder's OWN agent names (bare frontmatter `name`, NOT namespaced). This is
# a SECURITY control, so the set is HARDCODED here inside the protected hooks/**
# boundary rather than read from feeder.json. It MUST stay in sync with the
# `name:` of every agents/*.md (enforced by the CI drift-guard in
# scripts/validate-plugin-structure.py). Machine-parseable literal (one
# space-separated set on the next line; keep that exact shape for the guard):
# FEEDER_OWN_AGENTS: architect issue-author roadmap-splitter remediator
$FeederOwnAgents = @('architect', 'issue-author', 'roadmap-splitter', 'remediator')

if ($env:CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT -eq '1') { exit 0 }

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
try { $hook = $raw | ConvertFrom-Json -ErrorAction Stop } catch { exit 0 }

. (Join-Path $PSScriptRoot 'patch-input.ps1')

# Legacy edit tools carry one path; a Codex apply_patch carries every target in
# tool_input.command.
$paths = [Collections.Generic.List[string]]::new()
$filePath = $hook.tool_input.file_path
if (-not $filePath) { $filePath = $hook.tool_input.notebook_path }
if ($filePath) { $paths.Add([string]$filePath) }
foreach ($target in (Read-CodexPatch ([string]$hook.tool_input.command)).Paths) { $paths.Add($target) }
if ($paths.Count -eq 0) { exit 0 }

# Actor identity (see header). $hasAgentId distinguishes an absent agent_id (main
# thread) from a present one; $agentType is a plain string so a missing/empty
# value compares unequal to every name in $FeederOwnAgents.
$hasAgentId = $null -ne $hook.agent_id -and "$($hook.agent_id)" -ne ''
$agentType = [string]$hook.agent_type
$isCodex = $null -ne $hook.PSObject.Properties['turn_id']


# Resolve project dir.
$projectDir = $hook.cwd
if (-not $projectDir) { $projectDir = $env:CLAUDE_PROJECT_DIR }
if (-not $projectDir) { $projectDir = (Get-Location).Path }
$projectDir = ([string]$projectDir) -replace '\\', '/'
$projectDir = ConvertTo-HookPath $projectDir ((Get-Location).Path -replace '\\', '/')

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

# Exemptions apply to each normalized target; an exempt target cannot allow
# later source operations in the same patch.
foreach ($path in $paths) {
    $norm = ConvertTo-HookPath $path $projectDir
    if ($norm -cmatch '/(?:docs|\.claude|Obsidian)/') { continue }
    $rel = $norm
    if ($norm.StartsWith("$projectDir/", [StringComparison]::Ordinal)) { $rel = $norm.Substring($projectDir.Length + 1) }

    foreach ($g in $globs) {
        $pattern = ([string]$g) -replace '\\', '/'
        $pattern = $pattern -replace '\*\*', '*'   # ** -> * ; PowerShell -clike '*' already crosses '/'
        # Case-SENSITIVE (-clike) to match bash's case-sensitive `case` glob match.
        if (($rel -clike $pattern) -or ($norm -clike "*/$pattern")) {
            # Source-glob match. Apply the actor gate: ALLOW only a positively-
            # identified non-feeder subagent (agent_id present AND a non-empty
            # agent_type that is not one of the feeder's own agents). The main thread
            # (no agent_id), the feeder's own subagents, and any ambiguous actor
            # (agent_id present but empty agent_type) all fall through and are
            # BLOCKED (fail-closed).
            if ($hasAgentId -and $agentType -ne '' -and ($FeederOwnAgents -cnotcontains $agentType)) {
                exit 0   # positively-identified non-feeder subagent
            }
            $reason = "milestone-feeder: edits to source ('$rel') are blocked. The feeder authors no code. Set CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT=1 to override."
            if ($isCodex) {
                # ASCII-only: Codex on Windows reads this stdout in the console code page.
                @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; permissionDecision = 'deny'; permissionDecisionReason = $reason } } | ConvertTo-Json -Compress -EscapeHandling EscapeNonAscii
                exit 0
            }
            [Console]::Error.WriteLine($reason)
            exit 2
        }
    }
}

exit 0
