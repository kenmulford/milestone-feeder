# Milestone plan (PREVIEW) — Build the 10 admin list pages (standard data-table per entity)

Self-check: PASS — all 10 issues GAPS: none (milestone-driver reviewers). #B (Orders) required 1 of ≤2 re-authors to clear a triage Blocker (Order data-access contract) — cleared on re-triage. Every UI issue passed the real `milestone-driver:design-reviewer` with the FULL table directive present and UNWEAKENED.
Source brief: file:tests/scenarios/06-cross-cutting-consistency/brief.md

## Milestone description (preview)

Build the 10 admin list pages — one per entity (Users, Orders, Products, Invoices, Shipments, Refunds, Coupons, Reviews, Support Tickets, Audit Log). Each page renders its entity's records in a standard data table with view/edit/delete row actions, reusing the shared `DataTable` component (`src/components/DataTable.tsx`) and conforming to the standing data-table convention (`project/design-system.md`): every column sortable + filterable except Actions, server-side pagination at 30 rows per page with a page-size control defaulting to 30, a shared `EmptyState` empty view, and skeleton-row loading. The detail/edit pages behind the row actions are out of scope (a separate milestone).

## Waves
- Wave 1 (parallel): #A, #B, #C, #D, #E, #F, #G, #H, #I, #J

## Issues

### #A — Build the Users admin list page   [ui, risk:heavy]   [self-check: PASS]
## Summary
Add the Users admin list page under `src/pages/**` so administrators can browse Users records in a standard, paginated table with per-column sorting and filtering and per-row view/edit/delete actions. The page reuses the shared `DataTable` component and conforms to the standing data-table design convention so it behaves identically to every other admin list page.

## Acceptance criteria
- [ ] Happy path: the page renders a `DataTable` of Users records with the standard Users columns plus a trailing row-actions column exposing view, edit, and delete actions; every data column is sortable and has a column filter; pagination is server-side at 30 rows per page with a page-size control defaulting to 30.
- [ ] Empty state: when there are no Users records, the page shows the shared `EmptyState` illustration plus a primary CTA (per convention). (CTA exact label/target is a parked product detail — see Design.)
- [ ] Loading state: while the page loads, the table shows skeleton rows (no spinner, no blank screen).
- [ ] Error / failure path: when the records request fails, the page shows a non-blocking error state with a retry affordance instead of skeleton rows or an empty table.
- [ ] Disabled / edge state: the row-actions column is neither sortable nor filterable (no sort control, no column filter on Actions); the delete action requires an explicit confirmation affordance before deletion; all interactive controls (sort toggles, column filters, row-action buttons) carry accessibility labels.

## Design (recorded, consistent)
- Page lives under `src/pages/**` (uiSurfaceGlobs) and renders the Users entity; it reuses the shared `DataTable` component rather than hand-rolling a table.
- Column rules (full convention, unweakened): every data column is sortable AND has a column filter; the trailing row-actions (Actions) column is the sole exception — no sort, no filter.
- Pagination: server-side at exactly 30 rows per page, with a page-size control whose default is 30.
- Empty state: render the shared `EmptyState` illustration plus a primary CTA relevant to the Users entity. The empty-state BEHAVIOR (illustration + a primary CTA) is grounded by the convention and is required. PARKED PRODUCT DETAIL: the CTA's exact label and navigation target are undefined this milestone (the create/detail destinations are out of scope), so the implementer renders the CTA slot per convention and does not invent its final wording/target.
- Loading state: skeleton rows while the page loads (the `DataTable` skeleton mode), not a spinner.
- Row actions: view / edit / delete per row. Delete is destructive and therefore requires a confirmation affordance (e.g., a confirm dialog) before the record is deleted.
- Accessibility: every interactive element — per-column sort toggles, per-column filter inputs, and the view/edit/delete row-action buttons — carries an accessibility label.
- The view/edit/delete destinations (detail and edit pages) are out of scope for this milestone.
- Convention followed: `project/design-system.md` ("Design system — data tables (standing convention)"); `src/components/DataTable.tsx` is the shared component to reuse.

## Dependencies
- None

## Classification
- Surface: UI
- Risk: heavy

---

### #B — Build the Orders admin list page   [ui, risk:heavy]   [self-check: PASS (re-authored ×1)]
## Summary
Add the Orders admin list page: a server-side-paginated, sortable, filterable table of Orders with per-row view/edit/delete actions, built by reusing the shared `DataTable` component. The page reads the existing Order entity's standard fields as its column set and consumes the existing entity data-access layer the shared `DataTable` is wired to for its list fetch and delete mutation. This gives admins a consistent, conventional surface for browsing and managing Orders, matching every other admin list page in the app.

## Acceptance criteria
- [ ] Happy path: the page renders the Orders as a `DataTable` of the Order entity's standard columns, with server-side pagination at exactly 30 rows per page and a page-size control defaulting to 30; every column is sortable and has a column filter EXCEPT the row-actions column (no sort, no filter on Actions); each row exposes view, edit, and delete actions.
- [ ] Empty state: when the list fetch returns zero rows, the page shows the shared `EmptyState` illustration plus a primary CTA relevant to Orders (exact CTA label/target parked — see Design; behavior = render the shared `EmptyState` with a single primary CTA affordance).
- [ ] Loading state: while the list fetch is in flight, the table shows skeleton rows (the `DataTable` loading state).
- [ ] Error/failure path: when the list fetch fails, the page surfaces the `DataTable`'s error state rather than skeleton rows or an empty table; sort/filter/page changes that fail re-surface the same error state without losing the current query parameters.
- [ ] Disabled/edge + destructive: the delete row action is destructive and is gated behind a confirm affordance before the delete mutation fires; while the delete mutation is in flight the triggering row action is disabled to prevent double-submit, and on mutation success the list re-fetches (returning to the empty state if it was the last row) while on mutation failure the error state is surfaced and the row remains.

## Design (recorded, consistent)
- Reuse the shared `DataTable` component (`src/components/DataTable.tsx`) — do not hand-roll the table. Pattern to mirror for table presentation, the loading/empty/error states, and the server-side data wiring.
- Columns: the Order entity's standard columns ARE the existing fields of the Order model/type that lives in the target repo under `sourceGlobs` (`src/**`). The page does not define a bespoke column set — it reads the entity's existing fields as the column set, per the brief's "standard columns for that entity" directive. Every column is sortable and filterable EXCEPT the row-actions column.
- Data-access contract (the existing layer the page consumes — NOT a new bespoke endpoint):
  - List fetch: consumed via the existing Order-entity data-access path under `sourceGlobs` (`src/**`) that the shared `DataTable` is wired to. Because the standing convention mandates server-side pagination, the fetch is driven through the shared `DataTable`'s documented server-side data interface, passing the server-side pagination params (page + page size, defaulting to 30/page), the server-side sort param (active column + direction), and the server-side filter params (per-column filters). Reuses the existing entity data-access pattern; no new request shape.
  - Delete mutation: consumed via the same existing Order-entity data-access layer the `DataTable` row actions are wired to. The delete action calls the entity's existing delete mutation for the selected Order id; on success the list re-fetches (preserving the current page/sort/filter), on failure the `DataTable` error state is surfaced and the row is retained.
- Pagination: server-side, exactly 30 rows per page, with a page-size control defaulting to 30.
- Row actions column: view, edit, delete. The actions column is not sortable and not filterable.
- Destructive affordance: delete is destructive → it requires a confirm affordance (confirm step before the mutation fires); the row's delete control is disabled while its mutation is in flight.
- States to render: empty = shared `EmptyState` illustration + primary CTA relevant to Orders; loading = skeleton rows; error = the `DataTable` error state for both the initial fetch and subsequent sort/filter/page/delete failures.
- Accessibility: each interactive element carries an accessibility label — the column sort controls, the per-column filter inputs, the page-size control, the pagination controls, and each row action (view/edit/delete order); the destructive delete confirm affordance is announced as a confirmation.
- Convention followed: project/design-system.md "data tables (standing convention)" — sortable+filterable columns EXCEPT Actions; server-side pagination 30/page with page-size control default 30; empty = shared `EmptyState` + primary CTA; loading = skeleton rows; reuse shared `DataTable` (`src/components/DataTable.tsx`).
- Convention followed: brief directive "standard columns for that entity" + `sourceGlobs` (`src/**`) — the Order type/columns are sourced from the existing Order model/type in the target repo, and the list-fetch and delete-mutation contracts are the existing Order-entity data-access pattern under `src/**` that the shared `DataTable`'s server-side data interface already supports (no new bespoke endpoint).

## Dependencies
- None. (No decomposer edge touches this candidate.)

## Classification
- Surface: UI
- Risk: heavy

---

### #C — Build the Products admin list page   [ui, risk:heavy]   [self-check: PASS]
## Summary
Add a Products admin list page under `src/pages/**` that renders the standard Products records in a table with view/edit/delete row actions. The page reuses the shared `DataTable` component (`src/components/DataTable.tsx`) and follows the standing data-tables convention from `project/design-system.md` (sortable/filterable columns except Actions, server-side pagination at 30 rows/page with a page-size control defaulting to 30, `EmptyState` illustration + primary CTA on empty, skeleton rows while loading). Detail and edit pages are out of scope.

## Acceptance criteria
- [ ] Happy path: Given Products records exist, when the page loads, then `DataTable` renders the standard Products columns (every column sortable and filterable EXCEPT the Actions column) with server-side pagination at exactly 30 rows/page and a page-size control defaulting to 30; each row exposes view, edit, and delete actions.
- [ ] Empty: Given zero Products records, when the page loads, then the shared `EmptyState` illustration renders with a primary CTA relevant to Products (exact label/target parked — see Design); the table chrome (pagination/filters) is not shown.
- [ ] Error/failure: Given the Products fetch fails, when the page loads, then `DataTable` surfaces its standard error state in place of rows (no skeleton, no empty illustration) and does not crash the page.
- [ ] Disabled/edge: Given the delete row action is invoked, when the user clicks Delete, then a confirmation affordance is presented before any destructive action; while a page of records is loading, skeleton rows are shown in place of data rows and row actions are not actionable.

## Design (recorded, consistent)
- Mirror the shared data-tables pattern: render via the shared `DataTable` component at `src/components/DataTable.tsx` — do not hand-roll a table.
- Columns: standard Products columns; every column sortable + filterable EXCEPT the Actions column (Actions is neither sortable nor filterable).
- Pagination: server-side, exactly 30 rows/page; page-size control present and defaulting to 30.
- States — empty: shared `EmptyState` illustration + a primary CTA relevant to Products. The empty-state BEHAVIOR is grounded and recorded here; the CTA's exact label and navigation target are PARKED (product gap) and must be resolved before implementation finalizes the CTA wiring.
- States — loading: skeleton rows (per convention).
- States — error: `DataTable`'s standard error state.
- States — disabled: during loading, row actions are not actionable (skeleton rows only).
- Affordances: view, edit, delete row actions. Delete is destructive and MUST present a confirmation affordance before deleting.
- Accessibility: the table and each row action carry accessible labels (e.g., per-row "View {product}", "Edit {product}", "Delete {product}"); the confirmation affordance is reachable and labeled.
- Convention followed: project/design-system.md

## Dependencies
None.

## Classification
- Surface: UI
- Risk: heavy

---

### #D — Build the Invoices admin list page   [ui, risk:heavy]   [self-check: PASS]
## Summary
Add an Invoices admin list page under `src/pages/**` that renders the standard Invoices columns in a table with per-row view/edit/delete actions. The page reuses the shared `DataTable` component (`src/components/DataTable.tsx`) and follows the standing data-table convention in `project/design-system.md` — sortable + filterable columns (except Actions), server-side pagination at 30 rows/page, skeleton-row loading, and a shared `EmptyState` with a primary CTA. Detail and edit pages are out of scope.

## Acceptance criteria
### Happy path
- The page lives under `src/pages/**` and renders the standard Invoices columns plus an Actions column.
- Rows are loaded via server-side pagination at exactly 30 rows/page; the page-size control is present and defaults to 30.
- Every column is sortable AND filterable EXCEPT the Actions column, which is neither sortable nor filterable.
- Each row exposes view, edit, and delete actions.
- The table is rendered through the shared `DataTable` component (`src/components/DataTable.tsx`); the table is not hand-rolled.
### Empty state
- When the query returns zero invoices, the page renders the shared `EmptyState` illustration plus a primary CTA relevant to invoices (per `project/design-system.md`).
- The exact CTA label and navigation target are NOT specified by this issue (parked product gap) and must not be invented; wire the CTA slot but leave label/target to be resolved before implementation closes.
### Loading state
- While a page of invoices is being fetched (initial load and on page/sort/filter changes), the table shows skeleton rows per the convention.
### Error / failure state
- When the server request for a page of invoices fails, the page surfaces an error state instead of a stuck skeleton or a misleading empty state, with a way to retry the failed fetch.
### Disabled / edge cases
- The delete row action is destructive and MUST present a confirmation affordance before deleting; dismissing the confirmation performs no deletion.
- The Actions column is excluded from sort and filter affordances (it offers neither a sort control nor a filter input).
- On the last/partial page (fewer than 30 rows) pagination controls reflect that there is no next page.

## Design
- Surface: UI. Mirror the existing data-table usage pattern of the shared component at `src/components/DataTable.tsx` rather than building a new table.
- States: empty → shared `EmptyState` illustration + primary CTA (CTA specifics parked, see Dependencies); loading → skeleton rows; error → error state with retry; disabled → delete gated behind a confirmation affordance.
- Affordances: row-level view / edit / delete controls; delete is destructive and requires an explicit confirm step (e.g. confirmation dialog) with cancel; pagination control and page-size control (default 30); per-column sort and filter affordances on all columns except Actions.
- Accessibility: row action controls carry descriptive accessible labels that name the action and identify the invoice row (e.g. "Delete invoice {identifier}", "Edit invoice {identifier}", "View invoice {identifier}"); the destructive-action confirmation is focusable and announced; sort/filter controls carry accessible labels naming their column.
- Convention followed: project/design-system.md

## Dependencies
- Reuses the shared `DataTable` component at `src/components/DataTable.tsx` (no hand-rolled table).
- Follows the standing data-table convention in `project/design-system.md`.
- Product gap (parked, non-blocking for authoring): the empty-state primary CTA's exact label and navigation target are not yet specified. The empty-state behavior is grounded; only the CTA label/target specifics are parked.
- No cross-issue dependency edges touch this candidate.

## Classification
- Surface: UI (matches `uiSurfaceGlobs` `src/pages/**`, `src/components/**`)
- Risk: heavy

---

### #E — Build the Shipments admin list page   [ui, risk:heavy]   [self-check: PASS]
## Summary
Add a Shipments admin list page under `src/pages/**` that displays shipments in a table with view, edit, and delete row actions. The page mirrors the standing data-table convention in `project/design-system.md` and reuses the shared `DataTable` component at `src/components/DataTable.tsx` rather than hand-rolling a table. Scope is the list page only; shipment detail and edit pages are out of scope.

## Acceptance criteria
### Happy path
- The page renders the shared `DataTable` (`src/components/DataTable.tsx`) populated with standard Shipments columns.
- Every column is both sortable and filterable EXCEPT the Actions column, which is neither sortable nor filterable.
- Pagination is server-side at exactly 30 rows per page, with a page-size control whose default value is 30.
- Each row exposes view, edit, and delete actions in the Actions column.
- The view/edit actions invoke navigation toward the (out-of-scope) detail/edit destinations.
### Empty state
- When the shipments query returns zero rows, the page renders the shared `EmptyState` illustration plus a primary CTA relevant to Shipments, per `project/design-system.md`.
- The exact CTA label and target are parked. The empty-state BEHAVIOR (shared `EmptyState` illustration + a primary CTA) is required and in scope; only the CTA's specific label/target is deferred.
### Loading state
- While the shipments query is in flight, the table shows skeleton rows (per the convention's loading treatment), not a blank table or a spinner-only state.
### Error / failure state
- When the shipments query fails, the page surfaces an error treatment (not a silent blank table) and does not render skeleton rows indefinitely.
- When a delete action fails, the page surfaces the failure and the row remains present (the delete is not optimistically dropped from the table on error).
### Disabled / edge
- The delete action is destructive and MUST present a confirmation affordance before deletion is performed; dismissing the confirmation performs no deletion and leaves the row unchanged.
- The Actions column is excluded from sort and filter affordances entirely (no sort caret, no filter input on that column header).
- Changing the page-size control re-queries server-side and resets to a valid page within the new page size.

## Design
- Surface: UI page under `src/pages/**`, reusing `src/components/DataTable.tsx`.
- Pattern to mirror: the "data tables (standing convention)" section of `project/design-system.md` — sortable + filterable columns except Actions, server-side pagination at 30/page with a page-size control defaulting to 30, shared `EmptyState` illustration + primary CTA for empty, skeleton rows for loading, and mandatory reuse of `DataTable` (`src/components/DataTable.tsx`).
- States to implement: empty (shared `EmptyState` + primary CTA), loading (skeleton rows), error (non-silent error treatment for load failure and for delete failure), disabled/edge (confirm-before-delete; Actions column excluded from sort/filter).
- Affordances: per-row view / edit / delete actions; delete is destructive and requires an explicit confirmation step (confirm dialog or equivalent) before performing the deletion.
- Accessibility: row action controls carry accessible labels naming both the action and the row subject (e.g. "Delete shipment", "Edit shipment", "View shipment"); the delete confirmation is reachable and operable via keyboard and screen reader; sortable/filterable column headers expose their sort/filter state to assistive technology.
- Convention followed: project/design-system.md
- Component reused: src/components/DataTable.tsx

## Dependencies
- None. (No edges touch this candidate.)
- Parked product detail (non-blocking): the empty-state primary CTA's exact label and navigation target are deferred; the empty-state behavior is grounded and required.

## Classification
- Surface: UI (matches `uiSurfaceGlobs`: `src/pages/**`, `src/components/**`)
- Risk: heavy

---

### #F — Build the Refunds admin list page   [ui, risk:heavy]   [self-check: PASS]
## Summary
Add a Refunds admin list page so operators can browse, inspect, and manage refund records from one screen. The page renders the standard Refunds columns in a sortable, filterable, server-paginated table and exposes per-row view / edit / delete actions. It is grounded in the standing data-table convention and reuses the shared `DataTable` component rather than hand-rolling a table.

## Acceptance criteria
- [ ] Happy: navigating to the Refunds list page renders the standard Refunds columns in the shared `DataTable`, with server-side pagination at exactly 30 rows/page and a page-size control defaulting to 30; every column is sortable AND filterable except the Actions column, which is neither sortable nor filterable.
- [ ] Happy: each row exposes view, edit, and delete actions in the Actions column.
- [ ] Empty: when the refunds query returns zero rows, the page renders the shared `EmptyState` illustration plus a primary CTA relevant to refunds (CTA exact label/target parked — see Design), and renders no table rows.
- [ ] Loading: while the refunds page (or page-size/sort/filter change) is in flight, the table shows skeleton rows in place of data.
- [ ] Error / failure: when the refunds fetch fails, the page surfaces the table's error state instead of rows or the empty state, and offers a retry path; a failed delete leaves the row present and surfaces the failure (no optimistic removal of a row whose delete did not succeed).
- [ ] Disabled / edge: the delete row action is destructive and requires an explicit confirm affordance before the delete is issued; cancelling the confirm performs no mutation and leaves the row unchanged.
- [ ] Accessibility: each row action carries an accessible label that identifies both the action and its row subject (e.g. "View refund", "Edit refund", "Delete refund"); the confirm affordance is reachable and labeled for assistive tech.

## Design (recorded, consistent)
Implements the standing data-table convention for the Refunds entity:
- Table: reuse the shared `DataTable` (`src/components/DataTable.tsx`) — do not hand-roll a table.
- Columns: standard Refunds columns plus a trailing Actions column. Every column is sortable AND filterable EXCEPT the Actions column, which is neither.
- Pagination: server-side, exactly 30 rows/page, with a page-size control whose default is 30.
- Empty state: shared `EmptyState` illustration plus a primary CTA relevant to refunds. The empty-state BEHAVIOR (illustration + a primary CTA) is fixed by the convention and recorded here; the CTA's exact label and navigation target are parked as a product decision and are intentionally not invented here.
- Loading: skeleton rows (the convention's loading treatment).
- Row actions: view, edit, delete. Delete is destructive and gated behind a confirm affordance (e.g. a confirmation dialog) before any mutation.
- States to mirror via the shared component: empty (`EmptyState` + CTA), loading (skeleton rows), error (table error + retry), and the disabled/no-op path when a destructive confirm is cancelled.
- Accessibility: per-action accessible labels naming the action and row subject; labeled confirm affordance.
- Pattern to mirror: the data-table standing convention as defined in `project/design-system.md` ("data tables (standing convention)"), realized through `src/components/DataTable.tsx`.
- Out of scope: the refund detail and edit pages.
- Convention followed: project/design-system.md ("data tables (standing convention)"); shared component `src/components/DataTable.tsx`; shared empty state `EmptyState`.

## Dependencies
- None.

## Classification
- Surface: UI
- Risk: heavy

---

### #G — Build the Coupons admin list page   [ui, risk:heavy]   [self-check: PASS]
## Summary
Add a Coupons admin list page under `src/pages/**` that displays coupons in a standard entity table with per-row view/edit/delete actions. The page must reuse the shared `DataTable` component (`src/components/DataTable.tsx`) and follow the standing data-tables convention in `project/design-system.md`. Detail and edit pages are out of scope for this issue.

## Acceptance criteria
### Happy path
- The Coupons list page renders standard Coupons columns plus an Actions column (view / edit / delete row actions).
- Every column is sortable AND filterable EXCEPT the Actions column, per `project/design-system.md`.
- Pagination is server-side at EXACTLY 30 rows per page, with a page-size control that defaults to 30 (per `project/design-system.md`).
- The page is built on the shared `DataTable` component at `src/components/DataTable.tsx` — no hand-rolled table.
- Sorting, filtering, and pagination requests are issued server-side (the table does not sort/filter/paginate already-fetched data client-side).
### Empty path
- When the coupons query returns zero rows, render the shared `EmptyState` illustration plus a primary CTA relevant to coupons, per `project/design-system.md`.
- NOTE: the exact CTA label and navigation target are NOT yet specified (parked product gap). The empty state must render the `EmptyState` illustration + a primary CTA slot; wire the CTA's final label/target when product specifies them. Do not invent a label/target.
### Loading path
- While the coupons query is in flight, render skeleton rows in the table, per `project/design-system.md`.
### Error / failure path
- When the coupons query fails, the table does not render skeleton rows indefinitely and does not show the empty state; surface a load-failure affordance (error surface) instead of silently rendering an empty table.
- When a delete row action fails, the row is not removed from the table and the failure is surfaced to the user; the table remains in its pre-delete state.
### Disabled / edge path
- The Actions column is neither sortable nor filterable.
- The delete row action is destructive and MUST present a confirmation affordance before deleting; deletion only proceeds on explicit confirmation, and is abandoned with no change on cancel.
- The page-size control offers selectable page sizes and resets to / defaults to 30; changing page size re-issues a server-side query.

## Design
- Mirror the standing data-tables pattern defined in `project/design-system.md` and implement it via the shared component at `src/components/DataTable.tsx` (do not hand-roll a table).
- States to honor on the table surface:
  - empty → shared `EmptyState` illustration + primary CTA (CTA label/target parked; render the slot)
  - loading → skeleton rows
  - error → load-failure affordance (not skeleton, not empty state)
  - disabled → Actions column not sortable/filterable
- Affordances:
  - view / edit / delete row actions per row
  - delete is destructive → MUST show a confirmation affordance (e.g. confirm dialog) before removing; cancel makes no change
  - page-size control defaulting to 30
- Accessibility:
  - the Actions column and each row action (view / edit / delete) carry accessible labels (e.g. "View coupon", "Edit coupon", "Delete coupon")
  - the destructive-delete confirmation affordance is reachable and labeled for assistive tech
- Convention followed: project/design-system.md

## Dependencies
None.

## Classification
- Surface: UI (page lives under `src/pages/**`; component under `src/components/**` — both in `uiSurfaceGlobs`).
- Risk: heavy
- Non-negotiables: React 18 + TypeScript.

---

### #H — Build the Reviews admin list page   [ui, risk:heavy]   [self-check: PASS]
## Summary
Add a Reviews admin list page under `src/pages/**` that displays Reviews in the shared data table with standard Reviews columns and per-row view/edit/delete actions. The page mirrors the standing data-table convention (`project/design-system.md`) and reuses the shared `DataTable` component (`src/components/DataTable.tsx`) — no hand-rolled table. Detail and edit pages are out of scope; the edit/view row actions navigate to those pages (owned elsewhere) and are not implemented here.

## Acceptance criteria
### Happy path
- The Reviews list page renders the shared `DataTable` (`src/components/DataTable.tsx`) populated with standard Reviews columns plus a trailing Actions column.
- Every column is sortable and filterable EXCEPT the Actions column, which is neither sortable nor filterable.
- Pagination is server-side at exactly 30 rows per page, with a page-size control defaulting to 30.
- Each row exposes view, edit, and delete actions.
### Empty state
- When the query returns zero Reviews, the page shows the shared `EmptyState` illustration plus a primary CTA relevant to Reviews (per `project/design-system.md`).
- The exact CTA label and navigation target are NOT specified here (see Dependencies — parked product gap); render the CTA per the shared `EmptyState` contract once the label/target is decided.
### Error / failure path
- When the Reviews fetch fails, the page surfaces a fetch-failure state rather than an empty table or a perpetual skeleton.
- A delete that fails surfaces a delete-failure message and leaves the row present (no optimistic removal that strands the user on a deleted-but-still-present row).
### Loading / disabled / edge
- While Reviews are loading, the table shows skeleton rows (not a blank table or spinner-only state).
- The delete row action is destructive and MUST require a confirmation affordance before deleting; cancelling the confirmation performs no mutation.
- Sort/filter/pagination controls are disabled (or otherwise non-interactive) while a fetch is in flight, so they cannot be triggered against stale/loading data.

## Design
- UI page under `src/pages/**`; mirror the standing data-table pattern documented in `project/design-system.md` and reuse `src/components/DataTable.tsx` rather than hand-rolling a table.
- States to implement: empty (shared `EmptyState` illustration + primary Reviews CTA), loading (skeleton rows), error (fetch-failure surface; delete-failure message), disabled (controls non-interactive while a fetch is in flight; confirmation-driven delete).
- Affordances: per-row view / edit / delete; delete is destructive and requires a confirm affordance (cancel = no mutation).
- Accessibility: the table and its controls carry accessible labels; each row action (view/edit/delete) has an accessible label that identifies both the action and its target Review; the delete confirmation is announced/labelled as a destructive confirmation.
- Convention followed: project/design-system.md
- Reference component: `src/components/DataTable.tsx`.

## Dependencies
- None (no edges recorded for this candidate).
- Parked product gap: the empty-state CTA exact label and navigation target are not yet decided. Empty-state BEHAVIOR is grounded and in scope; only the CTA label/target specifics are parked.
- Out of scope: Reviews detail and edit pages.

## Classification
- Surface: UI (`src/pages/**`, `src/components/**`)
- Risk: heavy

---

### #I — Build the Support Tickets admin list page   [ui, risk:heavy]   [self-check: PASS]
## Summary
Add a Support Tickets admin list page under `src/pages/**` that renders existing support tickets in the shared data table with per-row view/edit/delete actions. The page mirrors the standing data-table convention (`project/design-system.md`) and reuses the shared `DataTable` component (`src/components/DataTable.tsx`) — no hand-rolled table. Scope is the list page only; ticket detail and edit pages are out of scope (the row actions navigate/trigger but their target pages are owned by separate issues).

## Acceptance criteria
### Happy path
- The page lives under `src/pages/**` and renders the shared `DataTable` (`src/components/DataTable.tsx`); the table is not hand-rolled.
- Standard Support Tickets columns are shown (e.g. ticket ID/reference, subject, requester, status, priority, assignee, created/updated timestamps), plus a trailing Actions column.
- Every data column is sortable and filterable. The Actions column is neither sortable nor filterable.
- Server-side pagination is used at exactly 30 rows per page, and the page-size control defaults to 30.
- Each row exposes three actions: View, Edit, and Delete.
- View and Edit are affordances that target the ticket's detail/edit destinations (target pages out of scope for this issue).
### Empty state
- When there are zero support tickets, the table is replaced by the shared `EmptyState` illustration plus a single primary CTA relevant to support tickets, per `project/design-system.md`.
- The exact CTA label and navigation target are NOT specified here (see Dependencies — product gap) and must not be invented; wire the CTA slot per the convention and leave the label/target to be filled once resolved.
### Loading state
- While the first page (or any page) of rows is being fetched server-side, the table body shows skeleton rows per the convention.
### Error / failure state
- When the server-side fetch (initial load, pagination, sort, or filter) fails, the page surfaces a non-destructive error affordance in place of rows (not a blank table) and offers a retry; no partial/stale rows are presented as if successful.
### Disabled / edge
- The Delete action is destructive and MUST present a confirmation affordance before deletion is performed; dismissing the confirmation performs no deletion.
- The Actions column is excluded from sort and filter affordances entirely (no sort caret, no filter input on that column header).
- Sorting/filtering operate against the server (server-side), consistent with server-side pagination; client-only sort/filter of the current page is not used.

## Design
- Mirror the standing data-table pattern defined in `project/design-system.md` ("data tables (standing convention)") and reuse `src/components/DataTable.tsx`; do not hand-roll a table.
- Columns: every column sortable + filterable EXCEPT the trailing Actions column.
- Pagination: server-side, exactly 30 rows/page; page-size control defaults to 30.
- Empty state: shared `EmptyState` illustration + one primary CTA relevant to support tickets (CTA label/target parked — see Dependencies).
- Loading: skeleton rows.
- Error: in-table error affordance with retry; never blank, never stale-as-success.
- Row actions: View / Edit / Delete. Delete is destructive → confirmation affordance required before performing the delete; dismiss = no-op.
- States to honor: empty (EmptyState + CTA), loading (skeleton rows), error (error + retry), disabled/edge (Actions column never sortable/filterable; destructive Delete gated behind confirm).
- Accessibility: the Actions column header carries an accessible label; each row action (View/Edit/Delete) carries an accessible name scoped to its row/ticket so the control is unambiguous to assistive tech; the destructive Delete confirmation is reachable and operable via keyboard and announced to assistive tech.
- Convention followed: project/design-system.md
- Pattern to mirror: `src/components/DataTable.tsx` (shared data-table component) as configured by `project/design-system.md`.

## Dependencies
- None.
- Product gap (non-blocking for this surface): the empty-state primary CTA's exact label and navigation target are parked/unresolved. The empty-state BEHAVIOR is grounded in `project/design-system.md` and is implemented here; only the CTA's concrete label/target remain to be filled once resolved.

## Classification
- Surface: UI (page under `src/pages/**`, component under `src/components/**`)
- Risk: heavy

---

### #J — Build the Audit Log admin list page   [ui, risk:heavy]   [self-check: PASS]
## Summary
Add an Audit Log admin list page under `src/pages/**` that renders audit records in a standard entity table, reusing the shared `DataTable` component per the standing data-tables convention. Scope is the list page only; record detail and edit pages are out of scope.

## Acceptance criteria
### Happy path
- The page renders the audit records in the shared `DataTable` (`src/components/DataTable.tsx`) with standard Audit Log columns: Timestamp, Actor, Action, Entity/Target, and Details.
- Every column is sortable AND filterable EXCEPT the Actions column.
- Pagination is server-side at exactly 30 rows/page, with a page-size control that defaults to 30.
- Each row exposes a View action (opens/links to the record per existing row-action wiring; detail page itself is out of scope).
- All columns and interactive controls carry accessibility labels (sortable headers announce sort state; filter controls and the page-size control are labelled).
### Empty state
- When there are zero audit records, the page renders the shared `EmptyState` illustration plus a primary CTA relevant to the entity (per the convention). The exact CTA label/target is a parked product detail — see Design.
### Loading state
- While records are loading, the table renders skeleton rows (per the convention).
### Error / failure
- When the records request fails, surface the error in-page (do not render a stale/partial table). Provide a retry affordance.
### Disabled / edge
- The Actions column is never sortable or filterable.
- When a filtered/sorted query returns zero rows (vs. no records existing), the empty state still renders rather than a blank table body.
- Sort/filter/page-size controls operate against server-side pagination (changing sort or filter resets to page 1).
- Any destructive row action, if present, MUST gate behind a confirm affordance (see Design — edit/delete row actions are parked).

## Design
This is a UI surface (`src/pages/**`, `src/components/**`). Mirror the standing data-tables pattern; do not hand-roll a table.
- Pattern to mirror: shared `DataTable` component at `src/components/DataTable.tsx`; standing data-tables convention in `project/design-system.md`.
- States:
  - empty — shared `EmptyState` illustration + primary CTA (CTA label/target parked, see Dependencies/parked notes).
  - loading — skeleton rows.
  - error — in-page error with retry affordance.
  - disabled — Actions column non-sortable/non-filterable; sort/filter changes reset to page 1.
- Affordances: column sort toggles, per-column filters, page-size control (default 30), View row action. Any destructive action (e.g. delete) MUST present a confirm affordance before executing.
- Accessibility: labelled sortable headers (announce sort direction), labelled filter inputs, labelled page-size control, labelled row actions (e.g. "View audit record").
- Convention followed: project/design-system.md

PARKED PRODUCT DETAILS (do not guess; do not block the page core on these):
1. Empty-state CTA — the convention mandates "a primary CTA relevant to the entity" but does not specify the Audit Log CTA's exact label or target. The empty-state BEHAVIOR (EmptyState illustration + a primary CTA) is grounded and authored above; only the CTA label/target is parked.
2. Audit Log mutability (edit/delete row actions) — the brief applies uniform view/edit/delete row actions across all entities, but an audit log is conventionally immutable/append-only and the substrate establishes NO convention on whether Audit Log records are editable/deletable. Whether this page carries edit/delete row actions (vs. view-only) is a product/compliance decision with no conventional default. The View action and full table directive ARE authored; the edit/delete row actions are parked pending that decision. Per the standing convention, IF such destructive actions are later added, each MUST gate behind a confirm affordance.

## Dependencies
None.

## Classification
- Surface: UI (matches uiSurfaceGlobs `src/pages/**`, `src/components/**`).
- Risk: heavy

## Substrate grounding
- Table behavior for ALL 10 pages (sortable+filterable except Actions / server-side pagination at 30 per page / page-size control default 30 / shared `EmptyState` + primary CTA empty view / skeleton-row loading / reuse shared `DataTable`) — grounded in `project/design-system.md` ("Design system — data tables (standing convention)"), lines 3-13. Cited as `Convention followed:` in every issue's Design section.
- Shared table component reuse — grounded in `project/design-system.md#reuse-the-shared-datatable-component` → `src/components/DataTable.tsx`.
- #B Order data-access grounding — the Order type/columns and the list-fetch + delete-mutation contracts are grounded in the brief's "standard columns for that entity" directive + the existing entity data-access pattern under `sourceGlobs` (`src/**`) that the shared `DataTable` server-side data interface supports (recorded after the §6.5 re-author).
- Row actions (view/edit/delete) — grounded in the brief ("plus row actions (view / edit / delete)").
- Degradations: none. `uiSurfaceGlobs` is set (`src/pages/**`, `src/components/**`), so all 10 page-issues correctly classify as UI and engaged the real `design-reviewer`.

## Needs human input
See `.milestone-feeder/needs-product-input-admin-list-pages.md` — `productGaps[]` is non-empty (two recorded product decisions surfaced by the decomposer). NOTE: both are Advisory-level and did NOT block any issue from the self-check gate (every issue PASSED); they are recorded so a human resolves the per-entity empty-state CTA copy/target and the Audit Log mutability decision before/at build. No issue was parked as needs-human-direction.

---
To create these on GitHub, re-run with `--apply` — it ensures the labels, creates-or-adopts the milestone, opens each gate-surviving issue, rewrites the slug references to real issue numbers, and patches the milestone description with the Wave order. This preview wrote no GitHub state.
