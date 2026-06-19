# Milestone plan — Build the 10 admin list pages, one per entity, each a table following the standing data-table convention

Milestone title (exact): Admin list pages
Self-check: PASS — all 10 issues GAPS: none / Advisory-only (milestone-driver reviewers). The real `milestone-driver:design-reviewer` reviewed every one of the 10 UI issues and confirmed the FULL standing table directive is present and UNWEAKENED on each (pattern-consistency PASS, no drift). #A/#B/#C/#E each took 1 of ≤2 re-authors to clear non-directive triage Blockers (column-source / data-contract grounding; page-size option set) — cleared on re-review. Zero parked, zero dropped.
Source brief: inline

## Milestone description (Wave order)

Build the 10 admin list pages, one per entity — each a table of the entity's records with standard columns and view/edit/delete row actions, every table following the standing data-table convention (project/design-system.md).

## Waves
- Wave 1 (parallel): #A, #B, #C, #D, #E, #F, #G, #H, #I, #J

## Issues

### #A — Build the Users admin list page   [ui, risk:light]   [self-check: PASS]

## Summary
Add the Users admin list page: a table of user records with the standard Users columns and per-row actions (view / edit / delete). The shared `DataTable`/`EmptyState`/confirm-dialog and the Users list resource already exist; this issue adds only the page. Detail/edit pages behind the row actions are out of scope (separate milestone).

## Acceptance criteria
- [ ] Happy path: the page renders a table of users via the shared `DataTable` component (`src/components/DataTable.tsx`); every column is sortable and has a column filter, EXCEPT the row-actions (Actions) column (no sort, no filter on Actions).
- [ ] Columns: renders the standard Users column set — the existing Users list resource's fields, in resource order, with resource labels — plus a trailing Actions column. The page renders the entity's existing resource fields; it does not hand-pick or invent a column set.
- [ ] Data source: consumes the existing Users list resource in the data-access layer; introduces no new endpoint or type. Server-side pagination/sort/filter are delegated to that resource via the shared `DataTable` contract.
- [ ] Pagination: server-side pagination at 30 rows per page, with a page-size control whose options are 30 / 50 / 100 and which defaults to 30.
- [ ] Empty state: when there are no users, show the shared `EmptyState` illustration plus a Users-relevant primary CTA ("Invite user"); the CTA is a non-functional placeholder this milestone (its destination is the user-create flow, a separate milestone).
- [ ] Loading state: skeleton rows render while the page loads.
- [ ] Error/failure path: on fetch failure, surface the shared `DataTable` error state (no silent blank table).
- [ ] Disabled/edge state: the per-row delete action opens a confirm dialog (destructive-styled "Delete" default-focus button + "Cancel") before deleting; on success the list refetches, on failure the error state surfaces and the dialog re-enables; row actions are disabled while a row mutation is in flight (row-level spinner); view/edit navigate to the detail/edit pages (separate milestone) and render disabled until those land.

## Design (recorded, consistent)
- Mirror the shared `DataTable` component at `src/components/DataTable.tsx` — do not hand-roll a table.
- Columns sortable + filterable except the Actions column (no sort, no filter on Actions).
- Server-side pagination at 30 rows/page; page-size control options 30/50/100, default 30.
- Empty state uses the shared `EmptyState` illustration + an entity-relevant primary CTA.
- Loading state renders skeleton rows.
- Row actions view/edit/delete; delete is destructive → confirm dialog before deletion (refetch on success, error + re-enable on failure); row actions disabled during an in-flight mutation.
- Standard columns = the existing Users list resource's fields (resource order/labels); data read through that existing resource — no new endpoint/type.
- Accessibility: accessible labels on the sort toggle, filter inputs, row-action buttons, and confirm-dialog buttons.
- Convention followed: project/design-system.md (data-table standing convention) for table mechanics; the existing per-entity Users list resource for the standard column set and data source.

## Dependencies
- None. The shared `DataTable`/`EmptyState`/confirm-dialog and the Users list resource are existing artifacts this page consumes. #A–#J are independent peer list pages.

## Classification
- Surface: UI
- Risk: light

---

### #B — Build the Orders admin list page   [ui, risk:light]   [self-check: PASS]

## Summary
Add the Orders admin list page: a table of order records with the standard Orders columns and per-row actions (view / edit / delete). The shared `DataTable`/`EmptyState`/confirm-dialog and the Orders list resource already exist; this issue adds only the page. Detail/edit pages out of scope (separate milestone).

## Acceptance criteria
- [ ] Happy path: renders a table of orders via the shared `DataTable` (`src/components/DataTable.tsx`); every column sortable + filterable EXCEPT the Actions column (no sort, no filter).
- [ ] Columns: renders the standard Orders column set — the existing Orders list resource's fields, in resource order, with resource labels — plus a trailing Actions column. No hand-invented columns.
- [ ] Data source: consumes the existing Orders list resource; introduces no new endpoint or type. Server-side pagination/sort/filter delegated to that resource via the `DataTable` contract.
- [ ] Pagination: server-side pagination at 30 rows per page, with a page-size control whose options are 30 / 50 / 100 and which defaults to 30.
- [ ] Empty state: shared `EmptyState` illustration + Orders-relevant CTA ("Create order"), a non-functional placeholder this milestone.
- [ ] Loading state: skeleton rows while loading.
- [ ] Error/failure path: on fetch failure, surface the shared `DataTable` error state (no silent blank table).
- [ ] Disabled/edge state: delete opens a confirm dialog (destructive "Delete" default-focus + "Cancel") before deleting; on success refetch, on failure surface error + re-enable; row actions disabled during an in-flight mutation (row-level spinner); view/edit navigate to detail/edit pages (separate milestone) and render disabled until those land.

## Design (recorded, consistent)
- Mirror the shared `DataTable` at `src/components/DataTable.tsx` — do not hand-roll a table.
- Columns sortable + filterable except the Actions column.
- Server-side pagination at 30 rows/page; page-size control options 30/50/100, default 30.
- Empty state: shared `EmptyState` + Orders CTA.
- Loading: skeleton rows.
- Delete destructive → confirm dialog; on success refetch, on failure surface error + re-enable; row actions disabled during in-flight mutation.
- Standard columns = the existing Orders list resource's fields (resource order/labels); data via that existing resource — no new data layer.
- Accessibility: accessible labels on interactive controls + confirm-dialog buttons.
- Convention followed: project/design-system.md (data-table standing convention) for table mechanics; the existing per-entity Orders list resource for columns + data source.

## Dependencies
- None. Shared primitives and the Orders list resource are existing; no sibling introduces a consumed type/screen. #A–#J independent peers.

## Classification
- Surface: UI
- Risk: light

---

### #C — Build the Products admin list page   [ui, risk:light]   [self-check: PASS]

## Summary
Add the Products admin list page: a table of product records with the standard Products columns and per-row actions (view / edit / delete). The shared `DataTable`/`EmptyState`/confirm-dialog and the Products list resource already exist; this issue adds only the page. Detail/edit pages out of scope.

## Acceptance criteria
- [ ] Happy path: renders products via the shared `DataTable` (`src/components/DataTable.tsx`); every column sortable + filterable EXCEPT the Actions column (no sort, no filter).
- [ ] Columns: standard Products column set — the existing Products list resource's fields, resource order, resource labels — + trailing Actions column. No hand-invented columns.
- [ ] Data source: consumes the existing Products list resource; no new endpoint/type. Server-side pagination/sort/filter delegated via the `DataTable` contract.
- [ ] Pagination: server-side pagination at 30 rows per page, with a page-size control whose options are 30 / 50 / 100 and which defaults to 30.
- [ ] Empty state: shared `EmptyState` illustration + Products CTA ("Add product"), a non-functional placeholder this milestone.
- [ ] Loading state: skeleton rows while loading.
- [ ] Error/failure path: on fetch failure, surface the shared `DataTable` error state.
- [ ] Disabled/edge state: delete opens a confirm dialog (destructive "Delete" default-focus + "Cancel"); on success refetch, on failure surface error + re-enable; row actions disabled during an in-flight mutation (row-level spinner); view/edit render disabled until the detail/edit milestone lands.

## Design (recorded, consistent)
- Mirror the shared `DataTable` at `src/components/DataTable.tsx` — do not hand-roll a table.
- Columns sortable + filterable except the Actions column.
- Server-side pagination at 30 rows/page; page-size control options 30/50/100, default 30.
- Empty state: shared `EmptyState` + Products CTA.
- Loading: skeleton rows.
- Delete destructive → confirm dialog; on success refetch, on failure surface error + re-enable; row actions disabled during in-flight mutation.
- Standard columns = the existing Products list resource's fields (resource order/labels); data via that existing resource — no new data layer.
- Accessibility: accessible labels on interactive controls + confirm-dialog buttons.
- Convention followed: project/design-system.md (data-table standing convention) for table mechanics; the existing per-entity Products list resource for columns + data source.

## Dependencies
- None. Shared primitives and the Products list resource are existing; no sibling introduces a consumed type/screen. #A–#J independent peers.

## Classification
- Surface: UI
- Risk: light

---

### #D — Build the Invoices admin list page   [ui, risk:light]   [self-check: PASS]

## Summary
Add the Invoices admin list page: a table of invoice records with the standard Invoices columns and per-row actions (view / edit / delete). The shared `DataTable`/`EmptyState`/confirm-dialog and the Invoices list resource already exist; this issue adds only the page. Detail/edit pages out of scope.

## Acceptance criteria
- [ ] Happy path: renders invoices via the shared `DataTable` (`src/components/DataTable.tsx`); every column sortable + filterable EXCEPT the Actions column (no sort, no filter).
- [ ] Columns: standard Invoices column set — the existing Invoices list resource's fields, resource order, resource labels — + trailing Actions column. No hand-invented columns.
- [ ] Data source: consumes the existing Invoices list resource; no new endpoint/type. Server-side pagination/sort/filter delegated via the `DataTable` contract.
- [ ] Pagination: server-side pagination at 30 rows per page, with a page-size control whose options are 30 / 50 / 100 and which defaults to 30.
- [ ] Empty state: shared `EmptyState` illustration + Invoices CTA ("Create invoice"), a non-functional placeholder this milestone.
- [ ] Loading state: skeleton rows while loading.
- [ ] Error/failure path: on fetch failure, surface the shared `DataTable` error state.
- [ ] Disabled/edge state: delete opens a confirm dialog (destructive "Delete" default-focus + "Cancel"); on success refetch, on failure surface error + re-enable; row actions disabled during an in-flight mutation (row-level spinner); view/edit render disabled until the detail/edit milestone lands.

## Design (recorded, consistent)
- Mirror the shared `DataTable` at `src/components/DataTable.tsx` — do not hand-roll a table.
- Columns sortable + filterable except the Actions column.
- Server-side pagination at 30 rows/page; page-size control options 30/50/100, default 30.
- Empty state: shared `EmptyState` + Invoices CTA.
- Loading: skeleton rows.
- Delete destructive → confirm dialog; on success refetch, on failure surface error + re-enable; row actions disabled during in-flight mutation.
- Standard columns = the existing Invoices list resource's fields (resource order/labels); data via that existing resource — no new data layer.
- Accessibility: accessible labels on interactive controls + confirm-dialog buttons.
- Convention followed: project/design-system.md (data-table standing convention) for table mechanics; the existing per-entity Invoices list resource for columns + data source.

## Dependencies
- None. Shared primitives and the Invoices list resource are existing; no sibling introduces a consumed type/screen. #A–#J independent peers.

## Classification
- Surface: UI
- Risk: light

---

### #E — Build the Shipments admin list page   [ui, risk:light]   [self-check: PASS]

## Summary
Add the Shipments admin list page: a table of shipment records with the standard Shipments columns and per-row actions (view / edit / delete). The shared `DataTable`/`EmptyState`/confirm-dialog and the Shipments list resource already exist; this issue adds only the page. Detail/edit pages out of scope.

## Acceptance criteria
- [ ] Happy path: renders shipments via the shared `DataTable` (`src/components/DataTable.tsx`); every column sortable + filterable EXCEPT the Actions column (no sort, no filter).
- [ ] Columns: standard Shipments column set — the existing Shipments list resource's fields, resource order, resource labels — + trailing Actions column. No hand-invented columns.
- [ ] Data source: consumes the existing Shipments list resource; no new endpoint/type. Server-side pagination/sort/filter delegated via the `DataTable` contract.
- [ ] Pagination: server-side pagination at 30 rows per page, with a page-size control whose options are 30 / 50 / 100 and which defaults to 30.
- [ ] Empty state: shared `EmptyState` illustration + Shipments CTA ("Create shipment"), a non-functional placeholder this milestone.
- [ ] Loading state: skeleton rows while loading.
- [ ] Error/failure path: on fetch failure, surface the shared `DataTable` error state.
- [ ] Disabled/edge state: delete opens a confirm dialog (destructive "Delete" default-focus + "Cancel"); on success refetch, on failure surface error + re-enable; row actions disabled during an in-flight mutation (row-level spinner); view/edit render disabled until the detail/edit milestone lands.

## Design (recorded, consistent)
- Mirror the shared `DataTable` at `src/components/DataTable.tsx` — do not hand-roll a table.
- Columns sortable + filterable except the Actions column.
- Server-side pagination at 30 rows/page; page-size control options 30/50/100, default 30.
- Empty state: shared `EmptyState` + Shipments CTA.
- Loading: skeleton rows.
- Delete destructive → confirm dialog; on success refetch, on failure surface error + re-enable; row actions disabled during in-flight mutation.
- Standard columns = the existing Shipments list resource's fields (resource order/labels); data via that existing resource — no new data layer.
- Accessibility: accessible labels on interactive controls + confirm-dialog buttons.
- Convention followed: project/design-system.md (data-table standing convention) for table mechanics; the existing per-entity Shipments list resource for columns + data source.

## Dependencies
- None. Shared primitives and the Shipments list resource are existing; no sibling introduces a consumed type/screen. #A–#J independent peers.

## Classification
- Surface: UI
- Risk: light

---

### #F — Build the Refunds admin list page   [ui, risk:light]   [self-check: PASS]

## Summary
Add the Refunds admin list page: a table of refund records with the standard Refunds columns and per-row actions (view / edit / delete). The shared `DataTable`/`EmptyState`/confirm-dialog and the Refunds list resource already exist; this issue adds only the page. Detail/edit pages out of scope.

## Acceptance criteria
- [ ] Happy path: renders refunds via the shared `DataTable` (`src/components/DataTable.tsx`); every column sortable + filterable EXCEPT the Actions column (no sort, no filter).
- [ ] Columns: standard Refunds column set — the existing Refunds list resource's fields, resource order, resource labels — + trailing Actions column. No hand-invented columns.
- [ ] Data source: consumes the existing Refunds list resource; no new endpoint/type. Server-side pagination/sort/filter delegated via the `DataTable` contract.
- [ ] Pagination: server-side pagination at 30 rows per page, with a page-size control whose options are 30 / 50 / 100 and which defaults to 30.
- [ ] Empty state: shared `EmptyState` illustration + Refunds CTA ("Issue refund"), a non-functional placeholder this milestone.
- [ ] Loading state: skeleton rows while loading.
- [ ] Error/failure path: on fetch failure, surface the shared `DataTable` error state.
- [ ] Disabled/edge state: delete opens a confirm dialog (destructive "Delete" default-focus + "Cancel"); on success refetch, on failure surface error + re-enable; row actions disabled during an in-flight mutation (row-level spinner); view/edit render disabled until the detail/edit milestone lands.

## Design (recorded, consistent)
- Mirror the shared `DataTable` at `src/components/DataTable.tsx` — do not hand-roll a table.
- Columns sortable + filterable except the Actions column.
- Server-side pagination at 30 rows/page; page-size control options 30/50/100, default 30.
- Empty state: shared `EmptyState` + Refunds CTA.
- Loading: skeleton rows.
- Delete destructive → confirm dialog; on success refetch, on failure surface error + re-enable; row actions disabled during in-flight mutation.
- Standard columns = the existing Refunds list resource's fields (resource order/labels); data via that existing resource — no new data layer.
- Accessibility: accessible labels on interactive controls + confirm-dialog buttons.
- Convention followed: project/design-system.md (data-table standing convention) for table mechanics; the existing per-entity Refunds list resource for columns + data source.

## Dependencies
- None. Shared primitives and the Refunds list resource are existing; no sibling introduces a consumed type/screen. #A–#J independent peers.

## Classification
- Surface: UI
- Risk: light

---

### #G — Build the Coupons admin list page   [ui, risk:light]   [self-check: PASS]

## Summary
Add the Coupons admin list page: a table of coupon records with the standard Coupons columns and per-row actions (view / edit / delete). The shared `DataTable`/`EmptyState`/confirm-dialog and the Coupons list resource already exist; this issue adds only the page. Detail/edit pages out of scope.

## Acceptance criteria
- [ ] Happy path: renders coupons via the shared `DataTable` (`src/components/DataTable.tsx`); every column sortable + filterable EXCEPT the Actions column (no sort, no filter).
- [ ] Columns: standard Coupons column set — the existing Coupons list resource's fields, resource order, resource labels — + trailing Actions column. No hand-invented columns.
- [ ] Data source: consumes the existing Coupons list resource; no new endpoint/type. Server-side pagination/sort/filter delegated via the `DataTable` contract.
- [ ] Pagination: server-side pagination at 30 rows per page, with a page-size control whose options are 30 / 50 / 100 and which defaults to 30.
- [ ] Empty state: shared `EmptyState` illustration + Coupons CTA ("Create coupon"), a non-functional placeholder this milestone.
- [ ] Loading state: skeleton rows while loading.
- [ ] Error/failure path: on fetch failure, surface the shared `DataTable` error state.
- [ ] Disabled/edge state: delete opens a confirm dialog (destructive "Delete" default-focus + "Cancel"); on success refetch, on failure surface error + re-enable; row actions disabled during an in-flight mutation (row-level spinner); view/edit render disabled until the detail/edit milestone lands.

## Design (recorded, consistent)
- Mirror the shared `DataTable` at `src/components/DataTable.tsx` — do not hand-roll a table.
- Columns sortable + filterable except the Actions column.
- Server-side pagination at 30 rows/page; page-size control options 30/50/100, default 30.
- Empty state: shared `EmptyState` + Coupons CTA.
- Loading: skeleton rows.
- Delete destructive → confirm dialog; on success refetch, on failure surface error + re-enable; row actions disabled during in-flight mutation.
- Standard columns = the existing Coupons list resource's fields (resource order/labels); data via that existing resource — no new data layer.
- Accessibility: accessible labels on interactive controls + confirm-dialog buttons.
- Convention followed: project/design-system.md (data-table standing convention) for table mechanics; the existing per-entity Coupons list resource for columns + data source.

## Dependencies
- None. Shared primitives and the Coupons list resource are existing; no sibling introduces a consumed type/screen. #A–#J independent peers.

## Classification
- Surface: UI
- Risk: light

---

### #H — Build the Reviews admin list page   [ui, risk:light]   [self-check: PASS]

## Summary
Add the Reviews admin list page: a table of review records with the standard Reviews columns and per-row actions (view / edit / delete). The shared `DataTable`/`EmptyState`/confirm-dialog and the Reviews list resource already exist; this issue adds only the page. Detail/edit pages out of scope.

## Acceptance criteria
- [ ] Happy path: renders reviews via the shared `DataTable` (`src/components/DataTable.tsx`); every column sortable + filterable EXCEPT the Actions column (no sort, no filter).
- [ ] Columns: standard Reviews column set — the existing Reviews list resource's fields, resource order, resource labels — + trailing Actions column. No hand-invented columns.
- [ ] Data source: consumes the existing Reviews list resource; no new endpoint/type. Server-side pagination/sort/filter delegated via the `DataTable` contract.
- [ ] Pagination: server-side pagination at 30 rows per page, with a page-size control whose options are 30 / 50 / 100 and which defaults to 30.
- [ ] Empty state: shared `EmptyState` illustration + Reviews CTA ("View flagged reviews"), a non-functional placeholder this milestone.
- [ ] Loading state: skeleton rows while loading.
- [ ] Error/failure path: on fetch failure, surface the shared `DataTable` error state.
- [ ] Disabled/edge state: delete opens a confirm dialog (destructive "Delete" default-focus + "Cancel"); on success refetch, on failure surface error + re-enable; row actions disabled during an in-flight mutation (row-level spinner); view/edit render disabled until the detail/edit milestone lands.

## Design (recorded, consistent)
- Mirror the shared `DataTable` at `src/components/DataTable.tsx` — do not hand-roll a table.
- Columns sortable + filterable except the Actions column.
- Server-side pagination at 30 rows/page; page-size control options 30/50/100, default 30.
- Empty state: shared `EmptyState` + Reviews CTA.
- Loading: skeleton rows.
- Delete destructive → confirm dialog; on success refetch, on failure surface error + re-enable; row actions disabled during in-flight mutation.
- Standard columns = the existing Reviews list resource's fields (resource order/labels); data via that existing resource — no new data layer.
- Accessibility: accessible labels on interactive controls + confirm-dialog buttons.
- Convention followed: project/design-system.md (data-table standing convention) for table mechanics; the existing per-entity Reviews list resource for columns + data source.

## Dependencies
- None. Shared primitives and the Reviews list resource are existing; no sibling introduces a consumed type/screen. #A–#J independent peers.

## Classification
- Surface: UI
- Risk: light

---

### #I — Build the Support Tickets admin list page   [ui, risk:light]   [self-check: PASS]

## Summary
Add the Support Tickets admin list page: a table of support-ticket records with the standard Support Tickets columns and per-row actions (view / edit / delete). The shared `DataTable`/`EmptyState`/confirm-dialog and the Support Tickets list resource already exist; this issue adds only the page. Detail/edit pages out of scope.

## Acceptance criteria
- [ ] Happy path: renders support tickets via the shared `DataTable` (`src/components/DataTable.tsx`); every column sortable + filterable EXCEPT the Actions column (no sort, no filter).
- [ ] Columns: standard Support Tickets column set — the existing Support Tickets list resource's fields, resource order, resource labels — + trailing Actions column. No hand-invented columns.
- [ ] Data source: consumes the existing Support Tickets list resource; no new endpoint/type. Server-side pagination/sort/filter delegated via the `DataTable` contract.
- [ ] Pagination: server-side pagination at 30 rows per page, with a page-size control whose options are 30 / 50 / 100 and which defaults to 30.
- [ ] Empty state: shared `EmptyState` illustration + Support Tickets CTA ("Open ticket"), a non-functional placeholder this milestone.
- [ ] Loading state: skeleton rows while loading.
- [ ] Error/failure path: on fetch failure, surface the shared `DataTable` error state.
- [ ] Disabled/edge state: delete opens a confirm dialog (destructive "Delete" default-focus + "Cancel"); on success refetch, on failure surface error + re-enable; row actions disabled during an in-flight mutation (row-level spinner); view/edit render disabled until the detail/edit milestone lands.

## Design (recorded, consistent)
- Mirror the shared `DataTable` at `src/components/DataTable.tsx` — do not hand-roll a table.
- Columns sortable + filterable except the Actions column.
- Server-side pagination at 30 rows/page; page-size control options 30/50/100, default 30.
- Empty state: shared `EmptyState` + Support Tickets CTA.
- Loading: skeleton rows.
- Delete destructive → confirm dialog; on success refetch, on failure surface error + re-enable; row actions disabled during in-flight mutation.
- Standard columns = the existing Support Tickets list resource's fields (resource order/labels); data via that existing resource — no new data layer.
- Accessibility: accessible labels on interactive controls + confirm-dialog buttons.
- Convention followed: project/design-system.md (data-table standing convention) for table mechanics; the existing per-entity Support Tickets list resource for columns + data source.

## Dependencies
- None. Shared primitives and the Support Tickets list resource are existing; no sibling introduces a consumed type/screen. #A–#J independent peers.

## Classification
- Surface: UI
- Risk: light

---

### #J — Build the Audit Log admin list page   [ui, risk:light]   [self-check: PASS]

## Summary
Add the Audit Log admin list page: a table of audit-log records with the standard Audit Log columns and per-row actions (view / edit / delete), matching the brief's uniform treatment of all 10 list pages. The shared `DataTable`/`EmptyState`/confirm-dialog and the Audit Log list resource already exist; this issue adds only the page. Detail/edit pages out of scope.

## Acceptance criteria
- [ ] Happy path: renders audit-log entries via the shared `DataTable` (`src/components/DataTable.tsx`); every column sortable + filterable EXCEPT the Actions column (no sort, no filter).
- [ ] Columns: standard Audit Log column set — the existing Audit Log list resource's fields, resource order, resource labels — + trailing Actions column. No hand-invented columns.
- [ ] Data source: consumes the existing Audit Log list resource; no new endpoint/type. Server-side pagination/sort/filter delegated via the `DataTable` contract.
- [ ] Pagination: server-side pagination at 30 rows per page, with a page-size control whose options are 30 / 50 / 100 and which defaults to 30.
- [ ] Empty state: shared `EmptyState` illustration + Audit Log CTA ("View activity"), a non-functional placeholder this milestone.
- [ ] Loading state: skeleton rows while loading.
- [ ] Error/failure path: on fetch failure, surface the shared `DataTable` error state.
- [ ] Disabled/edge state: delete opens a confirm dialog (destructive "Delete" default-focus + "Cancel"); on success refetch, on failure surface error + re-enable; row actions disabled during an in-flight mutation (row-level spinner); view/edit render disabled until the detail/edit milestone lands.

## Design (recorded, consistent)
- Mirror the shared `DataTable` at `src/components/DataTable.tsx` — do not hand-roll a table.
- Columns sortable + filterable except the Actions column.
- Server-side pagination at 30 rows/page; page-size control options 30/50/100, default 30.
- Empty state: shared `EmptyState` + Audit Log CTA.
- Loading: skeleton rows.
- Delete destructive → confirm dialog; on success refetch, on failure surface error + re-enable; row actions disabled during in-flight mutation.
- Standard columns = the existing Audit Log list resource's fields (resource order/labels); data via that existing resource — no new data layer.
- Row actions view/edit/delete per the brief's uniform treatment of all 10 pages (the brief lists view/edit/delete for every entity, including Audit Log).
- Accessibility: accessible labels on interactive controls + confirm-dialog buttons.
- Convention followed: project/design-system.md (data-table standing convention) for table mechanics; the existing per-entity Audit Log list resource for columns + data source; brief.md for the uniform view/edit/delete row-action set.

## Dependencies
- None. Shared primitives and the Audit Log list resource are existing; no sibling introduces a consumed type/screen. #A–#J independent peers.

## Classification
- Surface: UI
- Risk: light

## Parked issues
None.

## Dropped issues
None.

## Project-docs grounding
- Standing table directive (sortable+filterable-except-Actions; server-side pagination at the literal 30 rows/page, page-size default 30; shared `EmptyState` + entity CTA; skeleton-row loading; shared `DataTable` reuse) — grounded in project/design-system.md (data-table standing convention). Propagated, complete and unweakened, into ALL 10 page-issues (#A–#J), each carrying the literal 30/page and citing project/design-system.md on a `Convention followed:` line.
- Per-entity column set + data source — grounded in each entity's existing list resource (resource fields/order/labels; read via the existing data-access resource; no new endpoint/type). The brief scopes only the 10 list pages; per-entity resources pre-exist.
- Uniform view/edit/delete row-action set (including for the Audit Log) — grounded in brief.md; kept as stated, not weakened/carved-out (carving it would invent product scope).
- Page-size option set 30/50/100 (default 30) — additive over the directive's stated default; recorded uniformly on all 10 to keep the sibling pages consistent. The literal default 30 is preserved on every issue.
- Degradations: none. uiSurfaceGlobs is set → all 10 candidates classify as UI and the design-reviewer engaged on each.

## Needs human input
None — productGaps is empty and no issue parked as needs-human-direction.

---
This plan file is the build artifact — run `/milestone-feeder:create` to deploy it to GitHub (it ensures the labels, creates-or-adopts the milestone by the exact title above, opens each surviving issue, rewrites the slug references to real issue numbers, and patches the milestone description with the Wave order). `plan` wrote no GitHub state.
