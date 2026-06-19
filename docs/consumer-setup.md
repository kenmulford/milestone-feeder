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
| [`superpowers`](https://github.com/anthropics/claude-code) | **Required** | A hard dependency, declared in `.claude-plugin/plugin.json`. The plan pipeline depends on it. |
| `milestone-driver` | **Optional** | The backend for the `reviewer: "milestone-driver"` mode — the feeder dispatches the driver's own `triage-reviewer` / `design-reviewer` as its pre-emit reviewer gate. **Absent → degrades to `"internal"`**, and the pipeline still runs. |

**The `milestone-driver` soft dependency.** `milestone-driver` is the **optional
backend** for the `"milestone-driver"` reviewer mode. When it is installed, the
reviewer gate backs each generated (or, in `update`, each live) issue with the
driver's real reviewers, so the feeder's quality bar *is* the driver's entry gate.
When it is **absent**, `reviewer` degrades to `"internal"` at runtime — the
feeder's own checklist mirroring the five triage criteria — and the pipeline still
runs. (Setting `reviewer: false` skips the gate entirely, with a visible 🔴
warning that the issues were not vetted.) The feeder also reads the driver's
profile (`.milestone-config/driver.json`) for shared keys (`sourceGlobs`,
`uiSurfaceGlobs`, `integrationBranch`) and `nonNegotiables` (the version/platform
constraints the gate's reviewer checks against); these resolve to documented
defaults when no driver profile is present, so a driver-less repo still works.

## 2. Add the project profile

The first time you run `/milestone-feeder:plan` (or `create`), the plugin
**auto-invokes `/milestone-feeder:setup`** if `.milestone-config/feeder.json` is
absent. The bootstrap infers every key it can from repo signals (the standing-docs
directory (`projectDocs`), the resolvable driver profile, whether the driver's
reviewers resolve) and presents detected defaults — you accept, edit, or skip. It
writes the profile to `.milestone-config/feeder.json`, provisions the label
taxonomy, and returns control so the original plan continues immediately.

Unlike the driver, the feeder has **no required hard-stop key** — it writes no
branches and runs fully on bundled defaults, so an empty `{}` profile is valid (all
defaults apply). Setup still writes the file even when every key defaults, so
config-presence detection is unambiguous.

You can also run `/milestone-feeder:setup` directly at any time to create or repair
the profile.

**Manual authoring (fallback).** Create `.milestone-config/feeder.json` by hand —
see [`profile-schema.md`](profile-schema.md) for the full key reference. Every
own-key has a bundled default, so omit any key you do not override (absent-means-
default); a minimal profile carries only what diverges. Commit it so every clone
and CI has the same `no-source-edit` behavior. Minimal example:

```json
{
  "projectDocs": ".project/",
  "reviewer": "milestone-driver"
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
| Read config + project docs | Loads `feeder.json` (auto-invokes `setup` if absent), reads the standing docs best-effort, resolves shared keys (and `nonNegotiables`) from the driver config. |
| Plan | Dispatches the architect once → candidate issues + dependency edges + Wave order. |
| Author | Dispatches the `issue-author` per candidate → each issue's full §4 spec (acceptance criteria covering empty/error/disabled states, recorded consistent design, declared edges, UI/logic + risk). |
| Reviewer gate | Vets every generated issue against the same gate that fronts the driver's build loop (the driver's reviewers when `reviewer: "milestone-driver"`, else the internal checklist). FAILed issues are re-authored (≤2 retries) or parked. Runs on every path — **no GitHub writes.** |
| Emit | Writes a plan file to `.milestone-feeder/plan-<slug>.md` — the milestone description (Wave order) plus every gate-surviving issue body — and a "needs product input" report when product gaps remain. **No GitHub writes** — the GitHub artifacts are built later by `create`. |

**The park boundary.** A decision with no conventional default — what to build, or
user-facing behavior the standing docs and conventions do not answer — is **parked**
to the "needs product input" report, never guessed. Decide each, record it, and
re-run.

## The plan-then-create flow

Issue creation is consequential and the feeder is exactly the stage where human
product input matters most, so the flow is **plan, review, then create** — never
fully autonomous creation. End to end:

| Step | Command | What happens |
|---|---|---|
| 1. Plan | `/milestone-feeder:plan <brief>` | Runs the full pipeline including the reviewer gate and stops at a **plan file** (`.milestone-feeder/plan-<slug>.md`). **No GitHub state is written** — no milestone, no issue, no label, no comment. |
| 2. Review | *(read the plan file)* | Read the milestone description (Wave order), every gate-surviving issue body, and the "needs product input" report. Resolve any parked product gaps and re-run the plan until it is right. |
| 3. Create | `/milestone-feeder:create <brief>` | Deploys **exactly the plan you approved** — reads the plan file (running `plan` first only if none exists yet), then creates the GitHub artifacts: ensures the four labels, **creates-or-adopts the milestone by title** (reopening it if closed, never deleting), opens each gate-surviving issue, rewrites the slug references to real issue numbers in the issue bodies and the milestone description, and files the needs-product-input report (a comment on the epic for a GitHub-epic brief, else a local file). |

`create` is **idempotent on re-run**: it adopts the existing milestone and matches
issues by exact title, so re-running reuses what exists rather than duplicating it.
The plan file lives under `.milestone-feeder/` (which the repo gitignores) and is
the build artifact `create` deploys — review it before you run `create`.

## Updating an existing milestone

`/milestone-feeder:update <brief>` reconciles a **refreshed plan** onto a milestone
that **already exists** — the maintenance counterpart of `create`. Where `create`
*builds* a milestone, `update` *reconciles* the plan against the live one,
**creating and deleting no issues**. The flow: edit your brief, re-run `plan` to
refresh the plan file, then `update` reconciles it against the live milestone —
showing the diff before it writes:

| Step | Command | What happens |
|---|---|---|
| 1. Refresh the plan | `/milestone-feeder:plan <brief>` | Re-runs the pipeline on your edited brief and refreshes the plan file. Because the plan going in is always gate-clean, reconciling it inherently repairs any issue that drifted from spec. **No GitHub writes.** |
| 2. Update | `/milestone-feeder:update <brief>` | Resolves the existing milestone by title, then reconciles the refreshed plan against its live issues (matched by exact title): creates an issue in the plan but not on GitHub, patches a live body whose plan differs (**showing the diff first**), adds new dependency edges and re-renders the Wave order. A live issue **not** in the refreshed plan is **flagged for your decision** — never auto-closed. Nothing differs → a **true no-op**. |

`update` **never closes and never deletes** — a live issue absent from your
refreshed plan is flagged in the report, not auto-closed (closing is your call). It
is **idempotent**: re-running it on an already-synced milestone writes nothing. If
the named milestone does not exist, `update` **stops** (it never creates one — run
`/milestone-feeder:create` first).

---

For the internal design reference, see [`architecture.md`](architecture.md). For
the full profile reference, see [`profile-schema.md`](profile-schema.md).
