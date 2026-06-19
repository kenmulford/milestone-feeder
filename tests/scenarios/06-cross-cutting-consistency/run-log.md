# Run log — 06-cross-cutting-consistency (FLAGSHIP)

**Skill:** `/milestone-feeder:plan`
**Mode:** PREVIEW — read-only on GitHub. Zero writes (no milestone, no issue, no label, no comment). Output is local scratch: the plan file (no needs-input report was needed).
**Surface version:** v0.3.0 (vocabulary: plan / create / update; reviewer / projectDocs; architect / issue-author).
**Source brief:** inline (`brief.md`).

> Announce (as the skill says first):
> "Standing by while I turn the brief into a milestone + issues and run the self-check gate. This is read-only on GitHub — I'll write a reviewable plan file and create nothing on GitHub. Run `/milestone-feeder:create` afterward to deploy the plan."

---

## What this scenario hunts

The brief asks for 10 admin list pages but **deliberately does not restate the standing table directive** — that directive lives ONLY in `project/design-system.md`. The flagship failure mode is **DRIFT**: the directive present on the early issues but quietly missing or weakened on the later ones (issues 7–10). The run must pull the directive from the project docs and propagate the **complete, unweakened** directive into **every** table-bearing page-issue, citing `project/design-system.md` on each, then prove — via the **real** `milestone-driver:design-reviewer` per UI issue — that no issue silently shipped without it.

---

## Step 0 — Read config + project docs

`feeder.json` present → no `setup` bootstrap needed.

| Key | Resolved value | Source |
|---|---|---|
| `projectDocs` | `project/` | feeder.json |
| `reviewer` | `"milestone-driver"` | feeder.json (default) |
| `architectAgent` | `milestone-feeder:architect` | default |
| `issueAuthorAgent` | `milestone-feeder:issue-author` | default |
| `issueSize` | (none) | absent → default ~1 PR each |

Shared keys (driver-config chain → `.milestone-config/driver.json`):

| Shared key | Resolved value |
|---|---|
| `sourceGlobs` | `["src/**"]` |
| `uiSurfaceGlobs` | `["src/pages/**", "src/components/**"]` — **SET** |
| `integrationBranch` | `"develop"` |
| `nonNegotiables` (reviewer-profile input, not a shared key) | `["React 18 + TypeScript"]` |

`uiSurfaceGlobs` is **set** → the 10 pages all touch `src/pages/**`, so each classifies as **UI** and the `design-reviewer` engages. No degradation.

**Project docs read (best-effort):** `project/design-system.md` exists and carries the standing data-table convention. This is **the** grounding source for the table directive — the brief never restates it.

### The standing table directive — pulled from `project/design-system.md`

Read verbatim from the project doc, every table in the admin app MUST:

| # | Directive clause | The literal value to carry (no weakening) |
|---|---|---|
| 1 | Sortable + filterable columns | every column sortable AND has a column filter, **EXCEPT** the row-actions (Actions) column — no sort, no filter on Actions |
| 2 | Pagination | **server-side pagination at 30 rows per page**, page-size control **defaulting to 30** (carry the literal **30** — never weaken to "paginated" / "a sensible page size") |
| 3 | Empty state | shared `EmptyState` illustration + a primary CTA relevant to the entity |
| 4 | Loading state | skeleton rows while the page loads |
| 5 | Component reuse | reuse the shared `DataTable` component (`src/components/DataTable.tsx`) — do not hand-roll tables |

This directive is the cross-cutting convention the run must propagate, verbatim-equivalent, into all 10 page-issues, each citing `project/design-system.md` on a `Convention followed:` line.

---

## Step 1 — Ingest the brief

Form: **inline text** (`brief.md`). Normalized:

```
goal:         Build the 10 admin list pages, one per entity — each a table of the entity's
              records with standard columns and view/edit/delete row actions, every table
              following the standing data-table convention.
in-scope:     [the 10 list pages]
out-of-scope: [the detail / edit pages behind the row actions — a separate milestone]
surfaces:     [Users, Orders, Products, Invoices, Shipments, Refunds, Coupons, Reviews,
               Support Tickets, Audit Log] — all under src/pages/**
epicIssueNumber: (none — inline brief)
```

---

## Step 2 — Product-gap check (the park boundary)

| Decision implied | Class | Resolution |
|---|---|---|
| Table styling (sort/filter/pagination/empty/loading/component) | **Design** | Resolved — `project/design-system.md` supplies every clause. Cited per issue. |
| Per-entity column set | **Design (convention)** | Resolved — each entity's existing list resource defines its standard fields/order/labels; the page renders the resource's fields, it does not invent a set. Cited per issue. |
| Data source per page | **Design (convention)** | Resolved — each page reads the entity's existing list resource in the data-access layer; introduces no new endpoint/type. |
| Row-action set (view/edit/delete) | **Product (brief-stated)** | Resolved — the brief states view/edit/delete uniformly for all 10 entities (incl. Audit Log). Kept as the brief specifies; **not** weakened/carved-out — doing so would invent product scope. |

**No product gap blocks candidate-set formation.** `productGaps[]` is empty. Proceed — the pipeline forms all 10 candidates.

---

## Step 3 — Dispatch the architect (once)

Dispatched `milestone-feeder:architect` once (proxied faithfully under the harness; plugin not installed as commands). Returned block:

```
CANDIDATES:
  - #A Build the Users admin list page            surface: ui  risk: light
  - #B Build the Orders admin list page           surface: ui  risk: light
  - #C Build the Products admin list page          surface: ui  risk: light
  - #D Build the Invoices admin list page          surface: ui  risk: light
  - #E Build the Shipments admin list page         surface: ui  risk: light
  - #F Build the Refunds admin list page           surface: ui  risk: light
  - #G Build the Coupons admin list page           surface: ui  risk: light
  - #H Build the Reviews admin list page           surface: ui  risk: light
  - #I Build the Support Tickets admin list page   surface: ui  risk: light
  - #J Build the Audit Log admin list page         surface: ui  risk: light
EDGES: []
WAVES:
  - "Wave 1 (parallel): #A, #B, #C, #D, #E, #F, #G, #H, #I, #J"
PRODUCT_GAPS: none
```

Each candidate's `sketch` grounds its table design in `project/design-system.md` and its column set in the entity's existing list resource. The 10 pages are mutually independent (each reuses the already-existing shared `DataTable`; none introduces a type/screen another consumes) → **EDGES `[]`**, **all 10 in Wave 1**. No architect product gaps.

---

## Step 4 — Dispatch issue-author per candidate (×10)

Dispatched `milestone-feeder:issue-author` once per candidate (proxied faithfully). **The propagation step:** each issue's Acceptance criteria and Design section carry the **complete** standing directive (all 5 clauses, the literal **30 rows/page**), and each Design section ends with `Convention followed: project/design-system.md (data-table standing convention)` plus the entity's existing list resource for columns/data. Every issue enumerates happy + columns + data-source + pagination + empty + loading + error + disabled/edge states (no happy-path-only list).

All 10 returned `STATUS: AUTHORED` (no `PRODUCT_GAP`).

---

## Step 5 — Assemble graph + render the milestone description

EDGES `[]` → no graph edges. Wave-ordered description (local slugs):

```
Build the 10 admin list pages, one per entity — each a table of the entity's records with
standard columns and view/edit/delete row actions, every table following the standing
data-table convention (project/design-system.md).

## Waves
- Wave 1 (parallel): #A, #B, #C, #D, #E, #F, #G, #H, #I, #J
```

---

## Step 6 — Self-check gate (the keystone) — REAL reviewers

`reviewer: "milestone-driver"`. **The reviewers resolved** (`milestone-driver:triage-reviewer` and `milestone-driver:design-reviewer` are dispatchable in this session). **No degrade to internal.** Per UI issue: a real `triage-reviewer` dispatch, and — since every issue returns `NEEDS_DESIGN_REVIEW: yes` (all touch `src/pages/**`) — a real `design-reviewer` dispatch. Each reviewer was briefed from the GENERATED issue text; recorded-design-decisions briefed as **empty** (no GitHub issue exists yet); the Step 5 milestone description supplied as cross-issue context; the profile (`sourceGlobs`, `uiSurfaceGlobs`, `nonNegotiables`) passed through.

**Gate ran with REAL reviewers? YES.** Every one of the 10 UI issues was reviewed by the real `milestone-driver:design-reviewer` (and the real `milestone-driver:triage-reviewer`). No issue was passed without a live design-reviewer verdict — so an issue silently missing the directive could not pass the gate undetected.

### Per-issue gate table (real reviewers; all 10 UI issues)

| Issue | Entity | triage-reviewer | design-reviewer | Net verdict | Re-author? |
|---|---|---|---|---|---|
| #A | Users | rev0: 2 Blockers (no data-contract / column-source recorded) → rev1: Advisory only | Advisory only (confirm-dialog detail, in-flight visual) | **PASS** (rev1) | 1 |
| #B | Orders | rev0: 2 Blockers (resource/components "cannot verify") → rev1: Advisory (page-size options) | Advisory only (in-flight visual) | **PASS** (rev1) | 1 |
| #C | Products | rev0: 1 Blocker (column set not resolvable) → rev1: GAPS none | rev0: 1 Blocker (page-size options unspecified) → rev1: GAPS none | **PASS** (rev1) | 1 |
| #D | Invoices | Advisory only (column set deferred to resource) | GAPS: none | **PASS** | 0 |
| #E | Shipments | rev0: 2 Blockers (undeclared-dependency / not-buildable columns) → rev1: GAPS none | Advisory only (confirm-dialog + in-flight detail) | **PASS** (rev1) | 1 |
| #F | Refunds | Advisory only (page-size options) | GAPS: none | **PASS** | 0 |
| #G | Coupons | GAPS: none | GAPS: none | **PASS** | 0 |
| #H | Reviews | GAPS: none | GAPS: none | **PASS** | 0 |
| #I | Support Tickets | GAPS: none | GAPS: none | **PASS** | 0 |
| #J | Audit Log | Advisory only (page-size options) | GAPS: none | **PASS** | 0 |

### What the early-round Blockers were — and were NOT

The round-0 Blockers on #A/#B/#C/#E were **never about the standing table directive**. They were:

- **Data-contract / column-source unrecorded** (#A, #C, #E): the issue named "the standard columns for that entity" without recording where the column set comes from. **Design-resolvable** (§6.5 design/impl-resolvable): re-authored to record a `Convention followed:` line — each page renders the entity's **existing list resource** fields (resource order/labels) and reads that existing resource; introduces no new data layer. This is grounded (the brief scopes only the 10 pages; per-entity resources pre-exist), so the gap downgraded to Advisory.
- **Page-size option set unspecified** (#C design-reviewer): the directive's "page-size control defaulting to 30" did not enumerate the selectable options. Re-authored to record options **30 / 50 / 100, default 30** — the literal **30** default preserved (directive **not** weakened). Cleared.
- **Harness "cannot verify X exists"** (#B, #E): the shared `DataTable`/`EmptyState` and the list resources are real components the design-system doc treats as existing, but the sandbox does not materialize the `src/**` tree. The re-author brief stated the harness grounding (these are existing givens per the standing doc + brief); the reviewers then cleared them. A sandbox artifact, not a directive defect.

**Crucially:** on the **core directive itself** (sortable+filterable-except-Actions, 30 rows/page, EmptyState, skeleton, DataTable reuse), **every** `design-reviewer` returned a positive pattern-consistency PASS — explicitly confirming the recorded design "mirrors the standing convention point-for-point / verbatim, no divergence, no drift, no weakening." Had any issue omitted or weakened a clause, the design-reviewer's pattern-consistency / missing-state / missing-affordance check would have flagged it as a Blocker (the exact failure mode being hunted). It did not, because no issue drifted.

### §6.5 retry / park accounting

- Re-authors used: #A ×1, #B ×1, #C ×1, #E ×1 — all within the ≤2 per-issue cap; all cleared on the **first** re-author. #D/#F/#G/#H/#I/#J cleared with **zero** re-authors.
- **Parked:** none. **Dropped:** none. `productGaps[]` empty.
- §6.6 undeclared-edge absorb: none needed. The lone `undeclared-dependency` finding (#E round-0) was a harness "list-resource not materialized" artifact, resolved by the re-author's existing-resource grounding — not a real sibling edge. EDGES stays `[]`, Wave order unchanged.

### Advisory notes carried forward (do NOT fail the gate — §6.3)

- Page-size **options** 30/50/100 extend the directive (which fixes only the default = 30); additive, default-30 honored. Recorded uniformly on all 10 for consistency.
- Confirm-dialog visual detail (destructive-styled "Delete" default-focus + "Cancel") and in-flight row-spinner treatment — recorded uniformly; were Advisory, now specified.

---

## EXPLICIT consistency check — the flagship assertion

For each of the 10 surviving issues, does the issue carry the **COMPLETE, UNWEAKENED** directive, with the **literal page-size number**, citing `project/design-system.md`?

| Issue | sort+filter except Actions | **30 rows/page (literal)** | EmptyState + CTA | skeleton loading | shared DataTable reuse | cites `project/design-system.md` |
|---|:--:|:--:|:--:|:--:|:--:|:--:|
| #A Users | ✓ | ✓ 30 | ✓ | ✓ | ✓ | ✓ |
| #B Orders | ✓ | ✓ 30 | ✓ | ✓ | ✓ | ✓ |
| #C Products | ✓ | ✓ 30 | ✓ | ✓ | ✓ | ✓ |
| #D Invoices | ✓ | ✓ 30 | ✓ | ✓ | ✓ | ✓ |
| #E Shipments | ✓ | ✓ 30 | ✓ | ✓ | ✓ | ✓ |
| #F Refunds | ✓ | ✓ 30 | ✓ | ✓ | ✓ | ✓ |
| #G Coupons | ✓ | ✓ 30 | ✓ | ✓ | ✓ | ✓ |
| #H Reviews | ✓ | ✓ 30 | ✓ | ✓ | ✓ | ✓ |
| #I Support Tickets | ✓ | ✓ 30 | ✓ | ✓ | ✓ | ✓ |
| #J Audit Log | ✓ | ✓ 30 | ✓ | ✓ | ✓ | ✓ |

**10 / 10 carry the complete, unweakened directive. Zero drift.** The literal "30 rows per page" appears on all 10 (never softened to "paginated" or "a sensible page size"). No issue — including the late ones (#G–#J) — dropped or weakened a clause. The Audit Log (#J), the last issue, carries the identical full directive.

---

## Step 7 — Write the plan file (PREVIEW)

Surviving issue set = all 10 (gate-clean: PASS, Advisory-only allowed). None parked, none dropped.

- Plan-file slug (deterministic, from the one-line goal): `build-the-10-admin-list-pages-one-per-entity-each-a-table`
- Plan file path: `.milestone-feeder/plan-build-the-10-admin-list-pages-one-per-entity-each-a-table.md`
- Self-check verdict line: **PASS — all 10 issues GAPS: none / Advisory-only (milestone-driver reviewers)**
- Needs-input report: **not written** (`productGaps[]` empty; no issue parked as needs-human-direction).

The full plan-file PREVIEW artifact (header, self-check line, milestone description, the §4 body for each of the 10 issues, project-docs grounding) is in `run-output.md`.

**GitHub writes performed: ZERO.** No milestone, no issue, no label, no comment. PREVIEW only.

---

## Summary

| Metric | Result |
|---|---|
| Candidates | 10 (one per entity) |
| Surviving / parked / dropped | 10 / 0 / 0 |
| Carry the complete unweakened directive (incl. literal 30/page) | **10 / 10 — no drift** |
| Real design-reviewer dispatches | 10 (one per UI issue) + 1 re-review (#C rev1) |
| Real triage-reviewer dispatches | 10 + 4 re-triage (#A/#B/#C/#E rev1) |
| Gate ran with REAL reviewers? | **YES** |
| Re-authors (≤2 cap) | #A,#B,#C,#E ×1 each; rest 0 — all cleared first re-author |
| Self-check verdict | PASS |
| GitHub writes | ZERO (PREVIEW) |
