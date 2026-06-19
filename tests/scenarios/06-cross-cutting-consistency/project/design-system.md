# Design system — data tables (standing convention)

Every data table in the admin app MUST follow these rules:

- **Sortable + filterable columns:** every column is sortable and has a column filter,
  EXCEPT the row-actions column (no sort, no filter on Actions).
- **Pagination:** server-side pagination at **30 rows per page**, with a page-size control
  defaulting to 30.
- **Empty state:** when there are no rows, show the shared `EmptyState` illustration plus a
  primary CTA relevant to the entity.
- **Loading state:** skeleton rows while the page loads.
- **Reuse the shared `DataTable` component** (`src/components/DataTable.tsx`) — do not
  hand-roll tables.
