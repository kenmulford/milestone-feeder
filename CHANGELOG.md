# Changelog

Release notes for milestone-feeder. Each tagged release is also published on the
[GitHub Releases page](https://github.com/kenmulford/milestone-feeder/releases).

## v0.2.0 — Gate & apply

**Theme:** The feeder grows teeth and a write hand. The preview slice now runs the
**same self-check gate that fronts the driver's build loop** against every generated
issue before emit — so what the feeder ships passes the driver's triage clean — and
gains an `--apply` path that turns the gate-surviving plan into a real GitHub
milestone + issues + labels. A new `refine` skill re-vets and patches a milestone
that already exists. Preview stays the default and still writes no GitHub state; the
gate runs on every path; product calls are still parked, never invented; the feeder
still authors no code.

### ✨ The self-check gate

| Issue | What |
|---|---|
| #9 | The self-check gate (decompose Step 6, §6.1–§6.6): dispatches the driver's `triage-reviewer` (and `design-reviewer` for UI issues) against each generated issue before emit, gating on the returned `GAPS` block. Three backends — `"milestone-driver"` (degrades to `"internal"` at runtime if the reviewers don't resolve, with a per-issue fallback), `"internal"` (built-in checklist mirroring the five triage criteria), and `false` (skip with a visible 🔴 warning). FAILed issues are re-authored (≤2 retries) or parked; undeclared edges are absorbed and the Wave order re-rendered. Runs in preview too — no GitHub writes. Also reads `nonNegotiables` from the driver profile as a reviewer input. |

### ✨ The `--apply` GitHub-write path

| Issue | What |
|---|---|
| #10 | The `--apply` path (decompose Step 7 §7-apply): preview stays the default; `--apply` ensures the four labels idempotently, creates-or-adopts the milestone by exact title (reopen-if-closed, never deletes), creates each gate-surviving issue, rewrites slug→`#n` references (substring-safe) in the issue bodies and the milestone description, PATCHes the Wave-encoded milestone description, and files the needs-product-input report (epic comment on apply / local file otherwise). Idempotent re-apply via adopt + match-by-title; a defined partial-failure resume path. All `gh` writes are performed by the skill itself — every dispatched agent stays read-only. |

### ✨ The refine skill

| Issue | What |
|---|---|
| #11 | The `refine` skill (`/milestone-feeder:refine <milestone>`): an idempotent re-run against an **existing** milestone. Re-triages its live issues (their real GitHub comments + live bodies) through the #9 gate, patches gapped bodies, fills missing dependency edges, and re-renders the Wave order. Preview (default) writes a diff-style patch plan; `--apply` edits the live issues. Creates and deletes no issues; an issue already at `GAPS: none` is left byte-unchanged; a clean milestone is a true no-op. Reuses decompose's gate (Step 6) and `--apply` write-primitives (§7-apply) by reference — no second, drifting definition. |

### ✨ Docs

| Issue | What |
|---|---|
| #12 | This docs update to the as-built v0.2.0 surface: `docs/architecture.md` (the self-check gate result→action table, the Step 7 `--apply` write order, the apply/refine modes — flipped from "Planned (v0.2.0)" to shipped), `docs/consumer-setup.md` (the optional `milestone-driver` self-check backend, the preview-then-apply flow, the refine flow), `docs/profile-schema.md` (the `nonNegotiables` reviewer input note), the README status alignment to the shipped v0.2.0 surface, and this CHANGELOG. |

### Consumer notes

- **`milestone-driver` is the optional self-check backend.** It powers `selfCheck: "milestone-driver"`; absent → the gate degrades to `"internal"` and the pipeline still runs. It also supplies the shared keys and `nonNegotiables` the feeder reads.
- **Preview is still the default; `--apply` writes GitHub state.** Preview writes a reviewable plan file and no GitHub state on any path. `--apply` creates the milestone + issues + labels (and an epic comment for a GitHub-epic brief), idempotently on re-run.
- **`refine` maintains an existing milestone.** It re-vets and patches live issues; it creates and deletes no issues, and a clean milestone is a no-op.

## v0.1.0 — Preview slice

**Theme:** The first runnable slice of the feeder: a plugin scaffold with one
mechanical gate, and a preview decompose pipeline that turns a feature brief into a
reviewable milestone plan — small, well-formed issues with Wave-ordered dependencies
— **without writing any GitHub state**. It reads code and the project substrate to
ground its design calls, parks product calls it cannot ground, and authors no code.
The self-check gate, `--apply`, and refine ship in v0.2.0.

### ✨ Scaffold & safety spine

| Issue | What |
|---|---|
| #1 | Plugin scaffold: `.claude-plugin/plugin.json` (the `superpowers` dependency, `0.1.0` version), `marketplace.json`, `LICENSE`, `.gitattributes` (LF enforcement for hook scripts), and the `.gitignore` hygiene baseline. |
| #2 | Config schema (`.milestone-config/feeder.json`) + `docs/profile-schema.md`: the feeder's own keys (`substrateDir`, `selfCheck`, agent overrides, `issueSizeGuidance`, self-protection `sourceGlobs`), absent-means-default discipline, and the two resolution chains (the hook's `sourceGlobs` self-protection chain; the shared-keys chain read from the driver config). |
| #3 | The `no-source-edit` gate: a `PreToolUse` hook (`Write`/`Edit`/`MultiEdit`/`NotebookEdit`) via the bash-first/pwsh-fallback launcher, unconditionally denying edits to the resolved `sourceGlobs` (feeder.json → driver config → fail-open), with a `CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT` escape hatch. |
| #4 | The `setup` skill: inference-first profile bootstrap, no required hard-stop key, label taxonomy provisioning aligned to the driver's (`ui`/`logic`/`risk:light`/`risk:heavy`), auto-invoked by `decompose` when the profile is absent. |

### ✨ Decompose preview pipeline

| Issue | What |
|---|---|
| #5 | The `decomposer` agent: architect lens, dispatched once — brief + substrate + repo → candidate issues + dependency edges + Wave order, local tags only, every design call grounded or parked as a product gap. |
| #6 | The `issue-author` agent: per-candidate, authors one issue's full §4 spec (the five triage criteria — consistency, buildability, completeness, dependencies, UI/logic + risk) so it passes the driver's triage clean. |
| #7 | The `decompose` skill: the preview orchestrator (Steps 0–5), brief ingestion (epic/file/inline), the product-gap park boundary, parallel issue authoring, the Wave-ordered milestone description, and the plan-file emit to `.milestone-feeder/plan-<slug>.md`. Preview only — no GitHub writes. |
| #8 | This docs set: `docs/architecture.md` (internal design reference), `docs/consumer-setup.md` (adopter runbook), this CHANGELOG, and the README alignment to v0.1.0. |

### Consumer notes

- **`superpowers` is required** (declared in `plugin.json`); the decompose pipeline depends on it.
- **`milestone-driver` is optional.** It powers the `selfCheck: "milestone-driver"` mode (a v0.2.0 capability) and supplies the shared keys the feeder reads. Absent → `selfCheck` degrades to `"internal"` and shared keys resolve to defaults; the pipeline still runs.
- **Preview only this release.** `/milestone-feeder:decompose` writes no GitHub state — it emits a reviewable plan file (and a "needs product input" report when product gaps remain). The `--apply` token is recognized but unimplemented; real GitHub creation, the driver-backed self-check, and `refine` ship in **v0.2.0**.
