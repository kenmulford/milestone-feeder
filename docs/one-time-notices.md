# One-time notices: shared reference

This file is the authoritative reference for seven one-time Step-0 units (a
self-heal and six printed notices) shared across `plan`, `create`, and
`update`. Each one either announces a self-heal `plan` just performed, flags a
repo-state problem for you to fix by hand, points you at a new or optional
capability you can opt into, or announces a behavior change. Every printed
notice shows at most once per clone: the block drops a small marker file under
`.milestone-config/.runtime/` the first time it fires, then stays silent on
every later run. The self-heal in the first section is the one exception: it
is gated on file-absence, not a marker, so it re-checks every run and acts
only when the file it writes is missing.

No skill restates a notice's text or gating logic inline: `plan`, `create`,
`update`, and `setup` each run the `scripts/emit-notice` twin pair (see "How
each skill runs this file" below), which prints from
`scripts/emit-notice.json`.

## Section fields

Each `##` section below is one notice:

- **Marker**: the per-clone marker file under `.milestone-config/.runtime/`
  that makes the notice fire at most once per clone, or `none` for the
  file-absence-gated self-heal.
- **Skills**: which skill(s) evaluate this section: `plan`, `create`,
  `update`, or a combination. A skill evaluates a section only when the
  section's `Skills` field includes that skill's own name.
- **Trigger**: the exact condition that must hold for the notice to fire.
- **Legacy-fallback**: a stale pre-`.milestone-config/.runtime/` marker
  checked alongside the current marker, or `none` when the notice was born
  entirely on the current path (`none` for all seven sections below).
- **Writes**: what the unit writes when it fires.
- **Safety**: its failure/abort behavior.
- **Text**: the notice's printed lines, fenced below the bullets. The copy
  that actually prints is that unit's `text` array in
  `scripts/emit-notice.json`.

## How each skill runs this file

Nothing reads this file at run time. Immediately after its own Step-0 config
read, each of `plan`, `create`, `update`, and `setup` runs the emitter twin
pair once: `scripts/emit-notice.sh` on a host with bash,
`scripts/emit-notice.ps1` on a Windows host without one. The script walks
`scripts/emit-notice.json`, the runtime source of every unit's printed lines
and the self-heal's file body, **in file order**, and for each selected unit
performs the marker gate, the trigger check, the print, and the marker write
in one step. Never re-type a notice as free-form agent text. `plan`,
`create`, and `update` pass their own name and select the units whose
`skills` list holds it; `setup` is none of those three, so it selects by
section id (`--section <id>`). A unit a call site does not select is **never
evaluated** there. A malformed unit is **skipped for that entry only**: never
a crash, never a partial print, never an aborted run. Every unit is
**best-effort**, and read-only except for the `.runtime/` dir + marker (and
the self-heal, which writes the nested `.gitignore`). A bash host without
`jq` emits nothing, under that same best-effort contract.

This file stays the human-readable reference for what each unit says, when it
fires, and why. `scripts/emit-notice.json` is what prints. Keep the two in
step.

**Contents**

1. [Self-heal the nested .milestone-config/.gitignore](#self-heal-the-nested-milestone-configgitignore)
2. [Legacy-blanket root .gitignore notice](#legacy-blanket-root-gitignore-notice)
3. [Bootstrap-nudge notice](#bootstrap-nudge-notice)
4. [Roadmap-routing notice](#roadmap-routing-notice)
5. [Implied-surfaces notice](#implied-surfaces-notice)
6. [md-epic parent notice](#md-epic-parent-notice)
7. [Consumer issue-template notice](#consumer-issue-template-notice)

## Self-heal the nested .milestone-config/.gitignore

- **Marker:** none (gated on file-absence, not a marker).
- **Skills:** plan
- **Trigger:** file-absence only (`[ ! -f ]` / `-not (Test-Path ...)`). Create-only, NOT marker-gated.
- **Legacy-fallback:** none.
- **Writes:** the nested `.milestone-config/.gitignore`.
- **Safety:** best-effort; never clobbers a user-edited file; a failed self-heal never aborts the run.
- **Sync:** the authority for the entry set is this repo's committed `.milestone-config/.gitignore`. This block carries all 12 of its entries, byte-exact, in its order. Keep it byte-exact with this unit's `writes.lines` array in `scripts/emit-notice.json`, which is what the self-heal actually writes; `plan` Step 0 and feeder `setup` Phase 3 both run that one unit, so the two call sites cannot drift. The driver's `tests-green` twins (`milestone-driver/hooks/tests-green.sh` / `tests-green.ps1`) **DIVERGE**: 6 entries, and a first comment line still carrying the em-dash form this repo has purged. Both live in the `milestone-driver` repo, so do not edit them from here.

```gitignore
# milestone-driver / milestone-feeder per-clone scratch, git-invisible by default.
# Committed so per-run scratch stays out of `git status` with zero user setup.
# Patterns are relative to this .milestone-config/ directory. Tracked config
# (driver.json, feeder.json) is intentionally NOT listed, so it stays tracked.
preflight-notice
trello-notice
visualcapture-notice
parallel-default-notice
code-review-gate-notice
aiprefilter-notice
cost-record-notice
uisurfaceglobs-notice
triage-cache.json
tests-stamp
.runtime/
worktrees/
```

## Legacy-blanket root .gitignore notice

- **Marker:** `.milestone-config/.runtime/legacy-blanket-notice`.
- **Skills:** plan
- **Trigger:** a root `.gitignore` blanket for `.milestone-config` is detected AND the per-clone marker is absent.
- **Legacy-fallback:** none.
- **Writes:** the `.runtime/` directory and the marker. Read-only on the root `.gitignore`: it never auto-edits it.
- **Safety:** best-effort; a failed detect or marker write never aborts the run.

```text
🔴 Legacy blanket detected in your root .gitignore

| What | Your root .gitignore ignores the whole .milestone-config/ directory
|      | (a line like `.milestone-config/`, `.milestone-config/*`, or
|      | `.milestone-config`). That hides this suite's TRACKED config
|      | (feeder.json, driver.json, and the nested .milestone-config/.gitignore)
|      | from git, so your config is silently dropped from version control.
| Fix  | Edit your root .gitignore BY HAND and delete the `.milestone-config`
|      | blanket line. The nested .milestone-config/.gitignore (already
|      | written) then keeps per-run scratch invisible while feeder.json /
|      | driver.json / the nested .gitignore stay tracked. We never edit your
|      | root .gitignore for you: it is yours and may hold unrelated rules.
| Note | This notice shows at most once per clone.
```

## Bootstrap-nudge notice

- **Marker:** `.milestone-config/.runtime/bootstrap-nudge-notice`.
- **Skills:** plan
- **Trigger:** the repo is un-bootstrapped (the resolved `projectDocs` path is absent or has no readable files, OR `.milestone-config/driver.json` is missing) AND the per-clone marker is absent.
- **Legacy-fallback:** none.
- **Writes:** the `.runtime/` directory and the marker. Read-only: it never runs the bootstrapper and never writes `projectDocs` / `.project/` or `driver.json`.
- **Safety:** best-effort; a failed resolve, detect, or marker write never aborts the run.

```text
🟡 This repo isn't bootstrapped: your plan's grounding will be weak

| What | This repo has no .project/ standing docs and/or no
|      | .milestone-config/driver.json. Without them, plan has no project
|      | constitution to ground issue design on and no driver profile to
|      | resolve shared keys from, so it falls back to thin inferred
|      | conventions and the issues it writes are weaker.
| Fix  | Run milestone-bootstrapper first to scaffold your .project/ docs and
|      | driver profile, then re-run /milestone-feeder:plan. We won't do this
|      | for you and we won't block: config is optional and plan will
|      | continue with best-effort grounding.
| Note | This notice shows at most once per clone.
```

## Roadmap-routing notice

- **Marker:** `.milestone-config/.runtime/roadmap-routing-notice`.
- **Skills:** plan
- **Trigger:** the per-clone marker is absent. Otherwise unconditional: there is no repo-state condition, because the notice announces a behavior change.
- **Legacy-fallback:** none.
- **Writes:** the `.runtime/` directory and the marker. `plan` Step 0 only, no `setup` twin.
- **Safety:** best-effort; a failed notice or marker write never aborts the run.

```text
🟡 New: an oversized brief now routes into a roadmap flow

| What | When you give plan a whole-app brief that spans several
|      | releases, plan now hands it to a roadmap step first: it
|      | proposes a sequenced set of milestones and asks you to
|      | confirm, merge, split, reorder, or reject the split before
|      | it plans any single milestone.
| When | Only when the brief reads as several milestones. A normal,
|      | single-release brief is unchanged: no roadmap step, no
|      | extra prompt.
| Note | This notice shows at most once per clone.
```

## Implied-surfaces notice

- **Marker:** `.milestone-config/.runtime/implied-surfaces-notice`, shared verbatim text and shared marker across both skills below, so the notice shows at most once per clone across both.
- **Skills:** plan, update
- **Trigger:** the overlay `.milestone-config/implied-surfaces.md` is absent AND the per-clone marker is absent.
- **Legacy-fallback:** none.
- **Writes:** the `.runtime/` directory and the marker. Read-only: it never writes the overlay.
- **Safety:** best-effort; a failed detect, notice, or marker write never aborts the run.

```text
🟡 Optional: add project-specific implied surfaces

| What | You can add an optional overlay file at
|      | .milestone-config/implied-surfaces.md. The architect reads it
|      | alongside the plugin's bundled implied-surfaces reference when it
|      | breaks your brief into issues.
| Why  | The bundled reference is universal, so it can't carry capability
|      | clusters specific to your domain (a church app's "giving", say).
|      | Your overlay merges in additively: it can add a new capability
|      | and extend an existing one, but never removes a surface the
|      | bundled reference already defines.
| How  | Create .milestone-config/implied-surfaces.md and write one
|      | capability per ## heading with its implied surfaces beneath, the
|      | same shape as the bundled reference. Leave it out and the bundled
|      | reference is used as-is; an absent overlay is never an error.
| Note | This notice shows at most once per clone.
```

## md-epic parent notice

- **Marker:** `.milestone-config/.runtime/md-epic-parent-notice`, shared between both skills below, so it shows at most once per clone across both (the same cross-verb sharing the Implied-surfaces notice already uses between `plan` and `update`).
- **Skills:** create, update
- **Trigger:** the per-clone marker is absent. Otherwise unconditional: there is no repo-state condition, because the notice announces a behavior change.
- **Legacy-fallback:** none.
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

## Consumer issue-template notice

- **Marker:** `.milestone-config/.runtime/issue-template-notice-v2`.
- **Skills:** plan
- **Trigger:** the per-clone marker is absent. Otherwise unconditional: there is no repo-state condition, because the notice announces a behavior change.
- **Legacy-fallback:** none.
- **Writes:** the `.runtime/` directory and the marker. `plan` Step 0 only, no `create` / `update` twin.
- **Safety:** best-effort; a failed notice or marker write never aborts the run.

```text
🟡 New: plan now adopts your repo's issue template

| What | plan now authors each issue to your repo's own issue template
|      | instead of its own built-in structure. It uses the template your
|      | driver config records as agentIssueTemplate; with no such key, the
|      | single template under .github/ISSUE_TEMPLATE/ (the reserved
|      | config.yml is not counted, so bug.yml + config.yml counts as one).
|      | No key and no single template keeps the built-in structure.
| When | Every plan run. The built-in structure authors four sections:
|      | Summary, Acceptance criteria, Design (recorded, consistent),
|      | and Dependencies, plus Non-goals when the issue records a scope
|      | boundary.
| Note | This notice shows once per clone, and again after an upgrade
|      | that revises it.
```
