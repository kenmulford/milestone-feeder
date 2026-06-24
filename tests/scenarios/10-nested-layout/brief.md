# Brief: Export-status banner on the dashboard

The dashboard should tell a user when their last export is still running.

In scope:
- A backend endpoint that reports the status of the user's most recent export job.
- A banner on the dashboard that polls that endpoint and shows "Export in progress…"
  while a job is running, and clears when it finishes.

Out of scope:
- Starting or cancelling exports (the export pipeline already exists).
- Push/websocket delivery — polling the endpoint is fine for now.
