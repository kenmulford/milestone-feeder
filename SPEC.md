# milestone-feeder: as-built spec

A Claude Code plugin that turns a feature brief into a **GitHub milestone + small, well-formed issues** that `milestone-driver` can build with no human clarification. The direct predecessor of the driver.

Sibling of `milestone-driver`, same design DNA (see the suite plan: [`../dev-tools/SUITE-PLAN.md`](../dev-tools/SUITE-PLAN.md) §1). Separate plugin, separate config. Status: **as-built spec**. The live surface is verbs `plan` / `create` / `update` / `setup`, no flags, plan-file-as-contract, with **user-owned, versioned milestone identity** (the semver lives in the milestone title), **`update` retargeting by deploy receipt + bounded rename-in-place**, and the **whole-app roadmap**: an oversized brief is carved into a confirmed, sequenced set of milestones, planned and deployed in build order, with the v0.3.1 multi-milestone advisory now its **trigger** (§3.1). `.claude-plugin/plugin.json` is the single source of truth for the plugin version.

Decisions already locked: name `milestone-feeder`; config at `.milestone-config/feeder.json`; separate plugin in its own repo (suite/marketplace linkage deferred). Decisions taken as sensible defaults below are marked **Decision (default)**; veto any.

---

## 1. Purpose & scope

One job: **turn a brief into a milestone of small, well-formed issues.** Input a brief; output a milestone whose issues each pass the driver's triage clean (`GAPS: none`).

Refuses, on purpose: writing code, opening PRs, touching branches, and **inventing product decisions** (what to build / user-facing behavior with no conventional default). It will make *implementation and design* decisions when the project docs or a repo convention supplies the answer; it will not make *product* calls: a decision with no conventional default it **flags for your decision**, never guesses.

Success criterion is testable: everything it emits is drafted to pass the same triage that gates the driver. The feeder targets the driver's triage bar as its quality bar (§5), so its quality bar *is* the driver's entry gate, no second, drifting definition of "well-formed", but it does not run that gate itself; the driver's triage is where it is enforced.

---

## 2. Pipeline position

```
feature brief (file / inline / GitHub epic issue)
        │   reads project docs (.project/) + .milestone-config/driver.json (shared keys)
        ▼
   ┌───────────────┐   milestone + issues    ┌──────────────────┐
   │ milestone-feeder │ ──────────────────────▶ │ milestone-driver │ ──▶ merged PRs
   └───────────────┘  (pass triage clean)     └──────────────────┘
        │
        └── flags PRODUCT gaps for your decision → "needs product input" report (never invents scope)
```

The grounding line: `plan` reads the project's standing docs under `projectDocs` (default `.project/`) and resolves the shared keys (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`) from the driver config, never duplicated in `feeder.json`.

---

## 3. Plugin contents

| Component | Path | Trigger | Purpose |
|---|---|---|---|
| `plan` skill | `skills/plan/SKILL.md` | `/milestone-feeder:plan <brief>` | Compiles a reviewable **plan file**: brief → milestone + small, well-formed candidate issues, drafted to pass the driver's triage clean. **Read-only on GitHub** (writes only local scratch). |
| `create` skill | `skills/create/SKILL.md` | `/milestone-feeder:create <brief>` | Deploys the approved plan file to GitHub: labels + milestone + issues + build order. Read-the-plan, **faithful** (trusts the recorded plan; regenerates/re-checks nothing). |
| `update` skill | `skills/update/SKILL.md` | `/milestone-feeder:update <brief>` | Reconciles a refreshed plan onto an existing milestone: safe, **never-close**, idempotent. |
| `setup` skill | `skills/setup/SKILL.md` | `/milestone-feeder:setup` (or auto by `plan`) | Bootstraps `.milestone-config/feeder.json`; aligns the issue-label taxonomy with the driver's. Mirrors `milestone-driver:setup`. |
| `build-roadmap` skill | `skills/build-roadmap/SKILL.md` | **internal**, invoked by `plan` (Step 3.6) on an oversized whole-app brief; never a user command | Turns one oversized brief into a confirmed, sequenced roadmap of milestones: dispatches `roadmap-splitter` once, surfaces the split for the user to confirm / merge / split / reorder / reject, and on confirmation writes a roadmap manifest to `.milestone-feeder/roadmap-<slug>.md`. **Read-only on GitHub** (writes one local scratch manifest). See §3.1. |
| `architect` agent | `agents/architect.md` (id `milestone-feeder:architect`) | dispatched by `plan`, **once** per run | The architect lens: brief + project docs + repo → candidate issues + dependency graph + build order (Wave order), one heavy reasoning step. Raises `SCOPE_SPANS_MULTIPLE_MILESTONES` (triggers the roadmap route); consults the implied-surfaces reference for `disposition: implied` candidates; when the project states a layering convention, assigns each candidate's architectural `layer`; and resolves each directive that binds two or more candidates once, as an `INVARIANTS` entry the issue-authors transcribe rather than re-derive (§3.1). |
| `issue-author` agent | `agents/issue-author.md` (id `milestone-feeder:issue-author`) | dispatched by `plan`, once **per candidate** | Per-issue spec authoring to the §4 output contract. Keeps each authoring ask small, the breakdown-for-quality principle applied to writing, not just building. |
| `roadmap-splitter` agent | `agents/roadmap-splitter.md` (id `milestone-feeder:roadmap-splitter`) | dispatched by `build-roadmap`, **once** per run | The roadmap lens: an oversized whole-app brief + project docs → a strict, build-ordered partition into named milestones (the `ROADMAP` block). Read-only; supersedes the architect's passive multi-milestone advisory with a real, ordered split. |
| `implied-surfaces` reference | `docs/implied-surfaces.md` | consulted by `architect` during breakdown | The stack-agnostic implied-surfaces **reasoning reference**: standard companion surfaces a capability or new entity implies, framed as a reviewable **floor**, never a scope-emitting catalog. Defines the optional project-local overlay (`.milestone-config/implied-surfaces.md`, additive-merge). PR-able. See §3.1. |
| Manifest + registration | `.claude-plugin/plugin.json`, `hooks/hooks.json` | n/a | Plugin metadata + hook registration. |
| Hook: `no-source-edit` | `hooks/` | PreToolUse (`Write`/`Edit`/`MultiEdit`/`NotebookEdit`) | Deny edits to `sourceGlobs`. The feeder reads code, never writes it. The only mechanical gate it needs (it authors no code and opens no PRs, so the driver's other gates don't apply). |

**Targets the driver's triage, does not run it.** The feeder authors every issue to the same five criteria `milestone-driver`'s `triage-reviewer` / `design-reviewer` check (§4), so its quality bar *is* the driver's entry gate: one shared definition of "well-formed." The feeder runs **no** reviewer of its own: the driver's triage is the single automated gate, run once after `create`, and the human reviews the plan file before `create` (§5).

---

## 3.1 The plan-file contract: the load-bearing build artifact

The plan file is the **interface** between `plan` (writes it) and `create` / `update` (read it, regenerate nothing): **the plan file is the spec; GitHub is the deployment.**

`plan` writes it to a gitignored per-run scratch path, by a **deterministic slug** of the milestone goal, so `create` / `update` resolve the same path from the same brief:

```
.milestone-feeder/plan-<slug>.md
```

Derive `<slug>`: lowercase the one-line milestone goal, replace non-alphanumeric runs with a single hyphen, strip leading/trailing hyphens, and cap the length. A changed brief derives a different slug, the staleness signal `create` / `update` re-plan on.

### Fields a consumer parses (the contract)

The plan file MUST carry, unambiguously, every field below:

| Field | Why `create` / `update` need it |
|---|---|
| **Milestone title (exact)** + one-line goal | The identity field: `create` / `update` resolve the milestone by this exact title (create-or-adopt). Carries the semver; no separate version field. Distinct from the one-line goal, which is descriptive only. |
| **Milestone number (GitHub):** `<n>`, the deploy receipt | The stable handle for `update`: `create` writes it post-deploy, `plan` preserves it on re-plan, `update` resolves and renames by it. Additive: a plan file lacking it still parses. |
| **Version provenance** (one line: `explicit` \| `declaration` \| `inferred from <tag/milestone>` \| `prompted`) | Records which ladder rung resolved the title (§7) so the surfaced default is legible: the user can trust or correct it. |
| **Multi-milestone advisory**, the `SCOPE_SPANS_MULTIPLE_MILESTONES` flag + proposed split, when raised | Surfaces the guardrail when a brief reads as several milestones but the roadmap route wasn't taken; doesn't change what gets deployed. Superseded by the confirmed roadmap (below) when that route is taken. |
| **Milestone description** (Wave / build order, local slugs `#A`/`#B`) | The wave-encoded description to PATCH onto the milestone after issue numbers exist. |
| **Per surviving issue**: slug, title, the full §4 body verbatim, labels, surface/risk | The issues to create / patch, verbatim, no regeneration. |
| **Parked issues**: slug, title, kind (`product-gap`) | Marked, never created. Routed to the needs-input report. |
| **Dropped issues**: slug, title, the parked dependency that dropped them | Marked, never created (a dependent of a parked issue can't build). |
| **Source brief reference**: `inline` \| `file:<path>` \| `epic #<n>` | Drives report routing and the brief↔plan match. An `epic #<n>` reference routes the needs-input report to an epic comment. |

### The slug→`#n` rewrite happens at write time

Issue numbers don't exist until creation, so the plan file carries **local slugs** (`#A`/`#B`) throughout; the two-pass slug→`#n` rewrite happens when `create` / `update` write to GitHub, once the issues exist. `plan` itself does no rewrite. Issue bodies, labels, and waves are read from the plan file, not regenerated.

### v0.3.1: user-owned versioned identity, `update` retargeting, the multi-milestone guardrail

v0.3.1 is additive: no command or config breaks, the new plan-file fields degrade gracefully (a v0.3.0 plan file lacking them still parses), and the change is in where a milestone's identity comes from, not in the `plan → create → update` pipeline. Three behaviors:

> **Discovery / migration-path principle (normative).** Every new feature, config key, or behavior change ships an existing-user **discovery / migration path** (a one-time notice, a setup re-run prompt, or a documented upgrade note) so an existing user *finds out* about it, not only that their old config keeps working. Non-breaking is not sufficient: additive / degrades-gracefully keeps old config *working*; this principle makes sure the user *discovers* the change. Canonical implementation: the driver's one-time-notice pattern (`milestone-driver/skills/solve-milestone/SKILL.md` steps 1.2/2.1); the feeder applies it in `plan` Step 0 (the legacy-blanket notice and the un-bootstrapped grounding-is-weak nudge). The principle is **normative** here and a §4 issue-authoring quality bar (the Completeness criterion) the feeder drafts every issue to satisfy. Enforcement is the driver's triage (§5), which needs a companion `triage-reviewer` criterion; that cross-repo change is out of scope here (milestone-driver issue #224).

- **User-owned, versioned milestone identity.** The milestone title is a user-owned field carrying the semver (e.g. `myapp v1.2.0`); there is no separate version field, the driver parses it from the title. The user can state the title up front (inline, or as a `Milestone: <name> vX.Y.Z` line in the brief); otherwise `plan` resolves a default by a layered ladder: the project's `versioning` declaration (§7), then inference from the highest semver among existing milestone titles or the latest `vX.Y.Z` git tag, then a one-time prompt only when nothing is inferable. The resolved title and its version provenance are surfaced in the plan file for confirm/override before `create`. A `"none"` declaration means no version and no prompt.
- **`update` retargeting + bounded rename-in-place.** Because identity is now the explicit title, `update` resolves the source plan by the brief slug but the target milestone by the identity, so a revised plan in a new brief file reconciles onto its existing milestone. To survive a title change, `create` writes the GitHub milestone number back into the plan file as a deploy receipt (`Milestone number (GitHub): <n>`); `update` resolves by that number first, falling back to title-match when absent, and when it resolved by number and the plan's title differs, it PATCHes the new title, the single bounded way `update` mutates a milestone's identity. `plan` carries the receipt forward on re-plan so the handle isn't stranded.
- **The multi-milestone guardrail (advisory → roadmap trigger).** When a brief reads as distinct phased deliverables or release boundaries, the architect raises `SCOPE_SPANS_MULTIPLE_MILESTONES` with a proposed split. The signal now **triggers** a real `brief → N milestones` split (below, "The roadmap"): `plan`'s front-door routes the brief into `build-roadmap`, which carves it into a confirmed, sequenced set of milestones and plans them all. The passive *"this looks like ~N milestones"* advisory remains as the backstop when that route is declined or degrades. Never a hard block, never a silent giant milestone: the user always confirms.

### The roadmap: an oversized brief → a confirmed, sequenced set of milestones

The feeder is no longer one brief → one milestone for an oversized whole-app brief. The single-milestone pipeline (Steps 1–7, §6) is a named, callable inner routine that `plan` wraps in a conditional outer loop: the default single-brief path invokes it exactly once, and an oversized brief routes through `build-roadmap` and invokes it once per milestone the roadmap names, in build order. Milestone identity, the version ladder, and the plan file stay the routine's; only run count and brief slice change.

The architect's `SCOPE_SPANS_MULTIPLE_MILESTONES` signal is the sole arbiter of "oversized": signal `none` runs the single-milestone routine once; signal raised routes the brief into `build-roadmap` instead of passively flagging it.

**The `build-roadmap` routine** (`skills/build-roadmap/SKILL.md`), an internal skill invoked by `plan`, never a user command:

1. **Split.** Dispatch `roadmap-splitter` once. It returns a `ROADMAP` block: a strict, build-ordered partition of the brief into named milestones (every part in exactly one milestone, none dropped or duplicated; positions `1..N`).
2. **One confirmation checkpoint.** Surface the proposed split for the user to confirm / merge / split / reorder / reject, a single up-front sign-off before anything is written (`.project/design-philosophy.md#One-way doors`). A user edit is re-verified as a strict partition; on reject, nothing is written.
3. **Manifest.** On confirmation, write a roadmap manifest (`.milestone-feeder/roadmap-<slug>.md`): the cross-milestone build artifact recording which milestones to plan, in what order, plus the full original brief. It carries no per-milestone §4 issue bodies; those live in each milestone's own `plan-<slug>.md`.

Each milestone's version and exact title resolve once, on the main thread, before the per-milestone fan-out: the version ladder's one interactive rung can never run inside a background subagent. `create` deploys every roadmap milestone in build order too (§6, Step 1R).

**Discovery path (§3.1 principle).** A whole-app brief that used to get only the passive *"~N milestones"* advisory now routes into the roadmap flow, so `plan` Step 0 prints a one-time, per-clone, marker-gated notice announcing the new routing. No new config key: the roadmap reuses the existing `projectDocs` grounding. A brief the architect reads as one coherent release, or a user who declines the split, still falls straight back to today's single-milestone plan.

### Implied companion surfaces: capability-aware completeness

A brief names a capability ("add email", "user management", "sync") or introduces a new entity, and that name quietly commits to a standard set of companion surfaces (screens, endpoints, jobs, settings) the brief never spells out. Left unaddressed, those companions surface one-at-a-time mid-build as unplanned rework. So during breakdown the `architect` consults a curated, stack-agnostic implied-surfaces reference (`docs/implied-surfaces.md`), a reasoning prompt / floor, not a scope-emitting catalog, and for each named capability or new entity the brief invokes, considers the companions it implies, sorting each with the same grounded-vs-product-gap judgment it already applies (`agents/architect.md` clause 8; the rigor gate's recognized dispositions):

- **Conventional companion** (a standard surface with a conventional default, e.g. email → a delivery-failure log, a Users entity → reset-password) → proposed as a default-in candidate for review, riding `CANDIDATES` with the architect's optional `disposition: implied` field. It is proposed for review, never committed scope: it lands in a plan the human approves before any issue exists, fully reversible.
- **Genuine product-call** (no conventional default, e.g. a suppression / unsubscribe policy) → parked via `PRODUCT_GAPS`, never silently pre-included. The never-invent floor (§2, the park boundary) holds for implied surfaces too: a companion that can be neither grounded in a default nor tied to a real product decision is never emitted as `implied`.

The reference's three triggers: the new-entity baseline (list / detail / create / edit / delete / states / permissions / audit) is considered per entity; named capabilities are concept-matched, not keyword-matched ("let admins message members" is the email capability without the word "email"); cross-cutting concerns (search / filter / sort, background jobs) are considered once at the app level. States (empty / loading / error / unauthorized) land as acceptance criteria inside their own screen issue (`agents/issue-author.md` Completeness), never as standalone issues. Fanned-out surfaces reuse the architect's existing ~1-PR sizing.

**The disposition threads architect → plan → issue-author → plan file.** `plan` captures the optional `disposition` (`grounded | implied`, default/omitted = `grounded`) verbatim alongside each candidate (Step 3), threads it into the issue-author brief (Step 4), and at Step 7 renders each `implied` candidate distinctly, carrying the `[implied — review / trim / augment]` marker on its issue heading. Only when the plan carries at least one implied candidate, `plan` fires a structural anti-fixation prompt at the same confirm/override moment the user already sees the milestone identity, the verbatim `this is a starting set for YOUR app — what's missing?`, advisory and non-blocking, so the user reviews / trims / augments before `create`. When no candidate is `implied`, nothing here surfaces. The field is additive: every downstream consumer reads `tag` / `title` / `surface` / `risk` / `sketch` and is unaffected by its presence.

**The project-local overlay (additive).** The bundled reference is universal, so a project extends it with an optional overlay at the fixed path `.milestone-config/implied-surfaces.md`, discovered by that path, not a `feeder.json` key (`docs/profile-schema.md`). `plan` Step 0 resolves and merges it into the bundled reference additively: an overlay can add a capability and extend an existing one, but never remove a surface the global reference defines (per-run trimming is the plan review's job). An absent overlay (the common case) uses the bundled reference unchanged, no error; a malformed overlay is skipped best-effort and never breaks a run.

**Discovery path (§3.1 principle).** `setup` Phase 2 mentions the overlay informationally (discovered by a fixed path, not a key), and `plan` / `update` Step 0 print a shared one-time, per-clone notice naming it and explaining its additive merge. No schema change: the overlay is a fixed-path file, not a key. A brief invoking no capability and introducing no new entity breaks down exactly as before; the reference is a floor, not a completeness guarantee, so the anti-fixation prompt still asks for what a curated list can't know.

### Layer-aware breakdown: architecture-keyed ordering

When the project's standing docs state a stack + layering convention, the `architect` assigns each candidate its architectural layer and derives the issue order from the layer dependency, not only from ad-hoc type references (`agents/architect.md` clause 9). The architect consults the stated architecture (primarily `.project/design-philosophy.md#Layering & boundaries` for the layers and their allowed dependency directions, with `.project/conventions.md#File & folder layout` for where each layer's files live and `.project/library-manifest.md#Runtime & frameworks` for the stack), places each CRUD / helper task in the layer the convention dictates, and records the result:

- **Assignment.** Each candidate carries an optional `layer` field naming the architectural layer the convention places it in: a CRUD / persistence task in the data layer, a formatting helper in the utility layer, a view-model in the view-model layer.
- **Ordering.** A layer that others depend on precedes them: the architect emits a dependency edge keyed by layer (`#B depends_on #A - layer: <B-layer> depends on <A-layer> per <citation>`), consumed by the same Waves / topological sort the dependency graph already uses (§4, Milestone description template). A concrete artifact `depends_on` edge is authoritative; a layer edge only orders candidates that are otherwise independent. The two compose, and a layer edge never violates a concrete edge.
- **Grounded, never invented.** Each layer assignment and layer edge cites the project's stated architecture (`.project/<doc>#<section>` or a sibling `file:line`), the same rigor gate every design call clears. A layer that cannot be grounded is not assigned.
- A project whose `.project` states no layering convention (the section absent / `[TBD]`, or an unlayered stack) produces the dependency-only breakdown it does today: no `layer` field, no layer edge. No error, no fabricated layering (`.project/design-philosophy.md#Error & failure philosophy`).

**The layer threads architect → plan → issue-author → issue.** `plan` captures the optional `layer` verbatim alongside each candidate (Step 3), threads it into the issue-author brief (Step 4), and the issue-author records it as a `Layer:` line in the issue's existing `## Design` block (§4), so the driver sees which layer the work sits in. A candidate with no assigned layer carries no `layer` field and no `Layer:` line. No new config key: the layer pass reuses the existing `projectDocs` grounding, so nothing in `feeder.json` / `setup` changes; the discovery path is this spec plus the architect / plan / issue-author contracts.

### Cross-candidate invariants: resolve once, transcribe verbatim

A directive that must hold across two or more candidates (a page size, a sort order, a date format, an ID or naming rule) is resolved ONCE during breakdown and returned in `INVARIANTS`, rather than left for each candidate's issue-author to re-derive independently (`agents/architect.md` clause 10). The architect records each one as an entry carrying `key` (a short stable name), `value` (the directive verbatim, literal values intact), `citation` (its grounding), and `applies_to` (the two or more candidate tags it binds):

- **Scope.** `applies_to` draws its tags from `CANDIDATES` as returned, the full set, never the reduced set the Step 3.5 pre-park and the Step 5 drop pass leave. An entry naming a candidate parked later still binds the surviving candidates it names.
- **Two or more, never one.** A directive binding exactly one candidate stays that candidate's own design decision, grounded in its sketch under clause 2.
- **Grounded, never invented.** Each entry cites the recorded brief line, the project docs, or an established repo convention. A directive that cannot be grounded falls back to a clause 2 call on each candidate it would have bound, resolved or parked to `PRODUCT_GAPS`.
- **Still recorded per candidate.** Every tag in `applies_to` still records the directive in its own sketch, and the entry pins the one resolution they share. The issue-author records it once, in the `value`'s wording.
- **`none` is a value, not an omission.** A breakdown in which no directive binds two or more candidates returns the literal `none`. `INVARIANTS:` is one of the return block's always-required top-level keys (`agents/architect.md` → "Structured return block"); the roadmap path's per-dispatch verify enumerates it among the keys it checks (`docs/roadmap-fan-out.md` §3.7.e).

**The invariants thread architect → plan → issue-author → issue.** `plan` captures each entry's `key` / `value` / `citation` / `applies_to` verbatim (Step 3), inventing none and rewording none, and at Step 4 hands each candidate the entries whose `applies_to` names its tag, on the same brief list that already carries `disposition` and `layer`. The hand-in is explicitly empty rather than absent: a candidate no entry names, and every candidate when `INVARIANTS` is `none`, is handed an empty list and transcribes nothing. The issue-author transcribes each handed-in `value` into the issue body verbatim, carrying its `citation` as the grounding ref and never re-deriving or overriding it; `applies_to` is scoping context only and never becomes a `Depends on` line. A `STATUS: AUTHORED` return that dropped or reworded a handed-in `value`, so that it no longer appears in the `ISSUE_BODY` as a literal substring, is malformed, caught by `plan`'s existing per-dispatch verify pass, whose one bounded retry feeds back every failing entry's `key` and its exact `value`. A second miss takes the park path any other malformed return takes: the candidate and every candidate transitively depending on it leave the milestone at the Step 5 drop pass. No new config key: the invariants pass reuses the brief and `projectDocs` grounding the architect already reads. The discovery path is this spec plus the architect / plan / issue-author contracts.

### The `create` → driver handoff (build kickoff)

When `create` finishes building a milestone and its issues, it can hand the milestone straight to `milestone-driver` to start building, closing the feeder→driver seam, instead of ending the run and leaving the user to invoke the driver. It is build-kickoff only: it invokes `/milestone-driver:solve-milestone "<exact milestone title>"` (the title `create` deployed, carrying the user-owned semver), and never authors code, merges, or crosses the release boundary itself. Governed by the own-key `autoHandoff` (§7): `"prompt"` (default, ask), `"auto"` (kick off immediately), or `"off"` (never); an unrecognized value is treated as `"prompt"`.

**Three gates, all must hold to offer the handoff:**

1. **Clean run only, no gaps/parks.** The run produced no product gap and parked / dropped nothing (the plan file's `## Needs human input` pointer is "none", the same signal `create` pass (e) reads). A gapped run surfaces its gaps as today and offers no handoff; the human stays in the loop on any run with known gaps.
2. **Driver installed, else silent skip.** `create` detects whether `/milestone-driver:solve-milestone` resolves in this session; if not, it silently skips, no prompt, no error, exactly as the optional `milestone-driver` soft-dependency degrades silently elsewhere (`docs/consumer-setup.md` §1).
3. **Never crosses `develop → main`.** `solve-milestone` merges only to the integration branch; release (`develop → main`), closing the milestone object, and deploy stay manual and human-only (`milestone-driver/skills/solve-milestone/SKILL.md` "Bounded blast radius"). The handoff never auto-merges to a protected branch and never removes the release gate, preserving the autonomy boundary (`.project/design-philosophy.md#One-way doors`).

**Discovery path (§3.1 principle).** `autoHandoff`'s default (`"prompt"`) is new behavior for existing users, so `setup` Phase 2 presents it (plain-language label + skip-consequence) and `docs/profile-schema.md` documents the key (table row + per-key note), with the default visible. A user who wants today's no-handoff behavior sets `"off"`.

---

## 4. Output contract: the interface to the driver

Maps 1:1 to the five criteria the driver's triage checks. The issue-author guarantees each.

| Triage criterion | What the feeder guarantees |
|---|---|
| Consistency | Each issue's recorded design is internally non-contradictory. |
| Buildability | Every decision the criteria require is recorded, or resolvable by a *stated* repo convention, nothing left for the implementer to invent. |
| Completeness | Acceptance criteria enumerate states, branches, and error / empty / disabled paths, not just the happy path, and, when the change affects existing users or their config, an existing-user discovery path (the normative principle, §3.1): a one-time notice, a setup re-run prompt, or a documented upgrade note. Scoped: a change touching neither existing users nor existing config (pure greenfield) carries no discovery-path requirement. The driver's one-time-notice pattern (`milestone-driver/skills/solve-milestone/SKILL.md`, steps 2.1 / 1.2) is the canonical example. |
| Dependencies | Hard dependencies are declared as edges, and the milestone description encodes the Wave order (the source triage reads via `gh api .../milestones .description`). |
| UI flag | Each issue is classified UI vs logic; UI issues carry the spec the design-reviewer needs (states, affordances, accessibility, the existing pattern to mirror). |

### Issue body template

```markdown
## Summary

<2-3 plain sentences: what changes and why, in product terms>

## Acceptance criteria

- [ ] <happy path, observable>
- [ ] <empty state>
- [ ] <error / failure path>
- [ ] <disabled / edge state>

## Non-goals

- <a scope boundary the criteria deliberately do not cross. OPTIONAL: omit the heading too when there is none>

## Design (recorded, consistent)

<the decisions an implementer would otherwise have to invent, grounded in your
project docs or a cited sibling pattern. No contradictions. Cite as path (anchor)
or file:line per milestone-driver/skills/citation-format.md, one form per
reference and never both, and use the heading ref where the cited region is a heading.>

- Convention followed: <conventions.md ref, or the path (anchor) / file:line of the sibling pattern>
- Layer: <the architectural layer the architect assigned, citing the stated architecture that places it (.project/<doc>#<section>, or a sibling ref). OPTIONAL: omit when the candidate carried no `layer` field>
- Config pointers: <the `.project` config the driver reads at BUILD time, keyed to what the issue touches: styling → `.project/tokens.json` + `.project/design-system.md#<section>`; deployment/env → `.project/environment.md`. PATH only, never resolved values (no hex, no parsed tokens, no pre-solved render). OPTIONAL: omit when the issue touches none or the doc is absent>

## Dependencies

- Depends on #<n> - <one-line reason / the exact reference>
```

**Section order is locked.** `## Non-goals` sits directly after `## Acceptance criteria`, and is omitted entirely when the issue records no scope boundary.

Labels applied by `create`: a UI/logic label, and `risk:light` / `risk:heavy` when the feeder is confident, aligned with the driver's existing taxonomy so triage and solve read them natively. The four-label set (`ui`, `logic`, `risk:light`, `risk:heavy`) is provisioned by `setup` and ensured idempotently by `create`.

**Config pointers.** The `## Design` block points each issue at the `.project` config the driver reads at build time (mechanics in the template above); rendering and resolving values is the driver's job, not the feeder's. Reuses `projectDocs`: no new config key.

**Consumer template adopted, house style as the fallback.** The template above is the built-in default, not the only structure. When the consumer repo keeps its own issue convention, `plan` Step 0 resolves it once, repo-wide, and hands it into every issue-author brief, so agent-filed and human-filed issues read and triage the same way. Selection is deterministic, classification-free, and degrades to the built-in default on any absence or parse failure, no error, no park (`docs/step-0-grounding.md` §5, the authoritative rung order). Adopting a consumer template changes the section headers only: the five §4 criteria above still bind, including the Completeness row's discovery-path requirement. The feeder adds no config key of its own: it reads a path GitHub already defines and `agentIssueTemplate`, a key `milestone-bootstrapper` provisions ([#156](https://github.com/kenmulford/milestone-bootstrapper/issues/156)) down the existing driver-config chain. That read is not a fourth consumer-facing shared key; the canonical set stays exactly three (§7).

### Milestone description template (encodes the Wave order)

```markdown
<what this milestone delivers, and its scope boundary, both facts, at whatever length states them>

## Waves
- Wave 1 (parallel): #A, #B, #C
- Wave 2: #D (depends on #A, #B)
- Wave 3: #E (depends on #D)
```

Human-readable, and the exact ordering source `solve-milestone` and triage consume. In the plan file the identifiers are local slugs; `create` rewrites them to real GitHub numbers once the issues exist.

---

## 5. The quality bar: the driver's triage (targeted, not run)

The feeder's quality bar *is* the driver's entry gate: every issue it drafts is authored to pass the driver's `triage-reviewer` (and `design-reviewer` for UI issues) clean (`GAPS: none`), one shared definition of "well-formed," never a second drifting copy. The feeder runs no reviewer gate of its own: it drafts issues that target that bar, and the driver's own triage is the single automated entry gate, run once after `create` when the driver picks the milestone up. Between them stands the human: `plan` writes a reviewable plan file, and the human reviews it before `create` deploys.

| Concern in the issue | How the feeder targets the bar |
|---|---|
| Design / implementation decision with a conventional default | Recorded and cited (`.project/<doc>.md#<section>` or a sibling `file:line`), so the driver's Buildability check clears. |
| Genuine **product** gap (no conventional default) | Flagged for your decision in the "needs product input" report; never invented (§2 park boundary). |
| UI issue | Carries the states, affordances, accessibility, and existing pattern to mirror that the driver's `design-reviewer` checks. |

The `reviewer` own-key and its `"milestone-driver" | "internal" | false` backends are retired: the feeder no longer selects or runs a reviewer backend, so there is no in-feeder gate to configure. An existing profile that still carries a `reviewer` key is ignored gracefully (unknown key → no error).

---

## 6. Procedure (the `plan` skill)

`plan` runs the full pipeline (Steps 0–5) and stops at a reviewable plan file (Step 7). It is read-only on GitHub: its entire output is local scratch files.

| Step | Action |
|---|---|
| 0 | Read `.milestone-config/feeder.json` (absent → `setup`); read the project docs (`projectDocs`, default `.project/`, best-effort); resolve the shared keys (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`) from the driver config. |
| 1 | Ingest the brief (file path, inline text, or a GitHub epic issue); normalize freeform input internally first. |
| 2 | **Product-gap check** (the flag boundary): separate product decisions (no conventional default) from design/implementation decisions (resolvable from project docs/convention). Product gaps are recorded, not guessed. |
| 3 | Dispatch the **`architect`** agent **once**: candidate issue set (small, independently-buildable, ~one PR each) + dependency edges + Wave order. |
| 4 | Dispatch the **`issue-author`** agent **per candidate** (parallelizable) → full spec to §4. |
| 5 | Resolve the **milestone identity**, the user-owned exact title carrying the semver, by the v0.3.1 layered ladder (explicit → declaration → inference → prompt; §3.1), with its version provenance; **drop parked issues + their dependents**; assemble the dependency graph; render the milestone description (§4) with local slugs. |
| 7 | **Write the plan file** (`.milestone-feeder/plan-<slug>.md`), the build artifact (§3.1), plus the needs-input report when anything was parked; **surface the resolved identity (title + provenance) for confirm/override**, and the multi-milestone advisory **when raised**, before `create`; **carry forward** an existing deploy receipt on re-plan. No GitHub writes. |

**The roadmap path wraps this routine (§3.1).** When the architect raises `SCOPE_SPANS_MULTIPLE_MILESTONES`, `plan`'s front-door (Step 3.6) routes the brief into `build-roadmap` (split → confirm → manifest), then (Step 3.7) runs Steps 1–7 once per milestone, in build order, fanning out in parallel. Steps 3.6/3.7 are outer, run-level orchestration; a dispatched per-milestone routine never re-enters them, so the fan-out cannot recurse.

**Then `create` deploys the plan file** (faithful): ensure labels → create-or-adopt the milestone by exact title → create the surviving issues + build the slug→`#n` map → second-pass slug→`#n` rewrite (issue bodies + the milestone description) → file the needs-input report (epic comment when the brief was an epic; else local file). After the milestone is resolved, `create` writes the deploy receipt (`Milestone number (GitHub): <n>`) back into the plan file, the stable handle `update` later resolves by (a back-write failure is a reported notice, never a blocked deploy). On a roadmap run (`create` Step 1R) it loops this same per-plan deploy over the manifest's milestones in build order, recording each one's `build order: milestone X of N` line; the single-plan path is the unchanged N=1 case.

**And `update` reconciles it** onto an existing milestone (create-or-patch / add-edge-and-re-render / flag-never-close / no-op): it resolves the milestone by the deploy-receipt number first (falling back to exact-title when absent) and, when resolved by number with a changed plan title, renames the milestone in place (a single bounded title PATCH); then creates any plan issue missing on GitHub, patches any drifted body (showing the diff first), adds any new dependency edge and re-renders the build order, and flags, never closes, any live issue the plan no longer carries. A wholesale new brief with a new title and no receipt → no title match → error-and-stop directing you to `create`, with the one-line `gh` rename command for the rare true-rename case. A fully-synced milestone is a true no-op.

There are no flags anywhere: `plan` previews (writes the plan file), `create` / `update` write, each *is* its own verb.

---

## 7. Config schema: `.milestone-config/feeder.json`

Thin and consumer-driven, same discipline as the driver: new keys only when a real consumer needs them. The file name stays `feeder.json` (pairs with `driver.json`, matches the plugin name, avoids hook-script churn); the keys inside, the part a user reads and edits, are humanized.

| Key | Type | Default | Purpose |
|---|---|---|---|
| `projectDocs` | string | `.project/` | Where the project's standing docs live. |
| `autoHandoff` | `"prompt" \| "auto" \| "off"` | `"prompt"` | After `create` builds a milestone, whether the feeder offers to hand it to `milestone-driver` to start building (`"prompt"` = ask; `"auto"` = start immediately; `"off"` = never). Unrecognized → treated as `"prompt"`. See §3 (the create→driver handoff). |
| `versioning` | `"semver" \| "none"` | *(none)*, absent is a distinct "infer-or-ask" state | Whether this project is semver-versioned; drives milestone-version resolution at plan time (three-way: `"semver"` = version every milestone, `"none"` = never add a version or prompt, **absent** = infer from repo signals else prompt). |
| `issueSize` | string | *(none)* | Optional natural-language sizing rule (e.g. "≤1 PR, ≤1 new screen"). |
| `architectAgent` | string | `milestone-feeder:architect` | Override the breakdown (architect) agent. |
| `issueAuthorAgent` | string | `milestone-feeder:issue-author` | Override the authoring agent. |
| `sourceGlobs` | string[] | `["skills/**","agents/**","hooks/**"]` | **Self-protection only**: the paths the feeder's own `no-source-edit` hook guards in the feeder's *own* repo. Distinct from the consumer's shared `sourceGlobs`. |

Consumer-facing shared keys (`uiSurfaceGlobs`, `integrationBranch`, and the *consumer's* `sourceGlobs`) are read from the driver config, not duplicated: resolved `.milestone-config/driver.json` → root `milestone-driver.json`.

The `no-source-edit` hook resolves the paths to guard from `feeder.json` first, falling back to the resolved driver config (`.milestone-config/driver.json` → root `milestone-driver.json`), then fail-open if neither carries it.

### `.milestone-config/` migration note

Adopting `.milestone-config/` suite-wide means the driver resolves its profile from `.milestone-config/driver.json` first, falling back to the legacy root `milestone-driver.json` (backward compatible: existing repos keep working).

---

## 8. Modes & autonomy

Three intent-named verbs, **zero flags**. Each verb *is* the explanation of what it does.

| Verb | Trigger | Behavior |
|---|---|---|
| `plan` | `/milestone-feeder:plan <brief>` | Full procedure, stops at a reviewable plan file (read-only on GitHub). |
| `create` | `/milestone-feeder:create <brief>` | Deploys the approved plan file: labels + milestone + issues + build order. Faithful: trusts the recorded plan (regenerates/re-checks nothing); runs `plan` first if no plan file exists for the brief. |
| `update` | `/milestone-feeder:update <brief>` | Reconciles a refreshed plan onto the existing milestone. Never closes/deletes; idempotent; shows the diff before patching. |

Authoring autonomy boundary: makes design/implementation calls grounded in the project docs; flags product calls (no conventional default) for your decision in the "needs product input" report. Authors no code, opens no PRs, never touches branches.

---

## 9. Build order (dogfood it)

Build the feeder as its own milestone the driver can run, the as-built sequence:

1. **Agent + config rename**: `architect` agent; keys `projectDocs` / `issueSize` / `architectAgent`; `setup` updated (the spine, no behavior change).
2. **`plan` skill**: the plan file becomes the formalized contract (§3.1); drop the apply path.
3. **`create` skill**: read-the-plan deploy + run-`plan`-first fallback; inherits the §6 apply write sequence.
4. **`update` skill**: plan-driven reconcile; never-close, idempotent.
5. README / docs / metadata re-vocab to the new surface.
6. Harness migrate + re-run (the credibility scenarios, on the new verbs/keys).
7. Verify the old vocabulary is gone; bump to v0.3.0.

Steps 1–2 are the spine with no irreversible GitHub side effects, the safe first build target.

---

## 10. Resolved during build (was: open questions)

These were settled by the as-built skills:

- **Brief format.** Accepted freeform and normalized internally first into `{ goal, in-scope, out-of-scope, surfaces, epicIssueNumber? }` before anything downstream consumes it (`skills/plan/SKILL.md` Step 1).
- **Milestone ownership.** Create-or-adopt by exact title: `create` creates the milestone if no title match, adopts (and reopens if closed) an existing one, never deletes (`skills/create/SKILL.md` pass b). `update` adopts read-only and errors-and-stops if no milestone exists.
- **Where the "needs product input" report lives.** A local file (`.milestone-feeder/needs-product-input-<slug>.md`), or a comment on the epic issue when the brief was a GitHub epic. `plan` writes the report body; `create` / `update` route it by the recorded source-brief reference (`skills/create/SKILL.md` pass e).
