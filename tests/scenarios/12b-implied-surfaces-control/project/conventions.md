# Engineering conventions

- **Dashboard:** the existing Dashboard page lives at `src/pages/DashboardPage.tsx`.
  Its empty-state message is a plain string constant, rendered when there is no
  data to show.
- **Copy style:** user-facing copy is sentence case, no trailing period required on
  short status messages.
- **States:** empty and error states are required on every user-facing surface
  (already present here; this change edits only the empty-state text, it does not
  add a new state).
