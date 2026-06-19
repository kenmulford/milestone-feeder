# Engineering conventions

- **API:** REST endpoints under `/api/v1/`; JSON or streamed bodies; auth required; errors return `{ "error": "..." }` with the correct HTTP status.
- **Rate limiting:** use the shared `RateLimiter` middleware (token-bucket). Limited responses return `429` with a `Retry-After` header. Pattern: `src/middleware/rate_limit.py`.
- **User-facing actions:** show a success/error toast via the shared `useToast()` hook; disable the trigger control while the action is in flight.
- **States:** empty and error states are required on every user-facing surface.
