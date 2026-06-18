# milestone-feeder — consumer setup

Adopt milestone-feeder in a repository in four steps. Most of this is one-time
wiring; after that, `/milestone-feeder:decompose <brief>` previews a milestone
plan, `… --apply` creates it on GitHub, and `/milestone-feeder:refine <milestone>`
re-vets and patches one that already exists.

## 1. Install the plugin

Install `milestone-feeder` in Claude Code (dev-install via `claude --plugin-dir`,
or from a marketplace once published). Confirm it is enabled with `/plugin`.

| Plugin | Status | Why |
|---|---|---|
| [`superpowers`](https://github.com/anthropics/claude-code) | **Required** | A hard dependency, declared in `.claude-plugin/plugin.json`. The decompose pipeline depends on it. |
| `milestone-driver` | **Optional** | The backend for the `selfCheck: "milestone-driver"` self-check mode — the feeder dispatches the driver's own `triage-reviewer` / `design-reviewer` as its pre-emit self-check gate. **Absent → degrades to `"internal"`**, and the pipeline still runs. |

**The `milestone-driver` soft dependency.** `milestone-driver` is the **optional
backend** for the `"milestone-driver"` self-check mode. When it is installed, the
self-check gate backs each generated (or, in `refine`, each live) issue with the
driver's real reviewers, so the feeder's quality bar *is* the driver's entry gate.
When it is **absent**, `selfCheck` degrades to `"internal"` at runtime — the
feeder's own checklist mirroring the five triage criteria — and the pipeline still
runs. (Setting `selfCheck: false` skips the gate entirely, with a visible 🔴
warning that the issues were not vetted.) The feeder also reads the driver's
profile (`.milestone-config/driver.json`) for shared keys (`sourceGlobs`,
`uiSurfaceGlobs`, `integrationBranch`) and `nonNegotiables` (the version/platform
constraints the gate's reviewer checks against); these resolve to documented
defaults when no driver profile is present, so a driver-less repo still works.

## 2. Add the project profile

The first time you run `/milestone-feeder:decompose`, the plugin **auto-invokes
`/milestone-feeder:setup`** if `.milestone-config/feeder.json` is absent. The
bootstrap infers every key it can from repo signals (the substrate directory, the
resolvable driver profile, whether the driver's reviewers resolve) and presents
detected defaults — you accept, edit, or skip. It writes the profile to
`.milestone-config/feeder.json`, provisions the label taxonomy, and returns control
so the original decompose continues immediately.

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
  "substrateDir": ".project/",
  "selfCheck": "milestone-driver"
}
```

## 3. Restart Claude Code

The one mechanical gate — `no-source-edit` — is a plugin `PreToolUse` hook
registered in `hooks/hooks.json`. It **loads at session start**, so restart Claude
Code after installing or updating the plugin for the hook to take effect. No
separate native-hook installation step is required.

## 4. Provide the substrate

The decompose pipeline grounds its issue authoring in the **substrate** — the
project-constitution docs (vision, architecture, conventions) under the
`substrateDir` (default `.project/`). The decomposer and issue-author read these
to resolve design defaults: format conventions, naming, the existing patterns to
mirror.

The substrate is read **best-effort**: a missing directory is not an error, and a
section that is absent or marked `[TBD]` is skipped, never grounded on. A **thin**
substrate means more decisions have no conventional default — so more candidates
get parked as product gaps rather than authored. Richer constitution docs → fewer
parks, more issues authored clean.

## What a decompose run does

`/milestone-feeder:decompose <brief>` runs the full pipeline. As a consumer, the
shape that matters:

| Stage | What happens |
|---|---|
| Read config + substrate | Loads `feeder.json` (auto-invokes `setup` if absent), reads the substrate best-effort, resolves shared keys (and `nonNegotiables`) from the driver config. |
| Decompose | Dispatches the `decomposer` once → candidate issues + dependency edges + Wave order. |
| Author | Dispatches the `issue-author` per candidate → each issue's full §4 spec (acceptance criteria covering empty/error/disabled states, recorded consistent design, declared edges, UI/logic + risk). |
| Self-check gate | Vets every generated issue against the same gate that fronts the driver's build loop (the driver's reviewers when `selfCheck: "milestone-driver"`, else the internal checklist). FAILed issues are re-authored (≤2 retries) or parked. Runs on every path — **no GitHub writes.** |
| Emit | **Preview (default):** writes a plan file to `.milestone-feeder/plan-<slug>.md` — the milestone description (Wave order) plus every gate-surviving issue body — and a "needs product input" report when product gaps remain. **No GitHub writes.** **`--apply`:** writes the plan file as the local record, then creates the GitHub artifacts. |

**The park boundary.** A decision with no conventional default — what to build, or
user-facing behavior the substrate and conventions do not answer — is **parked** to
the "needs product input" report, never guessed. Decide each, record it, and re-run.

## The preview-then-apply flow

Issue creation is consequential and the feeder is exactly the stage where human
product input matters most, so the flow is **preview, review, then apply** — never
fully autonomous creation. End to end:

| Step | Command | What happens |
|---|---|---|
| 1. Preview | `/milestone-feeder:decompose <brief>` | Runs the full pipeline including the self-check gate and stops at a **plan file** (`.milestone-feeder/plan-<slug>.md`). **No GitHub state is written** — no milestone, no issue, no label, no comment. |
| 2. Review | *(read the plan file)* | Read the milestone description (Wave order), every gate-surviving issue body, and the "needs product input" report. Resolve any parked product gaps and re-run the preview until the plan is right. |
| 3. Apply | `/milestone-feeder:decompose <brief> --apply` | Re-runs the pipeline, then creates the GitHub artifacts: ensures the four labels, **creates-or-adopts the milestone by title** (reopening it if closed, never deleting), opens each gate-surviving issue, rewrites the slug references to real issue numbers in the issue bodies and the milestone description, and files the needs-product-input report (a comment on the epic for a GitHub-epic brief, else a local file). |

`--apply` is **idempotent on re-run**: it adopts the existing milestone and matches
issues by exact title, so re-applying reuses what exists rather than duplicating it.
The plan file is per-run scratch you review and discard (it is written under
`.milestone-feeder/`, which the repo gitignores).

## Refining an existing milestone

`/milestone-feeder:refine <milestone>` re-vets and repairs a milestone that
**already exists** — the maintenance counterpart of `decompose`. Where `decompose`
*creates* a milestone, `refine` *re-vets and patches* one, **creating and deleting
no issues**:

| Step | Command | What happens |
|---|---|---|
| 1. Preview | `/milestone-feeder:refine <milestone>` | Loads the milestone's live issues (bodies + their real GitHub comments), re-triages each through the self-check gate, and writes a **diff-style patch plan** (`.milestone-feeder/refine-plan-<slug>.md`) showing the proposed body patches, added labels, and added dependency edges. **No GitHub writes.** |
| 2. Apply | `/milestone-feeder:refine <milestone> --apply` | Edits the gapped live issue bodies, adds the implied labels, fills missing edges, and re-renders the milestone description's Wave order. An issue already at `GAPS: none` is left **byte-unchanged**; a **fully-clean milestone is a true no-op** — refine writes nothing and says so. |

Refine is **idempotent**: re-running it on a milestone it just patched is a no-op.
If the named milestone does not exist, refine **stops** (it never creates one — run
`decompose` first).

---

For the internal design reference, see [`architecture.md`](architecture.md). For
the full profile reference, see [`profile-schema.md`](profile-schema.md).
