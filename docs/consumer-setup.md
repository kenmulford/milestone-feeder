# milestone-feeder — consumer setup

Adopt milestone-feeder in a repository in four steps. Most of this is one-time
wiring; after that, `/milestone-feeder:plan <brief>` previews a milestone
plan, `/milestone-feeder:create <brief>` builds it on GitHub, and
`/milestone-feeder:update <brief>` reconciles a refreshed plan onto an existing
milestone.

## 1. Install the plugin

Install `milestone-feeder` in Claude Code (dev-install via `claude --plugin-dir`,
or from a marketplace once published). Confirm it is enabled with `/plugin`.

| Plugin | Status | Why |
|---|---|---|
| [`superpowers`](https://github.com/anthropics/claude-code) | **Required** | A hard dependency — a required prerequisite you install yourself (no longer auto-installed; see `README.md`). The plan pipeline depends on it. |
| `milestone-driver` | **Optional** | The feeder drafts every issue to pass the driver's triage clean, and on a clean run `create` can hand the milestone straight to the driver to start building — and, if the driver is set up with Trello, mirror the milestone onto your board. **Absent → the feeder still plans and deploys**; you run the driver later (or not at all). |

**The `milestone-driver` soft dependency.** The feeder writes issues meant to be
built by `milestone-driver`, so it drafts every issue to pass the driver's triage
clean — one shared definition of "well-formed." The feeder itself runs **no**
reviewer: it *targets* that bar, and the driver's own triage is where the bar is
enforced when the driver later picks the milestone up. So `milestone-driver` is
**optional** for planning and deploying — absent, the feeder still plans and
deploys, and you run the driver whenever you like (or, on a clean run, let `create`
hand it off for you; see `autoHandoff`). The feeder also reads the driver's profile
(`.milestone-config/driver.json`) for shared keys (`sourceGlobs`, `uiSurfaceGlobs`,
`integrationBranch`); these resolve to documented defaults when no driver profile is
present, so a driver-less repo still works.

**The optional Trello mirror.** If you use the driver's Trello integration — its
`integrations.trello` in `.milestone-config/driver.json` — `create` **also drops a
milestone card on your board** when it finishes deploying: one card on the board's
queue list, with the milestone's issues as a checklist, so a freshly-planned
milestone shows up on your project board the moment it's created (instead of waiting
for the driver's first build run). It reads that setting from the **driver's**
profile — **there is no feeder-side Trello setting to add** (the driver already owns
the board destination). If you don't use the driver's Trello integration — or run no
driver at all — **nothing changes**: `create` deploys to GitHub exactly as before and
the mirror is a silent no-op. The card's shape and its best-effort, never-blocking
behavior are the driver's; `create` just seeds the card — see milestone-driver's
`skills/solve-milestone/trello-sync.md` for the details, and
[`create-deploy-sequence.md`](create-deploy-sequence.md) → "Step 3 — pass f" for
where `create` records the mirror pass.

## 2. Add the project profile

The first time you run `/milestone-feeder:plan` (or `create`), the plugin
**auto-invokes `/milestone-feeder:setup`** if `.milestone-config/feeder.json` is
absent. The bootstrap infers every key it can from repo signals (the standing-docs
directory (`projectDocs`), the resolvable driver profile) and presents detected
defaults — you accept, edit, or skip. It
writes the profile to `.milestone-config/feeder.json`, provisions the label
taxonomy, and returns control so the original plan continues immediately.

Unlike the driver, the feeder has **no required hard-stop key** — it writes no
branches and runs fully on bundled defaults, so an empty `{}` profile is valid (all
defaults apply). Setup still writes the file even when every key defaults, so
config-presence detection is unambiguous.

You can also run `/milestone-feeder:setup` directly at any time to create or repair
the profile.

**Manual authoring (fallback).** Create `.milestone-config/feeder.json` by hand —
see [`profile-schema.md`](profile-schema.md) for the full key reference. Most keys
have a bundled default, so omit any key you do not override (absent-means-
default); a minimal profile carries only what diverges. Commit it so every clone
and CI has the same `no-source-edit` behavior. Minimal example:

```json
{
  "projectDocs": ".project/"
}
```

**The optional `versioning` key.** `versioning` tells the feeder whether your
project uses version numbers. Set it to `"semver"` if your project is versioned
(every milestone gets a version), or `"none"` if it isn't (no version is ever
added and you're never asked). It is **optional** — you can leave
it out, and the feeder degrades gracefully: **if you skip it, the feeder figures
out whether you version by looking at your repo** — your existing milestone titles
first, then your git tags — and only **asks you once at plan time** if it can't
tell. So skipping it costs you nothing on a repo that already has versioned
milestones or `vX.Y.Z` tags; on a brand-new repo with neither, you'll get one
quick question the first time you plan. Set it explicitly to skip even that
question:

```json
{
  "projectDocs": ".project/",
  "versioning": "semver"
}
```

## 3. Restart Claude Code

The one mechanical gate — `no-source-edit` — is a plugin `PreToolUse` hook
registered in `hooks/hooks.json`. It **loads at session start**, so restart Claude
Code after installing or updating the plugin for the hook to take effect. No
separate native-hook installation step is required.

## 4. Provide your project docs

The plan pipeline grounds its issue authoring in your project's **standing docs** —
the constitution docs (vision, architecture, conventions) under `projectDocs`
(default `.project/`). The architect and issue-author read these to resolve design
defaults: format conventions, naming, the existing patterns to mirror.

The standing docs are read **best-effort**: a missing directory is not an error,
and a section that is absent or marked `[TBD]` is skipped, never grounded on. Thin
project docs mean more decisions have no conventional default — so more candidates
get parked as product gaps rather than authored. Richer constitution docs → fewer
parks, more issues authored clean.

## What a plan run does

`/milestone-feeder:plan <brief>` runs the full pipeline. As a consumer, the
shape that matters:

| Stage | What happens |
|---|---|
| Read config + project docs | Loads `feeder.json` (auto-invokes `setup` if absent), reads the standing docs best-effort, resolves shared keys from the driver config. |
| Plan | Dispatches the architect once → candidate issues + dependency edges + Wave order. |
| Author | Dispatches the `issue-author` per candidate → each issue's full §4 spec (acceptance criteria covering empty/error/disabled states, recorded consistent design, declared edges, UI/logic + risk), drafted to pass the driver's triage clean. |
| Drop + emit | Drops parked issues and their dependents, then writes a plan file to `.milestone-feeder/plan-<slug>.md` — the milestone description (Wave order) plus every surviving issue body — and a "needs product input" report when product gaps remain. **No GitHub writes** — the GitHub artifacts are built later by `create`. |

**The park boundary.** A decision with no conventional default — what to build, or
user-facing behavior the standing docs and conventions do not answer — is **parked**
to the "needs product input" report, never guessed. Decide each, record it, and
re-run.

## When your brief spans several releases (the roadmap)

Most briefs describe one release, and the flow above plans them as a single
milestone. But if your brief really reads as **several** separate releases — a whole
app, or a few phased deliverables — `plan` does something different: it turns your
brief into a **roadmap** of milestones and plans them all. Here is what you see when
that happens:

| Stage | What happens |
|---|---|
| Propose the split | `plan` carves your brief into a build-ordered set of milestones — each roughly one release — and shows you the proposed split. |
| Confirm it (your call) | You **confirm** it, **merge** two milestones, **split** one, **reorder** them, or **reject** the split — one decision, up front, before anything is planned or written. Reject, and `plan` falls back to planning your brief as a single milestone. |
| Plan them all | Once you confirm, `plan` plans **every** milestone in the roadmap (in parallel), each to its own plan file, in build order. |
| Deploy in order | `create` deploys the milestones **in build order**, recording each one's position (`milestone X of N`) so the driver builds them in sequence. |
| Check coverage | As its last step, `create` reads the deployed milestones and issues back from GitHub and checks they cover **everything your original brief asked for** — surfacing a short punch-list of anything missed, covered twice, or drifted. It never edits your issues; the punch-list is yours to act on. |

**A normal, single-release brief is unchanged.** The roadmap only kicks in when your
brief reads as several releases — you get no extra step and no extra prompt
otherwise. And there is **nothing new to configure**: the roadmap reuses the same
project docs `plan` already grounds on. The first time the roadmap path could apply,
`plan` shows a one-time heads-up so you know the behavior exists.

## Add project-specific implied surfaces (optional)

When `plan` breaks your brief into issues, it also catches the work your brief
*implies* but never spells out. Name a capability — "add email", "user management",
"sync" — or introduce a new kind of record, and a standard set of companion pieces
comes with it: a delivery-failure log for email, activate / deactivate /
reset-password for users, a list and a detail screen for a new record. `plan`
consults a built-in reference of these companions and proposes the conventional ones
into your plan, each marked `[implied — review / trim / augment]` so you can keep it,
trim it, or add the ones it missed — **before any issue is created**. It also asks
you, out loud, "this is a starting set for YOUR app — what's missing?", because a
built-in list can't know your domain. (A real product call with no obvious default
isn't guessed — it's set aside for your decision, exactly like any other product
gap.)

That built-in reference is universal, so it can't hold the companions specific to
**your** domain — a church app's "giving" (recurring schedules, statements, refunds,
gateway config), say. You can teach it yours with an **optional overlay file**:

| Detail | What it is |
|---|---|
| Where it lives | A file at `.milestone-config/implied-surfaces.md` — the same folder your `feeder.json` is in. There is **nothing to set in `feeder.json`**: `plan` finds the file by that fixed name, not by a config key. |
| What to write | One capability per `##` heading, with its implied surfaces listed beneath — the same shape as the built-in reference (see [`implied-surfaces.md`](implied-surfaces.md) → "Project-local overlay"). Anyone who can read that file can write an overlay. |
| How it merges | Your overlay is **added** to the built-in reference, never replaces it: you can add a new capability and extend an existing one, but you can't remove a companion the built-in reference already defines. Don't want one on a given plan? Trim it during your plan review — that's a per-plan call, not a config delete. |

**It is optional, and absent by default.** Most projects need no overlay, and that's
fine — leave the file out and `plan` uses the built-in reference as-is; there is
nothing to configure and an absent overlay is never an error. The first time you run
`plan` (or `update`) without one, you'll see a one-time heads-up telling you the
overlay exists, so you can add one if your domain needs it.

## The plan-then-create flow

Issue creation is consequential and the feeder is exactly the stage where human
product input matters most, so the flow is **plan, review, then create** — never
fully autonomous creation. End to end:

| Step | Command | What happens |
|---|---|---|
| 1. Plan | `/milestone-feeder:plan <brief>` | Runs the full pipeline and stops at a **plan file** (`.milestone-feeder/plan-<slug>.md`). **No GitHub state is written** — no milestone, no issue, no label, no comment. |
| 2. Review | *(read the plan file)* | Read the milestone description (Wave order), every surviving issue body, and the "needs product input" report. Resolve any parked product gaps and re-run the plan until it is right. |
| 3. Create | `/milestone-feeder:create <brief>` | Deploys **exactly the plan you approved** — reads the plan file (running `plan` first only if none exists yet), then creates the GitHub artifacts: ensures the four labels, **creates-or-adopts the milestone by title** (reopening it if closed, never deleting), opens each surviving issue, rewrites the slug references to real issue numbers in the issue bodies and the milestone description, and files the needs-product-input report (a comment on the epic for a GitHub-epic brief, else a local file). On a **clean** run, if `milestone-driver` is installed, `create` can then **offer to hand the milestone straight to the driver to start building** — see the handoff note below. |

`create` is **idempotent on re-run**: it adopts the existing milestone and matches
issues by exact title, so re-running reuses what exists rather than duplicating it.
The plan file lives under `.milestone-feeder/`, a per-run scratch folder the
feeder makes invisible to git automatically — on its first write it drops a
`.gitignore` containing `*` inside that folder, so the scratch never shows up in
your `git status` and you need to set nothing up. The plan file is the build
artifact `create` deploys — review it before you run `create`.

### Handing the milestone to milestone-driver to start building

If you have `milestone-driver` installed, `create` can hand the finished milestone
**straight to it** to start building — so you don't have to switch tools and run
the driver yourself. The `autoHandoff` setting in your `feeder.json` controls this:

- `"prompt"` (the default) — after a clean `create`, the feeder asks *"milestone-driver
  is installed — start building this milestone now, or review it first?"* Say yes to
  start the build; say no to stop and review.
- `"auto"` — the feeder starts the build immediately, no question asked.
- `"off"` — the feeder never offers; `create` just finishes, as it did before this
  feature existed.

Three things have to be true for the offer to appear: the run must be **clean** (no
product gaps, nothing flagged for your decision — a run with gaps surfaces them
instead of offering to build), `milestone-driver` must be **installed** (if it
isn't, `create` just finishes quietly — no prompt, no error), and the handoff only
**starts the build**. The driver builds onto your integration branch (e.g.
`develop`); it never merges to your protected branch (e.g. `main`) — releasing stays
your manual call, exactly as it is when you run the driver yourself. To keep the
pre-handoff behavior (`create` finishes and stops), set `autoHandoff` to `"off"`.

## Updating an existing milestone

`/milestone-feeder:update <brief>` reconciles a **refreshed plan** onto a milestone
that **already exists** — the maintenance counterpart of `create`. Where `create`
*builds* a milestone, `update` *reconciles* the plan against the live one,
**creating and deleting no issues**. The flow: edit your brief, re-run `plan` to
refresh the plan file, then `update` reconciles it against the live milestone —
showing the diff before it writes:

| Step | Command | What happens |
|---|---|---|
| 1. Refresh the plan | `/milestone-feeder:plan <brief>` | Re-runs the pipeline on your edited brief and refreshes the plan file. Because the plan going in is always drafted to the driver's triage bar, reconciling it inherently repairs any issue that drifted from spec. **No GitHub writes.** |
| 2. Update | `/milestone-feeder:update <brief>` | Resolves the existing milestone by title, then reconciles the refreshed plan against its live issues (matched by exact title): creates an issue in the plan but not on GitHub, patches a live body whose plan differs (**showing the diff first**), adds new dependency edges and re-renders the Wave order. A live issue **not** in the refreshed plan is **flagged for your decision** — never auto-closed. Nothing differs → a **true no-op**. |

`update` **never closes and never deletes** — a live issue absent from your
refreshed plan is flagged in the report, not auto-closed (closing is your call). It
is **idempotent**: re-running it on an already-synced milestone writes nothing. If
the named milestone does not exist, `update` **stops** (it never creates one — run
`/milestone-feeder:create` first).

---

For the internal design reference, see [`architecture.md`](architecture.md). For
the full profile reference, see [`profile-schema.md`](profile-schema.md).
