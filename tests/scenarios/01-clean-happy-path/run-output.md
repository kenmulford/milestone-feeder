# Milestone plan (PREVIEW) — Add user-facing CSV export to the Reports page

Self-check: PASS — 2 issues GAPS: none/Advisory-only (milestone-driver reviewers: triage-reviewer ×2, design-reviewer ×1). PARKED — 1 issue (#B) → needs product input (rate-limit threshold has no conventional default).
Source brief: inline

## Milestone description (preview)
Add user-facing CSV export to the existing Reports page: a streaming backend export endpoint and a Download CSV action on the Reports page. (The per-user rate limit on the export endpoint is parked — its threshold needs product input; see the needs-product-input report.)

## Waves
- Wave 1: #A
- Wave 2: #C (depends on #A)

## Issues

### #A — Add backend CSV export endpoint for the current report   [logic, risk:heavy]   [self-check: PASS]
## Summary
Add a REST endpoint that streams the current report's rows as CSV so the Reports page can offer a download. This is the backend half of user-facing CSV export; it does not add new report types or columns, and it does not schedule or email exports.

## Acceptance criteria
- [ ] Happy path: GET the export endpoint for a report returns the report's current rows as a streamed CSV body with a CSV content type; auth is required.
- [ ] Empty state: a report with zero rows returns a valid CSV containing only the header row (HTTP 200), not an error.
- [ ] Error path: an unknown/invalid report id returns the conventional error shape `{ "error": "..." }` with the correct HTTP status; an unauthenticated request is rejected.
- [ ] Edge: the response streams rather than buffering the whole report in memory (exports are expensive).

## Design (recorded, consistent)
- Endpoint lives under `/api/v1/` per the API convention; auth required; errors return `{ "error": "..." }` with the correct HTTP status.
- Body is a streamed CSV body (the API convention permits "JSON or streamed bodies").
- Backend is Python 3.11 (profile nonNegotiable).
- Convention followed: project/conventions.md#engineering-conventions (API: REST endpoints under `/api/v1/`; JSON or streamed bodies; auth required; errors return `{ "error": "..." }` with the correct HTTP status).

## Dependencies
- None.

## Classification
- Surface: logic
- Risk: heavy

### #C — Add a Download CSV action to the Reports page   [ui, risk:heavy]   [self-check: PASS]
## Summary
Add a "Download CSV" action to the existing Reports page. The action calls the backend export endpoint (#A) and saves the returned CSV file to the user's device. No new report types or columns are added.

## Acceptance criteria
- [ ] Happy path: clicking "Download CSV" on the Reports page calls the export endpoint and the browser saves the returned CSV file; a success toast is shown via the shared `useToast()` hook.
- [ ] Empty state: when the current report has zero rows, the action still downloads a valid (header-only) CSV — the action is available whenever a report is shown, mirroring the empty-state requirement for user-facing surfaces.
- [ ] Error path: if the endpoint returns an error (or the request fails), an error toast is shown via `useToast()` and no partial/corrupt file is saved.
- [ ] Disabled/in-flight: the "Download CSV" control is disabled while the request is in flight, per the user-facing-actions convention, and re-enabled when it settles.

## Design (recorded, consistent)
- Place the "Download CSV" trigger on the existing Reports page (a `src/pages/**` surface → UI).
- On click, call the backend export endpoint (#A) and save the streamed CSV response as a file.
- Show a success/error toast via the shared `useToast()` hook; disable the trigger control while the action is in flight (user-facing-actions convention).
- Required states: success (file saved + success toast), empty (header-only CSV downloads normally), error (error toast, no corrupt file), disabled/in-flight (control disabled during the request). Empty and error states are required on every user-facing surface (States convention).
- Accessibility: the trigger is a labeled control ("Download CSV") reachable and operable by keyboard and screen reader; the disabled state is conveyed to assistive tech while in flight.
- Frontend is React 18 (profile nonNegotiable); use the shared `useToast()` hook rather than a bespoke notification.
- Convention followed: project/conventions.md#engineering-conventions (User-facing actions: show a success/error toast via the shared `useToast()` hook; disable the trigger control while the action is in flight. States: empty and error states are required on every user-facing surface).

## Dependencies
- Depends on #A — the "Download CSV" action calls the backend CSV export endpoint that #A introduces; it cannot function until that endpoint exists.

## Classification
- Surface: UI
- Risk: heavy

### #B — Add a per-user rate limit to the CSV export endpoint   [parked — needs product input]
<marker only; no fabricated body — see the needs-product-input report. The rate-limit *mechanism* is fully grounded (shared `RateLimiter` token-bucket middleware; 429 + `Retry-After`; pattern `src/middleware/rate_limit.py` — project/conventions.md#engineering-conventions), but the *threshold value* (exports allowed per user per window, and the window/burst) has no conventional default in the substrate and is a product decision.>

## Substrate grounding
- #A: endpoint under `/api/v1/`, auth required, `{ "error": "..." }` error shape, streamed body — grounded in project/conventions.md#engineering-conventions (API line).
- #A/#C: backend Python 3.11 / frontend React 18 — grounded in profile `nonNegotiables` ("Python 3.11 backend; React 18 frontend").
- #C: success/error toast via shared `useToast()` hook; disable trigger while in flight — grounded in project/conventions.md#engineering-conventions (User-facing actions line).
- #C: empty + error states required on the surface — grounded in project/conventions.md#engineering-conventions (States line).
- #C: classified UI because the trigger lives on the existing Reports page, a `src/pages/**` surface — grounded in resolved `uiSurfaceGlobs` (`["src/pages/**","src/components/**"]`).
- #B (parked): rate-limit mechanism (shared `RateLimiter` token-bucket; 429 + `Retry-After`; pattern `src/middleware/rate_limit.py`) — grounded in project/conventions.md#engineering-conventions (Rate limiting line); only the threshold value is the product gap.
- Advisory notes (non-gating, recorded by the reviewers):
  - #A — triage Advisory: the issue does not name the report-rows data source/service it streams; resolvable from the existing Reports read path in the consumer repo. (No `src/**` tree exists in this fixture to pin it.)
  - #C — triage Advisory: `useToast()` is referenced as a shared hook; confirm it pre-exists in the consumer repo (it is a stated convention in project/conventions.md#engineering-conventions, treated as pre-existing).
- Degradations: none. `uiSurfaceGlobs` is present, so the design lens was applied; `nonNegotiables` is present and was passed to the reviewers. (Note: the fixture ships no actual `src/**` source tree — the reviewers grounded on the stated conventions in the substrate, which is the documented best-effort behavior.)

## Needs human input
See .milestone-feeder/needs-product-input-csv-export-reports-page.md — #B's rate-limit threshold is a product decision with no conventional default. (Equivalent local report content reproduced below in run-log.md for this test run.)

---
To create these on GitHub, re-run with `--apply` — it ensures the labels, creates-or-adopts the milestone, opens each gate-surviving issue (#A, #C), rewrites the slug references to real issue numbers, and patches the milestone description with the Wave order. This preview wrote no GitHub state.
