# Milestone plan (PREVIEW) — Add a "Featured" section to the homepage showing selected catalog items

Self-check: PARKED — 1 issue → needs product input (#A); 2 issue(s) → dropped as dependents of the parked issue (#B, #C). 0 issues survive the gate. (milestone-driver reviewers — real triage-reviewer + design-reviewer)
Source brief: inline

## Milestone description (preview)

Add a "Featured" section to the homepage that highlights a selection of catalog items, displayed in the standard product-card grid.

## Waves
- (no issues — every candidate parked or dropped at the self-check gate; see Needs human input)

## Issues
### #A — Add a featured-items read accessor in the models layer   [parked — needs product input]
Marker only; no fabricated body. The accessor's contract cannot be grounded without the featured-selection mechanism — a product decision the substrate explicitly records has no conventional default. See the needs-product-input report below.

### #B — Render the homepage "Featured" section using ProductCardGrid   [dropped — depends on parked #A]
Marker only; a dependent of a parked issue cannot build (Step 6 §6.6). Not emitted. (The render design itself is groundable in `ProductCardGrid`; it cannot ship until #A's accessor contract is decided.)

### #C — Add empty and error states to the homepage Featured section   [dropped — transitively depends on parked #A (via #B)]
Marker only; transitive dependent of the parked issue, not emitted (Step 6 §6.6).

## Substrate grounding
- Render featured items in the standard product-card grid — grounded in `project/conventions.md#UI` (reuse `ProductCardGrid` — `src/components/ProductCardGrid.tsx`).
- Empty + error states on the section — grounded in `project/conventions.md#States` (empty and error required on every user-facing surface).
- Read model location for the accessor — grounded in `project/conventions.md#Data` (read models live in `src/models/`; a new persisted field requires a migration).
- Stack constraint React 18 + TypeScript — `nonNegotiables` (driver profile).
- Degradations: none (uiSurfaceGlobs present; design lens applied to #B/#C). Note: no readable `src/` tree in the fixture — substrate references cited as stated conventions, not verified file:line; the reviewers flagged the unverifiable artifacts (`Item` type, `ProductCardGrid` behavior) as part of the gate findings.

## Needs human input
🔴 See the needs-product-input report below — `productGaps[]` is non-empty (#A parked as a product gap; #B and #C dropped as its dependents). In a non-test run this is `.milestone-feeder/needs-product-input-featured-homepage-section.md`.

---
To create these on GitHub, re-run with `--apply` — it ensures the labels, creates-or-adopts the milestone, opens each gate-surviving issue, rewrites the slug references to real issue numbers, and patches the milestone description with the Wave order. **This preview wrote no GitHub state.** Note: with the current gate outcome there are **zero gate-surviving issues**, so `--apply` would create the milestone + labels and post the needs-product-input report, but open no issues until the product gap below is resolved and decompose is re-run.

---

# 🔴 Needs human input — Add a "Featured" section to the homepage showing selected catalog items

These items blocked the milestone and were NOT guessed. Resolve each, then re-run decompose.

| # | Kind | Item | Why blocked | Blocks |
|---|---|---|---|---|
| 1 | product-gap | **How are featured items chosen?** The selection mechanism AND the policy that populates the featured set — e.g. a curated admin-managed list, a persisted per-item `featured` flag (+ migration), or a rules/query-based derivation. This choice also fixes the accessor's contract shape (sync `Item[]` vs async `Promise<Item[]>`, failable or not). | `project/conventions.md` explicitly records no product policy for how featured items are chosen, and there is no conventional default. The Data convention only prescribes HOW to persist *if* persistence is the chosen mechanism; it does not decide *whether* the mechanism is a persisted flag, a curated list, or a derived rule. The accessor contract — and therefore the loading/error states the render and states issues require — cannot be grounded until this is decided. Brief ref: "Whatever is needed to choose WHICH items are featured." | #A (the read accessor — parked) and, transitively, #B (render) and #C (states), which are dropped as dependents until #A is buildable. |

**To unblock:** decide the selection mechanism (and with it the accessor signature), record it in the substrate (e.g. `project/conventions.md`), then re-run `/milestone-feeder:decompose`. With the mechanism fixed, #A becomes buildable as a Wave-1 root and #B/#C re-enter the plan in Waves 2–3.
