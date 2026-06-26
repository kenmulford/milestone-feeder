# Test environment — 11 roadmap fan-out (what the run assumes)

This is an **oversized whole-app brief** — many features, a data model, auth, and
billing — so it spans **several milestones** and `plan`'s front-door (Step 3.6)
routes it into the `build-roadmap` flow instead of the single-milestone pipeline.

- `feeder.json`: defaults (`reviewer: "milestone-driver"`, `projectDocs: project/`).
- Driver shared keys (as if from `.milestone-config/driver.json`):
  - `sourceGlobs`: `["src/**"]`
  - `uiSurfaceGlobs`: `["src/pages/**", "src/components/**"]`  ← **set**, so the
    portal / dashboard / report page-issues classify as **UI** and the
    `design-reviewer` engages (as in scenario 06)
  - `integrationBranch`: `"develop"`
  - `nonNegotiables`: `["Python 3.11 + FastAPI backend; React 18 + TypeScript frontend"]`
- Project docs dir for this scenario: `project/`

> The brief is grouped into author sections (Accounts & access / Data model /
> Client management / Invoicing / Payments & billing / Client portal / Admin
> dashboard / Notifications). The roadmap split partitions these into a sequenced
> set of milestones and records, per milestone, how it changed the author's
> grouping (merged / split / reordered / unchanged) — so the split has a real diff
> to record. The fixture's `project/conventions.md` grounds the design and
> implementation calls (REST shape, auth guard, owner scoping, toast, states,
> `DataTable`); it deliberately does **not** name a payment provider, currency, or
> fee/tax policy — that is a product call with no conventional default.
