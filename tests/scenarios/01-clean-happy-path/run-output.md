# Milestone plan (PREVIEW) — Add user-facing CSV export to the existing Reports page

Milestone title (exact): CSV export for the Reports page
Self-check: PASS — all 3 issues clear (milestone-driver reviewers: triage-reviewer ×3, design-reviewer ×1; #A GAPS: none, #B/#C Advisory-only, no Blocker)
Source brief: inline

## Milestone description (Wave order)
Add user-facing CSV export to the existing Reports page: a backend endpoint that streams the current report's rows as CSV, a "Download CSV" action on the Reports page that calls it and saves the file, and a per-user rate limit on the export endpoint.

## Waves
- Wave 1: #A
- Wave 2: #B (depends on #A), #C (depends on #A)

## Issues

### #A — Export endpoint: stream report rows as CSV   [logic, risk:heavy]   [self-check: PASS]
## Summary

Add a REST endpoint under `/api/v1/` that streams the current report's rows as a CSV body. The endpoint requires authentication and returns a streamed response with a CSV content type. Scope is limited to the existing report's existing rows and columns — no new report types or columns. This endpoint is the backend foundation that the Download CSV action (#C) and the per-user rate limit (#B) build on.

## Acceptance criteria
- [ ] Happy path: An authenticated request to the export endpoint under `/api/v1/` returns a `200` with a streamed body whose content type is CSV, containing the existing report's existing rows and columns.
- [ ] Empty state: When the report has no rows, the endpoint returns a `200` with a CSV body containing the header row only (no data rows).
- [ ] Error/failure state: On a server-side failure while producing the export, the endpoint returns an error response shaped `{ "error": "..." }` with the correct (5xx) HTTP status.
- [ ] Auth-required (edge): An unauthenticated request is rejected with the conventional auth-failure status and an `{ "error": "..." }` body — it does not stream any report data.
- [ ] Scope guard: The endpoint exposes only the existing report's existing rows and columns; it introduces no new report types and no new columns.

## Design (recorded, consistent)
- The endpoint lives under `/api/v1/`, requires auth, and streams its body — consistent with the brief's "backend endpoint that streams the report's rows as CSV."
- Success returns a streamed CSV body; errors return `{ "error": "..." }` with the correct HTTP status.
- Backend is Python 3.11 (profile nonNegotiable).
- Convention followed: REST endpoint under `/api/v1/`, auth required, streamed body, and errors shaped `{ "error": "..." }` with the correct HTTP status — per `project/conventions.md#api`.

## Dependencies
- Depends on: none. (#B per-user rate limit and #C Download CSV action depend on this endpoint, but it depends on nothing.)

## Classification
- Surface: logic (backend endpoint; no user-facing UI in this issue).
- Risk: heavy (new streaming export endpoint with auth and error contracts; the foundation other issues build on).

### #B — Rate-limit the export endpoint (per-user)   [logic, risk:heavy]   [self-check: PASS (Advisory)]
## Summary

Throttle the CSV export endpoint on a per-user basis so that expensive exports cannot be run repeatedly in quick succession. Apply the shared `RateLimiter` token-bucket middleware to the export endpoint route/handler, keyed per user. When a user exceeds their allowance, the endpoint returns `429` with a `Retry-After` header instead of running the export.

## Acceptance criteria
- [ ] The `RateLimiter` token-bucket middleware is attached to the export endpoint route/handler, keyed per authenticated user (each user has an independent token bucket).
- [ ] Requests within the per-user allowance pass through and the export runs normally (happy path).
- [ ] Requests that exceed the per-user allowance are rejected with HTTP `429` and a `Retry-After` header indicating when the user may retry.
- [ ] The `429` error body follows the API error convention: `{ "error": "..." }`.
- [ ] The rate limit is keyed strictly per user: one user exhausting their bucket does not throttle a different user (independent buckets / no cross-user interference).
- [ ] Empty/boundary state: a user who has made no recent requests (full bucket) is never throttled on their first export; the very first request after a full refill always passes.
- [ ] Error/failure state: if the rate-limit check itself cannot be evaluated, the failure is surfaced as a `{ "error": "..." }` body with the correct HTTP status (per the API convention) rather than silently allowing or denying the export.

## Design (recorded, consistent)
- Reuse the shared `RateLimiter` token-bucket middleware rather than introducing a new throttling mechanism; attach it to the export endpoint route/handler keyed per user.
- Limited responses return `429` with a `Retry-After` header.
- Error bodies use the `{ "error": "..." }` shape with the correct HTTP status.
- Convention followed: rate limiting uses the shared `RateLimiter` middleware (token-bucket); limited responses return `429` with a `Retry-After` header; pattern lives at `src/middleware/rate_limit.py` (`project/conventions.md#rate-limiting`). API errors return `{ "error": "..." }` with the correct HTTP status; endpoint is under `/api/v1/` with auth required (`project/conventions.md#api`).

## Dependencies
- Depends on #A — the RateLimiter middleware attaches to the export endpoint route/handler introduced by #A.

## Classification
- Surface: logic
- Risk: heavy — touches shared rate-limiting middleware and the export endpoint's request path; misconfiguration could throttle legitimate users or fail to throttle expensive exports.

### #C — "Download CSV" action on the Reports page   [ui, risk:heavy]   [self-check: PASS (Advisory)]
## Summary

Add a "Download CSV" action to the existing Reports page (`src/pages/**` → a UI surface per `uiSurfaceGlobs`). On click, the action calls the export endpoint introduced by #A, receives the streamed CSV body, and saves it to the user's device as a file. While the request is in flight the trigger is disabled; on completion a success or error toast is shown via the shared `useToast()` hook. The surface renders the required empty and error states.

This is the user-facing half of the CSV export feature. The backend export endpoint, its request/response contract, and the per-user rate limit are out of scope here and are delivered by #A (endpoint) and #B (rate limit).

## Acceptance criteria
- [ ] A "Download CSV" trigger is present on the Reports page.
- [ ] Happy path: clicking the trigger calls the export endpoint (#A) under `/api/v1/`, reads the streamed CSV response body, and saves it to the user's device as a `.csv` file.
- [ ] In-flight (loading): while the request is pending, the trigger is disabled so it cannot be clicked again, and a loading affordance is shown on the trigger.
- [ ] Success: on a successful response, a success toast is shown via the shared `useToast()` hook, and the trigger returns to its enabled state.
- [ ] Error/failure: on a non-2xx response or a network/stream failure, the trigger returns to its enabled state and an error toast is shown via `useToast()`, surfacing the message from the API error envelope (`{ "error": "..." }`) when present.
- [ ] Rate-limited (429): when the endpoint returns `429`, the error toast communicates that the user is temporarily rate-limited; the trigger returns to its enabled state and remains usable (no permanent disable).
- [ ] Empty state: when the Reports page has no report data to export, the empty state is rendered and the "Download CSV" trigger is either hidden or shown disabled (nothing to export) — consistent with the page's existing empty-state treatment.
- [ ] Error state: when the Reports page itself fails to load its data, the page's error state is rendered (distinct from the per-click export error toast).
- [ ] Disabled state: the trigger is disabled while in flight and in the empty (nothing-to-export) case; in all other states it is enabled.

## Design (recorded, consistent)
- Pattern to mirror: a user-facing action that calls an endpoint and reports the result via a toast, disabling its trigger while the request is in flight.
- Convention followed: `project/conventions.md#user-facing-actions` — show a success/error toast via the shared `useToast()` hook, and disable the trigger control while the action is in flight. The "Download CSV" trigger uses `useToast()` for both success and error feedback and is disabled for the duration of the in-flight request.
- Convention followed: `project/conventions.md#states` — empty and error states are required on every user-facing surface. The Reports page renders an empty state (no report data) and an error state (page data failed to load); these are distinct from the transient per-click export toasts.
- Required states: Empty (no report data → empty state; trigger hidden or disabled), Loading (in-flight; trigger disabled with a loading affordance; no toast yet), Success (trigger re-enabled; success toast via `useToast()`), Error (trigger re-enabled; error toast carrying the API envelope message; `429` surfaced as a temporary rate-limit message), Disabled (trigger disabled while in flight and in the empty case).
- Affordances: a single "Download CSV" trigger; a visible loading/disabled treatment while in flight; toast notifications for success and error outcomes.
- Frontend is React 18 (profile nonNegotiable); use the shared `useToast()` hook rather than a bespoke notification.
- Accessibility: the trigger has an accessible name of "Download CSV"; its disabled state is conveyed to assistive technology so it is announced as unavailable while in flight or when there is nothing to export; the success/error toasts are announced via the shared toast mechanism's existing live-region behavior.

## Dependencies
- Depends on #A — the Download CSV action calls the export endpoint introduced by #A (route under `/api/v1/`, streamed CSV body, error envelope).

## Classification
- Surface: UI (`src/pages/**` per `uiSurfaceGlobs` — the Reports page).
- Risk: heavy — adds a new user-facing action with multiple states (empty, loading, success, error, rate-limited, disabled), a file-save side effect, and a hard dependency on the #A endpoint contract.

## Project-docs grounding
- #A: endpoint under `/api/v1/`, auth required, `{ "error": "..." }` error shape, streamed body — grounded in `project/conventions.md#api`.
- #B: shared `RateLimiter` token-bucket middleware, `429` + `Retry-After`, pattern `src/middleware/rate_limit.py` — grounded in `project/conventions.md#rate-limiting`.
- #C: success/error toast via shared `useToast()` hook; disable trigger while in flight — grounded in `project/conventions.md#user-facing-actions`.
- #C: empty + error states required on the surface — grounded in `project/conventions.md#states`.
- #C: classified UI because the trigger lives on the existing Reports page, a `src/pages/**` surface — grounded in resolved `uiSurfaceGlobs` (`["src/pages/**","src/components/**"]`).
- #A/#C: backend Python 3.11 / frontend React 18 — grounded in profile `nonNegotiables` ("Python 3.11 backend; React 18 frontend").
- Advisory notes (non-gating, recorded by the reviewers):
  - #B — triage Advisory: token-bucket capacity/refill rate for the per-user limit is not recorded; relies on the shared `RateLimiter` defaults. Confirm the export uses the shared default, or record an intended per-user capacity/refill if a tighter limit is wanted.
  - #C — triage Advisory: 401/auth-failure path folds into the generic error-toast branch (no explicit auth criterion); the `Retry-After` wait time is not surfaced in the rate-limit toast wording; the file-save mechanism/filename is unspecified (browser blob-download is the obvious React convention); the empty-state trigger hidden-vs-disabled is left as an either-or.
  - #C — design Advisory: the page-level loading state (Reports page fetching its own data, distinct from the per-click export in-flight state) is not named; the empty-state trigger hidden-vs-disabled is self-optional and partially contradicts the disabled-state rule — pick one.
- Degradations: none. `uiSurfaceGlobs` is present, so the design lens was applied; `nonNegotiables` is present and was passed to the reviewers. (Note: the fixture ships no actual `src/**` source tree — the architect, authors, and reviewers grounded on the stated conventions in `project/conventions.md`, the documented best-effort behavior.)

## Needs human input
none — no product gap was found and no issue was parked as needs-human-direction. All three issues cleared the self-check gate (no Blocker). The #B and #C Advisory notes above are non-gating refinements the implementer can resolve from the stated conventions; they did not park any issue.

---
This plan file is the build artifact — run `/milestone-feeder:create` to deploy it to GitHub (it ensures the labels, creates-or-adopts the milestone by the exact title above, opens each surviving issue (#A, #B, #C), rewrites the slug references to real issue numbers, and patches the milestone description with the Wave order). `plan` wrote no GitHub state.
