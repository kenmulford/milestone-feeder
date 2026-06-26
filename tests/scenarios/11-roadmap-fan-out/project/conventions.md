# Engineering conventions

- **API:** REST endpoints under `/api/v1/`; JSON bodies; auth required on every
  route; errors return `{ "error": "..." }` with the correct HTTP status.
- **Auth:** session cookies; sessions expire; role checks via the shared
  `requireRole()` guard (`src/middleware/auth.py`). Two roles: `owner`, `staff`.
- **Owner scoping:** every query is scoped to the current owner via the shared
  `owner_scope()` helper — records never leak across owners.
- **User-facing actions:** show a success/error toast via the shared `useToast()`
  hook; disable the trigger control while the action is in flight.
- **States:** empty and error states are required on every user-facing surface;
  list screens also show a loading skeleton.
- **Data tables:** reuse the shared `DataTable` component
  (`src/components/DataTable.tsx`) — columns sortable and filterable except an
  Actions column; server-side pagination at **30 rows per page**. Do not
  hand-roll tables.
- **Money:** store monetary amounts as integer minor units; never floats.
  (This fixes the storage representation only — it states no payment provider,
  currency, or fee/tax policy; those are product calls, not engineering ones.)
