---
name: plan
description: This skill should be used when the user invokes "/milestone-feeder:plan <brief>", or asks to "plan a milestone from a brief" or "turn an idea into a reviewable plan". Turns a feature brief into a reviewable plan file — small, well-formed candidate issues vetted through the driver's reviewers (the self-check gate) before they land in the plan. Read-only on GitHub: writes a single reviewable plan file (plus a needs-input report when something is parked) and creates nothing on GitHub. No flags. Authors no code; opens no PRs.
---

# plan — brief → reviewable plan file

Read config + project docs, ingest a brief, separate product gaps from design decisions, dispatch the architect once and the issue-author per candidate, assemble the dependency graph, render the milestone description, run the self-check gate against the generated issues, and write a reviewable plan file. The driver's predecessor: it specifies what the driver then builds.

This skill is the compile step of the feeder pipeline (`SPEC.md` §6, Steps 0–6; write the plan file at Step 7). It makes *design and implementation* calls when the project docs or a stated repo convention supplies the answer, and it parks *product* calls — decisions about what to build or user-facing behavior with no conventional default — to a report instead of guessing them (`SPEC.md` §2 park boundary). Before writing the plan file, it runs the **self-check gate** (Step 6, `SPEC.md` §5): it dispatches the driver's own reviewers against each generated issue and gates on the returned `GAPS` block — making the feeder's quality bar identical to the driver's entry gate. It runs every dispatched agent read-only, against provided text, and lands its output in local scratch files. **`plan` writes NO GitHub state** — its entire output is local scratch files (the plan file + the needs-input report). It creates no milestone, opens no issue, applies no label, posts no comment. The downstream `create` skill is the only thing that writes GitHub state, reading this plan file. Authors no code, opens no PRs, never touches branches, never invents product scope — product gaps are parked to a report, never guessed.

## Announce first

Say this to the user before doing any work:

> Standing by while I turn the brief into a milestone + issues and run the self-check gate. This is read-only on GitHub — I'll write a reviewable plan file and create nothing on GitHub. Run `/milestone-feeder:create` afterward to deploy the plan.

## Procedure

This procedure has two parts: a **once-per-run outer boundary** (Step 0) and a **callable single-milestone inner routine** (Steps 1–7).

- **Step 0 is the once-per-run OUTER boundary** — read config, auto-invoke `setup` when `feeder.json` is absent, self-heal the scratch-ignore, print the one-time notices, resolve the shared keys, and assemble the grounding digest. It runs **exactly once per run** and is **NOT part of the inner routine**; everything it resolves is handed *into* the routine and is **never re-resolved per invocation**.
- **Steps 1–7 are the single-milestone inner routine** — a named, callable, parameterized sub-procedure (its contract is stated just below Step 0, before Step 1). It plans exactly one milestone and returns one plan file (plus a needs-input report when anything parked).
- **The single-brief path is the default and is unchanged: it invokes the inner routine exactly ONCE**, with the whole brief as the lone brief-slice and its sole build-order position. On that path nothing about the emitted plan file changes — the inner routine is the same Steps 1–7 this skill has always run; this *inner-routine refactor* only *names and frames* them as a callable unit (it adds no outer loop or fan-out of its own — the oversized-brief **roadmap route** is added separately at the front-door, Step 3.6, and acts ONLY when the architect raises the multi-milestone signal). **For a normal single-brief (`none`-signal) run nothing about the emitted plan file changes**, so that refactor's existing-user discovery-path obligation is satisfied **vacuously** (nothing to discover or migrate); the **oversized-routing** behavior added at Step 3.6 ships its **own** one-time discovery notice (Step 0) per `SPEC.md` §3.1.

### Step 0 — Read config + project docs (best-effort) — once-per-run OUTER boundary

Read `.milestone-config/feeder.json`. **Absent → invoke `milestone-feeder:setup`** (it bootstraps the profile, aligns the label taxonomy, and returns control), then continue — the user does not re-run the command (`skills/setup/SKILL.md` Phase 5).

**Self-heal the scratch-ignore (best-effort, create-only — never clobber).** On the **already-configured** path — `feeder.json` is present, so `setup` is NOT auto-invoked above — nothing else establishes the nested scratch-ignore, so a legacy-blanket repo (config present but `.milestone-config/.gitignore` never written) would leak per-run scratch into `git status`. Ensure the `.milestone-config/` directory exists (`mkdir -p .milestone-config`), then write a **committed** `.milestone-config/.gitignore` so per-clone scratch (`preflight-notice`, `trello-notice`, `triage-cache.json`, `tests-stamp`, plus the `.runtime/` and `worktrees/` dirs) is git-invisible in the consumer repo with zero user setup — while tracked config (`driver.json`, `feeder.json` — intentionally NOT listed) stays tracked. **Write the file only when it is absent** (`[ ! -f ]` / `-not (Test-Path …)`), so a user-edited `.gitignore` is never overwritten, appended to, or truncated, and a re-run is a no-op. The write is **best-effort**: swallow any failure and continue the `plan` run — a failed self-heal must never abort `plan`. This mirrors the driver's canonical block verbatim (`milestone-driver/hooks/tests-green.sh` / `tests-green.ps1`) and the same block in feeder `setup` (`skills/setup/SKILL.md` Phase 3); keep the three in sync.

<!-- KEEP THIS BLOCK IN SYNC with the committed .milestone-config/.gitignore in this repo and with feeder setup, driver solve-issue / solve-milestone / triage. -->
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

**Detect a legacy-blanket root `.gitignore` and print a one-time by-hand-fix notice (read-only; NEVER auto-edit the root).** The self-heal above writes the *nested* `.milestone-config/.gitignore`, but it cannot help a consumer whose **root** `.gitignore` carries a legacy blanket for the config dir — `.milestone-config/`, `.milestone-config/*`, or bare `.milestone-config` (with or without a leading `/`). A root blanket hides everything under `.milestone-config/` from git — `feeder.json`, `driver.json`, and the nested `.gitignore` we just wrote — so the tracked config is silently dropped from version control and the self-heal is void for exactly those repos. **Detection is read-only — it writes NOTHING to the root `.gitignore` under any condition; the root file is the consumer's and may hold unrelated rules, so the fix is the user's to apply** (this skill already scopes its own scratch self-ignore to the nested `.milestone-config/.gitignore` "without touching the consumer's root `.gitignore`", `skills/plan/SKILL.md:336`). Mirrors the driver's one-time marker-gated notice pattern (`milestone-driver/skills/solve-milestone/SKILL.md` preflight / Trello notice: detect → print verbatim → drop a per-clone marker; `milestone-driver/skills/solve-issue/SKILL.md` first-run preflight notice).

Gate: print the 🔴 notice **verbatim** ONLY when a root blanket is detected **AND** the per-clone marker `.milestone-config/.runtime/legacy-blanket-notice` is **absent**. On print, ensure `.runtime/` exists (`mkdir -p .milestone-config/.runtime` / `New-Item -ItemType Directory -Force`), then create the marker. Stay **silent** if the marker already exists OR no blanket is detected. The marker lives under `.runtime/`, which the nested `.milestone-config/.gitignore` (written above) already ignores — so the marker is git-invisible with **no new gitignore line** (verified: `git check-ignore .milestone-config/.runtime/legacy-blanket-notice` resolves against the nested `.runtime/` entry). **Blanket-clearing rule:** a blanket counts as present UNLESS it is paired with a **broad** un-ignore that actually re-exposes tracked config (`!.milestone-config`, `!.milestone-config/`, or `!.milestone-config/*`). A lone single-file un-ignore such as `!.milestone-config/driver.json` does **NOT** clear it — `feeder.json` and the nested `.gitignore` stay hidden — so it still counts as a blanket and the notice fires. **Both forms below are best-effort: swallow any failure (unwritable dir, permission error, missing git) and continue the `plan` run — a failed detect/marker must never abort `plan`. Neither form ever writes to the root `.gitignore`.**

<!-- KEEP THIS DETECTION + NOTICE BLOCK IN SYNC with setup Phase 3 (skills/setup/SKILL.md). Read-only on the root .gitignore; marker is .milestone-config/.runtime/legacy-blanket-notice. -->
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

**Detect an un-bootstrapped repo and print a one-time non-blocking grounding-is-weak notice (read-only; NEVER auto-run the bootstrapper, NEVER scaffold config).** Grounding is strongest when this repo has both the project's standing docs (the project constitution `plan` grounds issue design on, found under the configurable `projectDocs` path — default `.project/`) and a driver profile (`.milestone-config/driver.json`, the shared-keys source). **The standing-docs path is the resolved `projectDocs` value, not a hardcoded `.project/`** — a consumer with a custom `projectDocs` (e.g. `docs/standards/`) that *is* bootstrapped must not get a false nudge. So this block resolves `projectDocs` in-place **before** the detect (the key-extraction table below has not run yet), reading `.milestone-config/feeder.json` directly with the **same default (`.project/`) the table uses** so the two reads cannot diverge; a missing file / malformed JSON / missing `jq` falls back to `.project/`. When the repo is missing one or both — the resolved `projectDocs` path absent or empty (no readable files), **OR** `.milestone-config/driver.json` missing — `plan` still runs, but falls back to thin inferred conventions, so the issues it writes are weaker. This notice tells the user that, names the resolved `projectDocs` path, points them at `milestone-bootstrapper`, and carries on. **It is purely advisory: never a hard block, never a prompt; it does NOT run `milestone-bootstrapper`, and it writes NOTHING to `.project/` or `driver.json` — its only writes are the `.runtime/` dir and the marker.** This trigger is **independent of** the `feeder.json`-absent → `setup` branch (`skills/plan/SKILL.md:22`) and of the driver-config absent-default resolution (the key-extraction table and the "Resolve the shared keys" steps below) — neither is altered, and a present `feeder.json` with an absent `driver.json` still nudges here while resolving driver keys by absent-default below. Mirrors the driver's one-time marker-gated notice pattern, the same family as the legacy-blanket sibling above (detect → print verbatim → drop a per-clone marker).

Gate: print the 🟡 notice **verbatim** ONLY when the repo is un-bootstrapped (resolved `projectDocs` path absent-or-no-readable-files **OR** `.milestone-config/driver.json` missing) **AND** the per-clone marker `.milestone-config/.runtime/bootstrap-nudge-notice` is **absent**. On print, ensure `.runtime/` exists (`mkdir -p .milestone-config/.runtime` / `New-Item -ItemType Directory -Force`), then create the marker. Stay **silent** if the marker already exists OR the repo is bootstrapped (both the resolved `projectDocs` path has a readable file AND `driver.json` is present). The marker lives under `.runtime/`, which the nested `.milestone-config/.gitignore` (written above) already ignores — so the marker is git-invisible with **no new gitignore line**. **Both forms below are best-effort: swallow any failure (unwritable dir, permission error, malformed feeder.json, missing `jq`) and continue the `plan` run — a failed resolve/detect/notice/marker must never abort `plan`. Neither form ever writes to `projectDocs` / `.project/` or `driver.json`, and neither runs the bootstrapper.**

<!-- KEEP THIS DETECTION + NOTICE BLOCK IN SYNC across the plan/setup one-time-notice family. plan Step 0 only (no setup twin). Read-only on projectDocs/.project/ and driver.json; never runs milestone-bootstrapper; marker is .milestone-config/.runtime/bootstrap-nudge-notice. -->
<!-- This text block shows the DEFAULT-config rendering (projectDocs = .project/). The runnable bash/PowerShell forms below interpolate the RESOLVED projectDocs path into the "| What |" line — so a custom projectDocs (e.g. docs/standards/) prints "...no docs/standards/ standing docs..." while the default stays byte-identical to this template. Do not make this template dynamic. -->
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

**Announce the new oversized-brief routing once per clone (read-only, non-blocking, marker-gated).** Existing `plan` users formed a habit before this routing existed: a whole-app brief that spans several releases used to get only a passive *"~N milestones"* advisory they had to act on by hand. Now `plan`'s front-door (Step 3.6) **routes** such a brief into the `build-roadmap` flow. So existing users get a discovery path — a one-time, per-clone notice that announces the new behavior, mirroring the legacy-blanket / bootstrap-nudge siblings above (print verbatim → drop a per-clone marker). **It is purely informational: never a block, never a prompt; its only writes are the `.runtime/` dir and the marker — it reads and changes nothing else.** Grounding: `SPEC.md` §3.1 (every behavior change ships an existing-user discovery path); `.project/design-philosophy.md#One-way doors` (a behavior change ships a discovery / migration path); `.project/conventions.md#Canonical exemplars` (the one-time-notice pattern → `plan` Step 0).

Gate: print the 🟡 notice **verbatim** ONLY when the per-clone marker `.milestone-config/.runtime/roadmap-routing-notice` is **absent**. This notice is **unconditional** — it announces a behavior change, so unlike the two siblings above it carries **no repo-state condition**; the marker is its only gate. On print, ensure `.runtime/` exists (`mkdir -p .milestone-config/.runtime` / `New-Item -ItemType Directory -Force`), then create the marker. Stay **silent** if the marker already exists. The marker lives under `.runtime/`, which the nested `.milestone-config/.gitignore` (written above) already ignores — so the marker is git-invisible with **no new gitignore line**. **Both forms below are best-effort: swallow any failure (unwritable dir, permission error) and continue the `plan` run — a failed notice/marker must never abort `plan`.** This notice is **`plan` Step 0 only** (no setup twin) — the oversized-brief routing is a `plan` behavior.

<!-- KEEP THIS NOTICE BLOCK IN SYNC across the plan one-time-notice family. plan Step 0 only (no setup twin). Read-only; marker is .milestone-config/.runtime/roadmap-routing-notice. -->
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

Extract the feeder's own keys with their bundled defaults (`docs/profile-schema.md`, absent-means-default):

| Key | Default | Use |
|---|---|---|
| `projectDocs` | `.project/` | Where the project's standing docs (the project-constitution docs) live (grounds authoring). |
| `reviewer` | `"milestone-driver"` | Which backend runs the self-check gate (Step 6). `"milestone-driver"` → dispatch the driver's `triage-reviewer` / `design-reviewer` per generated issue (degrades to `"internal"` at runtime if they don't resolve); `"internal"` → run the built-in checklist that mirrors the five triage criteria; `false` → **skip the gate with a visible warning** (resolved in full at Step 6). |
| `architectAgent` | `milestone-feeder:architect` | The breakdown agent dispatched once at Step 3. |
| `issueAuthorAgent` | `milestone-feeder:issue-author` | The authoring agent dispatched per candidate at Step 4. |
| `issueSize` | *(none)* | Optional sizing rule passed into the architect brief; absent → no constraint beyond the defaults. |

Read the project docs under `projectDocs` **best-effort** (`SPEC.md` §6 Step 0). Honor the `.project/` contract: a section that is absent or marked `[TBD]` is treated as **not present** — it is **skipped, never grounded on**. Degrade gracefully: a missing project-docs directory is not an error; the run proceeds on whatever sections exist and on stated repo conventions. Cite a project-docs-grounded decision as `.project/<doc>.md#<section>` when carrying it forward.

While reading, **also assemble a grounding digest** — a compact, ordered set of `.project/<doc>.md#<section>` *slices* (each = the section anchor in the citation form above, paired with that section's body text), built **once** here and reused by the downstream briefs instead of re-reading the directory whole-file. Select slices with the **same filter already in force** — exactly the sections that exist, absent / `[TBD]` skipped (the line above and Step 3's "only the sections that exist (absent / `[TBD]` skipped)"); introduce **no new** selection or skip rule. The digest is a **superset that supplements**, never a replacement: (1) **superset** — it carries *every* implicated existing section, so handing the digest downstream in place of the directory never drops grounding; (2) **supplement** — it adds to, and does not close, the agents' on-demand Read/grep path: the architect and issue-author still independently Read/grep to verify any citation before recording it (each agent's own rigor gate stays mandatory — the architect cites its grounding / verifies a sibling `file:line` before recording it, and the issue-author "grep[s] before [it] cite[s]"). Degrade exactly as the line above does: a missing `projectDocs` directory (this repo has none), all-absent/`[TBD]` sections, or a read/parse failure → an **empty/minimal digest and no error**; the run proceeds best-effort on stated repo conventions. This step only **produces** the digest; the Step-3 architect brief and Step-4 issue-author brief that consume it are wired by issues #96/#97 and are not altered here.

Resolve the **shared keys** the architect and issue-author need for grounding, from the driver config (`docs/profile-schema.md` shared-keys chain):

1. `.milestone-config/driver.json` (primary).
2. Root `milestone-driver.json` (legacy fallback).
3. **Absent-default** — an unset key uses its documented default; the feeder does not invent a value.

The shared keys are exactly three: `sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch` (the canonical consumer-facing set — `SPEC.md` §7, `docs/profile-schema.md` §2). Each resolves down the chain above.

Resolve `nonNegotiables` **separately**, down the **same chain** (`.milestone-config/driver.json` → root `milestone-driver.json` → absent → **OMITTED**, never invented): it is **not** a fourth shared key but an **additional reviewer-profile input the self-check gate (Step 6) passes through** — the framework/platform/version constraints the driver's triage-reviewer expects on the profile and gates against (§6.2). An absent `nonNegotiables` is OMITTED (the reviewer simply has no version/platform constraints to check). **Degradation:** when `uiSurfaceGlobs` is absent (neither driver file carries it), treat every candidate as **logic** (no UI surface can be matched, so no design-lens distinction is drawn) and **state the degradation** in the plan file's grounding section. The pipeline still runs.

### The single-milestone inner routine (Steps 1–7) — callable contract

Steps 1–7 below are **one named, callable routine** — the single-milestone planner. The outer boundary (Step 0) resolves its inputs once and invokes it; on the single-brief path it is called **exactly once** (see the two-part note under `## Procedure`). Its contract:

**Parameters (three):**

1. **`briefSlice`** — one milestone's brief in the **Step-1 normalized shape** (`{ goal, in-scope, out-of-scope, surfaces, epicIssueNumber?, milestoneLine? }`, Step 1). On the single-brief path this **is** the whole brief.
2. **`resolved`** — the once-per-run **config + shared-keys bundle** Step 0 produced and hands in: the feeder keys (`projectDocs`, `reviewer`, `architectAgent`, `issueAuthorAgent`, `issueSize`), the assembled **grounding digest** (built once at Step 0), the resolved **shared keys** (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`) and `nonNegotiables`. **The grounding digest and the shared-key resolution are resolved once at Step 0 and passed in — the routine NEVER re-assembles the digest or re-resolves a shared key per invocation.** (The `versioning` declaration is **not** part of this Step-0 bundle — Step 0's key table does not resolve it; the Step-5.1 version ladder reads it fresh from `.milestone-config/feeder.json` at rung 2. It is `feeder.json` config the routine consults there, not a Step-0 output.)
3. **`buildOrderPosition`** — this milestone's position in the run's build order. On the single-brief path it is the **sole** position and **does not alter the rendered single-milestone plan file**.

**Returns:** one plan file at `.milestone-feeder/plan-<slug>.md` (Step 7) — **plus** the needs-product-input report at `.milestone-feeder/needs-product-input-<slug>.md` when anything parked. Every in-routine failure exit is **part of the routine** and surfaces to the caller unchanged: the Step 2 product-gap STOP and the Step 6 self-check Blocker park/retry (§6.5) fire from inside the routine, not from the boundary. A `briefSlice` that yields **zero surviving buildable issues** (the parked/dropped path) still routes **entirely** through the routine and emits the same empty/parked plan-file markers and needs-product-input report as today.

The routine body is Steps 1–7, exactly as written below — unchanged by this refactor.

### Step 1 — Ingest the brief (inner routine — begins)

The brief arrives in one of three forms. **Detect** which:

| Form | Detection | Read |
|---|---|---|
| **GitHub epic issue** | The bare brief is `#<n>`, or a bare integer | `gh issue view <n> --json number,title,body,comments` |
| **File path** | The bare brief is a path to an existing file | Read the file |
| **Inline text** | Otherwise | Use the text as-is |

§10 lean (`SPEC.md` §10): accept the brief **freeform**, normalize internally **first** into this shape before anything downstream consumes it:

```
{
  goal:            <one paragraph: what to build and why, in product terms>,
  in-scope:        [<bullets>],
  out-of-scope:    [<bullets>],
  surfaces:        [<the screens / modules / surfaces the brief touches>],
  epicIssueNumber: <n>                # present only when the brief was a GitHub epic issue; else omitted
  milestoneLine:   <the verbatim "<name> vX.Y.Z" string>   # present only when the user stated the milestone identity up front; else omitted
}
```

Record `epicIssueNumber` when the brief was an epic issue. `plan` posts **nothing** to the epic — the number is recorded in the plan file's source-brief reference so the downstream `create` / `update` can route their needs-input report to the epic comment. `plan` itself writes no GitHub state.

**Capture the explicit milestone identity (`milestoneLine`) when the user states it up front** (`docs/specs/v0.3.1-driver-handoff.md` §3 — milestone identity is a user-owned field). The user may name the milestone — with its version — either as a labelled `Milestone: <name> vX.Y.Z` line **in the brief doc** or as an inline statement alongside the brief. When present, capture that verbatim `<name> vX.Y.Z` string as `milestoneLine` — it is carried **verbatim** into the version-resolution step (Step 5's ladder, rung 1; `docs/specs/v0.3.1-driver-handoff.md` §2). This field is **optional and additive**: a brief with no `Milestone:` line and no inline statement omits it and normalizes exactly as before (`skills/plan/SKILL.md:46` ingest, `:56` normalize) — the missing field degrades gracefully to the rest of the ladder.

### Step 2 — Product-gap check (the park boundary)

Separate the two classes of decision the brief implies (`SPEC.md` §2, §6 Step 2):

| Class | Test | Action |
|---|---|---|
| **Product decision** | No conventional default — what to build, or user-facing behavior the project docs / a stated convention does not answer | Record to `productGaps[]`. **Never guessed.** |
| **Design / implementation decision** | The project docs or a stated repo convention supplies the answer | Resolved — proceed; cite the grounding (`.project/<doc>.md#<section>` or a sibling `file:line`). |

If a product gap is severe enough that the candidate set **cannot even be formed** without it (the brief's core scope is undecided), **STOP**: write the "needs product input" report (Step 7 format) and end the run — do not dispatch the architect against an undecided scope. The report is the local file `.milestone-feeder/needs-product-input-<slug>.md`. Because this STOP can be the run's **first** write under `.milestone-feeder/`, ensure the scratch dir self-ignores before writing the report (Step 7's "Make the scratch git-invisible from the first write" — create `.milestone-feeder/` if absent and ensure `.milestone-feeder/.gitignore` contains `*`). (No issues exist on a Step 2 STOP, so only the report is written; nothing else is produced.) Otherwise carry `productGaps[]` forward: the pipeline proceeds with the decidable work, and the gaps surface in the plan + report at Step 7.

### Step 3 — Dispatch the architect (once)

Dispatch the agent named in `architectAgent` (default `milestone-feeder:architect`) **exactly once** (`SPEC.md` §6 Step 3 — one heavy reasoning step).

**Brief it with** (matches `agents/architect.md` → "What you receive"):

- The **normalized brief** from Step 1 (`{ goal, in-scope, out-of-scope, surfaces }`).
- The **resolved grounding digest** from Step 0 — the `.project/<doc>.md#<section>` slices assembled there — as the architect's project-docs grounding. The digest is what is handed in; an **empty digest** (no `.project/`, or all sections absent / `[TBD]`) is passed through unchanged and is **not an error** (degrade exactly as Step 0 does — "a missing project-docs directory is not an error"). The digest **supplements, never replaces** the architect's on-demand Read/grep citation-verification path: the architect still reads the repo on demand to verify any citation per its rigor gate (`agents/architect.md` Rigor gate — "Every design default cites its grounding"), so where a slice is insufficient it falls back to reading source. (The digest's slice shape and absent-/`[TBD]`-skip rule are defined in Step 0; not restated here.)
- The **resolved shared keys** — the *values* for `sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`.
- `issueSize` when set; else the default (~1 PR each, independently buildable).
- The `productGaps[]` carried from Step 2.

**It returns** (verbatim from `agents/architect.md` → "Structured return block"):

```
CANDIDATES:
  - tag: #A
    title: <imperative one-line issue title>
    surface: ui | logic
    risk: light | heavy
    sketch: <what this issue does + the project-docs ref / sibling file:line grounding its design>
  - … (one per candidate)
EDGES:
  - "#B depends_on #A — <reason / the exact artifact reference>"
  - …                       # [] when no candidate depends on another
WAVES:
  - "Wave 1 (parallel): #A, #C"
  - "Wave 2: #B (depends on #A)"
  - …                       # topological sort of EDGES; Wave 1 = no unmet deps
PRODUCT_GAPS:
  - gap: <the product decision with no conventional default>
    why_blocked: <why it cannot be grounded in the project docs or a convention>
    brief_ref: <the brief line / phrase that asks for it>
    blocks: [#B, #D]        # the candidate LOCAL TAGS this gap blocks (Step 3.5
                            #   pre-parks them); `[]` when the gap is NOT tied to
                            #   specific named candidates (a broad product decision
                            #   flagged for the human, naming no candidate subset —
                            #   nothing pre-parks for it) — so the two stay
                            #   distinguishable
  - …                       # "none" when the brief is fully resolvable
SCOPE_SPANS_MULTIPLE_MILESTONES:
  - milestone: <name of proposed milestone 1>
    tags: [#A, #C]          # the candidate LOCAL TAGS under this milestone
  - milestone: <name of proposed milestone 2>
    tags: [#B]
  - …                       # "none" when the brief is a single coherent release;
                            #   when raised, names two or more milestones forming a
                            #   strict partition of `CANDIDATES`
```

`EDGES` is the literal `[]` when no candidate depends on another; `PRODUCT_GAPS` is the literal `none` when the brief is fully resolvable. **Merge** any architect `PRODUCT_GAPS` into `productGaps[]` — they join the gaps found at Step 2 — capturing each gap's `blocks:` tags alongside its `gap` / `why_blocked` / `brief_ref` (a `blocks:` list naming specific candidate tags drives the Step 3.5 early park; `[]` marks a gap not tied to specific named candidates — a broad product decision that names no candidates to pre-park). Step 2 gaps carry no `blocks:` list — they name no specific candidates by construction.

**Capture `SCOPE_SPANS_MULTIPLE_MILESTONES`** exactly parallel to how `PRODUCT_GAPS` is consumed: record it **verbatim** when raised (the list of `{ milestone, tags }` — the architect's proposed split); the literal `none` when absent. `plan` does **NOT** re-partition — it carries the architect's proposed split verbatim (the architect owns the structural read; `plan` only surfaces it). **Non-blocking invariant (scoped to the front-door's path).** This signal NEVER **aborts** the run and is NEVER silently dropped. On the **`none` path** — and on the **oversized-but-degraded** path where the front-door's route falls back (Step 3.6) — it does not gate: `plan` produces today's deployable **single-milestone** plan, unchanged, and never alters `CANDIDATES` / `EDGES` / `WAVES` / the surviving issue set / Wave order / milestone identity. On the **oversized** path, the front-door (Step 3.6) **routes** the brief into `build-roadmap` *before* the Step 4 fan-out — itself a non-blocking, surface-for-confirm checkpoint that **supersedes** the single-milestone pipeline for this brief (a decline or failure degrades back to it); it never hard-blocks. **Edge:** because the signal is sourced from the architect's structural read of `CANDIDATES` (not the surviving issue set), it is carried verbatim and surfaced **even if every candidate is later parked/dropped at Step 6** — it is independent of which issues survive. Grounding: `docs/specs/v0.3.1-driver-handoff.md` §5 (detection + advisory, non-blocking) and §6 (the additive Multi-milestone advisory plan-file field).

### Step 3.5 — Park candidates blocked by a shared product gap (before the fan-out)

Before the Step 4–6 fan-out, park the candidates the architect already linked to an unresolved product gap — so the run dispatches **no** issue-author, triage-reviewer, or design-reviewer for a candidate that is going to park anyway (`SPEC.md` §2 park boundary — only the dispatch *ordering* changes here; the boundary does not). This is the fail-fast: a shared no-default decision that blocks several candidates is parked **once, up front**, instead of being rediscovered per candidate at the Step 6 self-check.

1. **Take the union of all `blocks:` tags** across the **unresolved** `PRODUCT_GAPS` in `productGaps[]` (the architect gaps merged at Step 3, plus any Step 2 gap that named candidate tags). A gap with `blocks: []` is **not tied to specific named candidates** — it pre-parks nothing here (it names no candidates; it rides along in `productGaps[]` and surfaces in the report). The union is the set of candidate tags blocked by an architect-linked gap.
2. **For each blocked candidate in the union**, mark it parked as `needs-product-input` (product-gap kind) **WITHOUT** dispatching an issue-author for it, and **remove it from the set of candidates Step 4 fans out over**. Every `blocks:` tag resolves to a `CANDIDATES` entry by contract (`agents/architect.md` clause 2), so the parked marker's title is always available. These candidates dispatch **NO** issue-author (Step 4) and **NO** triage-reviewer and **NO** design-reviewer (Step 6) — they are parked before the fan-out, not after it.
3. **This REUSES the §6.5 product-gap park routing and the §6.6 drop-parked-issues + drop-dependents rule, applied earlier — it adds no new park mechanism.** A pre-parked candidate lands in `productGaps[]` and is routed exactly as a §6.5 product-gap park (the same `needs-product-input` record). Because a Step-3.5 pre-park is a product-gap entry in `productGaps[]` — exactly the input §6.6's drop pass already consumes — §6.6's "drop parked issues" pass (`skills/plan/SKILL.md` §6.6, line 321) removes the pre-parked candidate **ITSELF** (not only its dependents) from the rendered milestone description and **re-renders**, so the Wave order Step 5 produced never leaves a phantom tag naming a parked candidate. The §6.6 drop-**dependents** rule applies on top: a candidate that **transitively depends** on a pre-parked candidate is dropped (a dependent of a parked issue cannot build), removed from the Step 4 set, and marked dropped-because-dependency — exactly as §6.6 does for a late park. The only thing Step 3.5 changes is **WHEN** the park happens (before the fan-out vs at the self-check), for the gaps the architect already linked to candidates.

**Quality-hold invariant.** The candidates the architect **LINKED** to an unresolved gap park here — the **same** candidates that would have parked at the §6.5 self-check on the identical gap, just **earlier**; this only changes **WHEN** they park (before the fan-out vs at the Step 6 self-check). A candidate the architect linked to a gap would have authored, triaged, and then parked at the §6.5 self-check on that identical product gap; parking it here reaches the **same parked end-state for those candidates** without paying for their doomed author + triage + design dispatches. Surviving (non-blocked) issues are authored, reviewed, and gated exactly as before — quality on them (the gate's verdict on the surviving issues) is **unchanged**. (Acceptance criterion 3: a shared decision blocking ≥2 candidates is detected **ONCE here**, not rediscovered per candidate at Step 6.)

**Complementary, not a replacement — the §6.5/§6.6 late park stays the catch-all.** Step 3.5 is an **early** park for gaps the architect **linked to candidates** via `blocks:`. A gap the architect did **NOT** link to candidates — one that surfaces only later, at the self-check (e.g. an issue-author returns `STATUS: PRODUCT_GAP`, or a reviewer raises a Buildability "no conventional default" Blocker) — STILL parks via §6.5 exactly as today, unchanged. The two paths are complementary: Step 3.5 catches the architect-linked gaps early; §6.5/§6.6 remains the catch-all for everything discovered during the fan-out.

### Step 3.6 — Front-door size/scope check: route an oversized brief into `build-roadmap`

This is the **front-door** size/scope check. It runs after the architect's structural read is fully captured (Step 3) and after the Step-3.5 pre-park, and **before the Step 4 issue-author fan-out**. The architect's `SCOPE_SPANS_MULTIPLE_MILESTONES` signal is its **SOLE arbiter** of "oversized" — the front-door introduces **no second threshold metric of its own**; the borderline call is the architect's, carried verbatim. **Initialize `roadmapRouteTaken = false` HERE, before branching on the signal** — so every path (including `none`, which never enters the route below) leaves the flag in a defined state for Step 7's read, regardless of which branch runs. Branch on the captured signal:

| Captured signal | Front-door action |
|---|---|
| **`none`** (single coherent release) | **Do not route.** Fall straight through to Step 4 on the whole brief — today's single-milestone pipeline, **byte-for-byte unchanged**. No `build-roadmap` invocation, no advisory change, no new prompt. |
| **Raised** (≥2 milestones forming a strict partition of `CANDIDATES`) | **Route into `build-roadmap`** (the internal skill #152 introduced) — see below. |

**The oversized route.** Invoke the `build-roadmap` skill — a Claude Code **skill invocation**, the same way `create` runs `plan` first (`skills/create/SKILL.md:267`); there is **no bash/pwsh form** for the invocation itself. Hand it exactly the inputs its Step 0 expects (`skills/build-roadmap/SKILL.md` Step 0 — "Receive the inputs from `plan`"), **all already in hand — re-resolve nothing** (the resolve-once boundary, `skills/plan/SKILL.md:22`):

- the **oversized whole-app brief** — the Step-1 normalized brief (`{ goal, in-scope, out-of-scope, surfaces, … }`);
- the **source-brief reference** (`inline` | `file:<path>` | `epic #<n>`) captured at Step 1;
- the **resolved feeder profile + shared keys** (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`) from Step 0;
- the **resolved project-docs grounding digest** from Step 0 (an empty digest passes through unchanged — not an error, `.project/design-philosophy.md#Error & failure philosophy`).

`build-roadmap` dispatches the roadmap-splitter once, **surfaces the proposed split for the user to confirm / merge / split / reorder / reject** (it owns that checkpoint — `plan` does not re-surface it), and returns control with **either a confirmed manifest path or none** (`skills/build-roadmap/SKILL.md` Step 4). The `#154 → #155` hand-off **manifest shape is OWNED by `build-roadmap`'s #152 manifest contract** — `plan` forwards the manifest path; it does **not** redefine its shape. Consume the return:

| `build-roadmap` return | Front-door outcome |
|---|---|
| **A confirmed manifest path** | **Route taken.** Surface the confirmed roadmap + the manifest path, and hand it to the downstream **per-milestone fan-out (#155)** — which runs the single-milestone inner routine (Steps 1–7) once per milestone the roadmap names, in build order. (Wiring that fan-out is **#155's** scope; **#154** owns detect + route + invoke + surface + hand off.) On this path the single-milestone **Steps 4–7 do NOT run for the whole brief**, so the Step-7 passive *"~N milestones"* advisory is **SUPERSEDED** — the confirmed roadmap was surfaced in its place. |
| **No manifest path** — `build-roadmap` resolved the brief to a single milestone, the user **rejected** the split, or its own dispatch/return failed; **OR** `build-roadmap` does **not resolve** in this session (optional-skill degrade, mirroring `create`'s silent soft-dependency degrade, `skills/create/SKILL.md:251`) | **Degrade gracefully — never abort, never drop the signal.** Fall through to Step 4 on the whole brief — today's single-milestone pipeline, **unchanged** — and **RETAIN** the passive *"~N milestones"* advisory (Step 7 emits it, since the architect raised the signal). `build-roadmap` surfaces the reason for its own non-manifest outcomes (single-milestone / reject / error) itself; the retained advisory is the non-blocking backstop that keeps the signal from being silently dropped (`.project/design-philosophy.md#Error & failure philosophy`). |

**Route-state flag.** Record `roadmapRouteTaken` = **true** only on the confirmed-manifest outcome; **false** on every other (signal `none`, degrade, decline, single-milestone-after-all). Step 7 reads it to choose **supersede** (true → omit the passive advisory) vs **retain** (false **and** signal raised → emit it). The flag never gates the run; it only selects which surface the user sees.

### Step 4 — Dispatch issue-author per candidate (parallelizable)

For **EACH** candidate returned at Step 3 **that was not pre-parked (or dropped) at Step 3.5**, dispatch the agent named in `issueAuthorAgent` (default `milestone-feeder:issue-author`). The fan-out — and its cap-4 rolling window below — runs only over this **reduced** set; pre-parked and dropped candidates get no dispatch. **Dispatch all N authors concurrently as background agents** — one `Agent(run_in_background: true)` per candidate — **with no more than 4 in flight at once**. If N > 4, use a **rolling window / batches** so the in-flight count never exceeds 4 (as one author returns, dispatch the next). When N ≤ 4 this rule is a no-op — dispatch all of them, no rolling window is needed (and N = 0 / N = 1 are trivial). Cap 4 is a safe, conservative default, mirroring the driver's worker fan-out (`milestone-driver` plugin `skills/solve-milestone/SKILL.md` Phase 1 step 2: "no more than 4 workers running at once… rolling window / batches so the in-flight count never exceeds 4"). **Quality hold:** issue-authors are stateless and write no shared state, so running them concurrently cannot change any issue body — the output is identical to a serial fan-out.

**Barrier at Step 5.** **Await ALL author completions before Step 5 (Assemble graph) begins** — Step 5 consumes every returned issue, so the whole fan-out must have returned before it can start. Authors that return concurrently are collected at this join; a returned `STATUS: PRODUCT_GAP` routes to `productGaps[]` at the join exactly as the serial path does (see the routing rule below), and the rolling window keeps refilling until every candidate has returned.

**Cap ownership (SKILL ↔ SPEC lockstep).** This SKILL carries the **operational** detail — the cap W = 4 and the rolling window above. `SPEC.md` §6 Step 4 remains the looser normative statement ("per candidate (parallelizable)"); it does not name a cap. SKILL.md owns the cap; SPEC.md is intentionally not made more specific here.

**Brief each with** (matches `agents/issue-author.md` → "What you receive"):

- The **candidate** — its tag, title, surface/risk hint, and sketch (from Step 3).
- The **brief** (the grounding source carrying *what to build*, in product terms) **and the resolved grounding digest** from Step 0 — the `.project/<doc>.md#<section>` slices assembled there — as the author's project-docs grounding. The digest is what is handed in; an **empty digest** (no `.project/`, or all sections absent / `[TBD]`) is passed through unchanged and is **not an error** (degrade exactly as Step 0 does — "a missing project-docs directory is not an error"). The digest **supplements, never replaces** the author's on-demand Read/grep citation-verification path: the author still greps the live repo to verify any citation before recording it per its rigor gate (`agents/issue-author.md` Rigor gate — "grep before you cite"), and may grep for anything not in the digest — the digest is not an allowlist. (The digest's slice shape and absent-/`[TBD]`-skip rule are defined in Step 0; not restated here.)
- The **resolved shared keys** — `sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`.
- The **edges naming this candidate** — the architect edges that touch this tag, to record verbatim (the author transcribes; it does not invent edges or reorder Waves).
- Any `productGaps[]` **scoped to this candidate**.

**Each returns** (verbatim from `agents/issue-author.md` → "Output format"):

```
STATUS: AUTHORED | PRODUCT_GAP
ISSUE_TAG: #A
TITLE: <final imperative title>
ISSUE_BODY: |
  <the §4 issue-body template, verbatim — Summary / Acceptance criteria /
   Design (recorded, consistent) / Dependencies / Classification>
LABELS: [<ui|logic>, <risk:light|risk:heavy if confident>]
PRODUCT_GAP (only when STATUS: PRODUCT_GAP): { what: <the product decision with no conventional default>, why: <why it cannot be grounded> }
```

When a candidate returns `STATUS: PRODUCT_GAP`, **route it to `productGaps[]`** — do **not** author a half-invented issue from a fabricated body. The candidate is recorded as parked, not authored; the plan file still renders the candidate's tag/title with a "parked — needs product input" marker.

### Step 5 — Assemble graph + render the milestone description

Build the **dependency graph** from the architect's `EDGES`: each candidate's direct dependencies, and the Wave-ordered topological sort the architect returned in `WAVES`. The graph uses the candidates' **local tags / slugs** — no GitHub issue numbers exist (`agents/architect.md` clause 6: local tags, not GitHub numbers).

Render the **milestone description** to the `SPEC.md` §4 Wave template, substituting the local slugs/tags for the `#<n>` placeholders:

```markdown
<one-paragraph milestone goal>

## Waves
- Wave 1 (parallel): #A, #B, #C
- Wave 2: #D (depends on #A, #B)
- Wave 3: #E (depends on #D)
```

This is the human-readable description and the exact ordering source the driver's `solve-milestone` and `triage` consume (`SPEC.md` §4). In the plan file the identifiers are **local slugs** (`#A`/`#B`); `create` rewrites them to real GitHub numbers once the issues exist (the two-pass slug→`#n` mechanic, owned by `create`). `plan` itself does no slug→`#n` rewrite — no GitHub numbers exist yet, so it writes local slugs only.

#### 5.1 — Resolve the milestone version + exact title (the version ladder)

Resolve the milestone's **exact title** — the load-bearing identity string that carries the semver **inside it** (there is **no separate version field**; the driver parses the version from the title, so that is the single place it can live — `docs/specs/v0.3.1-driver-handoff.md` §2, and §10's "A separate version field" non-goal). Resolve it by the **layered ladder below, FIRST-MATCH-WINS** — the first rung that yields an answer wins and the ladder STOPS (`docs/specs/v0.3.1-driver-handoff.md` §2 *"The layered version default"*). Alongside the title, record a one-line **version provenance** (one of `explicit` | `declaration` | `inferred from <tag/milestone>` | `prompted`) so the surfaced default is legible (`docs/specs/v0.3.1-driver-handoff.md` §6).

**This sub-step is READ-ONLY on GitHub.** Its only new repo reads are a read-only `git tag` read and a **read-only** `gh api` milestones read (rung 3); it **creates, posts, and patches nothing**. The greenfield prompt (rung 4) is the **one sanctioned interactive moment** of the run. This is consistent with the no-GitHub-write invariant (`skills/plan/SKILL.md:10` and the **Non-negotiables** section): `plan` writes NO GitHub state.

| Rung | Source | Outcome | Provenance |
|---|---|---|---|
| **1. Explicit** | The `milestoneLine` captured at Step 1 (the up-front `Milestone: <name> vX.Y.Z` line or inline statement) — **or** a version the user types when prompted at rung 4. | Used **verbatim** as the exact title. Ladder STOPS. | `explicit` |
| **2. Declaration** | `versioning` from `.milestone-config/feeder.json` (the optional key #56 introduced; `docs/profile-schema.md` — the `versioning` own-keys row + its per-key note). | `"none"` → **NO version, NO prompt**; goal-derived name only → ladder STOPS. `"semver"` → project IS versioned → **continue DOWN to rung 3** to find the number (the declaration confirms *versioned* but carries no number). Absent / invalid / unrecognized value → **treat as absent** → continue to rung 3 (infer-or-ask); **never error on the key** (per the `docs/profile-schema.md` `versioning` per-key note: an invalid/unrecognized value is treated as absent). | `declaration` (only on the `"none"` stop) |
| **3. Infer** | Read-only repo signals (see the two sub-rungs below). | The matched/latest **reference** semver composes the title (carried **verbatim**); the feeder **PROPOSES** the title and **surfaces it** in the plan file for confirm/adjust — it does **not** silently finalize. Falls to rung 4 only if neither signal yields anything. | `inferred from <milestone>` or `inferred from <tag>` |
| **4. Prompt** | Only when **nothing above resolved** (no declaration / no `"semver"`-with-a-number, no milestone titles, no tags — a greenfield repo). | Ask up front, **ONCE** — the one sanctioned interactive moment: *"Is this a versioned project? If so, what version is this milestone?"* (`docs/specs/v0.3.1-driver-handoff.md` §2 rung 4). **Version typed →** used **verbatim** as the exact title (the same verbatim-into-title mechanic as rung 1), with provenance `prompted` (NOT `explicit` — the value was prompted, not stated up front); ladder STOPS. **DECLINE →** NO version is added, the title uses the goal-derived name (exactly as rung 2 `"none"`), provenance is recorded as `declaration` (the user has declared this project non-versioned at the prompt), and the ladder STOPS. | `prompted` (version typed) / `declaration` (declined) |

**Provenance legibility note.** `declaration` provenance applies only to the rung-2 `"none"` STOP and the rung-4 DECLINE (above) — both record that the user declared the project non-versioned. A project declared `versioning:"semver"` (rung 2) that reaches the rung-4 prompt because nothing was inferable still records provenance `prompted`, not `declaration`: a number had to be prompted, so the provenance reflects how the *number* was obtained, even though the project was declared versioned.

**Rung 3 — the two read-only infer signals (in order):**

1. **FIRST, the highest semver among EXISTING milestone TITLES.** **Reuse the canonical `env.t`-style quote-safe `gh api` milestones read defined in `skills/create/SKILL.md` Step 3 pass (b) BY REFERENCE — do NOT re-define it** (the same reuse-by-reference discipline `skills/update/SKILL.md:60` follows; both bash and PowerShell 7+ forms are given at `skills/create/SKILL.md:84-90`). **One intentional delta from create pass (b):** create pass (b) `select`s the **one** milestone whose title equals `env.t`; here you read **ALL** milestone titles (no `env.t` filter — e.g. `--jq '.[] | .title'`) and scan them for the **highest** semver, since you are finding a reference version rather than matching one exact title (the delta is noted here exactly as `skills/update/SKILL.md` notes its own pass-(b) delta). The matched milestone's **NAME part is reused** for the title; its (highest) semver is the **REFERENCE** version. Provenance `inferred from <milestone>`.
2. **ELSE the latest `vX.Y.Z` git tag.** Use a cross-platform `git tag` read (plain `git tag` works identically on bash and PowerShell 7+; e.g. `git tag --list 'v*'` then pick the highest semver — keep any sort shell-neutral, do not rely on a shell-specific sort flag). The **reference** version is that tag; the **name** falls back to today's goal-derived name. Provenance `inferred from <tag>`.

**On EITHER infer path:** the inferred/composed title carries the **REFERENCE (highest existing) semver VERBATIM**, and the surfaced plan-file line is **WHERE THE USER ADJUSTS the patch / minor / major bump** — the feeder cannot know whether this milestone is a patch, minor, or major bump, so it proposes the reference version verbatim and lets the user adjust the bump on the surfaced line (`docs/specs/v0.3.1-driver-handoff.md` §2 rung 3). The feeder PROPOSES; it does not silently finalize.

**The resolved exact title always carries the semver INSIDE the title string** — there is no separate version field (`docs/specs/v0.3.1-driver-handoff.md` §2, §10). It lands in the plan file's `Milestone title (exact)` identity field (Step 7; `docs/specs/v0.3.1-driver-handoff.md` §6), with its `Version provenance` line, **both SURFACED for the user to confirm or override BEFORE running `create`** (`docs/specs/v0.3.1-driver-handoff.md` §2, §3). A `"none"` declaration (rung 2) yields a goal-derived name with **no semver** and provenance `declaration`; non-versioned projects are left alone.

### Step 6 — Self-check gate (the keystone)

Before writing the plan file, vet **every generated issue** with the same gate that fronts the driver's build loop, so what the feeder plans passes the driver's triage clean (`SPEC.md` §5; success criterion `SPEC.md` §1). This step performs **no GitHub writes**; it gates what the plan file (Step 7) reports. Dispatch every reviewer **read-only, against the generated text** (their contracts take provided issue text and make no `gh` call of their own — confirmed against `milestone-driver/agents/triage-reviewer.md:96-101` and `design-reviewer.md:94-99`; no agent modification is needed).

**Fan out the reviewer dispatches concurrently — two STAGED batches.** This step's first pass over the N generated issues is the densest dispatch phase in the run; run it concurrently, not serially. Batch it in the **same cap-4 rolling window as Step 4** (one `Agent(run_in_background: true)` per dispatch, **no more than 4 in flight at once**; if a batch exceeds 4, refill with a rolling window — as one returns, dispatch the next; ≤4 is a no-op of the same rule — see the Step 4 author fan-out above and the driver's `skills/solve-milestone/SKILL.md` Phase 1 step 2 it mirrors). Run the fan-out as **two staged batches**:

1. **Pass 1 — triage batch.** Dispatch all N `triage-reviewer` calls concurrently (one per generated issue), under the cap-4 rolling window. **Barrier:** await the whole triage batch before opening Pass 2.
2. **Pass 2 — design batch.** Dispatch the U `design-reviewer` calls concurrently — **only** for the issues whose triage returned `NEEDS_DESIGN_REVIEW: yes` — under the same cap-4 rolling window. (When `uiSurfaceGlobs` is absent, U = 0: no triage block flags a design review, so Pass 2 is empty — the existing degradation already covers this. U = 0 / U = 1 are trivial.)

**Quality hold — why batching is verdict-neutral.** The reviewers are read-only verdict functions over the provided text and make **no `gh` call of their own** (stated above; `skills/plan/SKILL.md:206`), so batching a single pass cannot change any verdict — the aggregated `GAPS` for each issue are identical to a serial fan-out. **Three invariants the batching MUST preserve (the gate logic is unchanged):**

- **(a) Within-issue staged ordering.** An issue's design review runs **only after that issue's triage returns `NEEDS_DESIGN_REVIEW: yes`** — so the two batches are STAGED, never interleaved per issue: the whole triage batch (Pass 1) barriers first, **then** Pass 2 opens for the flagged subset. No design dispatch starts before its issue's triage verdict is known.
- **(b) §6.1 degrade-decided-once survives batching.** §6.1's runtime degrade-to-internal trigger still decides the backend **once**, on the **first** triage return that lands — evaluate it on that first return, then batch/continue the remainder of Pass 1 under the chosen backend. Concurrency does not retry the degrade per issue, and the per-issue internal-fallback for a *later* non-resolution (§6.1) is likewise unchanged.
- **(c) Between-pass retry/re-render stay SERIAL.** The concurrency applies **only** to the within-a-single-pass fan-out (Pass 1 triage, Pass 2 design). The between-pass operations — §6.5's ≤2 `issue-author` re-dispatches per FAILed issue, and §6.6's absorb-edge → re-render-the-milestone-description (before any §6.5 re-dispatch) → re-run §6.3 — are **NOT** batched: they run serially, with the §6.6-before-§6.5 ordering and the ≤2-per-issue cap untouched.

#### 6.1 — Resolve the `reviewer` backend

The `reviewer` value read at Step 0 selects the backend. Resolve it as follows:

| `reviewer` | Backend |
|---|---|
| `"milestone-driver"` (default) | Dispatch `milestone-driver:triage-reviewer` per generated issue, and `milestone-driver:design-reviewer` for issues whose triage returns `NEEDS_DESIGN_REVIEW: yes`. **If the reviewers do not resolve at dispatch time, degrade to `"internal"` (see the runtime trigger below) — a notice, never a failure.** |
| `"internal"` | Run the **internal checklist** (§6.4) — the feeder's own check mirroring the five triage criteria. Same pass/Blocker verdict shape, so the gate logic downstream is backend-agnostic. |
| `false` | **Skip the gate.** Print a **visible 🔴 warning** to the user — `🔴 Self-check DISABLED (reviewer:false) — generated issues were NOT vetted against the driver's entry gate; they may not pass triage.` — and record `SKIPPED (reviewer:false)` in the plan-file verdict line (Step 7). Proceed straight to writing the plan file; run no reviewer and no checklist. |

**Runtime degrade-to-internal trigger (`"milestone-driver"` → `"internal"`).** The degrade is decided at **dispatch time, not config time** (mirrors the *config*-time reviewer-resolve probe in `skills/setup/SKILL.md:29`, but applied live here because availability can differ between setup and this run). On the **first** issue's `triage-reviewer` dispatch: attempt the dispatch; if the agent **does not resolve** (no such agent in the session — `milestone-driver` not installed) **or the dispatch returns no usable block** (the return does not contain a parseable `ISSUE:` / `GAPS:` block), then:

1. Emit a visible notice: `Self-check: milestone-driver reviewers did not resolve — degrading to the internal checklist for this run.`
2. Switch the backend to `"internal"` for the **remainder of the run** (do not retry `milestone-driver` per issue — decide once, on the first dispatch). **Under the concurrent Pass-1 triage batch (Step 6 intro), "first dispatch" means the first triage return that LANDS:** evaluate the degrade trigger on that first return, then batch/continue the rest of Pass 1 under the chosen backend — the decide-once semantics hold unchanged.
3. Record the outcome under the `INTERNAL` verdict line at Step 7.

This gives the `"milestone-driver"` → `"internal"` branch a single, defined trigger: a non-resolving agent or an unparseable return on the first dispatch. A reviewer that resolves and returns a valid block — even one full of Blockers — is **not** a degrade; that is a normal gate result handled by §6.3.

**Per-issue fallback for a later non-resolution.** The first-dispatch trigger above decides the backend for the run, but a **later** issue's `milestone-driver` dispatch can still come back unusable (no resolvable agent that call, or a return with no parseable `ISSUE:` / `GAPS:` block) even after the run committed to `"milestone-driver"`. Such a return matches neither §6.3 verdict (it is not `GAPS: none`, and it carries no parseable Blocker), so it must not fall through — an issue is **NEVER** planned unvetted. When it happens, run **that one issue** through the §6.4 internal checklist as a per-issue fallback, take its verdict from there, and record `internal-fallback` against that issue in the Step 7 verdict line. The run's backend stays `"milestone-driver"` for the remaining issues (this is a single-issue fallback, not the run-wide degrade).

#### 6.2 — Compose each reviewer brief (from GENERATED content)

Brief each reviewer from the **generated** artifacts (matches `triage-reviewer.md` → "What you receive" and `design-reviewer.md` → "What you receive"), using **local slug identifiers** throughout (`#A`/`#B`) — no GitHub numbers exist:

- **The issue** — the generated title, the generated `ISSUE_BODY` (Summary / Acceptance criteria / Design / Dependencies / Classification), and the acceptance criteria within it, from Step 4.
- **Recorded design decisions** — **empty** (no GitHub issue exists yet, so there are no comments / `design-cleared` notes). State this explicitly in the brief so the reviewer does not treat the empty set as a gap in itself.
- **Milestone description** — the Step 5 Wave-ordered description (with local slugs) as the **cross-issue dependency context** — this is the reviewer's ordering source for the Dependencies criterion.
- **The profile** — the resolved **real target-repo** shared keys `sourceGlobs`, `uiSurfaceGlobs` (for source grounding), **plus `nonNegotiables`** (the additional reviewer-profile input — not a shared key). All are already resolved at Step 0 (that is the single resolution authority — same chain, same absent-default rule); `nonNegotiables` absent → omitted (the reviewer simply has no version/platform constraints to check against).

For `design-reviewer`, brief the **pointers to existing UI surfaces** via the resolved `uiSurfaceGlobs` (matches `design-reviewer.md:38`).

#### 6.3 — Consume the returned blocks (the gate logic)

Each `triage-reviewer` returns an `ISSUE / DEPENDS_ON / NEEDS_DESIGN_REVIEW / GAPS` block; each `design-reviewer` returns an `ISSUE / GAPS` block (verbatim shapes at `triage-reviewer.md:59-70` and `design-reviewer.md:58-67`). For each generated issue, **aggregate** the `GAPS` entries from its triage block and (when dispatched) its design block, keyed on **lens / severity / description**:

| Aggregated result | Verdict |
|---|---|
| Every dispatched block returns `GAPS: none` | **PASS** — the issue clears the gate. |
| Any `GAPS` entry carries `severity: Blocker` | **FAIL** — the issue is gated; route it through the retry/park fork (§6.5). |

`severity: Advisory` entries do **not** fail the gate (they mirror the driver's own Advisory-is-not-blocking rule, `triage-reviewer.md:81-82`); record them in the plan file's grounding section as notes, but do not retry on them. `GAPS: none` passes; any `Blocker` fails — there is no third state.

The internal-checklist backend (§6.4) produces the **same verdict shape** — a per-issue PASS, or a FAIL carrying findings with the reviewers' five fields (`lens` / `severity` / `type` / `description` / `to_clear`) — so §6.5 reads `lens` and `severity` (and §6.6 reads `type`) identically regardless of backend.

#### 6.4 — The internal checklist (the `"internal"` backend)

When the backend is `"internal"` (configured, or degraded-to at §6.1, or the per-issue fallback at §6.1), apply this checklist to **each generated issue's text** — it mirrors, criterion-for-criterion, what the driver's reviewers check (`triage-reviewer.md:43-53`, `design-reviewer.md:42-52`) and this repo's five-criteria contract (`SPEC.md` §4 table). Emit each finding in the **same five-field shape the reviewers return** — `lens` / `severity` / `type` / `description` / `to_clear` — so §6.5 reads `lens` and `severity`, and §6.6 reads `type`, identically regardless of backend. An issue with no Blocker finding is PASS.

| # | Criterion (mirrors `SPEC.md` §4) | Internal check on the generated issue text | Blocker when |
|---|---|---|---|
| 1 | **Consistency** | Re-read the Design section: do any two recorded statements contradict (cannot both be true)? | Two recorded statements contradict (`triage-reviewer.md:45`). |
| 2 | **Buildability** | Does every decision the acceptance criteria require have a recorded value or a `Convention followed:` line citing the project docs / a sibling `file:line`? | A required decision is neither recorded nor resolvable by a stated convention (`triage-reviewer.md:47`). A choice an established convention answers is **Advisory**, not Blocker. |
| 3 | **Completeness** | Do the acceptance criteria enumerate happy + empty + error/failure + disabled/edge states — not just the happy path? **And, when the issue affects existing users or their config** (a new feature, config key, or behavior change touching them — not pure greenfield), do they record an existing-user **discovery path** — a one-time notice, a setup re-run prompt, or a documented upgrade note (the normative principle, `SPEC.md` §3.1; canonical example: `milestone-driver/skills/solve-milestone/SKILL.md` steps 2.1 / 1.2)? | A required state is silently missing and that makes the issue un-deliverable (`triage-reviewer.md:49`); **or** the issue affects existing users/config but records **no** discovery path. Both raise a `missing-criteria` finding (per the `type` map below) — non-breaking alone is necessary but not sufficient. |
| 4 | **Dependencies** | Does the issue reference a type/file/contract/screen another generated issue introduces, and is that edge declared in the Dependencies section + reflected in the Wave order? | An undeclared hard dependency exists (`triage-reviewer.md:51`). |
| 5 | **UI flag** *(+ design sub-criteria for UI issues)* | Is the issue classified UI vs logic against `uiSurfaceGlobs`? For a **UI** issue: does the Design section name the existing pattern to mirror (`file:line`), the required states (empty/loading/error/disabled), the affordances (confirm dialog for any destructive op), and accessibility labels? | A UI issue is missing a required state, a required affordance (e.g. confirm dialog on a destructive op), or names no pattern to mirror (`design-reviewer.md:44,50,52`). |

For each finding, set the five fields: **`lens`** = `architect` for criteria 1–4, `design` for criterion 5's UI sub-criteria (mirroring which driver reviewer owns the criterion); **`severity`** = `Blocker` per each row's "Blocker when" rule, else `Advisory` — a choice an established convention answers is **Advisory, not Blocker** (criterion 2's rule, applied to every criterion); **`type`** = the driver reviewers' own `type` vocabulary, mapped from the failing criterion (table below) so §6.6 can key on it exactly as it does for a `milestone-driver` block; **`description`** = the failing statement on the generated text; **`to_clear`** = what the issue must record to clear it. This is the same shape §6.3 aggregates and §6.5 classifies.

| Failing criterion | `type` (driver vocabulary) | Lens it maps to |
|---|---|---|
| 1 — Consistency | `contradiction` | architect (`triage-reviewer`) |
| 2 — Buildability | `not-buildable` — or `missing-criteria` when a required decision is simply *unrecorded* (no contradiction, just absent); pick the closest | architect (`triage-reviewer`) |
| 3 — Completeness | `missing-criteria` | architect (`triage-reviewer`) |
| 4 — Dependencies | `undeclared-dependency` ← **§6.6 keys on this; it MUST be present** | architect (`triage-reviewer`) |
| 5 — UI / design sub-criteria | the design-lens type matching the failing sub-criterion: `missing-state` (a required state absent), `missing-affordance` (a required affordance absent, e.g. no confirm dialog on a destructive op), `pattern-inconsistency` (the design diverges from the named existing pattern), `spec-insufficiency` (the design is under-specified to build), or `accessibility` (missing labels / a11y) | design (`design-reviewer`) |

When `uiSurfaceGlobs` is absent (the degradation noted at Step 0), treat every issue as **logic** — criterion 5's UI sub-criteria do not apply (no UI surface can be matched), exactly as the driver's reviewers emit `NEEDS_DESIGN_REVIEW: no` when `uiSurfaceGlobs` is absent (`triage-reviewer.md:53`).

#### 6.5 — Retry / park fork (per FAILed issue)

For each issue that FAILed §6.3, classify each Blocker and act — bounded to **at most 2** `issue-author` re-dispatches, the same cap the driver applies on every gate (`milestone-driver/skills/solve-issue/SKILL.md:119`):

| Blocker class | Test | Action |
|---|---|---|
| **Design / implementation-resolvable** | A Blocker in the issue **body** the project docs or a stated repo convention can answer — a recordable design/impl decision (e.g. a missing state, an unnamed pattern to mirror). *(An `undeclared-dependency` Blocker is **not** here — §6.6 handles it; see precedence below.)* | **Re-dispatch `issue-author`** for that candidate (§Step 4 brief) with the Blocker's `description` + `to_clear` and the existing `ISSUE_BODY` to fix. Re-run §6.3 on the revised issue. **≤2 retries.** |
| **Genuine product gap** | No conventional default — what to build / user-facing behavior the project docs and a stated convention do not answer (the Buildability "no conventional default" case). | **Park to `productGaps[]`** / the needs-product-input report — do **not** re-author (re-dispatching cannot resolve a product gap; only a human can). Record as `needs-product-input`. |
| **Still-Blocker after 2 retries** | A design/impl Blocker that has not cleared after the 2nd `issue-author` re-dispatch. | **Park as needs-human-direction** in the report (the issue is non-converging — usually the candidate's design is wrong). Do not re-author further. |

**Retry-budget shape.** The **≤2** cap counts `issue-author` **re-dispatches per issue** (not Blockers, not gate passes). Each re-dispatch's brief carries **all of that issue's currently-outstanding Blockers** at once — a re-dispatch addresses every open Blocker in a single authoring pass, not one Blocker per retry — so two re-dispatches give the candidate two full attempts to clear the whole gate.

**Precedence — `undeclared-dependency` is §6.6, not §6.5.** An `undeclared-dependency` Blocker is handled entirely by §6.6 (absorb the edge into the graph + re-render the milestone description); it does **not** consume a §6.5 `issue-author` re-dispatch. §6.5's re-author path is reserved for design/impl Blockers in the issue **body** (missing state, unnamed pattern to mirror, etc.). The two never both act on the same Blocker.

A parked issue is **not emitted** in the milestone (§6.6 handles it and its dependents). The needs-product-input report (Step 7 format) gains a row per parked issue, marking product-gap vs needs-human-direction. A candidate pre-parked at **Step 3.5** lands in this **same** `productGaps[]` → Parked issues table → needs-product-input report (as `product-gap`); the pre-parked candidate **itself** and its dropped dependents both flow through §6.6's drop-and-re-render (line 321) unchanged — §6.6's drop pass removes the pre-parked candidate from the rendered milestone description (it is a product-gap entry in `productGaps[]`) and drops every dependent — so Step 3.5 reuses this Step 7 machinery, it does not duplicate it.

#### 6.6 — Absorb undeclared edges; drop parked issues

- **Undeclared `DEPENDS_ON` edges.** When a returned block surfaces a `DEPENDS_ON` edge (a `triage-reviewer` block) **or** a `severity: Blocker` of `type: undeclared-dependency` (from either backend — a `milestone-driver` block or an internal-checklist Criterion-4 finding; both now carry `type`, so this resolves identically) the architect did not declare, **add it to the dependency graph** and **re-render the milestone description** (re-run Step 5's render) so the Wave order reflects the new edge **before** any §6.5 re-dispatch — the re-dispatched `issue-author` and any subsequent reviewer pass see the corrected ordering context. This absorb-and-re-render cycle participates in the **same ≤2 per-issue re-dispatch bound** as §6.5: an issue still carrying a Blocker after its 2nd re-dispatch **parks as needs-human-direction** regardless of how the edge was re-rendered, so the re-render/re-dispatch loop always terminates at the cap.
- **Drop parked issues and their dependents.** A parked issue (product-gap or needs-human-direction) is removed from the planned milestone, **and so is every issue that transitively depends on it** (a dependent of a dropped issue cannot build). Drop them from the rendered milestone description and mark them in the plan file as dropped-because-dependency. Re-render the milestone description once more after dropping, so the planned Wave order (Step 7) contains only the issues that actually ship.

After §6.6, the surviving issue set has either all-PASS (or all-Advisory-only) verdicts, or the run is `SKIPPED` (`reviewer:false`). Carry the gate outcome forward to the Step 7 verdict line.

### Step 7 — Write the plan file (inner routine — ends; returns the plan file)

By the time this step runs, the self-check gate (Step 6) has already produced the **surviving issue set** — the gate-clean (PASS / Advisory-only), **non-parked, non-dropped** issues from §6.6. Parked (product-gap / needs-human-direction) and dropped-dependent issues are **never carried as buildable**; they go to the report (parked) or are simply omitted (dropped). This step writes a single reviewable plan file. **No GitHub writes occur — `plan` writes only local scratch files.**

Write the reviewable **plan file** to a gitignored per-run scratch path: `.milestone-feeder/plan-<slug>.md`. The `<slug>` is a **deterministic** kebab-case slug of the milestone **goal**, so the same brief always resolves to the same path and `create` / `update` can locate it. Derive `<slug>` deterministically: take the one-line milestone goal, lowercase it, replace every run of non-alphanumeric characters with a single hyphen, then strip any leading/trailing hyphens (cap the length at a reasonable bound, trimming a trailing hyphen if the cut lands on one).

**Make the scratch git-invisible from the first write (zero user setup).** `.milestone-feeder/` is pure per-run scratch — the plan file and any reports the user reviews, then deploys via `create` — with no tracked config of its own (per-clone runtime scratch, like the driver's `.milestone-driver-*`). **Before writing any file under `.milestone-feeder/`, FIRST ensure the directory self-ignores:** create `.milestone-feeder/` if absent, and ensure `.milestone-feeder/.gitignore` exists containing a single `*` line. A `*` inside that folder makes the whole folder (and the `.gitignore` itself) invisible to `git status` in **any** consumer repo, without touching the consumer's root `.gitignore`. Do this on the first write of every run so a freshly-cloned consumer is clean from the very first `plan`:

```bash
# bash — ensure the scratch dir self-ignores BEFORE the first write under it.
mkdir -p .milestone-feeder
[ -f .milestone-feeder/.gitignore ] || printf '*\n' > .milestone-feeder/.gitignore
```

```powershell
# PowerShell 7+ — same ensure-self-ignore before the first write.
New-Item -ItemType Directory -Force -Path .milestone-feeder | Out-Null
if (-not (Test-Path .milestone-feeder/.gitignore)) { Set-Content -LiteralPath .milestone-feeder/.gitignore -Value '*' -Encoding utf8NoBOM }
```

**The plan-file contract.** The plan file is the load-bearing build artifact: `create` and `update` read it and write GitHub from it — they regenerate nothing. It MUST carry every field below, unambiguously (`SPEC.md` §3):

| Field | Requirement |
|---|---|
| **Milestone title (exact)** | The exact milestone title, on its own labeled line — **distinct** from the one-line goal. Now **user-owned** and carrying the resolved **semver inside the string** (no separate version field), resolved at Step 5.1 by the version ladder and **surfaced for the user to confirm or override BEFORE `create`** (`docs/specs/v0.3.1-driver-handoff.md` §3, §6). `create` / `update` still resolve the milestone by this exact title (creating it if absent, adopting it if it already exists), and the driver parses the version from it — this remains the load-bearing identity field; the one-line goal is descriptive only. |
| **Version provenance** | One line, one of `explicit` \| `declaration` \| `inferred from <tag/milestone>` \| `prompted` (the Step 5.1 ladder rung that resolved the title — `docs/specs/v0.3.1-driver-handoff.md` §6 "Version provenance" row). It makes the surfaced default **legible** so the user can trust or correct it. |
| **Multi-milestone advisory** | **ADDITIVE and OPTIONAL** — present **ONLY** on the **retained** path: the architect raised `SCOPE_SPANS_MULTIPLE_MILESTONES` (Step 3) **AND** the front-door (Step 3.6) did **NOT** route this brief into `build-roadmap` (`roadmapRouteTaken` false — the signal was raised but the route degraded, was declined, or resolved to a single milestone). On that path it carries the flag + the proposed split (milestone names + their candidate tags) **VERBATIM** from the architect — `plan` does not re-partition. **OMITTED entirely** when the signal is `none` (single-milestone plan byte-for-byte unchanged) **OR** when the front-door **took the route** (`roadmapRouteTaken` true — the confirmed roadmap was surfaced in its place, so this passive advisory is **SUPERSEDED**; on the route path the single-milestone Steps 4–7 do not run for the whole brief anyway). **Non-blocking** — it does not change what gets deployed; the plan stays a deployable single-milestone plan. Sourced from the architect's structural read of `CANDIDATES`, so on the retained path it is written even if every candidate is parked/dropped (Step 6). Grounding: `docs/specs/v0.3.1-driver-handoff.md` §6 (the additive plan-file field) and §5. |
| **One-line goal** | The milestone goal in one line — the header. |
| **Milestone description (Wave order)** | The Step 5 build-order / Wave description, verbatim, with local slugs (`#A`/`#B`). This is what `create` PATCHes onto the milestone after issue numbers exist. |
| **Per surviving issue** | For each surviving (gate-clean / Advisory-only) issue: its slug, title, the FULL §4 `ISSUE_BODY` verbatim, its labels, and its surface/risk. `create` reads these — no regeneration. |
| **Parked issues** | Each parked issue: slug, title, and kind (`product-gap` \| `needs-human-direction`). Marked, never created. |
| **Dropped issues** | Each dropped issue: slug, title, and the parked dependency that dropped it. Marked, never created. |
| **Self-check verdict line** | The Step 6 outcome (PASS / INTERNAL / PARKED / SKIPPED(reviewer:false)). `create` trusts it; no re-vet. |
| **Source brief reference** | `inline` \| `file:<path>` \| `epic #<n>` — drives the downstream report routing and the brief↔plan match. Record `epicIssueNumber` here when the brief was an epic. |

**Surface the resolved identity for confirm/override.** Both the resolved `Milestone title (exact)` (carrying the semver per the Step 5.1 ladder) **and** its `Version provenance` line are written to the plan file and **surfaced for the user to confirm or override BEFORE running `create`** — `plan` never silently finalizes a milestone identity the user cannot see or change (`docs/specs/v0.3.1-driver-handoff.md` §2, §3, §6). On an infer rung the title carries the **reference version verbatim**, and this surfaced line is **where the user adjusts the patch / minor / major bump** before `create` deploys it.

**Surface the multi-milestone advisory — ONLY on the retained path — alongside the same identity moment.** When the architect raised `SCOPE_SPANS_MULTIPLE_MILESTONES` (Step 3) **and the front-door (Step 3.6) did NOT take the roadmap route** (`roadmapRouteTaken` false — retained path), surface its advisory **prominently UP FRONT, at the same confirm/override moment** the user already sees the milestone identity above (NOT a separate prompt, NOT a hard block): a clear *"this looks like ~N milestones — deploy the one big milestone, or split the brief and re-run"* message plus the proposed split (the milestone names + their candidate tags, verbatim from the architect). It is **advisory only** — the user decides; `plan` still produced a deployable single-milestone plan and changes nothing about what `create` deploys. Surface it **ONLY on the retained path**; when the signal is `none`, surface **nothing** — no advisory line, no message — and the surfaced moment is exactly as before. When the front-door **took the route** (`roadmapRouteTaken` true), the confirmed roadmap was already surfaced by `build-roadmap` (Step 3.6), so this passive advisory is **superseded** — surface nothing here (`docs/specs/v0.3.1-driver-handoff.md` §5).

**Preserve an existing deploy receipt on re-plan.** The plan file may already carry a `Milestone number (GitHub): <n>` line — the **deploy receipt** `create` writes back post-deploy (the create-side write block at `skills/create/SKILL.md:99-135`; the exact field shape at `skills/create/SKILL.md:104`). It is the stable handle `update` resolves by, so a re-plan must NOT drop it: **before overwriting** `.milestone-feeder/plan-<slug>.md`, **read the PRIOR file at that same path** (if one exists) and **carry its receipt line forward, verbatim**, into the freshly-written plan file — as a sibling header line in the same position `create` writes it (after `Source brief:`). The receipt is **additive and READ-ONLY here**: `plan` never resolves a number or writes one (it has no milestone number — it writes only local slugs); it merely **preserves** the line `create` already recorded. **No prior file, OR a prior file with no receipt line → OMIT it, NO error** — a plan with no receipt is valid and deployable (`docs/specs/v0.3.1-driver-handoff.md` §6: *"A v0.3.0 plan file lacking them still parses (the consumers degrade gracefully)"*; the additive-fields row: *"`plan` preserves it on re-plan"*). Read the prior receipt line before the overwrite:

```bash
# bash — capture the prior receipt line (if any) BEFORE overwriting the plan file.
# rcpt is empty when there is no prior file or no receipt line — then omit it (no error).
plan=".milestone-feeder/plan-<slug>.md"
rcpt="$(grep -m1 '^Milestone number (GitHub):' "$plan" 2>/dev/null)"
```

```powershell
# PowerShell 7+ — same read; $rcpt is $null/empty when absent — then omit it (no error).
$plan = ".milestone-feeder/plan-<slug>.md"
$rcpt = (Get-Content -LiteralPath $plan -ErrorAction SilentlyContinue |
         Select-String -Pattern '^Milestone number \(GitHub\):' |
         Select-Object -First 1).Line
```

When `rcpt` is non-empty, write it verbatim into the new plan file as the sibling header line after `Source brief:`; when empty, write no such line.

**Plan-file format.** Write the file in this shape — the **Milestone title (exact)** line is its own labeled field, separate from the goal in the header:

```markdown
# Milestone plan — <milestone goal, one line>

Milestone title (exact): <the exact milestone title — carries the resolved semver INSIDE the string; create/update resolve the milestone by THIS string. SURFACED for the user to confirm/override before `create`; on an infer rung it carries the reference version verbatim — adjust the patch/minor/major bump on this line>
Version provenance: <explicit | declaration | inferred from <tag/milestone> | prompted>
Self-check: <the Step 6 outcome — one of:
  PASS — all <N> issues GAPS: none (milestone-driver reviewers)
  INTERNAL — all <N> issues GAPS: none (internal checklist; milestone-driver reviewers did not resolve)
  PARKED — <M> issue(s) → needs product input; <K> issue(s) → needs human direction (still-Blocker after 2 retries)
  SKIPPED (reviewer:false) — 🔴 gate disabled; generated issues were NOT vetted>
Source brief: <inline | file:<path> | epic #<n>>
Milestone number (GitHub): <n>   # OPTIONAL sibling header line — carried forward verbatim from a prior plan file if present; omitted on first plan (create writes it post-deploy, skills/create/SKILL.md:104)

## Milestone description (Wave order)
<the Step 5 Wave-ordered description, verbatim — the §4 template with local slugs>

## Issues
### #A — <title>   [<ui|logic>, <risk:*>]   [self-check: PASS]
<the full §4 ISSUE_BODY for #A>

### #B — <title>   [parked — needs product input]
<marker only; no fabricated body — see the needs-product-input report>

### #C — <title>   [parked — needs human direction (self-check Blocker, non-converging after 2 retries)]
<marker only; the issue did not clear the self-check gate — see the report>

### #D — <title>   [dropped — depends on parked #B]
<marker only; a dependent of a parked issue cannot build, so it is not carried (Step 6 §6.6)>

### … (one block per surviving candidate, in Wave order; only PASS / Advisory-only issues carry a full body)

## Multi-milestone advisory   <!-- OPTIONAL section — written ONLY on the retained path: the architect raised SCOPE_SPANS_MULTIPLE_MILESTONES (Step 3) AND the front-door did NOT route into build-roadmap (Step 3.6, roadmapRouteTaken false). OMITTED ENTIRELY when the signal is `none` (file byte-for-byte the pre-#61 shape) OR when the front-door took the route (roadmapRouteTaken true — superseded by the confirmed roadmap). Advisory only — does not change what gets deployed; the plan stays a deployable single-milestone plan. -->
🔴 This brief looks like ~<N> milestones. Deploy the one big milestone below, or split the brief and re-run. Proposed split (carried verbatim from the architect):
- <proposed milestone 1 name>: #A, #C
- <proposed milestone 2 name>: #B

## Project-docs grounding
- <each design call carried forward> — grounded in <.project/<doc>.md#<section> | sibling file:line>
- Degradations: <e.g. "uiSurfaceGlobs absent → all candidates treated as logic"; "none" otherwise>

## Needs human input
<pointer: "see .milestone-feeder/needs-product-input-<slug>.md" when productGaps is non-empty OR the self-check parked any issue as needs-human-direction; "none" otherwise>

---
This plan file is the build artifact — run `/milestone-feeder:create` to deploy it to GitHub (it ensures the labels, creates-or-adopts the milestone by the exact title above, opens each surviving issue, rewrites the slug references to real issue numbers, and patches the milestone description with the Wave order). `plan` wrote no GitHub state.
```

If `productGaps[]` is **non-empty** OR the self-check parked any issue as **needs-human-direction** (§6.5), also write a **"needs product input" report** to `.milestone-feeder/needs-product-input-<slug>.md` (same deterministic slug). The scratch dir already self-ignores by now (the plan-file write above ensured `.milestone-feeder/.gitignore` contains `*`), so this report is git-invisible too. The report carries a **Kind** column so the human can tell a product decision (no conventional default — decide and record it) from a non-converging self-check Blocker (the candidate's design is likely wrong — redirect it):

```markdown
🔴 Needs human input — <milestone goal, one line>

These items blocked the milestone and were NOT guessed. Resolve each, then re-run plan.

| # | Kind | Item | Why blocked | Blocks |
|---|---|---|---|---|
| 1 | product-gap | <the product decision with no conventional default> | <why the project docs / a convention cannot answer it> | <which candidate(s) / the whole scope> |
| 2 | needs-human-direction | <the self-check Blocker that did not clear in 2 retries> | <the reviewer's `description` / `to_clear`> | <which candidate(s) + any dropped dependents> |
| … | … | … | … | … |
```

The plan file and the report are local scratch. **Nothing is posted to GitHub** — no milestone is created, no issue is opened, no label is applied, no comment is added to any epic. The `create` skill is the only thing that writes GitHub state, reading this plan file.

## Output style

Be concise — report status and outcomes flatly, no wall-of-text. Present steps, gates, lists, and options as **tables**, not inline prose. Mark anything that needs a human with 🔴. (Mirrors the agents' communication-style contract.)

## Non-negotiables

- **`plan` writes NO GitHub state — its entire output is local scratch files (the plan file + the needs-input report).** No milestone is created, no issue is opened, no label is applied, no comment is posted on any epic. The plan file is the build artifact `create` reads; `create` is the only thing that writes GitHub state.
- **Authors no code, opens no PRs, never touches branches.** The feeder reads code to ground decisions; it never edits a source file, creates a branch, or opens a PR. Every dispatched agent is read-only and runs against provided text.
- **Parks product gaps — never invents scope.** A decision with no conventional default is recorded to `productGaps[]` and surfaced in the needs-product-input report — never guessed to make an issue buildable. Design / implementation calls the project docs or a stated convention answers are resolved and cited; calls with no conventional default are parked.
- **Project docs are read best-effort, never fabricated.** Absent or `[TBD]` sections are skipped, never grounded on. A design call cites its real grounding (`.project/<doc>.md#<section>` or a verified sibling `file:line`) or it is parked as a product gap.
- **The architect is dispatched exactly once; the issue-author once per candidate.** The pipeline owns the dispatch count; the agents return text and the orchestrator consumes it — no agent opens a GitHub artifact of its own.
- **Self-check gate is mandatory.** Every generated issue is vetted (§5 / §6 Step 6) before the plan file is written; a failing issue is retried (≤2) or parked — never silently planned. The gate is only skipped on an explicit `reviewer:false`, and only with a visible 🔴 warning recorded in the plan-file verdict line.
