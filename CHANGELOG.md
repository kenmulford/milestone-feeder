# Changelog

Release notes for milestone-feeder. Each tagged release is also published on the
[GitHub Releases page](https://github.com/kenmulford/milestone-feeder/releases).

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
