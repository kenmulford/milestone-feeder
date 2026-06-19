# Execution log — decompose PREVIEW — scenario 02-product-gap-parks

Mode: **Preview** (default; no `--apply` token). No GitHub writes performed.

## Step 0 — Config + substrate
| Key | Value | Source |
|---|---|---|
| substrateDir | `project/` | feeder.json |
| selfCheck | `"milestone-driver"` | feeder.json default |
| decomposerAgent | `milestone-feeder:decomposer` | default |
| issueAuthorAgent | `milestone-feeder:issue-author` | default |
| issueSizeGuidance | (none) → ~1 PR each | default |
| sourceGlobs | `["src/**"]` | driver shared key |
| uiSurfaceGlobs | `["src/pages/**", "src/components/**"]` | driver shared key |
| integrationBranch | `"develop"` | driver shared key |
| nonNegotiables | `["React 18 + TypeScript"]` | driver profile (reviewer-profile input, not a shared key) |

Substrate read (best-effort): `project/conventions.md` present. Filled sections:
- UI: reuse `ProductCardGrid` (`src/components/ProductCardGrid.tsx`) for any product listing.
- Data: read models in `src/models/`; a new persisted field requires a migration.
- States: empty + error states required on every user-facing surface.
- Explicit note: substrate records **no** product policy for HOW featured items are chosen — a product decision with no conventional default.

`uiSurfaceGlobs` present → design-lens distinction drawn (no degradation). Note: no readable `src/` tree exists in the fixture; the `ProductCardGrid`/`src/models/` references are STATED conventions, cited as conventions (not fabricated file:line).

## Step 1 — Ingest
Form: **inline text** (not `#<n>`, not a file path). `epicIssueNumber`: omitted.
Normalized brief:
- goal: Add a "Featured" homepage section highlighting selected catalog items in the standard product-card grid.
- in-scope: (1) Featured section displaying selected items in the standard product-card grid; (2) whatever is needed to choose WHICH items are featured.
- out-of-scope: redesigning the rest of the homepage.
- surfaces: homepage; product-card grid.

## Step 2 — Product-gap check
| Decision | Class | Action |
|---|---|---|
| Render featured items in the standard product-card grid | design (substrate: `ProductCardGrid`) | resolved |
| Empty + error states on the section | design (substrate: States convention) | resolved |
| HOW featured items are chosen (selection mechanism + policy) | **product** — substrate explicitly records no policy; no conventional default | recorded to `productGaps[]` |

Severity check: the product gap does **not** undecide the whole scope (the render slice is decidable). → **No Step-2 STOP.** Carried `productGaps[]` forward; dispatched the decomposer.

## Step 3 — Decomposer (dispatched once)
Note: `milestone-feeder:decomposer` is not installed as a dispatchable subagent in this environment; ran its contract via a general-purpose agent loaded with the full `agents/decomposer.md` contract (heavy reasoning kept off the main thread).

Returned:
- **CANDIDATES:** #A (logic, heavy) "Add a featured-items read accessor in the models layer"; #B (ui, heavy) "Render the homepage Featured section using ProductCardGrid"; #C (ui, light) "Add empty and error states to the homepage Featured section".
- **EDGES:** `#B depends_on #A` (consumes getFeaturedItems from `src/models/`); `#C depends_on #B` (adds states to #B's section markup).
- **WAVES:** Wave 1 #A; Wave 2 #B; Wave 3 #C.
- **PRODUCT_GAPS:** 1 — selection mechanism + policy populating the accessor (no conventional default). Merged with the Step-2 gap (same gap).

Notable: #A was sketched as "buildable now; HOW items become featured deferred to the PRODUCT_GAP" — flagged for the gate to test.

## Step 4 — Issue-author per candidate (3 dispatched, parallel)
Note: `milestone-feeder:issue-author` not installed as a subagent; ran its contract via general-purpose agents loaded with the full `agents/issue-author.md` contract.

| Tag | STATUS returned | Labels |
|---|---|---|
| #A | AUTHORED (scoped selection out via a "no-op/empty source", contract built against deferred policy) | logic, risk:heavy |
| #B | AUTHORED | ui, risk:heavy |
| #C | AUTHORED | ui, risk:light |

All three returned full §4 bodies. #A's body baked the unresolved selection mechanism into a "no-op source" deferral — surfaced to the gate.

## Step 5 — Graph + milestone description (local slugs)
Edges #B→#A, #C→#B. Waves: 1:#A · 2:#B · 3:#C.
```
Add a "Featured" section to the homepage that highlights a selection of catalog items, displayed in the standard product-card grid.

## Waves
- Wave 1 (parallel): #A
- Wave 2: #B (depends on #A)
- Wave 3: #C (depends on #B)
```

## Step 6 — Self-check gate (REAL milestone-driver reviewers)
Backend: `"milestone-driver"`. **Real reviewers used: YES** — `milestone-driver:triage-reviewer` (per issue) and `milestone-driver:design-reviewer` (UI issues #B, #C, both `NEEDS_DESIGN_REVIEW: yes`). No degrade-to-internal; first dispatch resolved and returned parseable blocks. No self-review.

### Per-issue verdicts (aggregated triage + design GAPS, §6.3)
| Issue | Reviewers | Blockers | Advisories | Verdict |
|---|---|---|---|---|
| #A | triage-reviewer | `architect/not-buildable` — cannot ground the accessor contract: the `Item`/population source is the unresolved selection mechanism; the "no-op source" deferral leaves WHAT makes an item "featured" undecided | `architect/missing-criteria` (sibling read-model pattern not named) | **FAIL** |
| #B | triage-reviewer + design-reviewer | `architect/undeclared-dependency` — #A's declared `getFeaturedItems(): Item[]` is sync/non-failable but #B's ACs require loading + reject states; `design/scalability` — cannot verify ProductCardGrid handles volume | `architect/missing-criteria`; `design/pattern-inconsistency`; `design/accessibility` | **FAIL** |
| #C | triage-reviewer + design-reviewer | `architect/contradiction` — sync `Item[]` vs loading/throws-rejects ACs; `architect/undeclared-dependency` — #A not declared as #C dependency; `design/spec-insufficiency` + `design/missing-state` — sync accessor can't be in-flight/reject | `architect/risky-design` (scope overlap with #B) | **FAIL** |

### Retry/park fork (§6.5–§6.6)
Root-cause analysis: every Blocker traces to **#A's accessor contract being undefinable without the selection mechanism** — the genuine product gap (no conventional default; the substrate explicitly says so). The sync-vs-async signature that #B/#C's contradiction Blockers hinge on IS the selection-mechanism decision (persisted flag vs curated list vs derived query → sync/async shape). Resolving it would require guessing product scope — forbidden.

| Issue | Classification | Action | issue-author re-dispatches consumed |
|---|---|---|---|
| #A | **Genuine product gap** (§6.5 row 2) — no conventional default | **Park to `productGaps[]`** as `needs-product-input`. Do NOT re-author (a re-dispatch cannot resolve a product gap). | 0 |
| #B | Dependent of parked #A | **Drop** (§6.6 — dependent of a dropped issue cannot build) | 0 |
| #C | Transitive dependent of #A (via #B) | **Drop** (§6.6) | 0 |

§6.6 edge note: #C's `undeclared-dependency` (add #A) was NOT absorbed as a re-render — the edge target #A is itself parked, so #C drops rather than re-rendering an edge to a dropped node. No re-render produced a shippable graph.

Re-rendered milestone description after dropping: **no surviving issues** (Waves empty).

### Gate outcome
**PARKED** — 1 issue (#A) → needs product input; 2 issues (#B, #C) → dropped (dependents of parked #A). 0 issues survive. 0 retries used. No issue emitted unvetted.

## Step 7 — Emit (PREVIEW)
Wrote `run-output.md` (the §7-preview plan file, `PREVIEW` header/footer) and the needs-product-input report content inline (productGaps non-empty). No GitHub writes. (In a real run the report would also land at `.milestone-feeder/needs-product-input-<slug>.md`; here it is folded into run-output.md per the test's WRITE instruction.)

## Real reviewers? **YES** — milestone-driver:triage-reviewer + milestone-driver:design-reviewer (the genuine driver gate). Decomposer/issue-author run via contract-loaded general-purpose agents (those two feeder agents are not registered as subagents in this environment); the load-bearing GATE used the real driver reviewers, never self-review.
