# Execution log — decompose PREVIEW, scenario 01 (clean-happy-path)

## Mode
- Trigger: `/milestone-feeder:decompose <inline brief>` — no `--apply` token, no NL "apply" equivalent → PREVIEW (default). No GitHub writes.

## Step 0 — config + substrate
- `feeder.json` empty `{}` → `selfCheck: "milestone-driver"` (default), `substrateDir: project/`.
- Shared keys (driver): `sourceGlobs=["src/**"]`, `uiSurfaceGlobs=["src/pages/**","src/components/**"]`, `integrationBranch="develop"`.
- `nonNegotiables=["Python 3.11 backend; React 18 frontend"]` (reviewer-profile input, passed through at the gate).
- Substrate read: `project/conventions.md` (all 4 sections present: API, Rate limiting, User-facing actions, States). No `[TBD]` sections; no absent docs. No degradation (uiSurfaceGlobs present).
- Note: fixture ships no actual `src/**` tree; grounding is on the stated conventions in the substrate (documented best-effort behavior).

## Step 1 — ingest brief
- Form: inline text (not `#n`, not a file path). `epicIssueNumber`: omitted.
- Normalized: goal = user-facing CSV export on existing Reports page; in-scope = streaming backend export endpoint, Download CSV action on Reports page, per-user rate limit on the endpoint; out-of-scope = new report types/columns, scheduled/emailed exports; surfaces = Reports page (src/pages/**), export endpoint (/api/v1/), RateLimiter middleware.

## Step 2 — product-gap check
- API shape, error shape, auth, streaming, toast/disable UX, required states, rate-limit mechanism → all answered by project/conventions.md → resolved design/impl decisions.
- Rate-limit THRESHOLD value (exports/user/window + window/burst) → no conventional default in substrate → product gap (scoped to #B). Candidate set can still be formed (gap is a parameter, not core scope) → no Step-2 STOP; carried forward.

## Step 3 — decompose (decomposer, dispatched once)
- CANDIDATES:
  - #A — Add backend CSV export endpoint for the current report — surface: logic, risk: heavy
  - #B — Add a per-user rate limit to the CSV export endpoint — surface: logic, risk: heavy
  - #C — Add a Download CSV action to the Reports page — surface: ui, risk: heavy
- EDGES:
  - #B depends_on #A — rate limit wraps the export endpoint #A introduces.
  - #C depends_on #A — Download CSV action calls the export endpoint #A introduces.
- WAVES (pre-park, topological sort):
  - Wave 1: #A
  - Wave 2 (parallel): #B (depends on #A), #C (depends on #A)
- PRODUCT_GAPS: rate-limit threshold value (scoped to #B). Merged into productGaps[].

## Step 4 — author per candidate (issue-author, one per candidate)
- #A → STATUS: AUTHORED. Full §4 body (Summary / 4 acceptance criteria happy+empty+error+edge / Design grounded in conventions API line + nonNegotiables / Dependencies: none / Classification logic+heavy). LABELS [logic, risk:heavy].
- #C → STATUS: AUTHORED. Full §4 body (4 acceptance criteria happy+empty+error+disabled / Design names states, toast affordance, in-flight disable, a11y, React 18 / Dependencies: Depends on #A / Classification UI+heavy). LABELS [ui, risk:heavy].
- #B → STATUS: PRODUCT_GAP. Mechanism grounded (RateLimiter token-bucket, 429+Retry-After, src/middleware/rate_limit.py) but threshold has no conventional default → routed to productGaps[]; NOT authored, no fabricated body. Recorded as parked, tag/title rendered with marker.

## Step 5 — assemble graph + render milestone description
- Graph (local tags): #A → {#B, #C}. Rendered §4 Wave description with local slugs (pre-park version matches Step 3 waves).

## Step 6 — SELF-CHECK GATE (REAL reviewers)
- Backend: `milestone-driver` (default). Reviewers RESOLVED on first dispatch → no degrade-to-internal. REAL milestone-driver subagents used (not self-review).
- Briefed each per §6.2: generated title/body/criteria; recorded design decisions = EMPTY (stated explicitly); milestone description as cross-issue context; resolved sourceGlobs/uiSurfaceGlobs/nonNegotiables; local slugs.

| Issue | Reviewer(s) dispatched | Returned | Verdict | Re-authors |
|---|---|---|---|---|
| #A | triage-reviewer | DEPENDS_ON: []; NEEDS_DESIGN_REVIEW: no; GAPS: 1× Advisory (missing-criteria — unnamed report-rows data source) | PASS (Advisory non-gating) | 0 |
| #C | triage-reviewer + design-reviewer (UI) | triage: DEPENDS_ON: [A]; NEEDS_DESIGN_REVIEW: yes; GAPS: 1× Advisory (not-buildable — useToast provenance). design: GAPS: none | PASS (Advisory non-gating; design clean) | 0 |
| #B | none (parked at Step 4 as PRODUCT_GAP — no authored body to review) | n/a | PARKED (product-gap) | 0 |

- §6.3 aggregation: #A all-Advisory → PASS; #C triage Advisory + design none → PASS. No `severity: Blocker` on any block → no FAIL → §6.5 retry/park fork not triggered for #A/#C.
- §6.6 undeclared edges: #C triage returned DEPENDS_ON: [A], already declared in the body and the Wave order → no new edge to absorb; no re-render needed. #A DEPENDS_ON: [] as expected.
- §6.6 drop parked + dependents: #B parked (product-gap). No candidate depends on #B (edges: #B→#A, #C→#A) → no dependents dropped. Re-rendered surviving milestone description = {#A (Wave 1), #C (Wave 2, depends on #A)}.

## Parks
- #B — Kind: product-gap. Item: per-user rate-limit threshold value (exports/user/window + window/burst). Why: substrate fixes the mechanism (RateLimiter token-bucket, 429+Retry-After, src/middleware/rate_limit.py) but carries no default threshold; no conventional default → product decision. Blocks: #B only (no dependents).

## Step 7 — emit (PREVIEW)
- Wrote `run-output.md` (the §7-preview plan-file format; header (PREVIEW), self-check status line, surviving milestone description, full bodies for #A/#C, marker for #B, substrate grounding incl. Advisory notes + "no degradations", needs-human-input pointer, PREVIEW footer).
- Wrote the needs-product-input report below (productGaps[] non-empty). No GitHub writes (preview).

## Gate ran with REAL reviewers?
- YES. `milestone-driver:triage-reviewer` dispatched for #A and #C; `milestone-driver:design-reviewer` dispatched for #C (UI). All resolved and returned parseable ISSUE/.../GAPS blocks. No degrade-to-internal, no internal-fallback, no self-review.

---

## needs-product-input report (content that would be written to .milestone-feeder/needs-product-input-csv-export-reports-page.md)

🔴 Needs human input — Add user-facing CSV export to the Reports page

These items blocked the milestone and were NOT guessed. Resolve each, then re-run decompose.

| # | Kind | Item | Why blocked | Blocks |
|---|---|---|---|---|
| 1 | product-gap | Per-user rate-limit threshold for the CSV export endpoint: how many exports per user per window, the window length, and any burst allowance | The substrate fixes the rate-limit *mechanism* (shared `RateLimiter` token-bucket middleware; 429 + `Retry-After`; pattern `src/middleware/rate_limit.py` — project/conventions.md#engineering-conventions) but specifies no default threshold. The numeric limit is a product decision with no conventional default — exports being "expensive" (brief) does not imply a specific number. | #B (per-user rate limit on the export endpoint). No other candidate depends on #B, so #A and #C still ship. |
