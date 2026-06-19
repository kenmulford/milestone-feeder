# Milestone plan — Add a "Featured" section to the homepage showing selected catalog items

Milestone title (exact): Featured items on the homepage
Self-check: PARKED — 1 issue → needs product input (#A, product-gap); 0 issue(s) → needs human direction. 2 issue(s) dropped as dependents of the parked issue (#B, #C). 0 issues survive the gate. (milestone-driver reviewers — real triage-reviewer ×2 + design-reviewer ×2)
Source brief: inline

## Milestone description (Wave order)

Add a "Featured" section to the homepage that highlights a selection of catalog items, displayed in the standard product-card grid.

## Waves
- (no issues — every candidate parked or dropped at the self-check gate; see Needs human input)

## Issues

### #A — Add a featured flag to the product read model with a migration   [parked — needs product input]
Marker only; no fabricated body. The `featured` field cannot be given semantics, a default, a backfill, or a write path without the featured-selection policy — a product decision the project docs explicitly record as having no conventional default. The issue-author returned `STATUS: PRODUCT_GAP` rather than invent the field's meaning. See the needs-product-input report below.

### #B — Render the homepage Featured section using ProductCardGrid   [dropped — depends on parked #A]
Marker only; a dependent of a parked issue cannot build (Step 6 §6.6). Not emitted. (The render design itself is groundable in `ProductCardGrid` per `conventions.md#UI`, but the section's sole data source is the parked #A, so the real `triage-reviewer` returned a Blocker — `undeclared-dependency` / `not-buildable` — and #B drops with #A.)

### #C — Add empty and error states to the homepage Featured section   [dropped — transitively depends on parked #A (via #B)]
Marker only; transitive dependent of the parked issue, not emitted (Step 6 §6.6). #C's own triage passed (`GAPS: none` — its criteria scope OUT the featuring policy), but it cannot ship atop the dropped #A → #B chain.

## Project-docs grounding
- Render featured items in the standard product-card grid — grounded in `project/conventions.md#UI` (reuse `ProductCardGrid` — `src/components/ProductCardGrid.tsx`).
- Empty + error states on the section — grounded in `project/conventions.md#States` (empty and error required on every user-facing surface).
- Read-model location for a featured field — grounded in `project/conventions.md#Data` (read models live in `src/models/`; a new persisted field requires a migration). Note: this convention prescribes HOW to persist *if* persistence is the chosen mechanism; it does NOT decide *whether* selection is a persisted flag at all — that is the parked product gap.
- Stack constraint React 18 + TypeScript — `nonNegotiables` (driver profile), passed through to the self-check gate.
- Degradations: none (`uiSurfaceGlobs` present; design lens applied to #B and #C). Note: no readable `src/` tree exists in the fixture — project-docs references are cited as stated conventions, not verified `file:line`; the real reviewers flagged the unverifiable artifacts (the `ProductCardGrid` contract, the `featured` field shape) as part of the gate findings.

## Needs human input
🔴 See the needs-product-input report below — `productGaps[]` is non-empty (#A parked as a product gap; #B and #C dropped as its dependents). In a non-test run this is `.milestone-feeder/needs-product-input-add-a-featured-section-to-the-homepage-that-highlights-a-sel.md`.

---
This plan file is the build artifact — run `/milestone-feeder:create` to deploy it to GitHub (it ensures the labels, creates-or-adopts the milestone by the exact title above, opens each surviving issue, rewrites the slug references to real issue numbers, and patches the milestone description with the Wave order). `plan` wrote no GitHub state. Note: with the current gate outcome there are **zero surviving issues**, so `create` would create-or-adopt the milestone "Featured items on the homepage" but open no issues until the product gap below is resolved and `plan` is re-run.

---

# 🔴 Needs human input — Add a "Featured" section to the homepage showing selected catalog items

These items blocked the milestone and were NOT guessed. Resolve each, then re-run plan.

| # | Kind | Item | Why blocked | Blocks |
|---|---|---|---|---|
| 1 | product-gap | **How are featured items chosen?** The selection policy that decides which catalog items are featured — e.g. a persisted per-item `featured` flag (admin-toggled, + migration), a curated admin-managed ordered list, or a rules/query-based derivation (top sellers, a campaign window). This choice also fixes the read model's data shape, its owner, its default value, and its backfill for existing products. | `project/conventions.md` explicitly records that there is no product policy for how featured items are chosen, and that it is "a product decision with no conventional default." The Data convention only prescribes HOW to persist *if* persistence is the chosen mechanism; it does not decide *whether* the mechanism is a persisted flag, a curated list, or a derived rule. The `featured` field's semantics — and therefore the render and the empty/error states that consume it — cannot be grounded until this is decided. Brief ref: "Whatever is needed to choose WHICH items are featured." | #A (the read-model field — parked) and, transitively, #B (render) and #C (states), both dropped as dependents until #A is buildable. |

**To unblock:** decide the featured-selection policy (and with it the read-model field's shape, default, and write path), record it in the project docs (e.g. `project/conventions.md`), then re-run `/milestone-feeder:plan`. With the mechanism fixed, #A becomes buildable as a Wave-1 root and #B/#C re-enter the plan in Waves 2–3.
