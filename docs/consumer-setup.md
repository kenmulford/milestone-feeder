# milestone-feeder — consumer setup

Adopt milestone-feeder in a repository in four steps. Most of this is one-time
wiring; after that, `/milestone-feeder:decompose <brief>` turns a feature brief
into a reviewable milestone plan.

## 1. Install the plugin

Install `milestone-feeder` in Claude Code (dev-install via `claude --plugin-dir`,
or from a marketplace once published). Confirm it is enabled with `/plugin`.

| Plugin | Status | Why |
|---|---|---|
| [`superpowers`](https://github.com/anthropics/claude-code) | **Required** | A hard dependency, declared in `.claude-plugin/plugin.json`. The decompose pipeline depends on it. |
| `milestone-driver` | **Optional** | Powers the `selfCheck: "milestone-driver"` mode — the feeder dispatches the driver's own `triage-reviewer` / `design-reviewer` as its pre-creation self-check (a v0.2.0 capability). |

**The `milestone-driver` soft dependency.** When `milestone-driver` is installed,
the self-check gate (v0.2.0) backs each generated issue with the driver's real
reviewers, so the feeder's quality bar *is* the driver's entry gate. When it is
**absent**, `selfCheck` degrades to `"internal"` — the feeder's own checklist
mirroring the five triage criteria — and the pipeline still runs. The feeder also
reads the driver's profile (`.milestone-config/driver.json`) for shared keys
(`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`); these resolve to documented
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

## What a preview run does

`/milestone-feeder:decompose <brief>` runs the preview pipeline and writes a
reviewable plan file. As a consumer, the shape that matters:

| Stage | What happens |
|---|---|
| Read config + substrate | Loads `feeder.json` (auto-invokes `setup` if absent), reads the substrate best-effort, resolves shared keys from the driver config. |
| Decompose | Dispatches the `decomposer` once → candidate issues + dependency edges + Wave order. |
| Author | Dispatches the `issue-author` per candidate → each issue's full §4 spec (acceptance criteria covering empty/error/disabled states, recorded consistent design, declared edges, UI/logic + risk). |
| Emit (preview) | Writes a plan file to `.milestone-feeder/plan-<slug>.md` — the milestone description (Wave order) plus every authored issue body. Writes a "needs product input" report when product gaps remain. |

**The park boundary.** A decision with no conventional default — what to build, or
user-facing behavior the substrate and conventions do not answer — is **parked** to
the "needs product input" report, never guessed. Decide each, record it, and re-run.

**Preview only this release.** The decompose pipeline writes **no GitHub state** on
any path: no milestone is created, no issue is opened, no label is applied, no
comment is posted. The plan file is per-run scratch you review and discard (it is
written under `.milestone-feeder/`, which the repo gitignores). Real GitHub creation
(`--apply`) and the driver-backed self-check ship in **v0.2.0**; the `--apply` token
is recognized this release but unimplemented, and the plan file's self-check line
records the gate as **deferred**, not passed.

---

For the internal design reference, see [`architecture.md`](architecture.md). For
the full profile reference, see [`profile-schema.md`](profile-schema.md).
