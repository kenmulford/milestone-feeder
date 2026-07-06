# Roadmap fan-out — per-milestone planning phases (3.7.a–3.7.g)

`plan`'s roadmap fan-out (`skills/plan/SKILL.md` Step 3.7) dispatches the single-milestone inner routine once per milestone a confirmed `build-roadmap` manifest names — but only when the front-door (`skills/plan/SKILL.md` Step 3.6) actually **routed** an oversized brief into `build-roadmap` and got back a confirmed manifest (`roadmapRouteTaken` = true). A plain single-milestone brief never reaches this file: Step 3.7 is skipped, and `plan` falls straight through to Step 4 on the whole brief.

This file is the canonical source for the fan-out's phase mechanics — phases 3.7.a through 3.7.g, run **in this order**. It is reference content relocated out of `skills/plan/SKILL.md` to keep that always-loaded file within the repo's own size standard (`.milestone-feeder/plan-progressive-disclosure-skill-trim.md:18`); nothing about what the fan-out does changes, only where its mechanics are recorded — mirrors the existing `docs/one-time-notices.md` relocation. The orchestration boundary itself (the "OUTER, run-level orchestration" statement, the `roadmapRouteTaken` gate, and the phase-ordering rule) stays inline at `skills/plan/SKILL.md` Step 3.7; this file holds only the phases' internal mechanics.

**Contents**

1. [3.7.a — Empty / single-milestone guard (first)](#37a--empty--single-milestone-guard-first)
2. [3.7.b — Probe FIRST: pin the dispatch topology (feasibility-verification-first)](#37b--probe-first-pin-the-dispatch-topology-feasibility-verification-first)
3. [3.7.c — Hoist version resolution to the main thread (before the fan-out dispatches)](#37c--hoist-version-resolution-to-the-main-thread-before-the-fan-out-dispatches)
4. [3.7.d — Pre-derive slugs + resolve collisions (deterministic)](#37d--pre-derive-slugs--resolve-collisions-deterministic)
5. [3.7.e — Dispatch the inner routine once per milestone (pinned topology, cap-4 rolling window)](#37e--dispatch-the-inner-routine-once-per-milestone-pinned-topology-cap-4-rolling-window)
6. [3.7.f — Record the cross-milestone build order as metadata](#37f--record-the-cross-milestone-build-order-as-metadata)
7. [3.7.g — Failed-milestone handling (continue the others) + surface the roster](#37g--failed-milestone-handling-continue-the-others--surface-the-roster)

## 3.7.a — Empty / single-milestone guard (first)

Branch on the count **N** of milestone entries in the confirmed manifest **before** the probe or any dispatch:

| N | Action |
|---|---|
| **0** | **No probe, no dispatch, no plan files.** Surface the empty manifest to the user (state it is empty) and **return control** — this is **NOT an error** (`.project/design-philosophy.md#Error & failure philosophy`). |
| **1** | **Degenerate the fan-out to a single inner-routine dispatch — no rolling window.** Still run the probe (3.7.b) and version resolution (3.7.c), then dispatch the inner routine **once**, producing **one** plan file. |
| **≥2** | The full fan-out (3.7.b → 3.7.f). |

(A confirmed manifest normally carries **N ≥ 2** — `build-roadmap` Step 2 routes <2 milestones to the single-milestone path with no manifest — but the guard handles N = 0/1 defensively, re-verified here, not assumed, mirroring `build-roadmap`'s own "re-verified here, not assumed" partition gate.)

## 3.7.b — Probe FIRST: pin the dispatch topology (feasibility-verification-first)

**Before planning ANY milestone**, run a single harness probe. Dispatch **one** background `Agent(run_in_background: true)` whose **sole** task is to attempt to dispatch a trivial sub-subagent **via the Agent tool** and report whether that **nested** dispatch succeeded. **Await** the probe, then **pin the run's dispatch topology** from its result:

| Probe result | Pinned topology |
|---|---|
| Nested dispatch **succeeded** | **Nested-supported** (preferred). |
| Nested dispatch **failed**, the probe errored, or it returned no usable result | **Flat-fallback.** |

**Nested sub-dispatch is NEVER relied on before the probe confirms it** — the documented async model is flat, one-level dispatch (`.project/environment.md#Async & messaging` — agents are dispatched as subagents within a `plan` run; it does **not** establish that a background subagent may itself dispatch subagents), so the default before the probe is **flat**, and **only a confirming probe licenses the nested topology** for this run. The probe runs **once per run** and pins the topology for **every** milestone dispatch in 3.7.e.

## 3.7.c — Hoist version resolution to the main thread (before the fan-out dispatches)

Resolve each milestone's **exact title** **on the MAIN THREAD, BEFORE** any dispatch — because a background subagent **cannot prompt**, so the version ladder's one interactive rung must never run inside a dispatch. For **each** milestone, run the **Step 5.1 version ladder** (`docs/version-ladder.md`) using **ONLY the non-interactive rungs 1–3** (explicit `milestoneLine` / `versioning` declaration / infer-and-**PROPOSE** from existing milestone titles or git tags — all read-only, none prompt; `docs/version-ladder.md#51--resolve-the-milestone-version--exact-title-the-version-ladder`).

- If a milestone would fall to **rung 4** (greenfield — nothing above resolved), fire the **rung-4 greenfield prompt ONCE, up front, on the main thread** — the run's **one sanctioned interactive moment**. Never inside a background subagent.
- Record each milestone's resolved **exact title** + its **true provenance** (`explicit | declaration | inferred from <…> | prompted`). **Pass each into that milestone's dispatch as the `preResolvedVersion` parameter** (3.7.e) — `{ title, provenance }`. The **Step 5.1 ADOPT branch** (`docs/version-ladder.md`) consumes it verbatim and runs **no** ladder rung and **no** prompt. **Use this dedicated parameter, NOT `milestoneLine`** — routing the title in via `milestoneLine` (rung 1) would mislabel every provenance as `explicit` and, when the version is empty/non-versioned, re-open the rung-4 prompt inside the background subagent. Each resolved title is **surfaced in that milestone's own plan file** (`skills/plan/SKILL.md` Step 7's `Milestone title (exact)` + `Version provenance`) **for confirm/override before `create`** — never silently invented (`.project/design-philosophy.md#One-way doors` — a one-way door is surfaced for sign-off, not silently finalized; `docs/specs/v0.3.1-driver-handoff.md` §2, §3, §6).

## 3.7.d — Pre-derive slugs + resolve collisions (deterministic)

For each milestone, derive its plan-file `<slug>` from its **goal** by the **same deterministic rule** the inner routine's `skills/plan/SKILL.md` Step 7 uses (`.project/conventions.md#Naming` — lowercase the one-line goal, collapse non-alphanumeric runs to single hyphens, trim, cap length). **Where two milestones derive the SAME `<slug>`**, append the milestone's **build-order index** for the colliding milestones — `plan-<slug>-m<index>.md`, where `<index>` is the manifest's `Build-order position`. The suffix is the position, so the disambiguation is **DETERMINISTIC**: re-planning the same roadmap resolves to the **same paths**, and **no plan file overwrites another** (acceptance criterion: slug-collision tiebreaker). **Pass each milestone its assigned (disambiguated) slug as the `assignedSlug` parameter** (3.7.e); `skills/plan/SKILL.md` **Step 7's ADOPT branch** writes that milestone's plan file to `.milestone-feeder/plan-<assignedSlug>.md`, so two colliding milestones never overwrite each other.

## 3.7.e — Dispatch the inner routine once per milestone (pinned topology, cap-4 rolling window)

**Reuse the `skills/plan/SKILL.md` Step-4 author fan-out's cap-4 rolling window** across the milestone-planning dispatches — the same window as `skills/plan/SKILL.md` Step 4 ("Step 4 — Dispatch issue-author per candidate"; mirrors the driver's worker fan-out, `milestone-driver` plugin `skills/solve-milestone/SKILL.md` Phase 1 step 2); M = 0 already returned at 3.7.a. **Await ALL dispatches** before 3.7.f (the barrier).

The pinned topology (3.7.b) selects **only the dispatch LEVEL** — both topologies yield **identical N plan files** and **the same build-order metadata**:

| Pinned topology | How the inner routine + its sub-dispatches run |
|---|---|
| **Nested-supported** | Dispatch the **#153 inner routine (Steps 1–7)** once per milestone, **EACH in its own background subagent that itself sub-dispatches** architect/issue-author. **Also cap the inner #153 `skills/plan/SKILL.md` Step-4 fan-out at 4** (total ≤16) so compound concurrency stays bounded. |
| **Flat-fallback** | The `plan` **MAIN THREAD** orchestrates each milestone's planning so the architect/issue-author sub-dispatches happen **at the main-thread level** — under the **same cap-4 rolling window** across milestones — with **NO subagent spawning sub-subagents**. |

Hand each milestone's dispatch the inner routine's **five contract parameters — three required + two optional** (`skills/plan/SKILL.md` "The single-milestone inner routine (Steps 1–7) — callable contract"):

| Parameter | What the fan-out passes |
|---|---|
| **`briefSlice`** | This milestone's **brief slice from the manifest**, normalized to `skills/plan/SKILL.md` Step-1 shape. |
| **`resolved`** | The **once-per-run** config + shared-keys bundle + grounding digest **`skills/plan/SKILL.md` Step 0 produced**, passed through **verbatim** — **re-resolve NOTHING** (the resolve-once boundary). Every milestone gets the **same** `resolved` bundle. |
| **`buildOrderPosition`** | This milestone's **position from the manifest's build order** (3.7.f). |
| **`preResolvedVersion`** (optional) | The **hoisted exact title + true provenance** resolved on the main thread at 3.7.c — `{ title, provenance }`. The **Step 5.1 ADOPT branch** (`docs/version-ladder.md`) consumes it and runs no ladder/prompt. |
| **`assignedSlug`** (optional) | The **disambiguated slug** assigned at 3.7.d. `skills/plan/SKILL.md` **Step 7's ADOPT branch** writes the plan file to `plan-<assignedSlug>.md`. |

**Both `preResolvedVersion` and `assignedSlug` are OPTIONAL and supplied ONLY here, on the roadmap path.** On the single-brief path they are **ABSENT**, so `skills/plan/SKILL.md` Step 5.1 runs the version ladder (`docs/version-ladder.md`) and Step 7 derives the slug from the goal — **single-brief behavior is unchanged**.

**Per-dispatch verify + one bounded retry (this milestone's Step 3 architect call — roadmap path only).** Each milestone's dispatch runs `skills/plan/SKILL.md` Step 3 (the architect) internally — inside the per-milestone background subagent on the Nested-supported topology, or directly at the main-thread level on Flat-fallback; either way, **before** that return feeds Step 3.5's park pass or this milestone's 3.7.g classification, **verify it against `agents/architect.md` → "Structured return block"** — the always-required top-level keys (`CANDIDATES:` / `EDGES:` / `WAVES:` / `PRODUCT_GAPS:` / `SCOPE_SPANS_MULTIPLE_MILESTONES:`). **Malformed** = present but missing one of those keys (`PRODUCT_GAPS:` / `SCOPE_SPANS_MULTIPLE_MILESTONES:` being the literal `none` is a **valid** value, **not** malformed) — **or** a key present but invalid at the VALUE level, extending the same scrutiny `PRODUCT_GAPS:` already gets to the block's other cross-referencing keys: **`WAVES:`** must place every tag that appears in `CANDIDATES:` (clause 4 — the Wave order is the topological sort of the edges over the FULL candidate set, so every candidate lands in exactly one Wave); an empty or literal-`none` `WAVES:` alongside a non-empty `CANDIDATES:` is malformed, and so is a populated `WAVES:` that omits one or more `CANDIDATES:` tags. **Each `CANDIDATES:` entry** must also carry its own required fields — `tag`, `title`, `surface`, `risk`, `sketch` (`agents/architect.md` → "Structured return block") — `disposition` and `layer` stay OPTIONAL per that same contract, so their absence alone is never malformed. **Empty** = no returned text at all.

On malformed/empty, **re-dispatch the SAME architect call once** for this milestone — same brief-slice, digest, implied-surfaces reference, shared keys, sizing guidance — **feeding back which check failed** (e.g. "your prior return was missing `WAVES:`"). Both the dispatch and its one retry are **same-run, immediate re-dispatches of the identical agent — never a queued or deferred job** (`.project/environment.md#Async & messaging`). If the retried call now parses, this milestone's planning proceeds exactly as a first-attempt success — Step 3.5, Step 4, Step 5, Step 7 run unchanged on the retried content. A retry re-uses this milestone's own slot in the cap-4 rolling window above — it is not a new milestone entering the window early, and the window's in-flight accounting is unaffected.

**The bound (single most safety-critical rule here): if the retry — the SECOND consecutive attempt for this milestone's architect call — ALSO returns malformed or empty, make NO third attempt, full stop.** Classify this milestone **failed-to-plan immediately**, via the **existing, unmodified** 3.7.g table (the "dispatch errored (no return)" row — a verify failure that survives one bounded retry is treated as this milestone's dispatch having produced no usable result). Record the reason as **"architect dispatch failed verify twice (malformed/empty return)"** in 3.7.g's roster "and why" column — the same free-text reason field 3.7.g already carries, so this reads distinctly from a Step-2 STOP or an all-parked/all-dropped failure, with **no new column and no new classification bucket**. This bounded-retry-then-classify-failed shape is this fan-out's instance of `.project/design-philosophy.md#Error & failure philosophy` ("best-effort... never stop plan") — one failure never aborts the whole roadmap, unchanged from 3.7.g's existing behavior.

## 3.7.f — Record the cross-milestone build order as metadata

The cross-milestone build order's **recorded home is the #152 MANIFEST** (its `Build order:` line + each milestone's `Build-order position`), **owned by the #152 manifest contract** (`skills/build-roadmap/SKILL.md` "Manifest format") — that manifest is the **source of truth** the downstream `create` / driver read for cross-milestone order. The fan-out **records nothing new and writes no build order into the individual per-milestone plan files** (per the #153 contract, `buildOrderPosition` does **not** alter the rendered plan file). It only **consumes** the order from the manifest — **never re-deriving it or redefining the schema** — and **surfaces** it to the user in the 3.7.g roster; the manifest remains its recorded home (`docs/specs/v0.3.1-driver-handoff.md` §6).

## 3.7.g — Failed-milestone handling (continue the others) + surface the roster

**One milestone's failure NEVER aborts the roadmap.** Classify each milestone's dispatch outcome at the barrier:

| Outcome | Classify |
|---|---|
| The dispatch returned a plan file at its assigned path (even if some issues parked) | **planned** — record its plan-file path into the manifest's `Plan file:` field (see below). |
| The dispatch **errored** (no return), the routine **`skills/plan/SKILL.md` Step-2 STOPped** (needs-product-input report only, no plan file), or **every candidate parked/dropped so no buildable issue survived** | **failed-to-plan** — record the milestone and the reason. |

A **failed-to-plan** milestone is recorded and the fan-out **CONTINUES** the remaining milestones (the rolling window keeps refilling) — one failure never aborts the whole roadmap (`.project/design-philosophy.md#Error & failure philosophy`).

**Record each planned milestone's plan-file path into the manifest (close the producer→consumer handle for `create`).** For every milestone classified **planned**, record its real plan-file path — `.milestone-feeder/plan-<assignedSlug>.md`, the `assignedSlug` pre-derived at 3.7.d — into that milestone's entry in the confirmed manifest, in the `Plan file:` field the #152 manifest contract reserves (`skills/build-roadmap/SKILL.md` "Manifest format"). Edit the manifest **in place**, consistent with how `plan` writes its own scratch files (`skills/plan/SKILL.md` Step 7) — it is local scratch the model already authored, so **no new shell is needed**; key the write to the milestone entry by its `Build-order position`, so re-planning the same roadmap overwrites the field to the **same deterministic path** (idempotent). This records the path into the **MANIFEST only** — it writes **nothing** into the per-milestone plan files (consistent with 3.7.f, which keeps cross-milestone metadata out of the plan files). A **failed-to-plan** milestone's `Plan file:` field is **left pending** (no file exists to point at). When the barrier completes, every planned milestone's entry carries its real plan-file path — the deterministic handle `create`'s deploy-loop resolves each milestone's plan file by (`skills/create/SKILL.md` Step 1R), **never** a slug re-derived from the milestone name.

**Surface the roster.** After the barrier, surface a concise per-milestone roster (a table) — the **build order**, **which milestones produced plan files** (and their paths), and **which failed-to-plan** (and why). This is the roadmap-path surface that **replaces** the single-milestone "here's your plan file" moment: the user reviews each milestone's plan file (confirming/overriding its surfaced title), then runs `/milestone-feeder:create` per milestone in build order. **`plan` wrote no GitHub state.** Control returns here — the run does not continue into `skills/plan/SKILL.md` Step 4.
