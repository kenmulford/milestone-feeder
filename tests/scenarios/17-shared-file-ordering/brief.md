# Brief: CSV exports

Let a signed-in user export a report as CSV. The user queues an export, the export runs in
the background, and finished exports are listed back to the user. The report is the user's
archive listing, one CSV row per archived item with columns `name`, `size_bytes`, `archived_at`,
read through the existing `src/services/ArchiveService.ts` (which this feature calls, never
modifies). The export job is
registered in the queue manifest at `src/jobs/manifest.ts`.

In scope:
- Queue an export: `POST /exports`. The endpoint refuses a new export when the user already
  has N exports in flight; N is the config key `exports.maxInFlight`, default 3.
- List a user's exports: `GET /exports`, newest first, no paging.
- The background pipeline that writes the CSV file and records the export row. A finished
  export is kept for 30 days.
- A URL-safe filename for each finished export, derived from the report title.
- Telemetry events for the export lifecycle (queued, started, finished, failed).
- Email the user when an export finishes. Whether the email attaches the CSV or links to the export is not decided.
- A nightly purge job deletes finished exports older than 30 days.

Out of scope:
- Editing, re-running, or deleting an export.
- Any web/UI surface: this is the backend only.
- Export formats other than CSV.
