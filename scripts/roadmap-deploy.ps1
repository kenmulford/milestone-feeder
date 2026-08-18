#!/usr/bin/env pwsh
#
# roadmap-deploy.ps1: create's Step 1R roadmap outer-loop mechanics (PowerShell
# 7+ twin of roadmap-deploy.sh).
#
# What this does, in plain terms:
#   docs/create-deploy-sequence.md (Step 1R) describes a roadmap deploy: an
#   outer loop over the manifest's N milestones, each one guarded by a resume
#   checkpoint and each one recording its cross-milestone build-order line. The
#   three mechanical operations behind that prose live here, once, so this
#   script and its bash twin cannot drift from each other or from the doc. The
#   judgment steps (the resolution table, the per-milestone step table, the
#   reporting narrative) stay in the doc and in skills/create/SKILL.md.
#
# Invocation (one form, identical on both twins, so a caller documents one):
#
#   roadmap-deploy.ps1 checkpoint-read <slug> <position>
#     Row 0. Resolves this milestone's `Plan file:` path out of the roadmap
#     manifest, then consults the deploy checkpoint and runs the one cheap
#     existence check. Prints exactly three `key=value` lines, in this order:
#       planfile=<path>          (empty when the manifest has no entry)
#       short_circuit=<0|1>      (1 = confirmed fully deployed, skip passes a-d)
#       number=<n>               (the confirmed milestone number; empty on 0)
#
#   roadmap-deploy.ps1 checkpoint-upsert <slug> <position> <planfile> <number> <pass> <status>
#     Upsert-by-position. Rewrites this milestone's checkpoint entry in place,
#     never growing a duplicate. Call it at each pass-start and pass-end site
#     with that site's own <pass>/<status>. <number> is empty until pass (b)
#     resolves it, and is recorded as JSON null while empty.
#
#   roadmap-deploy.ps1 build-order-line <position> <total> <milestone-number> <goal> <waves>
#     Assembles milestone X's augmented description (the goal, the ONE canonical
#     `build order: milestone X of N` line, the slug-rewritten Waves block) and
#     applies it with pass (d)'s existing REPLACE-form PATCH. No new
#     read-modify-write of the description is added: pass (d) already replaces
#     the whole description every run, so the line is overwritten in place and
#     its count never grows.
#
#   Positional `$args` rather than a `param()` block, deliberately: the two
#   twins take the SAME argv, so a call site documents one invocation and
#   `param()` would fork that into two.
#
# Where the state lives:
#   .milestone-feeder/deploy-state-<slug>.json and
#   .milestone-feeder/roadmap-<slug>.md, both relative to the CURRENT working
#   directory: the consumer's repo root, where the calling skill already stands.
#   <slug> is derived by the identical rule the plan file and the roadmap
#   manifest use (skills/plan/SKILL.md Step 7); this script never derives it.
#
# Why no jq:
#   Native ConvertFrom-Json/ConvertTo-Json, so the PowerShell path carries no jq
#   dependency at all (mirrors hooks/no-source-edit.ps1's convention vs the bash
#   twin, and .project/library-manifest.md (## Approved libraries (by purpose))).
#   position and milestoneNumber are cast to [int] explicitly so ConvertTo-Json
#   always emits a JSON number, never a string a regex capture upstream could
#   have left un-typed: a string-typed position would never match the bash
#   reader's `--argjson x` numeric comparison, permanently defeating the
#   short-circuit.
#
# Failure posture, per operation (these differ deliberately):
#   checkpoint-read / checkpoint-upsert are FAIL-OPEN. An absent or 0-byte or
#   unreadable state file, a `gh` error, a title mismatch, a `state != "open"`,
#   or a failed write costs only this milestone's checkpoint: an upsert failure
#   emits a notice and returns WITHOUT aborting the deploy in progress, and a
#   read failure simply reports short_circuit=0 so this milestone falls through
#   to its own full deploy. No other milestone's entry is touched or affected.
#   build-order-line is NOT best-effort: it is pass (d)'s load-bearing
#   description write, so it exits with `gh`'s own status and the caller's
#   existing mid-loop failure path handles a non-zero.
#
# Parity with the bash twin (the emitted bytes are the contract):
#   Both twins print the same three `key=value` lines in the same order, the
#   same notice text, and the same assembled description. That description ends
#   at the last line of the Waves block on BOTH twins: the explicit LF joins
#   below carry no trailing newline, and the bash twin's command substitution
#   strips the one its printf format emits, so the two payloads agree byte for
#   byte. The joins are explicit rather than a here-string so the payload stays
#   LF on every host.
#
# Run it locally from a consumer repo root:
#   <plugin>/scripts/roadmap-deploy.ps1 checkpoint-read my-slug 1
#
# Exit codes:
#   0 = the operation ran (a fail-open operation reports 0 even when it skipped)
#   the `gh` exit status, for build-order-line only
#   2 = usage error (an unknown operation, or the wrong argument count)

function Show-Usage {
    [Console]::Error.WriteLine('usage: roadmap-deploy.ps1 checkpoint-read <slug> <position>')
    [Console]::Error.WriteLine('       roadmap-deploy.ps1 checkpoint-upsert <slug> <position> <planfile> <number> <pass> <status>')
    [Console]::Error.WriteLine('       roadmap-deploy.ps1 build-order-line <position> <total> <milestone-number> <goal> <waves>')
    exit 2
}

if ($args.Count -lt 1) { Show-Usage }
$op = [string]$args[0]

switch ($op) {

    # --- Row 0: resolve the plan file, consult the checkpoint, one cheap check
    #
    # $cpPass/$cpStatus/$cpNumber are the CHECKPOINT-RECORDED values,
    # deliberately NOT $pass/$status/$number, so they never collide with
    # checkpoint-upsert's caller-supplied parameters of those same names.
    'checkpoint-read' {
        if ($args.Count -ne 3) { Show-Usage }
        $slug = [string]$args[1]
        $X = [string]$args[2]

        $shortCircuit = $false
        $number = ''
        $manifest = ".milestone-feeder/roadmap-$slug.md"
        $state = ".milestone-feeder/deploy-state-$slug.json"

        $planfile = ''
        $inBlock = $false
        try {
            foreach ($line in (Get-Content -LiteralPath $manifest -ErrorAction Stop)) {
                if ($line -match "^### $X\. ") { $inBlock = $true; continue }
                if ($line -match '^### ') { $inBlock = $false }
                if ($inBlock -and $line -match '^- Plan file: *(.+)') { $planfile = $Matches[1]; break }
            }
        } catch { }

        # Length -gt 0 mirrors the bash twin's `-s`, not `-f`: an empty file is
        # treated the same as an absent one, so a corrupted-to-empty state file
        # is never accepted as valid content.
        $stateHasContent = (Test-Path -LiteralPath $state -PathType Leaf) -and ((Get-Item -LiteralPath $state).Length -gt 0)
        if ($stateHasContent) {
            try {
                $checkpoint = Get-Content -LiteralPath $state -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                $entry = $checkpoint.milestones | Where-Object { $_.position -eq [int]$X } | Select-Object -First 1
                if ($entry) {
                    $cpPass = $entry.pass
                    $cpStatus = $entry.status
                    $cpNumber = $entry.milestoneNumber
                    if ($cpPass -eq 'd' -and $cpStatus -eq 'complete' -and $cpNumber) {
                        $titleLine = Get-Content -LiteralPath $planfile -ErrorAction Stop | Where-Object { $_ -match '^Milestone title \(exact\): *(.+)' } | Select-Object -First 1
                        $null = $titleLine -match '^Milestone title \(exact\): *(.+)'
                        $title = $Matches[1]
                        # stdout only (2>$null): never merge gh's stderr into the
                        # JSON we parse below, so an incidental stderr line on an
                        # otherwise-successful call can never masquerade as
                        # unparsable JSON and force a false negative.
                        $live = gh api "repos/{owner}/{repo}/milestones/$cpNumber" --jq '{title, state}' 2>$null
                        if ($LASTEXITCODE -eq 0) {
                            $liveObj = $live | ConvertFrom-Json
                            if ($liveObj.title -eq $title -and $liveObj.state -eq 'open') {
                                $shortCircuit = $true
                                $number = $cpNumber
                            }
                        }
                    }
                }
            } catch { }
        }

        Write-Output "planfile=$planfile"
        Write-Output ("short_circuit=" + $(if ($shortCircuit) { '1' } else { '0' }))
        Write-Output "number=$number"
        exit 0
    }

    # --- upsert this milestone's checkpoint entry by position -----------------
    #
    # Fail-open: any error emits a notice and returns WITHOUT aborting the deploy
    # in progress. A 0-byte/absent state file is (re)seeded fresh (mirrors the
    # bash twin's `-s`, not `-f`, guard). $number is empty until pass (b)
    # resolves it.
    'checkpoint-upsert' {
        if ($args.Count -ne 7) { Show-Usage }
        $slug = [string]$args[1]
        $X = [string]$args[2]
        $planfile = [string]$args[3]
        $number = [string]$args[4]
        $pass = [string]$args[5]
        $status = [string]$args[6]

        $state = ".milestone-feeder/deploy-state-$slug.json"
        try {
            $stateHasContent = (Test-Path -LiteralPath $state -PathType Leaf) -and ((Get-Item -LiteralPath $state).Length -gt 0)
            $checkpoint = if ($stateHasContent) { Get-Content -LiteralPath $state -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop } else { [pscustomobject]@{ slug = $slug; milestones = @() } }
            $rest = @($checkpoint.milestones | Where-Object { $_.position -ne [int]$X })
            $numberJson = if ($number) { [int]$number } else { $null }
            $rest += [pscustomobject]@{
                position        = [int]$X
                planFile        = $planfile
                milestoneNumber = $numberJson
                pass            = $pass
                status          = $status
            }
            $checkpoint.milestones = $rest
            $checkpoint | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $state -Encoding utf8NoBOM -ErrorAction Stop
        } catch {
            Write-Output "create: could not persist the deploy checkpoint for milestone $X (pass $pass, $status), continuing without it"
        }
        exit 0
    }

    # --- assemble the description, then pass (d)'s REPLACE-form PATCH ---------
    #
    # $goal and $waves are the two halves of the description pass (d) already
    # builds (slugs rewritten to #n). X = Build-order position; N = the
    # manifest's count.
    'build-order-line' {
        if ($args.Count -ne 6) { Show-Usage }
        $X = [string]$args[1]
        $N = [string]$args[2]
        $number = [string]$args[3]
        $goal = [string]$args[4]
        $waves = [string]$args[5]

        $desc = $goal + "`n`n" + "build order: milestone $X of $N" + "`n`n" + $waves
        gh api --method PATCH "repos/{owner}/{repo}/milestones/$number" -f "description=$desc"
        exit $LASTEXITCODE
    }

    default { Show-Usage }
}
