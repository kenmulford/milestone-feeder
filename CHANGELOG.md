# Changelog

Release notes for milestone-feeder. Each tagged release is also published on the
[GitHub Releases page](https://github.com/kenmulford/milestone-feeder/releases).

## v0.11.2 — implied-surfaces and scenario-harness fixes

**Theme:** Gaps surfaced by the first real installed-plugin run of the scenario harness (item 4a, 2026-07-06): one implied-surfaces design call plus two test-harness fixes.

### ✨ Scenario-harness hardening

| Issue | PR | What |
|---|---|---|
| #285 scenario 12: the implied-surfaces control assertion (no-capability slice) is never exercised | #289 | Creates `tests/scenarios/12b-implied-surfaces-control/` — a capability-free control sibling to scenario 12; its grader-only expectations assert zero `implied`-disposition candidates, no `[implied …]` marker, and no anti-fixation prompt string. |
| #286 scenario harness: enforce blind-runner isolation (expected.md is readable from the runner path) | #290 | Renames the grader answer key `expected.md` → `expected.grader.md` in all 11 scenario dirs, defines the runner input set explicitly as {`brief.md`, `project/`, `feeder-env.md`}, and records a neutral runner-brief template — a blind runner can no longer ground on the answer key by accident (the recorded Option C decision). |

### 🔧 Fixes

| Issue | PR | What |
|---|---|---|
| #284 implied-surfaces: mark [implied] or absorb companions that already exist as app-wide infra? (DECISION) | #288 | Records the human decision in architect clause 8: the architect marks EVERY conventional companion surface `disposition: implied` — net-new and reused-existing-infra alike. The first scenario-12 run graded PARTIAL because reused-infra companions were absorbed as grounded rather than marked. |
| #292 skills: plan/update/build-roadmap frontmatter is invalid YAML — skills fail to register in Claude Desktop | #293 | Converts the three descriptions to `>-` folded block scalars (an unquoted `": "` mid-scalar is invalid strict YAML, so Claude Desktop's loader silently dropped the skills) and adds a stdlib-only strict-scalar gate to the structure validator so the defect class can't recur. |

### Consumer notes (upgrading from v0.11.1)

- **Claude Desktop users:** `plan`, `update`, and `build-roadmap` failed to register in Claude Desktop on all prior releases (strict-YAML frontmatter defect, #292) — this release restores them. Claude Code CLI was unaffected.
- **Architect behavior change:** companion surfaces that reuse existing app-wide infra are now marked `[implied]` in candidate issues instead of being silently absorbed as grounded — you'll see the marker on more candidates when planning briefs that touch conventional companions (logs, retries, audit trails).
- **Test-harness only:** the `expected.md` → `expected.grader.md` rename and the 12b control fixture affect only the in-repo scenario harness; nothing changes for consumers who don't run it.
- **No schema changes** to `.milestone-config/feeder.json`.

### ⚖️ Post-run audit trail

Judgment-call PRs for this release: none

## v0.11.1: audit remediation — re-trims, honest harness, size budgets

Patch release — the audit-remediation milestone (10 issues, all merged CI-green).

- `plan/SKILL.md` re-trim: 3.7 fan-out phases → `docs/roadmap-fan-out.md`, Step 5.1 version ladder → `docs/version-ladder.md` (12,183 → 9,729 words) (#262)
- Agent frontmatter descriptions trimmed to role+trigger (~320 words combined); worked examples relocated verbatim to body `## Examples` sections (#263)
- All six one-time Step-0 units consolidated behind `docs/one-time-notices.md` with Skills scoping; KEEP-IN-SYNC comments retired (#266)
- Dead `brief-coverage-verifier` hook-allowlist entry removed + reverse drift-guard (#264); README stops hardcoding the version (#265)
- `create` persists a roadmap deploy checkpoint for resumability (#267); build-roadmap correction loop bounded (#268)
- Per-dispatch verify + one bounded retry on both plan fan-outs, value-level checks (#269)
- Size budgets in the structure validator: per-file ratcheted SKILL.md word ceilings + 150w agent-description ceiling, fail-loud on missing governed files (#270)
- `tests/RESULTS.md` truth-up: fixture catalog, not a scorecard — no run claimed that never happened (#271)

## v0.11.0: md-epic parent issue

**Theme:** The suite's two halves gain a shared handoff object. When a roadmap deploy produces more than one milestone, `create` now also opens one parent issue, labeled `md-epic`, whose body lists the milestones in build order. `milestone-driver` (already shipped on v1.15.0) reads that parent and drives the milestones in sequence on its own, instead of relying on the free-text `milestone X of N` line a human had to read. A single-milestone plan or create stays byte-unchanged: no parent issue, no label, nothing new to configure.

### ✨ The roadmap gets a parent issue

| Issue | PR | What |
|---|---|---|
| #243 `roadmap-splitter` returns the parent's title and intro | #251 | The roadmap-splitter agent now also returns a one-line parent title and a short intro paragraph for the whole roadmap, alongside the milestone split it already returns. |
| #244 `build-roadmap` captures them into the manifest | #253 | The roadmap manifest gains `parent_title` and `parent_intro` fields, so the parent issue's text is reviewed alongside the milestone split before anything deploys. |
| #245 `create` produces the parent issue | #254 | `create` ensures the `md-epic` label exists, then creates or adopts one parent issue carrying the reviewed title and intro plus a `md-epic-order` block listing the deployed milestones in build order. A manifest receipt records the parent's issue number for idempotent re-runs. |
| #246 `create` links the milestones' issues | #255 | Each milestone's own issues are linked to the parent as native GitHub sub-issues, then each issue's own milestone is re-asserted, so linking never strands an issue on the parent's own (empty) milestone. |
| #247 `update` reconciles the parent on a re-plan | #256 | When a roadmap is re-planned, `update` rewrites the `md-epic-order` block to the current build order, links any newly-added milestone's issues, and reconciles the parent by adopting it, never duplicating or deleting it. |
| #248 One-time discovery notice | #252 | `plan` and `create` show a one-time, per-clone notice the first time the parent-issue behavior could apply, so an existing user learns about it without needing to read this changelog. |

The verification probe (#242, PR #250) confirmed the GitHub behavior this design relies on before any skill was edited; this entry (#249, its own PR) is the narrative docs sweep recording the above. Neither is a behavior change, so neither appears in the table.

### Consumer notes (upgrading from v0.10.0)

- **New, roadmap-only: a parent issue ties your milestones together.** When your brief spans several releases and `create` deploys more than one milestone, it now also opens one parent issue (labeled `md-epic`) whose body lists every deployed milestone in build order. `milestone-driver` reads that parent and builds the milestones in sequence on its own, instead of relying on a human reading the `milestone X of N` line. A single-milestone brief is byte-unchanged: no parent issue, no label, nothing to configure.
- **No new config key.** This is default behavior on the roadmap path. There is nothing to add to `.milestone-config/feeder.json`, and nothing in `/milestone-feeder:setup` changes.
- **One edge worth knowing.** A roadmap whose milestones add up to more than GitHub's 100-sub-issue-per-parent cap cannot link every issue. `create` warns clearly when this happens rather than failing silently or linking only some of the issues without saying so.

## v0.10.0 — size-aware split + Trello mirror

**Theme:** Two independent improvements to how a brief becomes milestones — and where the result shows up. The architect's roadmap nudge now also fires when a **single-theme** breakdown is simply too **large or heavy** to be one milestone — not only when a brief spans phased releases or release boundaries — so an oversized brief is steered toward a sequenced roadmap up front (a qualitative call, no numeric threshold). And when your `milestone-driver` is configured with Trello, `create` now **mirrors** each freshly-deployed milestone onto your board — one card on the queue list, its issues as a Wave-ordered checklist — so the work is visible on your project board the moment it's created, instead of waiting for the driver's first build run. The Trello destination is read from the **driver** profile; no new feeder config key is added.

### ✨ Size-aware split + Trello mirror

| Issue | PR | What |
|---|---|---|
| #233 Size/heaviness-aware multi-milestone detection | #237 | The architect now nudges toward a **roadmap** when a single-theme breakdown comes out **too large or heavy** to be one milestone — many candidates and/or several `risk:heavy` items, *and* a clean dependency seam to split on — alongside the existing phased-deliverable / release-boundary trigger. The call is **qualitative — no numeric threshold** (mirroring the phase trigger); a large/heavy breakdown with no clean seam stays a single milestone rather than forcing a bogus split. **Detection and nudge only** — `build-roadmap` and `roadmap-splitter` are unchanged, and a normally-sized, single-theme brief is byte-for-byte as before. |
| #234 Mirror the milestone to Trello at the end of `create` | #238 | When the resolved **driver** profile carries `integrations.trello`, `create`'s final deploy pass seeds **one** milestone-level card on the board's **queue** list — a Wave-ordered "Issues" checklist plus a `<!-- trello: <card-url> -->` back-link on the milestone description — reusing `milestone-driver`'s trello-sync conventions (1–7) **by reference**. Absent `integrations.trello`, or no driver profile → **silent no-op**, the GitHub deploy result byte-unchanged; best-effort and **never gating** (any Trello failure logs one line and continues). The feeder **seeds** the card; the driver **drives** it (the shared back-link lets the driver adopt the same card — no duplicate). **No new feeder config key.** |
| #235 Document the size/heaviness detection | #239 | Docs-sweep recording the widened size/heaviness detection trigger in the v0.3.1 driver-handoff spec §5 (the multi-milestone guardrail). |
| #236 Document `create`'s Trello milestone mirror | #240 | This docs-sweep — records `create`'s Trello milestone mirror across `docs/profile-schema.md` (framed as a **driver-config read**, not a `feeder.json` key), `docs/consumer-setup.md` (the optional-integration soft-dependency framing), `README.md`, and this changelog. References the driver's trello-sync conventions rather than restating them. Documentation only — no `skills/`, `agents/`, or `hooks/` file touched. |

### Consumer notes (upgrading from v0.9.0)

- **New — `create` can mirror the milestone to Trello.** When your `milestone-driver` profile carries `integrations.trello` (`.milestone-config/driver.json`), `create` now drops a milestone card on your board's queue list — with the issues as a checklist and a back-link on the milestone description — as its final deploy pass, so a freshly-planned milestone is visible on your project board immediately. It reads the board destination from the **driver's** profile; **there is no new feeder config key**, and nothing in `/milestone-feeder:setup` changes. When `integrations.trello` is absent (or you run no driver), `create` does nothing new — a **silent no-op**, best-effort and never blocking, and the GitHub deploy is byte-for-byte as before. The card's shape and behavior stay the driver's — `create` seeds the card by reference to `milestone-driver`'s `skills/solve-milestone/trello-sync.md`.
- **New — the roadmap nudge now also fires on an oversized, single-theme brief.** Previously `plan` only proposed a **roadmap** when your brief read as several phased releases. Now it also nudges toward one when a **single-theme** breakdown is simply too large or heavy to be one milestone (a qualitative call — no numeric threshold — and only when a clean dependency seam exists to split on). A normally-sized, single-release brief is unchanged — no roadmap step and no extra prompt — and the split, as before, is always yours to confirm, adjust, or reject.
- **No schema changes** to `.milestone-config/feeder.json`. The Trello mirror adds **no feeder key** — it reads `integrations.trello` from the existing driver profile — and the size/heaviness detection reuses the existing breakdown grounding. Same commands (`plan` / `create` / `update`), same plan-file output.

## v0.9.0 — lean plan

**Theme:** `plan` becomes a lean, architecture-aware drafter. The feeder no longer re-runs the driver's reviewers as an in-feeder self-check gate before anything is written — that gate was a redundant pre-audit of issues that don't exist yet (~63% of a plan run's token cost), because the driver's own triage runs the same reviewers on the created issues anyway. The feeder now **drafts** well-formed issues that **target** the driver's triage bar; the driver's triage is the single automated entry gate (you still review the plan before `create`). Freed of the gate, `plan` gains real value: the architect **breaks the work down along your project's architecture** — assigning each issue to the layer your `.project` layering convention dictates and ordering by layer dependency — and every issue **points at the relevant `.project` config** (tokens, design-system, environment) by path, a reference the driver reads at build time rather than a value pre-solved into the issue.

### ✨ Lean, architecture-aware plan

| Issue | PR | What |
|---|---|---|
| #223 Remove the plan self-check gate | #226 | Removes the feeder's `plan` self-check/reviewer gate and `create`'s post-deploy `brief-coverage-verifier`; the feeder **drafts** issues that **target** the driver's triage bar (the single automated entry gate) instead of running the reviewers itself. Product-gap parking is **kept** — its drop-parked-issues-and-dependents behavior relocated into the surviving pipeline. The `reviewer` config key is retired (an existing key is ignored gracefully). Net −454 lines. |
| #224 Layer-aware breakdown | #227 | The architect reads your project's stack + layering convention from `.project` and assigns each candidate an architectural **layer**, keying the Wave order to the layer dependency (not only ad-hoc type references). The `layer` threads through to the issue body, so the driver sees which layer the work sits in. Additive: a project stating no layering convention degrades to today's dependency-only breakdown, byte-for-byte. |
| #225 Point each issue at project config | #228 | Each generated issue records a **config-pointer** line in its Design block, naming the relevant `.project` config (`tokens.json` / `design-system.md#<section>` / `environment.md`) **by path** — a reference the driver reads at build time, never a pre-solved or inlined value. A recorded design directive (e.g. a literal "30 rows per page") still stays inlined; only resolved render/token values are pointed at. Degrades cleanly when a doc is absent. |

### Consumer notes (upgrading from v0.8.0)

- **`plan` is faster and no longer runs an in-feeder review gate.** The feeder used to dispatch the driver's `triage-reviewer` + `design-reviewer` against every generated issue and gate/retry on their findings before writing the plan — roughly 63% of a plan run's token cost. That gate is removed: `plan` now drafts issues that *target* the driver's triage bar, and the driver's own triage (which runs the same reviewers on the created issues) is the single automated entry gate. You still review the plan before `create`, exactly as before. Product-gap parking is unchanged — a brief that needs a human decision still parks to the needs-product-input report.
- **The `reviewer` config key is retired — this is the only schema change.** If your `.milestone-config/feeder.json` still carries a `reviewer` key, it is now ignored gracefully (unknown key → no error). No action needed.
- **`create` no longer runs a post-deploy coverage audit** (the `brief-coverage-verifier`). `create` still deploys and reads back for its own correctness; it just no longer re-audits coverage against the brief — consistent with "create is not a gatekeeper."
- **New — layer-aware breakdown.** When your `.project` declares a layering convention (a `#Layering & boundaries` section, or a stated layered stack), the architect assigns each issue its layer and orders by layer dependency. When no layering is declared you get today's dependency-only breakdown — no change, no fabricated layering.
- **New — config pointers in each issue.** Issues that touch styling/deployment/conventions now name the relevant `.project` doc by path so the driver reads the source of truth; they don't copy resolved token or design values into the issue body.

### ⚖️ Post-run audit trail

Judgment-call PRs for this release: **#226** (deferred the regenerated `tests/RESULTS.md` + scenario transcripts — they still show the removed self-check format), **#227** (the `SPEC.md` §4 template line was applied on the main thread, as `SPEC.md` is a doc outside `sourceGlobs`).

Deferred follow-up: `tests/RESULTS.md` and the per-scenario `run-log.md` / `run-output.md` transcripts still narrate the removed self-check gate — they are regenerated-not-hand-edited by convention (`tests/RESULTS.md`), so they refresh on the next `tests/scenarios/` harness re-run, not by hand.

## v0.8.0 — progressive-disclosure skill trim

**Theme:** A behavior-neutral refactor that brings the plugin's own oversized `SKILL.md` files into line with Claude's skill-authoring size standards. The heavy reference text, the canonical output templates, and the duplicated one-time-notice machinery that had accumulated inside the skills are relocated into on-demand `docs/` reference files, so each `SKILL.md` is now a lean overview plus a step skeleton that points at the reference it needs. **No consumer-facing behavior change** — every skill does exactly what it did before, and the `tests/scenarios/` end-to-end suite is byte-identical. This is internal maintainability work only.

### 🧹 Progressive-disclosure skill trim

| Issue | PR | What |
|---|---|---|
| #197 One-time-notices reference | #212 | New `docs/one-time-notices.md` — the canonical text for the five Step-0 one-time, per-clone notices, so the duplicated notice machinery lives in one place the skills point at. |
| #198 Plan-file-contract reference | #210 | New `docs/plan-file-contract.md` — extracts the plan-file contract and the canonical output templates into one shared reference. |
| #199 Trim `plan` Step 0 | #217 | `plan/SKILL.md` Step 0 trimmed to point the five notices and the key table at their `docs/` references. |
| #200 Trim `plan` Steps 1–5 | #213 | `plan/SKILL.md` Steps 1–5 trimmed — point at the agent contracts, dedupe repeated prose. |
| #201 Trim `plan` Step 6 keystone | #211 | `plan/SKILL.md` Step 6 self-check keystone trimmed (relocate-and-dedupe), the largest single region. |
| #202 Trim `plan` Step 7 | #216 | `plan/SKILL.md` Step 7 trimmed — point its templates and contract at the shared reference. |
| #203 Trim `setup` | #215 | `setup` trimmed 279 → 152 lines — Step-0 notices point at the shared reference; the tier prose is leaned out. |
| #204 Trim `update` | #218 | `update` trimmed — its Step-0 notice and plan-file contract point at the shared references. |
| #205 Trim `create` + deploy-sequence reference | #219 | New `docs/create-deploy-sequence.md`; `create` relocates its heavy deploy mechanics there (~57% smaller). |
| #206 Trim `build-roadmap` + manifest-format reference | #214 | New `docs/roadmap-manifest-format.md`; `build-roadmap` extracts its manifest-format scaffold there. |
| #208 Standing-docs sweep | — | Sweeps the standing docs that name the skill shape so the exemplar and contents pointers stay accurate after the trims (lands as a concurrent sibling of this release sync). |
| #209 v0.8.0 release sync | (this PR) | Re-synced the version stamps (`.claude-plugin/plugin.json` already `0.8.0`, the README `## Status` line, and `.project/library-manifest.md`) and authored this changelog entry — which doubles as the GitHub-release body. Documentation + version metadata only; no `skills/`, `agents/`, or `hooks/` file touched. |

### ⏸️ Deferred

| Issue | PR | What |
|---|---|---|
| #207 Byte-parity guard for the extracted twins | — | **Parked — needs design.** The mechanism for guaranteeing the bash and PowerShell twins of an extracted reference stay byte-for-byte in lockstep is underspecified (the two shells escape differently in the source bytes). Not in this release. |

### Consumer notes (upgrading from v0.7.0)

- **Nothing changes for you.** This release is a pure internal refactor of how the plugin's own skill files are organized. Every skill — `plan`, `create`, `update`, `setup`, `build-roadmap` — does exactly what it did before. The `tests/scenarios/` end-to-end suite is byte-identical, which is how the no-behavior-change guarantee is verified.
- **No config changes.** No schema changes to `.milestone-config/driver.json` or `.milestone-config/feeder.json`, no new config keys, and no changed defaults.
- **Version bump only in the source-of-truth locations.** `.claude-plugin/plugin.json` is `0.8.0`, the README `## Status` line is re-synced to match, and the `.project/library-manifest.md` version stamp is updated; the `SPEC.md` as-built header carries no version by design.

## v0.7.0 — implied surfaces: capability-aware completeness

**Theme:** A brief that names a capability — "add email", "user management", "sync" — or introduces a new kind of record quietly commits to a standard set of companion surfaces (screens, endpoints, jobs, settings) it never spells out. The feeder used to break down only what was literally written, so those companions surfaced one-at-a-time mid-build as unplanned rework. Now, during breakdown, the architect consults a curated, stack-agnostic **implied-surfaces reference** and, for each capability or new entity your brief invokes, proposes the standard companions it implies as reviewable `implied` candidates — each marked `[implied — review / trim / augment]` in the plan, with a built-in `this is a starting set for YOUR app — what's missing?` prompt so you trim or augment before any issue is created. It is a **floor, not a ceiling**: a genuine product-call with no conventional default still **parks** for your decision, never silently pre-included. A brief that invokes no capability and no new entity is unchanged.

### ✨ Implied surfaces

| Issue | PR | What |
|---|---|---|
| #178 Implied-surfaces reference + overlay shape | #186 | Ships the bundled, PR-able **implied-surfaces reasoning reference** (`docs/implied-surfaces.md`): the standard companion surfaces a capability or new entity implies, in stack-agnostic terms (screen / endpoint / job / setting), framed as a reviewable **floor** — a robust start, never a scope-emitting catalog. Also **defines** (does not yet wire) the optional project-local overlay file's shape. |
| #179 Architect consult step + `implied` disposition | #188 | Adds clause 8 to the `architect`: for each named capability or new entity, consult the reference and sort each companion with the **same grounded-vs-product-gap judgment** it already applies — a conventional companion rides `CANDIDATES` with a new optional `disposition: implied` label; a genuine product-call still parks via `PRODUCT_GAPS`. A deliberate, conscious evolution of the architect's contract and rigor gate, with the never-invent floor preserved. |
| #180 Wire `plan` end-to-end | #190 | `plan` resolves the bundled reference at Step 0 and hands it to the architect, threads the `disposition` field through to the plan file, renders each `implied` candidate **distinctly** (the `[implied — review / trim / augment]` marker on its heading), and — only when the plan carries an implied candidate — fires the structural **anti-fixation prompt** (`this is a starting set for YOUR app — what's missing?`) at the same confirm/override moment as the milestone identity. No implied candidate → nothing surfaces, byte-for-byte as before. |
| #181 Resolve + additively merge the overlay | #191 | `plan` Step 0 resolves the optional project-local overlay (`.milestone-config/implied-surfaces.md`) and merges it into the bundled reference **additively** — an overlay can add a capability and extend an existing one, but never remove a surface the global reference defines. Absent overlay → the global reference unchanged (no error); a malformed overlay is skipped best-effort. |
| #182 Issue-author awareness | #192 | The `issue-author` is made aware of the architect's optional `disposition: implied` label, so an implied candidate flows through authoring like any other while carrying its review instruction. Additive — a candidate without the field is authored exactly as before, and the field never lowers the rigor gate. |
| #183 Overlay discovery path | #189 | `setup` mentions the optional overlay (informational — discovered by a fixed path, not a key), and `plan` / `update` print a shared **one-time, per-clone** notice that names the overlay and explains its additive merge — so existing users discover the new optional surface. Read-only, marker-gated, non-blocking. |
| #185 e2e implied-surfaces scenario | #193 | Adds an end-to-end scenario exercising the implied-surfaces planning path. |
| #184 Implied-surfaces docs sweep + v0.7.0 | (this PR) | Documented the capability across `docs/architecture.md`, `docs/profile-schema.md`, `docs/consumer-setup.md`, `SPEC.md`, `README.md`, and this changelog; reflected the `implied` disposition + the bundled reference in the SPEC + architecture rosters; documented the overlay as an optional config **file** (not a `feeder.json` key) with additive-merge semantics; and re-synced the README `## Status` line to v0.7.0 (`.claude-plugin/plugin.json` was already `0.7.0`). Documentation + version metadata only — no runtime change, no `sourceGlobs` file touched. |

### 🔧 Fixes

| Issue | PR | What |
|---|---|---|
| #177 Drop the cross-marketplace `superpowers` dependency | #187 | Removed the cross-marketplace `superpowers` dependency from the plugin manifest so **Claude Desktop registers the feeder's slash commands**. `superpowers` is now a **user-installed prerequisite** you add yourself before installing milestone-feeder (the plan pipeline still depends on it) — see `README.md`. |

### Consumer notes (upgrading from v0.6.0)

- **New behavior during breakdown.** When your brief names a capability or introduces a new entity, the architect now proposes the standard companion surfaces that capability implies as reviewable **`implied` candidates** — each marked `[implied — review / trim / augment]` in the plan — and fires a one-line **anti-fixation prompt** (`this is a starting set for YOUR app — what's missing?`) at the same moment you confirm the milestone identity. Every implied surface lands in a plan you review, trim, or augment **before any issue is created** — nothing is created automatically. A genuine product-call with no conventional default still **parks** for your decision via the needs-input report, exactly as before. A brief that invokes no capability and no new entity is unchanged — no marker, no prompt.
- **A floor, not a guarantee.** The reference is deliberately short and conceptual — it ensures the architect *considers* the conventional companions, never guarantees the list is complete. The anti-fixation prompt is the built-in step that asks you for what a curated list can't know.
- **New optional overlay — nothing required.** You can teach the reference your domain's own capabilities with an optional file at `.milestone-config/implied-surfaces.md` (a sibling of `feeder.json`), merged **additively** — add a capability, extend an existing one, never remove a global surface. It is **discovered by that fixed path, not a config key** — there is **no schema change** to `.milestone-config/feeder.json` or `.milestone-config/driver.json`, and nothing in `/milestone-feeder:setup` to change. Most projects ship no overlay; that is the common case, never an error. `setup` mentions it and `plan` / `update` show a one-time heads-up so you discover it.
- **Install change — `superpowers` is no longer auto-installed (#177).** The cross-marketplace `superpowers` dependency was dropped from the manifest so Claude Desktop registers the feeder's slash commands. Install `superpowers` yourself first (it remains a required prerequisite for the plan pipeline) — see `README.md`.
- **Version bump only in the two source-of-truth locations.** `.claude-plugin/plugin.json` is `0.7.0` and the README `## Status` line is re-synced to match; the `SPEC.md` as-built header carries no version by design.

## v0.6.0 — the roadmap: a whole-app brief becomes a sequenced set of milestones

**Theme:** The feeder is no longer one brief → one milestone for an oversized whole-app brief. Hand `plan` a brief that spans several releases and it now carves it into a **roadmap** — a build-ordered set of milestones — confirms the split with you once, plans them all in parallel, and `create` deploys them in build order and then checks the result covers your whole brief. The v0.3.1 *"this looks like ~N milestones"* advisory is now the **trigger** for the real split, not a passive note. A normal, single-release brief is unchanged.

### ✨ The roadmap — whole-app brief → sequenced milestones

| Issue | PR | What |
|---|---|---|
| #151 Roadmap-splitter agent | #161 | A new read-only `milestone-feeder:roadmap-splitter` agent: a whole-app brief + your standing docs → a strict, build-ordered partition into named milestones (the `ROADMAP` block). It supersedes the architect's passive multi-milestone advisory with a real, ordered split — every part of the brief in exactly one milestone, none dropped or duplicated. |
| #152 Internal build-roadmap skill | #164 | A new **internal** `build-roadmap` skill (invoked by `plan`, never a user command): dispatch the splitter once, surface the proposed split for you to **confirm / merge / split / reorder / reject** before anything is written, and on confirmation write a **roadmap manifest** (`.milestone-feeder/roadmap-<slug>.md`) carrying the milestone build order and the full original brief. Read-only on GitHub. |
| #153 plan inner-routine refactor | #163 | `plan`'s Steps 1–7 are named as a **callable single-milestone inner routine** — behavior-neutral. The default single-brief path invokes it exactly once (byte-for-byte the prior behavior); the roadmap path invokes it once per milestone. |
| #154 plan front-door routing | #166 | `plan` gains a front-door size/scope check (Step 3.6): when the architect raises `SCOPE_SPANS_MULTIPLE_MILESTONES`, it routes the brief into `build-roadmap` instead of just flagging it. The signal is the sole arbiter of "oversized" — no second threshold; a decline or degrade falls back to the single-milestone plan with the passive advisory retained as a backstop. A one-time per-clone notice announces the new routing to existing users. |
| #155 parallel per-milestone fan-out | #167 | `plan`'s roadmap branch (Step 3.7) plans every milestone the confirmed roadmap names, in build order, fanning the per-milestone planning out in parallel (a probe pins the dispatch topology). Each milestone's version + title is resolved once on the main thread before the fan-out, so the version ladder's one interactive prompt never runs inside a background subagent; each milestone emits its own plan file. |
| #156 Brief-coverage-verifier agent | #162 | A new read-only `milestone-feeder:brief-coverage-verifier` agent: audits the read-back content of every created milestone + issue against the **original** brief and returns a coverage punch-list (uncovered / duplicated / distorted parts, plus read-errors). It runs no `gh` of its own — `create` does the read-back and hands it the content. |
| #157 create deploy-loop | #168 | `create` deploys a roadmap of **N** milestones by **looping its unchanged per-plan deploy** over the manifest's milestones in build order, recording each one's cross-milestone position as a single `build order: milestone X of N` line. The single-plan path is the N=1 case, byte-for-byte unchanged; a mid-loop failure stops and reports, deletes nothing, and a re-run resumes. |
| #158 post-create coverage verification | #170 | `create`'s **closing action** (Step 3V, always-on): read every deployed milestone + issue back from live GitHub and dispatch the brief-coverage-verifier once against the original brief, surfacing a coverage punch-list routed like the needs-input report. Best-effort and **non-blocking** — it never blocks `create`, the driver handoff, or any merge, and never auto-fixes a deployed issue. |

### 📝 Docs & version

| Issue | PR | What |
|---|---|---|
| #159 Roadmap docs sweep + v0.6.0 | (this PR) | Documented the roadmap pipeline across `SPEC.md`, `docs/architecture.md`, `docs/consumer-setup.md`, `README.md`, and this changelog; reconciled the v0.3.1 multi-milestone advisory prose to point at the real roadmap support (the advisory is now its trigger); added the two new agents (`roadmap-splitter`, `brief-coverage-verifier`) to the SPEC + architecture rosters; and bumped `.claude-plugin/plugin.json` `version` 0.5.0 → 0.6.0 with the README `## Status` line re-synced to match (also clearing the pre-existing `v0.4.6` README drift). Documentation + version metadata only — no runtime change. |

### Consumer notes (upgrading from v0.5.0)

- **New behavior on a whole-app brief.** A brief that reads as several separate releases now routes into the **roadmap flow**: `plan` proposes a sequenced set of milestones and asks you to confirm, merge, split, reorder, or reject the split before planning anything; `create` then deploys them in build order and checks the result covers your brief. Previously such a brief got only a passive *"this looks like ~N milestones"* advisory you acted on by hand — that advisory is now the **trigger** for the real split, and is kept only as a backstop when you decline the roadmap.
- **Small / normal briefs are unchanged.** The roadmap only triggers when your brief spans several releases — a single-release brief sees no roadmap step and no extra prompt, and the single-milestone plan output is byte-for-byte as before. `plan` shows a one-time, per-clone heads-up the first time the routing could apply, so you discover the behavior.
- **No schema changes.** No new config key — the roadmap reuses the existing `projectDocs` grounding; nothing in `.milestone-config/feeder.json`, `.milestone-config/driver.json`, or `/milestone-feeder:setup` changes.
- **Version bump only in the two source-of-truth locations.** `.claude-plugin/plugin.json` is `0.6.0` and the README `## Status` line is re-synced to match; the `SPEC.md` as-built header carries no version by design.

## v0.5.0 — automated feeder → driver handoff

**Theme:** When `create` finishes building a milestone on a clean, vetted run and `milestone-driver` is installed, the feeder can hand the milestone straight to the driver to start building — instead of leaving you to invoke the driver yourself. You stay in control: the default is to ask first, and the handoff never crosses the `develop → main` release boundary.

### ✨ The create → driver handoff

| Issue | PR | What |
|---|---|---|
| #148 Automated feeder → driver handoff | #149 | After `create` deploys a milestone and its issues, a new Step 4 can hand the milestone to `milestone-driver` by invoking `/milestone-driver:solve-milestone "<exact title>"`. It is **build-kickoff only** — the driver builds to the integration branch (`develop`); `develop → main` stays a manual human call. The new `feeder.json#autoHandoff` key governs it: `"prompt"` (default — ask "milestone-driver is installed — start building now, or review first?"), `"auto"` (kick off immediately, no prompt), or `"off"` (never offer — exactly today's no-handoff behavior). Three gates must all hold to offer the handoff: the run is **clean** (no product gap, nothing parked/dropped) **and the self-check actually ran** (a `reviewer: false` / `SKIPPED` run is not eligible — its issues were never vetted), the `milestone-driver` skill **resolves in this session** (absent → silently skip, no prompt, no error), and the handoff **never crosses the release boundary**. An unrecognized `autoHandoff` value is treated as the default `"prompt"`. |

### Consumer notes (upgrading from v0.4.6)

- **New behavior on a clean `create` run.** With `autoHandoff` unset, `create` now **prompts** once at the end of a clean, vetted run when `milestone-driver` is installed, offering to start the build. To keep exactly the old behavior (no handoff, no prompt), set `"autoHandoff": "off"` in `.milestone-config/feeder.json`. The new key is presented in `/milestone-feeder:setup` and documented in `docs/profile-schema.md`.
- **The handoff is build-kickoff only.** It invokes the driver, which merges only to your integration branch (`develop`); it never auto-merges to a protected branch and never removes the release gate — `develop → main` stays a manual human call.
- **No schema changes** to `.milestone-config/driver.json`. The only config change is the new optional `feeder.json#autoHandoff` own-key (absent-means-default `"prompt"`).
- v0.4.6 (the prior release, un-noted in this changelog) was a grounding-and-coverage release: the repo bootstrapped its own `.project/` standing docs, added a nested-layout (`siteroot/{web,api}`) end-to-end test scenario, and dropped the version from the SPEC.md as-built header (pointing readers at `plugin.json` as the single source of truth). The `plan` / `create` / `update` runtime surface was unchanged in v0.4.6.

## v0.4.5 — bootstrap nudge honors configurable projectDocs

**Theme:** The v0.4.4 bootstrap nudge now honors your configurable `projectDocs` path instead of a hardcoded `.project/`, so a custom standing-docs directory no longer triggers a false "your grounding will be weak" warning.

### 🔧 Fixes

| Issue | PR | What |
|---|---|---|
| #137 Make plan Step 0 bootstrap-nudge honor the resolved projectDocs path | #139 | The `plan` bootstrap nudge resolves the configurable `projectDocs` key (default `.project/`) from `feeder.json` and uses the resolved path in both the detection and the notice text — so a consumer who points `projectDocs` at a custom directory (e.g. `docs/standards/`) and is fully bootstrapped no longer gets a false "grounding is weak" nudge. Default-config repos are byte-identical to v0.4.4. Resolution is cross-platform-parity-hardened (string-type guard, strip-all-trailing-slashes, empty-after-normalize fallback) so degenerate values (`"/"`, doubled slashes, non-string) resolve identically in the bash and PowerShell 7+ forms. Non-blocking / best-effort / read-only preserved. |

### Consumer notes (upgrading from v0.4.4)

- If you set a custom `projectDocs` in `.milestone-config/feeder.json` (anything other than the default `.project/`), the bootstrap nudge now checks *that* path. Previously it checked the literal `.project/`, so a bootstrapped custom-`projectDocs` repo saw a false nudge — that's fixed. Default-config repos (`projectDocs` unset) see no change.
- **No schema changes** to `.milestone-config/driver.json` or `.milestone-config/feeder.json` — `projectDocs` is an existing key; this release only makes the nudge honor it.

### ⚖️ Post-run audit trail

Judgment-call PRs for this release: #139 (accepted three exotic-config edge cases — whitespace-only / outside-repo / mixed-path `\| Fix \|` line — as deliberate non-goals; see the PR's Code Review section).

## v0.4.4 — bootstrap nudge on unbootstrapped repos

**Theme:** When `plan` runs in a repo that was never bootstrapped, it now tells the user once that grounding will be weak and points them at `milestone-bootstrapper` — instead of silently proceeding on thin inferred conventions.

### ✨ Bootstrap discovery path

| Issue | PR | What |
|---|---|---|
| #132 Add a one-time non-blocking bootstrap-nudge notice in plan Step 0 | #134 | `plan` Step 0 now prints a one-time, non-blocking notice when the repo has no `.project/` standing docs and/or no `.milestone-config/driver.json` — warning that issue grounding will be weak and recommending `milestone-bootstrapper`, then carrying on. Shows at most once per clone, reads only (never writes `.project/` or `driver.json`), never runs the bootstrapper, and never stops `plan`. Ships as both a bash and a PowerShell 7+ form. |

### Consumer notes (upgrading from v0.4.3)

- New one-time notice in `plan` Step 0 for un-bootstrapped repos — those with no `.project/` docs and/or no `.milestone-config/driver.json`. It is purely advisory: `plan` still runs with best-effort grounding, and config stays optional by design. The notice shows at most once per clone, gated by a git-invisible `.milestone-config/.runtime/bootstrap-nudge-notice` marker (no new `.gitignore` line — the existing `.runtime/` entry covers it).
- Known limitation: the notice checks the literal `.project/` path, not a custom `projectDocs` override. Tracked as #133.
- **No schema changes** to `.milestone-config/driver.json` or `.milestone-config/feeder.json`.

### ⚖️ Post-run audit trail

Judgment-call PRs for this release: #134 (accepted the literal-`.project/` check over the configurable `projectDocs` key — see #133).

## v0.4.3 — Feeder-first scratch self-heal & discovery path

**Theme:** The feeder now establishes the suite's committed scratch-ignore on its own — so a repo that runs the feeder before any driver run no longer leaves per-clone scratch un-ignored or `feeder.json` untracked — and it adds a standing rule that every new feature ships a path for existing users to discover the change.

### ✨ Feeder-first self-heal & existing-user discovery

| Issue | PR | What |
|---|---|---|
| #120 Self-heal `.milestone-config/.gitignore` from setup Phase 3 | #125 | `setup` Phase 3 now writes the nested `.milestone-config/.gitignore` (create-only, never clobbers) so a feeder-first repo gets the committed scratch-ignore with zero user setup, instead of waiting for a driver run. Mirrors the driver's canonical block (bash + PowerShell 7+). |
| #121 Self-heal `.milestone-config/.gitignore` from plan Step 0 | #126 | `plan` Step 0 self-heals the same nested gitignore on an already-configured repo (where `setup` doesn't re-run) — covering the legacy case where `feeder.json` exists but the gitignore was never written. |
| #122 KEEP-IN-SYNC markers at the feeder self-heal blocks | — | The cross-suite sync markers above the two self-heal blocks; delivered inline with #120/#121 (closed as completed, no separate PR). |
| #123 Detect a legacy root `.milestone-config/*` `.gitignore` blanket + one-time notice | #128 | `setup` and `plan` read-only-detect a legacy root `.gitignore` blanket (which silently hides `feeder.json` and the nested gitignore) and print a one-time by-hand-fix notice — never editing your root `.gitignore`. |
| #124 Encode the existing-user discovery/migration-path principle | #127 | `SPEC.md` + the §4 / `plan` §6.4 quality criteria now require every new feature, config key, or behavior change to ship an existing-user discovery path; the feeder's own self-check enforces it (internal backend). |

### Consumer notes (upgrading from v0.4.2)

- **Feeder-first adoption now just works.** If you run `/milestone-feeder:setup` or `/milestone-feeder:plan` before ever running milestone-driver, the feeder now writes the committed `.milestone-config/.gitignore` itself — create-only, so it never touches a file you've edited — keeping per-clone scratch out of `git status` while `driver.json`/`feeder.json` stay tracked, with zero setup.
- **Legacy-blanket repos get a one-time heads-up.** If your repo's root `.gitignore` carries an old `.milestone-config/*` blanket (from older driver setups), `setup`/`plan` print a one-time 🔴 notice explaining that the blanket leaves `feeder.json` untracked, plus the one-line by-hand fix. The feeder **never edits your root `.gitignore`** — detection is read-only; you apply the fix.
- **No schema changes** to `.milestone-config/feeder.json`. Same commands (`plan` / `create` / `update`), same plan-file output.
- **New quality bar:** the spec now requires every new feature to ship an existing-user discovery path (non-breaking is necessary but not sufficient). The feeder's self-check enforces it on the internal backend; full default-path (driver `triage-reviewer`) enforcement is tracked as companion milestone-driver work (v1.12.2).

### ⚖️ Post-run audit trail

Judgment-call PRs for this release: none

## v0.4.2 — Release hygiene

**Theme:** Pure housekeeping — nothing about how the feeder works changes. The
docs had drifted behind the real plugin version: the as-built spec header, the
README status line, and a leftover label in the architecture doc all still named
an older version. This release re-syncs them to the source of truth and adds a
short release checklist so they stay in step from here on.

### 🧹 Hygiene — keep the version references honest

| Change | PR | What |
|---|---|---|
| Re-sync the spec header to the real version | #75 (#115) | `SPEC.md`'s as-built header (line 1 and the status line) still read `v0.3.1` while the plugin had already moved several releases ahead. It's now re-synced to `.claude-plugin/plugin.json`'s `version` — the single source of truth. |
| Add a release checklist so it can't drift again | #113 (#114) | Added a short "Release checklist" to `docs/architecture.md` — when the plugin version is bumped, re-sync the spec header to match — and tidied the version note above it, dropping the now-contradictory "only" and the stale "(currently `0.3.0`)" aside. |

### Consumer notes (upgrading from v0.4.1)

- **Pure housekeeping — nothing breaks, nothing changes for you.** Same commands
  (`plan` / `create` / `update`), same config file, same plan-file output. Only
  internal docs were touched — including the README `## Status` line and a stale
  `v0.3.0` label in the architecture doc, both refreshed to the current version.
- **Nested-app support isn't here — it moved to the bootstrapper.** This milestone
  was originally scoped to also add a configurable app-root for repos whose code
  lives in a subfolder. That work belongs in `milestone-bootstrapper` (v0.2.0): its
  new `appRoots` setting bakes each nested path into the `sourceGlobs` /
  `uiSurfaceGlobs` it scaffolds, while keeping the shared config and `.project/`
  docs at the repo root — so the feeder already works on a nested-app repo with
  **no feeder-side change**. The feeder issue was closed as superseded.
- **No config-key or schema changes** to `.milestone-config/feeder.json`.

### ⚖️ Post-run audit trail

Judgment-call PRs for this release: none

## v0.4.1 — Read your house docs once, not once per helper

**Theme:** This release stops `plan` from paying to read the same project docs over
and over. Before, every helper that `plan` runs under the hood — the architect that
designs the breakdown, and every issue-author that writes up a candidate issue —
re-read your whole `.project/` docs folder from scratch. On a populated docs folder
with many issues, that was the same content read many times over in a single run.
Now `plan` reads the relevant sections **once**, up front, into a compact "grounding
digest" and hands that digest to each helper instead of pointing them back at the
folder. **Nothing about your plans changes** — the issues you get, the design
decisions they record, the source citations they carry, and the checks they pass are
all exactly as before. This is purely a cost-and-size pass: each helper is handed the
same grounding it would have read, just resolved once instead of N times. Helpers can
still read the repo on demand to double-check any citation — the digest adds to that
path, it never replaces it — so grounding can't quietly degrade.

### ⚡ Efficiency — resolve the project docs once, reuse everywhere

| Change | PR | What |
|---|---|---|
| Build the grounding digest once | #95 (#100) | `plan`'s first step already reads your project docs (`.project/`). It now also gathers the relevant sections into a compact **grounding digest** — built one time per run — that later steps reuse instead of re-reading the folder. The digest carries every section the helpers would otherwise re-read (a superset, so nothing is dropped), and a missing or empty docs folder just yields an empty digest with no error. |
| Hand the digest to the architect | #96 (#101) | The architect — the helper that decomposes your brief into issues and build order — is now handed the resolved digest as its project-docs grounding, instead of a folder to re-read. It still reads the repo on demand to verify any citation. |
| Hand the digest to each issue-author | #97 (#102) | Each issue-author — one per candidate issue, the highest-multiplicity helper — is now handed the same resolved digest instead of re-reading the folder itself. This is the largest saving, since the re-read was previously paid once per issue. The brief and the on-demand verify path are unchanged. |
| Update the architect's contract | #98 (#103) | The architect helper's own instructions now describe receiving the resolved digest rather than a docs folder to walk, keeping the helper and the step that briefs it in lockstep. Its citation-checking rules are untouched. |
| Update the issue-author's contract | #99 (#104) | The issue-author helper's instructions are reframed the same way — it receives the resolved digest, not a re-read license — with its "grep before you cite" verification rule preserved exactly. |

### 🧹 Hygiene — keep per-run scratch out of your `git status`

| Change | PR | What |
|---|---|---|
| Self-ignore the per-run scratch folder | #107 | The feeder writes its plan file and reports into a `.milestone-feeder/` scratch folder in your repo. It now makes that folder invisible to git **on its first write** — it drops a `.gitignore` containing `*` inside the folder, so a run never leaves untracked files cluttering your `git status`, with zero setup on your part and without touching your repo's root `.gitignore`. |

### Consumer notes (upgrading from v0.4.0)

- **Additive — nothing breaks.** Same commands (`plan` / `create` / `update`),
  same config file (`.milestone-config/feeder.json`), same plan-file output.
- **Your plans get cheaper and smaller to produce,** with the issues, the design
  they record, the citations they carry, and the checks they pass all unchanged.
- **Grounding can't quietly degrade.** The digest is a superset of what the
  helpers used to re-read, and helpers still read the repo on demand to verify any
  citation — the digest supplements that path, it never replaces it.
- **No config-key or schema changes** to `.milestone-config/feeder.json`.

### ⚖️ Post-run audit trail

Judgment-call PRs for this release: none

## v0.4.0 — Faster plans, fail-fast on product gaps

**Released:** 2026-06-22

**Theme:** This release makes `plan` cheaper and quicker to run, and smarter
about stopping early. It does the same work as before — turn your brief into a
reviewable set of issues — but now uses a cheaper model where the work is
mechanical and a stronger one only where the thinking is hard, runs the
per-issue work in parallel instead of one at a time, and bails out up front when
a product decision you haven't made would block several issues at once. **Nothing
about the output changes** — the issues you get, the checks they pass, and the
files written are exactly as before. Same commands, same config: this is a
speed-and-cost pass plus one early-exit behavior change.

### ⚡ Efficiency — right model for each job, and parallel work

`plan` dispatches several helpers under the hood: one *architect* that designs the
breakdown once, one *issue-author* per candidate issue that writes it up, and
*reviewers* that check each issue before it lands in your plan. Until now these all
defaulted to the same strong (and expensive) model and ran one after another.

| Change | PR | What |
|---|---|---|
| Cheaper model for issue-writing | #80 (#85) | The issue-author — the helper that writes up each candidate issue — is now pinned to the cheaper **Sonnet** tier. It does structured transcription against a breakdown the architect already designed, so it doesn't need the top tier. Because there is one issue-author per candidate issue, this is the highest-multiplicity helper and where most of the cost sat; quality is held constant by the same reviewer checks that run afterward. |
| Strong model for the hard thinking | #81 (#86) | The architect — the helper that decomposes your brief, works out which issues depend on which, and sorts them into build order — is now pinned to the strong **Opus** tier on purpose. It runs only once per plan, it's the hardest reasoning step, and every later step builds on its output, so this is quality protection for the whole plan. |
| Write the issues in parallel | #82 (#88) | The per-issue writing now runs several issues at a time (a rolling window, **up to 4 at once**) instead of strictly one after another, joining before the review step. For a plan with many issues this turns wall-clock time from O(N) into roughly O(N/4). The issue-authors are independent and write no shared state, so running them together cannot change what any issue says. |
| Run the issue checks in parallel | #83 (#89) | The review step — the densest part of a run — now also batches **up to 4 checks at a time**, in two staged passes: first the buildability check on every issue, then the design check on the UI issues that need one. The reviewers only read and return a verdict, so batching cannot change any verdict; the staged ordering and the existing retry/re-render rules are preserved. |

### 🧭 Behavior — stop early when a shared product gap blocks several issues

When `plan` hits a design decision it can't make for you — say your brief asks to
"notify members" but never says *how* — it parks that issue and flags the decision
for you instead of guessing. Until now it discovered each blocked issue only late,
one at a time, while writing them up.

| Change | PR | What |
|---|---|---|
| Fail fast on shared product gaps | #87 (#91, #92) | The architect now records *which* candidate issues each open product decision blocks (a new `blocks:` tag on each product gap). `plan` parks those blocked issues at a new early step — **before** it writes and reviews the rest — so one decision you still need to make, like a missing notification channel that several issues depend on, is caught **once, up front** instead of being rediscovered separately for each affected issue. **Nothing else changes:** the same issues get parked and surfaced in the "needs your input" report through the same park machinery; only the timing moves earlier. Issues that aren't blocked are still written, reviewed, and checked exactly as before, and the late catch-all park still handles any gap the architect didn't tie to specific issues. |

### 📝 Docs

| Change | PR | What |
|---|---|---|
| One-marketplace install in the README | #77 (from #76) | The README now leads with the **milestone-suite** marketplace as the recommended way to install — one marketplace that carries all three milestone plugins — while keeping the per-repo marketplace as a still-supported, clearly-labeled alternative. |

### Consumer notes (upgrading from v0.3.2)

- **Additive — nothing breaks.** Same commands (`plan` / `create` / `update`),
  same config file (`.milestone-config/feeder.json`), same plan-file output.
- **Your plans get faster and cheaper to produce,** with the issues, the checks
  they pass, and the files written all unchanged.
- **`plan` now stops earlier** when a product decision you haven't made would
  block several issues — you'll see those flagged for your input up front rather
  than near the end of the run. The decision to make, and the report you get, are
  the same.
- **No config-key or schema changes** to `.milestone-config/feeder.json`. If you
  override the helper models yourself, note the new defaults: issue-author →
  Sonnet, architect → Opus.

## v0.3.2 — Actor-aware source guard

**Theme:** The feeder's source guard now tells *who* is editing apart — it still
stops the feeder from writing its own source, but lets a sibling builder
(milestone-driver's implementer) build the feeder without switching the guard off
wholesale.

### 🔧 Fixes

| Issue | PR | What |
|---|---|---|
| #63 Make the no-source-edit hook agent-type-aware | #72 | The `no-source-edit` PreToolUse gate is now **actor-aware**. It keeps blocking the feeder's own actors — the main thread and the feeder's own subagents (`architect` / `issue-author`, matched by their bare frontmatter `name`) — while allowing a positively-identified non-feeder subagent (e.g. milestone-driver's `implementer`) to edit source. The driver can now build the feeder's own `skills/` / `agents/` / `hooks/` with **no blanket `CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT=1` override**, closing the latent feeder + driver collision. The gate fails closed (the main thread, the feeder's own agents, and any ambiguous actor all block). A CI drift-guard in `scripts/validate-plugin-structure.py` keeps the hook's hardcoded agent set in sync with `agents/*.md`, and the bash + PowerShell scripts were brought to case-sensitive parity. |

### Consumer notes (upgrading from v0.3.1)

- **Additive — nothing breaks.** Same commands, same config.
- **If you run both milestone-feeder and milestone-driver:** the feeder's source
  guard no longer blocks the driver's `implementer` from building the feeder's own
  source, so you no longer need the blanket `CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT=1`
  override for that. The feeder's own subagents are still blocked from writing source.
- **The guard identifies actors by their bare agent `name`** (e.g. `architect`) —
  that is what a PreToolUse hook receives, not a plugin-namespaced id. The set of the
  feeder's own agent names is hardcoded inside the hooks (deliberately not in
  `feeder.json` — it's a security control); a CI check fails the build if a new agent
  is added without updating it.
- **No config-key or schema changes** to `.milestone-config/feeder.json`.

### ⚖️ Post-run audit trail

Judgment-call PRs for this release: none

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
| (guardrail) | The feeder stays **one brief → one milestone**, but stops being silent about a brief that's really several. When a brief reads as distinct phased deliverables / release boundaries, the architect raises a `SCOPE_SPANS_MULTIPLE_MILESTONES` signal with a proposed split (the candidate milestones and which issues fall under each). `plan` still writes a **deployable single-milestone plan** but **prominently flags** *"this looks like ~N milestones"* and shows the split, surfaced up front alongside the versioning step. Never a hard block, never a silent giant milestone — the user decides whether to deploy the one milestone or split the brief and re-run. Full `brief → N-milestones` decomposition is deferred to a future release. |

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
