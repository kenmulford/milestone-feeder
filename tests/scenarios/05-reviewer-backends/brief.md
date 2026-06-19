# Brief: Service health-check endpoint

Add a health-check endpoint at `GET /api/v1/health` that returns the service status
(overall status plus per-dependency checks for the database and the cache).

In scope:
- The endpoint and its status payload.

Out of scope:
- A status dashboard UI.
