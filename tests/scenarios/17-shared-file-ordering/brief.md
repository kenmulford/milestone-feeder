# Brief: CSV exports

Let a signed-in user export a report as CSV. The user queues an export, the export runs in
the background, and finished exports are listed back to the user. The export job is
registered in the queue manifest at `src/jobs/manifest.ts`.

In scope:
- Queue an export: `POST /exports`. The endpoint refuses a new export when the user already
  has N exports in flight; N is a config key.
- List a user's exports: `GET /exports`.
- The background pipeline that writes the CSV file and records the export row. A finished
  export is kept for 30 days.
- A URL-safe filename for each finished export, derived from the report title.
- Telemetry events for the export lifecycle (queued, started, finished, failed).

Out of scope:
- Editing, re-running, or deleting an export.
- Any web/UI surface: this is the backend only.
- Export formats other than CSV.
