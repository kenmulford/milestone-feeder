# Changelog

Release notes for milestone-feeder. Each tagged release is also published on the
[GitHub Releases page](https://github.com/kenmulford/milestone-feeder/releases).

## v0.3.1 — Explicit milestone naming & the driver handoff

**Theme:** v0.3.0 made the surface speak the user's language; v0.3.1 makes the
**handoff to `milestone-driver` clean.** The driver derives its target version by
parsing the milestone title for a semver — but a feeder-made milestone carried no
version, silently degrading the driver to "no version → prompt the user." v0.3.1
closes that gap by making **milestone identity explicit and user-owned, with the
semver living in the milestone title** where the driver reads it. It also lets
`update` find and rename the right milestone after a title change, and stops the
feeder being silent when a brief is really several milestones. **This release is
additive — nothing breaks.** No command or config changes; one new *optional*
config key and new (optional) plan-file fields. A v0.3.0 plan file with none of
the new fields still works — the new paths degrade gracefully.

### ✨ Versioned milestone naming (#50)

| Issue | What |
|---|---|
| #50 | The milestone title becomes a **user-owned field carrying the semver inside it** (e.g. `myapp v1.2.0`) — there is no separate version field, because the driver parses the version from the title. State the title up front (inline or a `Milestone: <name> vX.Y.Z` line in the brief), or let `plan` resolve a default by a **layered, first-match-wins ladder**: explicit → the project's `versioning` declaration → inference (the highest semver among existing milestone titles, else the latest `vX.Y.Z` git tag) → a one-time prompt only when nothing is inferable. The resolved title and a one-line **version provenance** (`explicit` / `declaration` / `inferred from <tag/milestone>` / `prompted`) are surfaced in the plan file for confirm/override before `create` — `plan` never silently invents an identity. A `"none"` declaration adds no version and never prompts. |

### ✨ `update` retargeting + bounded rename-in-place (#51)

| Issue | What |
|---|---|
| #51 | Because identity is now the explicit title, `update` resolves the **source plan** by the brief slug but the **target milestone** by identity — so a revised plan in a *new* brief reconciles onto its existing milestone. To survive a title change, `create` writes the GitHub milestone number back into the plan file as a **deploy receipt** (`Milestone number (GitHub): <n>`); `update` resolves **by that number first** (falling back to title-match when absent), and when it resolved by number and the plan's title differs, it **PATCHes the new title** — the single bounded way `update` mutates a milestone's identity. A wholesale new brief + new title + no receipt → no title match → **error-and-stop directing you to `create`**, with the one-line `gh` rename command for the rare true-rename case. `plan` carries the receipt forward on re-plan so the handle isn't stranded. Resolving by the stable number also hardens every non-rename `update`. |

### ✨ The multi-milestone guardrail (advisory, non-blocking)

| Issue | What |
|---|---|
| (guardrail) | The feeder stays **one brief → one milestone**, but stops being silent about a brief that's really several. When a brief reads as distinct phased deliverables / release boundaries, the architect raises a `SCOPE_SPANS_MULTIPLE_MILESTONES` signal with a proposed split (the candidate milestones and which issues fall under each). `plan` still writes a **deployable single-milestone plan** but **prominently flags** *"this looks like ~N milestones"* and shows the split, surfaced up front alongside the versioning step. Never a hard block, never a silent giant milestone — the user decides whether to deploy the one milestone or split the brief and re-run. Full `brief → N-milestones` decomposition is deferred to v0.4.0. |

### ✨ The optional `versioning` config key

| Issue | What |
|---|---|
| (config) | A new **optional** key in `.milestone-config/feeder.json` (no file rename). `versioning` answers only the *is-this-versioned* question — the version *number* comes from the layered ladder. Three-way: `"semver"` = version every milestone; `"none"` = non-versioned project, never add a version or prompt; **absent** = infer from repo signals (existing milestone titles, then git tags), else ask once at plan time. Forward-compatible with a future bootstrapper that will write this key at scaffold time. Defined in `docs/profile-schema.md` and offered by `setup` as an optional key (skip-consequence stated). |

### Consumer notes

- **This is an additive release.** Nothing breaks — same commands, same config
  file. The new `versioning` key is optional, and a v0.3.0 plan file still works.
- **Name your milestone with a version up front** (inline or a `Milestone: <name>
  vX.Y.Z` line in your brief) so the driver builds toward the right version. Skip
  it and the feeder proposes one from your existing milestones or git tags and
  shows it to you before building anything.
- **`update` finds the right milestone even after a rename.** It resolves by the
  milestone number `create` recorded, falling back to the title — and renames in
  place when your plan's title changed. A brand-new brief with a new title stops
  and points you at `create`.
- **The feeder flags a brief that looks like several milestones** — advisory only.
  It still builds one milestone; the split is yours to make.

## v0.3.0 — Humanize the surface

**Theme:** v0.2.0 works, but everything a user typed or read spoke in
implementation jargon. v0.3.0 is one focused pass that makes the surface speak the
user's language — intent-named command verbs, no flags, human config keys, and an
agent renamed to match what it does. **This release is breaking vs v0.2.0.** It is
not a behavioral redesign: one behavioral change ships, and only because it makes
the surface honest — `create` now builds exactly the plan you approved instead of
re-running the pipeline and possibly diverging from the preview.

### 💥 Breaking — the command surface (verbs, not flags)

Three intent-named verbs replace two verbs plus a flag. Each verb *is* the
explanation of what it does. There are no back-compat aliases — the old commands
are gone.

| v0.2.0 | v0.3.0 | What you mean |
|---|---|---|
| `decompose <brief>` (preview) | **`plan <brief>`** | "Turn my idea into a reviewable plan." |
| `decompose <brief> --apply` | **`create <brief>`** | "Approve it — build the milestone + issues." |
| `refine <milestone>` | **`update <brief>`** | "My plan changed — sync it to the milestone." |

- **`create` is read-the-plan and faithful.** It resolves the plan file `plan`
  wrote and deploys **exactly** it — no pipeline re-run, no re-vet. If no plan file
  exists yet, it runs `plan` for you first, then deploys that. What you reviewed is
  what gets built.
- **`update` is safe.** It reconciles a refreshed plan onto the existing milestone:
  creates missing issues, patches drifted bodies (showing the diff first), and adds
  new dependency edges. It **never closes or deletes** a live issue — one absent
  from your plan is flagged for your decision, not removed. Re-running on an
  already-synced milestone writes nothing (idempotent).

### 💥 Breaking — config keys renamed (the file stays the same)

The config file is still `.milestone-config/feeder.json` (no rename — pairs with
`driver.json`, avoids hook churn). The **keys inside** are humanized. There is no
silent old-key fallback; an external consumer who set the old keys re-runs `setup`.

| v0.2.0 key | v0.3.0 key | What it is |
|---|---|---|
| `substrateDir` | **`projectDocs`** | Where your project's standing docs live. |
| `selfCheck` | **`reviewer`** | Who checks each issue before it's created (`"milestone-driver"` / `"internal"` / `false`). |
| `issueSizeGuidance` | **`issueSize`** | Optional sizing rule. |
| `decomposerAgent` | **`architectAgent`** | Tracks the agent rename below. |

### ✨ Agent rename — `decomposer` → `architect`

| Issue | What |
|---|---|
| #27 | The breakdown agent (brief → candidate issues + dependency graph + build order) is renamed `decomposer` → `architect` (`agents/decomposer.md` → `agents/architect.md`, id `milestone-feeder:decomposer` → `milestone-feeder:architect`). It pairs cleanly with the issue-author: the architect designs the breakdown, the issue-author writes each issue. Logic and contracts are unchanged — only the name and the prose around it. |

### ✨ Release metadata & verification

| Issue | What |
|---|---|
| #33 | Release metadata re-vocab'd to the final surface: `plugin.json` (`version` → `0.3.0`, description rewritten to the `plan`/`create`/`update` surface, the `decomposition` keyword dropped), `marketplace.json` (no `--apply`, no residual `decompose` prose), and this CHANGELOG entry. |
| #36 | The credibility harness migrated to the v0.3.0 surface (new verbs, new keys, `feeder.json` kept) and **re-run** — fresh transcripts, so the **4/4 green** scorecard proves v0.3.0, not v0.2.0. The rename changed names, not behavior. |

### Consumer notes

- **This is a breaking release.** Use `plan` / `create` / `update` (not
  `decompose` / `decompose --apply` / `refine`), and the new config keys
  (`projectDocs` / `reviewer` / `issueSize` / `architectAgent`). The config file
  name is unchanged. Re-run `setup` if you had set any of the old keys.
- **`create` builds what you approved.** It deploys the recorded plan faithfully;
  to change what gets built, change your brief and re-run `plan`.
- **`update` never destroys.** It only creates and patches; an issue that left your
  plan is flagged, never auto-closed.

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
