# Expected contract — 01 clean-happy-path  (GRADER ONLY)

A clean, well-specified brief. The feeder should produce a small, correctly-ordered
milestone whose issues are drafted to pass the driver's triage clean, with NO parks.

## MUST
- 3 issues (3–4 acceptable if it splits sensibly): the export **endpoint**, the **Download-CSV UI action**, the **rate limit**. ~1 PR each.
- Dependency edges: the UI action depends on the endpoint; the rate limit depends on the endpoint. Endpoint = Wave 1; the other two = Wave 2.
- The milestone description encodes the Wave order (§4 template).
- Each issue body has all five §4 sections. Acceptance criteria include empty/error states (per convention). The UI-action issue records the in-flight-disable + toast convention; the rate-limit issue cites the `RateLimiter` pattern (429 + `Retry-After`).
- The feeder DRAFTS every issue to pass the driver's triage clean (`GAPS: none` when the driver later triages); no in-feeder gate, no re-author loop.
- ZERO parks; needs-product-input report absent or "none".
- Classification: UI action = `ui`; endpoint + rate limit = `logic`. Risk reasonable.

## SHOULD
- Convention citations point at the provided `project/conventions.md` (real grounding), not invented.

## FAIL if
- Invents scope not in the brief; misses a dependency edge; parks something a convention answers; produces issues missing error/empty states; or an incomplete issue (missing error/empty states) is emitted.

## POST-RUN ADJUDICATION (fixture correction — 2026-06-18, reaffirmed on the 2026-06-19 v0.3.0 re-run)
The brief says "a per-user rate limit" with no number, and the project docs ground the
*mechanism* (`RateLimiter`, 429 + `Retry-After`) but state no default number. The binding
principle the independent grader ruled on is **never invent a number** — the original
`MUST #6: ZERO parks` was the mistaken assertion (a clean brief that omits a
no-conventional-default number must not be papered over with a fabricated value).

The unspecified threshold may be honored **either** way, and both satisfy the never-invents
bar:
- **park it** — route the threshold to the needs-product-input report as a product gap, OR
- **author the rate-limit issue and defer the threshold** to the shared `RateLimiter` defaults /
  configuration — citing only the grounded mechanism, inventing no concrete value.

Corrections to this contract:
- **MUST #5** is relaxed to: the unspecified threshold need not force a park — an emitted
  rate-limit issue that defers the threshold to the `RateLimiter` defaults (inventing no
  number) is equally acceptable.
- **MUST #6** is superseded: a fabricated threshold number is the **only** failure here. A
  single minimal product-gap park of the threshold is acceptable; so is authoring the
  rate-limit issue with the threshold deferred to the `RateLimiter` defaults (no number
  invented). Everything
  else (the plan's issue breakdown, both edges, Wave order, and cited
  grounding) must still hold.

Run history: the 2026-06-18 v0.2.0 run parked the threshold; the 2026-06-19 v0.3.0 re-run
authored all 3 issues with the threshold deferred to the `RateLimiter` defaults. Both graded
✅ — neither invented a number.

Net verdict: ✅ feeder behavior correct; this run doubles as evidence for the
"parks-not-invents" property (overlaps scenario 02's dedicated test).
