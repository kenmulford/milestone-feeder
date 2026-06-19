# Run log — 02-product-gap-parks

**Mode:** `/milestone-feeder:plan` (PREVIEW — read-only on GitHub; writes local scratch only)
**Surface:** v0.3.0 — verbs `plan` / `create` / `update`; keys `reviewer` / `projectDocs`; agent `architect`.
**Brief:** inline (`tests/scenarios/02-product-gap-parks/brief.md`) — "Featured items on the homepage".
**GitHub writes:** ZERO. No milestone created, no issue opened, no label applied, no comment posted.

---

## Step 0 — Read config + project docs

| Key | Resolved value | Source |
|---|---|---|
| `reviewer` | `"milestone-driver"` | `feeder.json` default |
| `projectDocs` | `project/` | `feeder.json` default |
| `architectAgent` | `milestone-feeder:architect` | bundled default |
| `issueAuthorAgent` | `milestone-feeder:issue-author` | bundled default |
| `issueSize` | *(none)* | default — ~1 PR each |

Shared keys (driver config, same resolve chain):

| Shared key | Value |
|---|---|
| `sourceGlobs` | `["src/**"]` |
| `uiSurfaceGlobs` | `["src/pages/**", "src/components/**"]` |
| `integrationBranch` | `"develop"` |
| `nonNegotiables` (reviewer-profile input passed to the gate, not a 4th shared key) | `["React 18 + TypeScript"]` |

Project docs read (best-effort): `project/conventions.md` present. Sections used:
- **UI** — reuse `ProductCardGrid` (`src/components/ProductCardGrid.tsx`) for any product listing.
- **Data** — read models in `src/models/`; a new persisted field requires a migration.
- **States** — empty + error states required on every user-facing surface.
- **Explicit note** — "nothing here states a product policy for HOW featured items are chosen. That is a product decision with no conventional default."

No degradation: `uiSurfaceGlobs` present → UI/logic distinction drawn normally. Note: no readable `src/` tree exists in the fixture; the `ProductCardGrid` / `src/models/` references are STATED conventions, cited as conventions (not fabricated `file:line`).

## Step 1 — Ingest the brief

Form: **inline text** (not `#<n>`, not a file path). Normalized:

```
goal:         Add a "Featured" section to the homepage that highlights a selection of
              catalog items, displayed in the standard product-card grid.
in-scope:     - A homepage "Featured" section in the standard product-card grid.
              - Whatever is needed to choose WHICH items are featured.
out-of-scope: - Redesigning the rest of the homepage.
surfaces:     - homepage
```
No `epicIssueNumber` (inline brief).

## Step 2 — Product-gap check (the park boundary)

The brief implies two classes of work:

| Brief part | Class | Why |
|---|---|---|
| Display the selected items in the standard product-card grid | **Design/impl — resolved** | `conventions.md` grounds it: reuse `ProductCardGrid`; empty + error states required. |
| "Whatever is needed to choose WHICH items are featured" | **PRODUCT decision — no conventional default** | `conventions.md` states *verbatim*: "nothing here states a product policy for HOW featured items are chosen. That is a product decision with no conventional default." |

**The product gap (why it has no conventional default):** the brief asks the pipeline to decide HOW an item becomes featured — manual editorial curation vs. derived from sales/popularity vs. a time-windowed campaign, who owns it, by what rule. The project docs deliberately decline to state this, and no stated repo convention answers it. The gap is not cosmetic: the *data shape itself* is dictated by that policy (a stored per-item flag vs. a derived query over sales data vs. a curated ordered list vs. a campaign table), so it determines the read model the whole feature reads from.

**STOP test:** is the candidate set un-formable without the gap (a hard Step-2 STOP)? **No** — a candidate set can still be *proposed* (a display surface + its states + a selection-data candidate), so we did not hard-STOP at Step 2. We carried `productGaps[]` forward and let the architect, the issue-author, and the **real** self-check gate decide each candidate honestly. (The run still lands at zero surviving issues — but via the per-candidate park/drop fork at Step 6, not a Step-2 STOP.)

`productGaps[]` after Step 2: **1** — the featured-selection policy.

## Step 3 — Dispatch the architect (once)

Dispatched `architect` exactly once with the normalized brief, the filled `conventions.md` sections, the resolved shared keys, and the carried product gap. (The feeder's own `architect` is not registered as a dispatchable subagent from this repo — documented harness caveat — so it was proxied via a general-purpose agent loaded with the full `agents/architect.md` contract; the heavy reasoning stayed off the main thread.) Returned:

| Tag | Title | Surface | Risk |
|---|---|---|---|
| #A | Add a featured flag to the product read model with a migration | logic | heavy |
| #B | Render the homepage Featured section using ProductCardGrid | ui | heavy |
| #C | Add empty and error states to the homepage Featured section | ui | light |

EDGES: `#B depends_on #A` (Featured section's sole data source is #A's `featured` field); `#C depends_on #B` (empty/error branches attach to #B's section markup).
WAVES: Wave 1 → #A; Wave 2 → #B; Wave 3 → #C.
PRODUCT_GAPS: **1** — the featured-selection policy (merged into `productGaps[]`; same gap as Step 2, no new gap).

Note: the architect proposed #A as "the smallest groundable selection mechanism — a manual per-item flag", but flagged that the *policy* for how an item earns the flag stays a product gap. The orchestrator does NOT accept "smallest mechanism" as grounding for the field's semantics — whether selection is a stored per-item flag at all is itself the undecided product call (it fixes the read model's shape). Carried to the issue-author and the real gate to test honestly rather than pre-judging.

## Step 4 — Dispatch issue-author per candidate

Dispatched `issue-author` once per candidate, in parallel. (Same harness caveat as Step 3 — the feeder's `issue-author` proxied via general-purpose agents loaded with the full `agents/issue-author.md` contract.) Returns:

| Tag | STATUS | Note |
|---|---|---|
| #A | **PRODUCT_GAP** | Author honestly refused to invent the `featured` field's semantics / default / backfill — no conventional default per `conventions.md`. Routed to `productGaps[]`; NOT authored (no fabricated body). |
| #B | AUTHORED | Full §4 body. Declares `Depends on #A` (consumes #A's `featured` field as its sole data source). |
| #C | AUTHORED | Full §4 body. Declares `Depends on #B`. |

#A's PRODUCT_GAP routed to `productGaps[]` per Step 4 (do NOT author a half-invented issue from a fabricated body; the candidate is recorded parked). #B and #C entered Step 6 as AUTHORED issues to be vetted by the real gate.

## Step 5 — Assemble graph + render the milestone description

Graph from the architect EDGES (local slugs): `#A → #B → #C`.

```
Add a "Featured" section to the homepage that highlights a selection of catalog
items, displayed in the standard product-card grid.

## Waves
- Wave 1 (parallel): #A
- Wave 2: #B (depends on #A)
- Wave 3: #C (depends on #B)
```

## Step 6 — Self-check gate (REAL reviewers)

**`reviewer: "milestone-driver"` → dispatched the REAL driver reviewers via the Agent tool. No self-review, no degrade.** The reviewers resolved and returned parseable blocks on the first dispatch → the backend stays `"milestone-driver"` for the run (no degrade-to-internal trigger fired).

**Dispatch counts:**

| Reviewer | Dispatches | Against |
|---|---|---|
| `milestone-driver:triage-reviewer` | **2** | #B, #C (the two AUTHORED issues; #A parked → nothing to vet) |
| `milestone-driver:design-reviewer` | **2** | #B, #C (both triages returned `NEEDS_DESIGN_REVIEW: yes`) |

**Aggregated verdicts (§6.3 — any `severity: Blocker` ⇒ FAIL; Advisory is non-gating):**

| Issue | triage-reviewer | design-reviewer | Aggregate |
|---|---|---|---|
| #B | **FAIL** — `undeclared-dependency` (sole data source #A is a parked product gap; the field shape #B must read is undefined) + `not-buildable` (ProductCardGrid contract unverifiable). Advisory: `missing-criteria` (loading state / section placement). | **FAIL** — `pattern-inconsistency` (unverifiable named pattern) + `missing-state` (no loading state for an async read). Advisory: `accessibility`, `spec-insufficiency`. | **FAIL** |
| #C | **PASS** — `GAPS: none`. The reviewer judged #C's *own* criteria buildable: they scope OUT the featuring policy and handle the three read outcomes (≥1 item / 0 items / failure) regardless of what "featured" means; the #A dependency is real-but-transitive and already declared via #B. | **FAIL** — `spec-insufficiency` ×2 (unverifiable pattern; empty/error copy undecided) + `missing-affordance` (no retry control on the error state). | **FAIL** |

**Did the gate catch a body papering over the undecided product decision?** **Yes.** #B's authored body asserted it "renders whatever set #A's data source yields" — a tidy hand-off that quietly rested on the undecided `featured` semantics. The real `triage-reviewer` rejected it as a **Blocker** (`undeclared-dependency` / `not-buildable`): "a render surface whose sole data source is a parked, unauthored product decision is not buildable as recorded." The gate did NOT let #B through — it surfaced the dodge.

**§6.5 / §6.6 — retry / park / drop fork:**

| Issue | Root Blocker class | Action | Reason |
|---|---|---|---|
| #A | **genuine product gap** (§6.5 row 2) | **PARK** (product-gap) | No conventional default for the featured-selection policy. Re-authoring cannot resolve a product gap — only a human can decide what `featured` means. |
| #B | dependent of parked #A | **DROP** (dropped-because-dependency, §6.6) | A dependent of a parked issue cannot build. #B's sole data source is the parked #A → dropped. No re-author retries spent — the root Blocker is the parked product decision, not a recordable design/impl call. |
| #C | transitive dependent of parked #A (via #B) | **DROP** (dropped-because-dependency, §6.6) | #C → #B → #A; the chain rests on the parked product decision. #C's own triage passed, but it cannot build atop a dropped chain. The design Blockers on #C are moot once it drops. |

**§6.6 edge note:** no `undeclared-dependency` edge was *absorbed-and-re-rendered* into a shippable graph — the edge target (#A) is itself parked, so #B/#C drop rather than re-render an edge to a dropped node. The re-render-after-dropping leaves the Wave order empty.

**Re-author retries spent:** 0 of the ≤2-per-issue cap. No re-dispatch was warranted: #A is a product gap (un-retryable), and #B/#C drop as dependents of the parked #A rather than being re-authored. No issue was ever planned unvetted.

**Surviving issue set after §6.6: EMPTY.** Every candidate parked or dropped. Zero issues to emit.

## Step 7 — Write the plan-file PREVIEW

No issues survive → the plan-file artifact carries the milestone header, the `Self-check: PARKED` verdict line, **zero emitted issue bodies**, the parked/dropped markers, the project-docs grounding, and a pointer to the needs-product-input report. The report names the one undecided decision precisely. Both render into `run-output.md`. (In a real run these are `.milestone-feeder/plan-<slug>.md` + `.milestone-feeder/needs-product-input-<slug>.md`, slug `add-a-featured-section-to-the-homepage-that-highlights-a-sel`, gitignored scratch; here the test's WRITE instruction folds the report into `run-output.md`.)

---

## Parks

| # | Kind | Item | Why no conventional default | Blocks |
|---|---|---|---|---|
| 1 | product-gap | The policy for HOW items become featured — who decides and by what rule (manual editorial curation / derived from sales-popularity / time-windowed campaign), which fixes the featured data shape, owner, default, and backfill | `conventions.md` states verbatim there is no product policy for choosing featured items and calls it "a product decision with no conventional default." No project doc or stated convention supplies a default selection rule; the read model's shape itself depends on it. | #A (the data field), #B (the render surface — dropped), #C (the states — dropped) — i.e. the entire feature |

## Drops

| Tag | Title | Dropped because |
|---|---|---|
| #B | Render the homepage Featured section using ProductCardGrid | depends on parked #A (its sole data source) |
| #C | Add empty and error states to the homepage Featured section | transitively depends on parked #A (via #B) |

## Outcome

- Candidates: 3 (#A logic, #B ui, #C ui).
- Parked: 1 (#A — product-gap).
- Dropped: 2 (#B, #C — dependents of the parked #A).
- **Surviving / emitted issues: 0.**
- Self-check verdict: **PARKED** — 1 product gap; 0 needs-human-direction.

**Gate ran with REAL reviewers?** YES — `milestone-driver:triage-reviewer` ×2 (#B, #C) and `milestone-driver:design-reviewer` ×2 (#B, #C), dispatched read-only against the generated text via the Agent tool. No `"internal"` degrade, no self-review. The gate rejected #B's product-gap dodge as a Blocker. (The architect and issue-author were proxied per the documented harness caveat; the load-bearing GATE used the real driver reviewers.)

**GitHub writes:** ZERO (PREVIEW). No milestone, no issue, no label, no comment.
