# milestone-feeder: Codex apply_patch target parsing and lexical path
# normalization, dot-sourced by no-source-edit.ps1. Same contract as
# milestone-driver's hooks/patch-input.ps1 (the plugins ship independently, so
# this is a copy, not a reference).

# Every Add/Update/Delete target and every Update's Move-to destination between
# `*** Begin Patch` and `*** End Patch`. Hunk lines carry a +, - or space
# prefix, so their content is never read as an operation header.
function Read-CodexPatch([string]$Command) {
    $paths = [Collections.Generic.List[string]]::new()
    $active = $false; $mode = ''
    foreach ($line in ($Command -split "`n")) {
        $line = $line.TrimEnd("`r")
        if (-not $active) {
            if ($line -ceq '*** Begin Patch') { $active = $true }
            continue
        }
        if ($line -ceq '*** End Patch') { break }
        if ($line -cmatch '^\*\*\* (Add|Update|Delete) File: (.+)$') {
            $mode = $Matches[1]; $paths.Add($Matches[2].Trim())
        } elseif ($mode -ceq 'Update' -and $line -cmatch '^\*\*\* Move to: (.+)$') {
            $paths.Add($Matches[1].Trim())
        }
    }
    return @{ Paths = $paths.ToArray() }
}

# Lexical only, so new and deleted paths need not exist. Backslashes become
# slashes; drive, UNC and root prefixes survive.
function ConvertTo-HookPath([string]$Path, [string]$BasePath) {
    $pathText = $Path.Replace('\', '/')
    if ($pathText -notmatch '^(/|[A-Za-z]:/)') { $pathText = "$BasePath/$pathText" }
    $prefix = ''
    if ($pathText -match '^[A-Za-z]:/') { $prefix = $pathText.Substring(0, 3); $pathText = $pathText.Substring(3) }
    elseif ($pathText.StartsWith('//')) { $prefix = '//'; $pathText = $pathText.Substring(2) }
    elseif ($pathText.StartsWith('/')) { $prefix = '/'; $pathText = $pathText.Substring(1) }
    $parts = [Collections.Generic.List[string]]::new()
    foreach ($part in ($pathText -split '/')) {
        if (-not $part -or $part -eq '.') { continue }
        if ($part -eq '..') { if ($parts.Count) { $parts.RemoveAt($parts.Count - 1) }; continue }
        $parts.Add($part)
    }
    return $prefix + ($parts -join '/')
}
