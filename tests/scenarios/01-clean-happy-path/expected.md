# Expected contract — 01 clean-happy-path  (GRADER ONLY)

A clean, well-specified brief. The feeder should produce a small, correctly-ordered,
gate-clean milestone with NO parks.

## MUST
- 3 issues (3–4 acceptable if it splits sensibly): the export **endpoint**, the **Download-CSV UI action**, the **rate limit**. ~1 PR each.
- Dependency edges: the UI action depends on the endpoint; the rate limit depends on the endpoint. Endpoint = Wave 1; the other two = Wave 2.
- The milestone description encodes the Wave order (§4 template).
- Each issue body has all five §4 sections. Acceptance criteria include empty/error states (per convention). The UI-action issue records the in-flight-disable + toast convention; the rate-limit issue cites the `RateLimiter` pattern (429 + `Retry-After`).
- Self-check gate: every issue returns `GAPS: none` (PASS). No re-author, or at most a bounded one that clears.
- ZERO parks; needs-product-input report absent or "none".
- Classification: UI action = `ui`; endpoint + rate limit = `logic`. Risk reasonable.

## SHOULD
- Convention citations point at the provided `project/conventions.md` (real grounding), not invented.

## FAIL if
- Invents scope not in the brief; misses a dependency edge; parks something a convention answers; produces issues missing error/empty states; or the gate rubber-stamps an incomplete issue.

## POST-RUN ADJUDICATION (fixture correction — 2026-06-18)
The first run (blind) parked the **rate-limit threshold value** as a product gap: the brief
says "a per-user rate limit" with no number, and the substrate grounds the *mechanism*
(`RateLimiter`, 429 + `Retry-After`) but states no default number. The independent grader
ruled — correctly — that **parking the unspecified threshold rather than inventing one is
right behavior**, and that the original `MUST #6: ZERO parks` was the mistaken assertion
(a clean brief that omits a no-conventional-default number *should* park it).

Corrections to this contract:
- **MUST #5** is relaxed to: every emitted issue returns `GAPS: none` **or Advisory-only**
  (advisories are non-gating).
- **MUST #6** is superseded: exactly **one** minimal, correctly-scoped product-gap park
  (the threshold) is expected and correct — not a failure. Inventing a number would be the
  failure. Everything else (decomposition, both edges, Wave order, real-reviewer gate,
  cited grounding) must still hold.

Net verdict: ✅ feeder behavior correct; this run doubles as evidence for the
"parks-not-invents" property (overlaps scenario 02's dedicated test).
