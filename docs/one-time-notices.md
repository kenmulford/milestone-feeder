# Plan Step 0 — one-time notices

`plan` Step 0 prints up to five one-time notices the first time it runs in a
clone; a sixth notice (below) fires instead from `create`'s and `update`'s
Step 0. Each one either announces a self-heal `plan` just performed, flags a
repo-state problem for you to fix by hand, points you at a new or optional
capability you can opt into, or announces a behavior change. Every notice
shows at most once per clone: the block drops a small marker file under
`.milestone-config/.runtime/` the first time it fires, then stays silent on
every later run. The self-heal in the first section is the one exception: it
is gated on file-absence, not a marker, so it re-checks every run and acts
only when the file it writes is missing.

This file is the canonical source for those six notices. Each section records,
for one notice: when it fires, the per-clone marker that silences it, and what
it writes, then the notice text together with both emitter twins (a bash form
and a PowerShell 7+ form), byte-for-byte. The blocks are reference content;
nothing in this file runs on its own. The live emitter for notices 1-5 is
`skills/plan/SKILL.md` Step 0; the live emitter for notice 6 is
`skills/create/SKILL.md` Step 0 and `skills/update/SKILL.md` Step 0.

**Contents**

1. [Self-heal the nested .milestone-config/.gitignore](#self-heal-the-nested-milestone-configgitignore)
2. [Legacy-blanket root .gitignore notice](#legacy-blanket-root-gitignore-notice)
3. [Bootstrap-nudge notice](#bootstrap-nudge-notice)
4. [Roadmap-routing notice](#roadmap-routing-notice)
5. [Implied-surfaces notice](#implied-surfaces-notice)
6. [md-epic parent notice](#md-epic-parent-notice)

## Self-heal the nested .milestone-config/.gitignore

- **Gate:** file-absence only (`[ ! -f ]` / `-not (Test-Path ...)`) — create-only, NOT marker-gated.
- **Per-clone marker:** none.
- **Writes:** the nested `.milestone-config/.gitignore`.
- **Safety:** best-effort; never clobbers a user-edited file; a failed self-heal never aborts the run.

```gitignore
# milestone-driver / milestone-feeder per-clone scratch — git-invisible by default.
# Committed so per-run scratch stays out of `git status` with zero user setup.
# Patterns are relative to this .milestone-config/ directory. Tracked config
# (driver.json, feeder.json) is intentionally NOT listed, so it stays tracked.
preflight-notice
trello-notice
triage-cache.json
tests-stamp
.runtime/
worktrees/
```

```bash
# bash — create-only self-heal; never clobbers a user-edited file, never aborts plan.
mkdir -p .milestone-config 2>/dev/null || true
ignore_path=".milestone-config/.gitignore"
if [ ! -f "$ignore_path" ]; then
  printf '%s\n' \
    '# milestone-driver / milestone-feeder per-clone scratch — git-invisible by default.' \
    '# Committed so per-run scratch stays out of `git status` with zero user setup.' \
    '# Patterns are relative to this .milestone-config/ directory. Tracked config' \
    '# (driver.json, feeder.json) is intentionally NOT listed, so it stays tracked.' \
    'preflight-notice' 'trello-notice' 'triage-cache.json' 'tests-stamp' \
    '.runtime/' 'worktrees/' > "$ignore_path" 2>/dev/null || true
fi
```

```powershell
# PowerShell 7+ — same create-only self-heal; no-BOM UTF-8; never clobbers, never aborts.
try {
  New-Item -ItemType Directory -Force -Path '.milestone-config' | Out-Null
  $ignorePath = Join-Path '.milestone-config' '.gitignore'
  if (-not (Test-Path $ignorePath)) {
    $ignoreBody = @(
      '# milestone-driver / milestone-feeder per-clone scratch — git-invisible by default.'
      '# Committed so per-run scratch stays out of `git status` with zero user setup.'
      '# Patterns are relative to this .milestone-config/ directory. Tracked config'
      '# (driver.json, feeder.json) is intentionally NOT listed, so it stays tracked.'
      'preflight-notice'; 'trello-notice'; 'triage-cache.json'; 'tests-stamp'
      '.runtime/'; 'worktrees/'
    ) -join "`n"
    [System.IO.File]::WriteAllText($ignorePath, $ignoreBody + "`n", [System.Text.UTF8Encoding]::new($false))
  }
} catch {}
```

## Legacy-blanket root .gitignore notice

- **Gate:** a root `.gitignore` blanket for `.milestone-config` is detected AND the per-clone marker is absent.
- **Per-clone marker:** `.milestone-config/.runtime/legacy-blanket-notice`.
- **Writes:** the `.runtime/` directory and the marker. Read-only on the root `.gitignore` — it never auto-edits it.
- **Safety:** best-effort; a failed detect or marker write never aborts the run.

```text
🔴 Legacy blanket detected in your root .gitignore

| What | Your root .gitignore ignores the whole .milestone-config/ directory
|      | (a line like `.milestone-config/`, `.milestone-config/*`, or
|      | `.milestone-config`). That hides this suite's TRACKED config —
|      | feeder.json, driver.json, and the nested .milestone-config/.gitignore —
|      | from git, so your config is silently dropped from version control.
| Fix  | Edit your root .gitignore BY HAND and delete the `.milestone-config`
|      | blanket line. The nested .milestone-config/.gitignore (already
|      | written) then keeps per-run scratch invisible while feeder.json /
|      | driver.json / the nested .gitignore stay tracked. We never edit your
|      | root .gitignore for you — it is yours and may hold unrelated rules.
| Note | This notice shows at most once per clone.
```

```bash
# bash — read-only detect + one-time notice; NEVER writes the root .gitignore; never aborts plan.
# printf '%s\n' (NOT a heredoc): the same indent-safe construct the setup site uses, so both sites
# emit one consistent form. The notice text is the quoted args, so it prints flush-left —
# byte-identical to the setup site.
marker=".milestone-config/.runtime/legacy-blanket-notice"
if [ ! -f "$marker" ] && [ -f ".gitignore" ] \
   && grep -Eq '^[[:space:]]*/?\.milestone-config(/\*?)?[[:space:]]*$' .gitignore \
   && ! grep -Eq '^[[:space:]]*!/?\.milestone-config(/\*?)?[[:space:]]*$' .gitignore; then
  printf '%s\n' \
    '🔴 Legacy blanket detected in your root .gitignore' \
    '' \
    '| What | Your root .gitignore ignores the whole .milestone-config/ directory' \
    '|      | (a line like `.milestone-config/`, `.milestone-config/*`, or' \
    '|      | `.milestone-config`). That hides this suite'"'"'s TRACKED config —' \
    '|      | feeder.json, driver.json, and the nested .milestone-config/.gitignore —' \
    '|      | from git, so your config is silently dropped from version control.' \
    '| Fix  | Edit your root .gitignore BY HAND and delete the `.milestone-config`' \
    '|      | blanket line. The nested .milestone-config/.gitignore (already' \
    '|      | written) then keeps per-run scratch invisible while feeder.json /' \
    '|      | driver.json / the nested .gitignore stay tracked. We never edit your' \
    '|      | root .gitignore for you — it is yours and may hold unrelated rules.' \
    '| Note | This notice shows at most once per clone.'
  mkdir -p .milestone-config/.runtime 2>/dev/null && : > "$marker" 2>/dev/null || true
fi
```

```powershell
# PowerShell 7+ — same read-only detect + one-time notice; NEVER writes the root .gitignore; never aborts plan.
try {
  $marker = Join-Path '.milestone-config' (Join-Path '.runtime' 'legacy-blanket-notice')
  if ((-not (Test-Path $marker)) -and (Test-Path '.gitignore')) {
    $lines = Get-Content -LiteralPath '.gitignore'
    $blanket   = $lines | Where-Object { $_ -match '^\s*/?\.milestone-config(/\*?)?\s*$' }
    $unignored = $lines | Where-Object { $_ -match '^\s*!/?\.milestone-config(/\*?)?\s*$' }
    if ($blanket -and -not $unignored) {
      # Indent-safe array-join (the #120/#121 self-heal construct) — NOT a here-string: an
      # @'…'@ closing terminator must sit at column 0, which breaks when nested under indented
      # markdown. The text below is byte-identical to the bash printf args and the setup site.
      Write-Host (@(
        '🔴 Legacy blanket detected in your root .gitignore'
        ''
        '| What | Your root .gitignore ignores the whole .milestone-config/ directory'
        '|      | (a line like `.milestone-config/`, `.milestone-config/*`, or'
        '|      | `.milestone-config`). That hides this suite''s TRACKED config —'
        '|      | feeder.json, driver.json, and the nested .milestone-config/.gitignore —'
        '|      | from git, so your config is silently dropped from version control.'
        '| Fix  | Edit your root .gitignore BY HAND and delete the `.milestone-config`'
        '|      | blanket line. The nested .milestone-config/.gitignore (already'
        '|      | written) then keeps per-run scratch invisible while feeder.json /'
        '|      | driver.json / the nested .gitignore stay tracked. We never edit your'
        '|      | root .gitignore for you — it is yours and may hold unrelated rules.'
        '| Note | This notice shows at most once per clone.'
      ) -join "`n")
      New-Item -ItemType Directory -Force -Path (Join-Path '.milestone-config' '.runtime') | Out-Null
      New-Item -ItemType File -Force -Path $marker | Out-Null
    }
  }
} catch {}
```

## Bootstrap-nudge notice

- **Gate:** the repo is un-bootstrapped (the resolved `projectDocs` path is absent or has no readable files, OR `.milestone-config/driver.json` is missing) AND the per-clone marker is absent.
- **Per-clone marker:** `.milestone-config/.runtime/bootstrap-nudge-notice`.
- **Writes:** the `.runtime/` directory and the marker. Read-only — it never runs the bootstrapper and never writes `projectDocs` / `.project/` or `driver.json`.
- **Safety:** best-effort; a failed resolve, detect, or marker write never aborts the run.

```text
🟡 This repo isn't bootstrapped — your plan's grounding will be weak

| What | This repo has no .project/ standing docs and/or no
|      | .milestone-config/driver.json. Without them, plan has no project
|      | constitution to ground issue design on and no driver profile to
|      | resolve shared keys from, so it falls back to thin inferred
|      | conventions and the issues it writes are weaker.
| Fix  | Run milestone-bootstrapper first to scaffold your .project/ docs and
|      | driver profile, then re-run /milestone-feeder:plan. We won't do this
|      | for you and we won't block — config is optional and plan will
|      | continue with best-effort grounding.
| Note | This notice shows at most once per clone.
```

```bash
# bash — read-only detect + one-time notice; NEVER writes projectDocs/.project/ or driver.json, NEVER runs the bootstrapper; never aborts plan.
# printf '%s\n' (NOT a heredoc): the same indent-safe construct the sibling legacy-blanket block uses, so both
# sites emit one consistent form. The notice text is the quoted args, so it prints flush-left.
# Resolve projectDocs in-block (the key-extraction table below has not run yet) with the SAME default the table uses,
# so the two reads can't diverge; a non-string projectDocs (number/array), missing file / malformed JSON / missing jq
# all fall back to .project/. Strip ALL trailing slashes for the detect operand; an empty result (e.g. "/") falls back
# to .project so bash and PowerShell agree; the notice re-adds a single "/" so the printed path always ends in "/".
pd="$(jq -r 'if (.projectDocs | type) == "string" then .projectDocs else ".project/" end' .milestone-config/feeder.json 2>/dev/null || echo ".project/")"
[ -z "$pd" ] && pd=".project/"
while [ "$pd" != "${pd%/}" ]; do pd="${pd%/}"; done
[ -z "$pd" ] && pd=".project"
marker=".milestone-config/.runtime/bootstrap-nudge-notice"
if [ ! -f "$marker" ] \
   && { [ -z "$(find -L "$pd" -type f 2>/dev/null | head -1)" ] || [ ! -f ".milestone-config/driver.json" ]; }; then
  printf '%s\n' \
    '🟡 This repo isn'"'"'t bootstrapped — your plan'"'"'s grounding will be weak' \
    '' \
    "| What | This repo has no ${pd}/ standing docs and/or no" \
    '|      | .milestone-config/driver.json. Without them, plan has no project' \
    '|      | constitution to ground issue design on and no driver profile to' \
    '|      | resolve shared keys from, so it falls back to thin inferred' \
    '|      | conventions and the issues it writes are weaker.' \
    '| Fix  | Run milestone-bootstrapper first to scaffold your .project/ docs and' \
    '|      | driver profile, then re-run /milestone-feeder:plan. We won'"'"'t do this' \
    '|      | for you and we won'"'"'t block — config is optional and plan will' \
    '|      | continue with best-effort grounding.' \
    '| Note | This notice shows at most once per clone.'
  mkdir -p .milestone-config/.runtime 2>/dev/null && : > "$marker" 2>/dev/null || true
fi
```

```powershell
# PowerShell 7+ — same read-only detect + one-time notice; NEVER writes projectDocs/.project/ or driver.json, NEVER runs the bootstrapper; never aborts plan.
try {
  # Resolve projectDocs in-block (the key-extraction table below has not run yet) with the SAME default the table uses,
  # so the two reads can't diverge; a non-string projectDocs (number/array), missing file / malformed JSON all fall
  # back to .project/. Strip ALL trailing slashes for the detect operand; an empty result (e.g. "/") falls back to
  # .project so PowerShell and bash agree; the notice re-adds a single "/" so the printed path always ends in "/".
  $pd = '.project/'
  try { $pdRaw = (Get-Content -Raw -LiteralPath (Join-Path '.milestone-config' 'feeder.json') -ErrorAction Stop | ConvertFrom-Json).projectDocs; if ($pdRaw -is [string]) { $pd = $pdRaw } } catch {}
  $pd = $pd -replace '/+$',''
  if (-not $pd) { $pd = '.project' }
  $marker = Join-Path '.milestone-config' (Join-Path '.runtime' 'bootstrap-nudge-notice')
  $projectEmpty = -not (Test-Path $pd) -or -not (Get-ChildItem -LiteralPath $pd -File -Recurse -Force -ErrorAction SilentlyContinue | Select-Object -First 1)
  $driverMissing = -not (Test-Path (Join-Path '.milestone-config' 'driver.json'))
  if ((-not (Test-Path $marker)) -and ($projectEmpty -or $driverMissing)) {
    # Indent-safe array-join (the #120/#121 self-heal construct) — NOT a here-string: an
    # @'…'@ closing terminator must sit at column 0, which breaks when nested under indented
    # markdown. The text below is byte-identical to the bash printf args (same resolved $pd).
    Write-Host (@(
      '🟡 This repo isn''t bootstrapped — your plan''s grounding will be weak'
      ''
      "| What | This repo has no ${pd}/ standing docs and/or no"
      '|      | .milestone-config/driver.json. Without them, plan has no project'
      '|      | constitution to ground issue design on and no driver profile to'
      '|      | resolve shared keys from, so it falls back to thin inferred'
      '|      | conventions and the issues it writes are weaker.'
      '| Fix  | Run milestone-bootstrapper first to scaffold your .project/ docs and'
      '|      | driver profile, then re-run /milestone-feeder:plan. We won''t do this'
      '|      | for you and we won''t block — config is optional and plan will'
      '|      | continue with best-effort grounding.'
      '| Note | This notice shows at most once per clone.'
    ) -join "`n")
    New-Item -ItemType Directory -Force -Path (Join-Path '.milestone-config' '.runtime') | Out-Null
    New-Item -ItemType File -Force -Path $marker | Out-Null
  }
} catch {}
```

## Roadmap-routing notice

- **Gate:** the per-clone marker is absent. Otherwise unconditional — there is no repo-state condition, because the notice announces a behavior change.
- **Per-clone marker:** `.milestone-config/.runtime/roadmap-routing-notice`.
- **Writes:** the `.runtime/` directory and the marker. `plan` Step 0 only — there is no `setup` twin.
- **Safety:** best-effort; a failed notice or marker write never aborts the run.

```text
🟡 New: an oversized brief now routes into a roadmap flow

| What | When you give plan a whole-app brief that spans several
|      | releases, plan now hands it to a roadmap step first: it
|      | proposes a sequenced set of milestones and asks you to
|      | confirm, merge, split, reorder, or reject the split before
|      | it plans any single milestone.
| When | Only when the brief reads as several milestones. A normal,
|      | single-release brief is unchanged — no roadmap step, no
|      | extra prompt.
| Note | This notice shows at most once per clone.
```

```bash
# bash — one-time roadmap-routing discovery notice; read-only; marker-gated; never aborts plan.
# printf '%s\n' (NOT a heredoc): the same indent-safe construct the sibling Step-0 notices use,
# so all three sites emit one consistent form. The notice text is the quoted args — prints flush-left.
marker=".milestone-config/.runtime/roadmap-routing-notice"
if [ ! -f "$marker" ]; then
  printf '%s\n' \
    '🟡 New: an oversized brief now routes into a roadmap flow' \
    '' \
    '| What | When you give plan a whole-app brief that spans several' \
    '|      | releases, plan now hands it to a roadmap step first: it' \
    '|      | proposes a sequenced set of milestones and asks you to' \
    '|      | confirm, merge, split, reorder, or reject the split before' \
    '|      | it plans any single milestone.' \
    '| When | Only when the brief reads as several milestones. A normal,' \
    '|      | single-release brief is unchanged — no roadmap step, no' \
    '|      | extra prompt.' \
    '| Note | This notice shows at most once per clone.'
  mkdir -p .milestone-config/.runtime 2>/dev/null && : > "$marker" 2>/dev/null || true
fi
```

```powershell
# PowerShell 7+ — same one-time roadmap-routing discovery notice; read-only; marker-gated; never aborts plan.
try {
  $marker = Join-Path '.milestone-config' (Join-Path '.runtime' 'roadmap-routing-notice')
  if (-not (Test-Path $marker)) {
    # Indent-safe array-join (the #120/#121 self-heal construct) — NOT a here-string; byte-identical
    # to the bash printf args and the text template above.
    Write-Host (@(
      '🟡 New: an oversized brief now routes into a roadmap flow'
      ''
      '| What | When you give plan a whole-app brief that spans several'
      '|      | releases, plan now hands it to a roadmap step first: it'
      '|      | proposes a sequenced set of milestones and asks you to'
      '|      | confirm, merge, split, reorder, or reject the split before'
      '|      | it plans any single milestone.'
      '| When | Only when the brief reads as several milestones. A normal,'
      '|      | single-release brief is unchanged — no roadmap step, no'
      '|      | extra prompt.'
      '| Note | This notice shows at most once per clone.'
    ) -join "`n")
    New-Item -ItemType Directory -Force -Path (Join-Path '.milestone-config' '.runtime') | Out-Null
    New-Item -ItemType File -Force -Path $marker | Out-Null
  }
} catch {}
```

## Implied-surfaces notice

- **Gate:** the overlay `.milestone-config/implied-surfaces.md` is absent AND the per-clone marker is absent.
- **Per-clone marker:** `.milestone-config/.runtime/implied-surfaces-notice` — shared verbatim text and shared marker with the `update` Step-0 twin, so the notice shows at most once per clone across both verbs.
- **Writes:** the `.runtime/` directory and the marker. Read-only — it never writes the overlay.
- **Safety:** best-effort; a failed detect, notice, or marker write never aborts the run.

```text
🟡 Optional: add project-specific implied surfaces

| What | You can add an optional overlay file at
|      | .milestone-config/implied-surfaces.md. The architect reads it
|      | alongside the plugin's bundled implied-surfaces reference when it
|      | breaks your brief into issues.
| Why  | The bundled reference is universal, so it can't carry capability
|      | clusters specific to your domain (a church app's "giving", say).
|      | Your overlay merges in additively — it can add a new capability
|      | and extend an existing one, but never removes a surface the
|      | bundled reference already defines.
| How  | Create .milestone-config/implied-surfaces.md and write one
|      | capability per ## heading with its implied surfaces beneath — the
|      | same shape as the bundled reference. Leave it out and the bundled
|      | reference is used as-is; an absent overlay is never an error.
| Note | This notice shows at most once per clone.
```

```bash
# bash — read-only detect + one-time notice; NEVER writes the overlay; never aborts plan.
# printf '%s\n' (NOT a heredoc): indent-safe under this list item — a heredoc terminator must sit
# at column 0, but this block is nested, so an indented EOF would be a syntax error. Mirrors the
# plan Step-0 bootstrap-nudge form. The notice text is the quoted args, so it prints flush-left.
marker=".milestone-config/.runtime/implied-surfaces-notice"
if [ ! -f "$marker" ] && [ ! -f ".milestone-config/implied-surfaces.md" ]; then
  printf '%s\n' \
    '🟡 Optional: add project-specific implied surfaces' \
    '' \
    '| What | You can add an optional overlay file at' \
    '|      | .milestone-config/implied-surfaces.md. The architect reads it' \
    '|      | alongside the plugin'"'"'s bundled implied-surfaces reference when it' \
    '|      | breaks your brief into issues.' \
    '| Why  | The bundled reference is universal, so it can'"'"'t carry capability' \
    '|      | clusters specific to your domain (a church app'"'"'s "giving", say).' \
    '|      | Your overlay merges in additively — it can add a new capability' \
    '|      | and extend an existing one, but never removes a surface the' \
    '|      | bundled reference already defines.' \
    '| How  | Create .milestone-config/implied-surfaces.md and write one' \
    '|      | capability per ## heading with its implied surfaces beneath — the' \
    '|      | same shape as the bundled reference. Leave it out and the bundled' \
    '|      | reference is used as-is; an absent overlay is never an error.' \
    '| Note | This notice shows at most once per clone.'
  mkdir -p .milestone-config/.runtime 2>/dev/null && : > "$marker" 2>/dev/null || true
fi
```

```powershell
# PowerShell 7+ — same read-only detect + one-time notice; NEVER writes the overlay; never aborts plan.
try {
  $marker = Join-Path '.milestone-config' (Join-Path '.runtime' 'implied-surfaces-notice')
  $overlay = Join-Path '.milestone-config' 'implied-surfaces.md'
  if ((-not (Test-Path $marker)) -and (-not (Test-Path $overlay))) {
    # Indent-safe array-join (the #120/#121 self-heal construct) — NOT a here-string: an
    # @'…'@ closing terminator must sit at column 0, which breaks when nested under this
    # indented markdown list item. The text below is byte-identical to the bash printf args.
    Write-Host (@(
      '🟡 Optional: add project-specific implied surfaces'
      ''
      '| What | You can add an optional overlay file at'
      '|      | .milestone-config/implied-surfaces.md. The architect reads it'
      '|      | alongside the plugin''s bundled implied-surfaces reference when it'
      '|      | breaks your brief into issues.'
      '| Why  | The bundled reference is universal, so it can''t carry capability'
      '|      | clusters specific to your domain (a church app''s "giving", say).'
      '|      | Your overlay merges in additively — it can add a new capability'
      '|      | and extend an existing one, but never removes a surface the'
      '|      | bundled reference already defines.'
      '| How  | Create .milestone-config/implied-surfaces.md and write one'
      '|      | capability per ## heading with its implied surfaces beneath — the'
      '|      | same shape as the bundled reference. Leave it out and the bundled'
      '|      | reference is used as-is; an absent overlay is never an error.'
      '| Note | This notice shows at most once per clone.'
    ) -join "`n")
    New-Item -ItemType Directory -Force -Path (Join-Path '.milestone-config' '.runtime') | Out-Null
    New-Item -ItemType File -Force -Path $marker | Out-Null
  }
} catch {}
```

## md-epic parent notice

- **Gate:** the per-clone marker is absent. Otherwise unconditional: there is no repo-state condition, because the notice announces a behavior change.
- **Per-clone marker:** `.milestone-config/.runtime/md-epic-parent-notice`, shared between `create`'s and `update`'s Step-0 twins, so it shows at most once per clone across both verbs (the same cross-verb sharing the Implied-surfaces notice already uses between `plan` and `update`).
- **Writes:** the `.runtime/` directory and the marker. `create` Step 0 and `update` Step 0 only, no `plan` twin.
- **Safety:** best-effort; a failed notice or marker write never aborts the run.

```text
🟡 New: a roadmap deploy now also creates a driver parent issue

| What | When your roadmap deploys more than one milestone, create (and
|      | update, on a re-plan) now also creates one md-epic-labeled parent
|      | issue whose body lists the milestones in build order. The driver
|      | reads this parent to drive the milestones in sequence for you.
| When | Only when the roadmap deploys N>1 milestones. A single-milestone
|      | plan/create is unchanged. No parent issue, nothing new to look at.
| Note | This notice shows at most once per clone.
```

```bash
# bash: one-time md-epic-parent discovery notice; read-only; marker-gated; never aborts create/update.
# printf '%s\n' (NOT a heredoc): the same indent-safe construct the sibling Step-0 notices use,
# so all sites emit one consistent form. The notice text is the quoted args, so it prints flush-left.
marker=".milestone-config/.runtime/md-epic-parent-notice"
if [ ! -f "$marker" ]; then
  printf '%s\n' \
    '🟡 New: a roadmap deploy now also creates a driver parent issue' \
    '' \
    '| What | When your roadmap deploys more than one milestone, create (and' \
    '|      | update, on a re-plan) now also creates one md-epic-labeled parent' \
    '|      | issue whose body lists the milestones in build order. The driver' \
    '|      | reads this parent to drive the milestones in sequence for you.' \
    '| When | Only when the roadmap deploys N>1 milestones. A single-milestone' \
    '|      | plan/create is unchanged. No parent issue, nothing new to look at.' \
    '| Note | This notice shows at most once per clone.'
  mkdir -p .milestone-config/.runtime 2>/dev/null && : > "$marker" 2>/dev/null || true
fi
```

```powershell
# PowerShell 7+: same one-time md-epic-parent discovery notice; read-only; marker-gated; never aborts create/update.
try {
  $marker = Join-Path '.milestone-config' (Join-Path '.runtime' 'md-epic-parent-notice')
  if (-not (Test-Path $marker)) {
    # Indent-safe array-join (the #120/#121 self-heal construct), NOT a here-string: an
    # @'...'@ closing terminator must sit at column 0, which breaks when nested under indented
    # markdown. The text below is byte-identical to the bash printf args.
    Write-Host (@(
      '🟡 New: a roadmap deploy now also creates a driver parent issue'
      ''
      '| What | When your roadmap deploys more than one milestone, create (and'
      '|      | update, on a re-plan) now also creates one md-epic-labeled parent'
      '|      | issue whose body lists the milestones in build order. The driver'
      '|      | reads this parent to drive the milestones in sequence for you.'
      '| When | Only when the roadmap deploys N>1 milestones. A single-milestone'
      '|      | plan/create is unchanged. No parent issue, nothing new to look at.'
      '| Note | This notice shows at most once per clone.'
    ) -join "`n")
    New-Item -ItemType Directory -Force -Path (Join-Path '.milestone-config' '.runtime') | Out-Null
    New-Item -ItemType File -Force -Path $marker | Out-Null
  }
} catch {}
```
