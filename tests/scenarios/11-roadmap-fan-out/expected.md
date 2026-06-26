# Expected contract — 11 roadmap-fan-out  (GRADER ONLY)

An **oversized whole-app brief** that spans several milestones. `plan`'s front-door
(Step 3.6) must route it into the `build-roadmap` flow: **split** the brief into a
sequenced set of milestones → **confirm** that split → **parallel-plan** each
milestone (Step 3.7 fan-out) → (then `create`) **deploy-loop** + **verify** against
the original brief. This scenario asserts the three roadmap artifact classes the
path must emit, the empty / clean / degenerate outcomes, and the preview-vs-sandbox
execution split.

The claim under test (currently Unbacked): **`plan` turns a whole-app brief into an
ordered roadmap of milestones, plans each, and `create` deploys + audits them back
against the original brief.**

## Run-now scope vs sandbox follow-up (the execution split)

Per the harness write-path rule (`tests/README.md` "Execution model", lines 29 & 33–35):

| Path | Artifacts | Run now? |
|---|---|---|
| **Plan-side:** split → confirm → parallel-plan | the roadmap **manifest** + the **N per-milestone plan files**, emitted as **text artifacts** under `.milestone-feeder/` with **zero GitHub writes** | **✅ preview now** |
| **Create-side:** create deploy-loop (Step 1R) + post-create brief-coverage verification (Step 3V) | live milestones/issues + the coverage **punch-list** | **Sandbox follow-up** — designed here, run later against a throwaway repo, **labeled, not silently skipped** |

A grader runs the **✅** rows now and confirms the **sandbox** rows are designed (the
assertions exist), not executed.

---

## MUST — artifact class 1: the roadmap MANIFEST  (✅ preview)

- The front-door **routes** (architect raises `SCOPE_SPANS_MULTIPLE_MILESTONES`;
  `plan` Step 3.6 enters `build-roadmap`). It does **not** fall through to the
  single-milestone pipeline for the whole brief.
- Exactly **one** manifest is written, at `.milestone-feeder/roadmap-<slug>.md`
  (`<slug>` derived from the whole-app brief's one-line goal by the Naming rule).
- The manifest header carries: `Source brief:` (here `inline` or `file:…`),
  `Confirmed: yes` (the user-confirmed split, not the raw proposal), and a
  `Build order: <M1> → <M2> → … → <MN>` line.
- A **`## Original brief` … `## End original brief` paired-delimiter section persists
  the FULL whole-app brief, multi-line** — every author section, verbatim or
  near-verbatim, with the literal `## End original brief` line emitted immediately after
  the brief text. The brief extracts **intact even when it contains its own `## `
  headings** — Step 3V reads the lines strictly between the paired markers, so a brief
  with internal `## ` sections is NOT truncated at its first heading. (This is the
  durable copy the Step-3V verification reads; persisting it is the manifest's contract.)
- `## Milestones (in build order)` lists **N ≥ 2** entries forming a **strict
  partition** of the brief's in-scope: every author section assigned to exactly one
  milestone, none dropped, none duplicated, positions running `1..N` with no gaps or
  repeats. Each `### <position>. <name>` entry carries all five fields:
  - **name** — a milestone title,
  - **Brief slice** — the author section(s) this milestone owns,
  - **Build-order position** — its `1..N` slot,
  - **Plan file** — the `.milestone-feeder/plan-<slug>.md` handle (PENDING when
    `build-roadmap` writes the manifest; **populated by the Step-3.7 fan-out** after
    each milestone is planned — see artifact class 2),
  - **Change-rationale** — `merged | split | reordered | unchanged` **vs the
    author's headings**, with the reason.
- **The split records a real diff:** at least one milestone's change-rationale is a
  non-trivial **merge** or **reorder** (e.g. the data-model section folded into the
  milestone that first needs it; auth ordered first as the foundation;
  notifications/payments ordered after the things they act on). A roadmap that is a
  1:1 copy of the author's headings with every rationale `unchanged` fails to
  demonstrate the split.
- **Build order is a real dependency sequence**, not the author's listing order:
  the foundation milestone (accounts/auth) is **position 1**; a milestone that can
  only act on data another milestone introduces (notifications, payments,
  portal/reporting screens) sits **after** it.

## MUST — artifact class 2: the N per-milestone PLAN FILES  (✅ preview)

- The Step-3.7 fan-out plans **every** milestone the confirmed manifest names and
  emits **one plan file per milestone** at `.milestone-feeder/plan-<slug>.md`
  (with the deterministic `-m<index>` tiebreaker only if two milestones derive the
  same slug). **N milestones → N plan files.**
- Each plan file is an **ordinary single-milestone plan** produced by the existing
  pipeline unchanged: §4-shaped issue bodies, the milestone's intra-milestone Wave
  order, the self-check verdict, the `Milestone title (exact)` line. (Per-milestone
  planning reuses the single-milestone pipeline; the roadmap path adds the **outer**
  fan-out, not a new per-issue format.)
- After the fan-out, **each manifest entry's `Plan file:` field is populated** with
  that milestone's real path (no longer PENDING) — the handle `create`'s deploy-loop
  later resolves each milestone by (never a name-derived slug).
- **UI classification engages per milestone:** because `uiSurfaceGlobs` is set, the
  portal / dashboard / revenue-report **page-issues classify `ui`** and their
  authoring runs the `design-reviewer` (states + `DataTable` + 30/page directive
  cited from `project/conventions.md`); the auth / data-model / API issues classify
  `logic`.

## MUST — empty fan-out: single-milestone collapse is a valid outcome, not an error  (✅ preview)

- **Asserted alternate:** if the split **collapses to a single milestone** (the
  splitter returns fewer than two entries — e.g. were the brief reduced to just
  *Accounts & access*), then **NO manifest is written**, `build-roadmap` returns no
  manifest path, and `plan` **falls back to its single-milestone pipeline on the
  whole brief, unchanged** — zero roadmap artifacts (no manifest, no fan-out). This
  is an **asserted success outcome, not an error** and not a park.
- The equivalent guard holds at the fan-out (`plan` Step 3.7.a): **N = 0 → no probe,
  no dispatch, no plan files**, surfaced as empty, not aborted.

## MUST — degenerate: an undecided product call PARKS one issue and siblings continue  (✅ preview)

- The **Payments & billing** slice carries a product call with **no conventional
  default** — the brief names no payment provider, no currency, no fee/tax policy,
  and `project/conventions.md` supplies none (it fixes only the integer-minor-units
  storage representation). The issue that needs that decision must **PARK** to the
  **needs-product-input** report — **never invent** a provider, currency, or fee
  rule.
- **Parking is scoped, not fatal:** the park drops only the issue(s) that depend on
  the undecided call (and their dependents). **Sibling issues in the same milestone
  that the conventions DO ground continue to plan** — e.g. the `Payment` data model,
  the payment→invoice association, the "paid" status flip / badge. The park does
  **not** abort the Payments milestone, and **does not abort the roadmap**: the other
  milestones plan normally (`plan` Step 3.7.g — one milestone's trouble never aborts
  the roadmap; a failed-to-plan milestone is recorded, siblings continue).
- The needs-product-input report itemizes the parked decision with its blocking
  reason and brief reference; the manifest/plan artifacts for the unaffected work
  still emit.

## MUST — artifact class 3: the create deploy-loop  (SANDBOX follow-up — designed, not run now)

Designed here; **run later against a throwaway sandbox repo** (this makes real
GitHub writes, excluded from the preview run per `tests/README.md` lines 33–35):

- `create` Step 1R finds the manifest and runs the **outer loop** over its milestones
  **in build order (position 1 → N)**: for each, resolve the recorded `Plan file:`
  path, deploy via Step 3 passes a–e (labels / create-or-adopt milestone by exact
  title / open surviving issues / slug→`#n` rewrite + Wave PATCH / route report), and
  PATCH a single canonical `build order: milestone X of N` line into its description.
- **Idempotent / non-destructive:** create-or-adopt per milestone — never deletes,
  never duplicates a same-title open issue; a mid-loop failure **stops and reports**
  which milestones deployed, which failed and at which pass, which remain — and a
  re-run **resumes** (already-deployed milestones adopted by exact title).
- **Parked issues are never created**; they route to the needs-input report.

## MUST — artifact class 3 (cont.): the brief-coverage VERIFICATION punch-list  (SANDBOX follow-up — designed)

`create`'s closing step (Step 3V) reads back **all N** deployed milestones + issues
and dispatches `milestone-feeder:brief-coverage-verifier` against the manifest's
brief — the lines between the paired `## Original brief` … `## End original brief`
markers — returning `COVERAGE_VERDICT / UNCOVERED / DUPLICATED /
DISTORTED / READ_ERRORS`. Always-on, **non-blocking**, **never auto-fixes**. Two
asserted outcomes:

- **Clean verification:** when nothing is missing / duplicated / distorted (all four
  lists `none`), the punch-list is **empty** and the run reports
  **`coverage verified — nothing missed`** — and routes nothing.
- **Non-empty punch-list:** when a brief item is **uncovered, duplicated, or
  distorted** (e.g. the brief's weekly owner-summary email is covered by no deployed
  issue, or two milestones both claim the revenue report), the verifier returns a
  **NON-empty** block that **itemizes the fix** (the uncovered/duplicated/distorted
  item + where), routed to the local `.milestone-feeder/coverage-<slug>.md` (file/
  inline brief) or as an epic comment (`epic #<n>` brief). It is **advisory** —
  `create` changes nothing on GitHub to resolve it.

## Disabled / edge — bash/pwsh parity

- The plan-side preview portion (split → confirm → parallel-plan) is **prose-only**:
  the only scripted twins it touches are the scratch-dir self-ignore
  (`.milestone-feeder/.gitignore` ← `*`) writes, which carry no scenario-specific
  finding. **Parity is recorded N/A for the preview portion.**
- The cross-platform-parity obligation therefore **lands on the sandbox create-loop
  run**: where the deploy-loop / read-back `gh` twins (Step 1R, Step 3V — bash +
  PowerShell 7+) are exercised, the sandbox run MUST assert the two twins produce
  **identical** deploy receipts and identical coverage findings on the same inputs.
  (Cross-platform parity is itself a test obligation — `nonNegotiables`;
  `.project/conventions.md#Test patterns`.)

## SHOULD

- Convention citations point at the provided `project/conventions.md` (real
  grounding) — REST shape, `requireRole()` / owner-scope, `useToast()`, required
  states, `DataTable` + 30/page — not invented.
- The milestone split mirrors real build dependencies (one milestone per coherent
  release boundary), not an arbitrary even slicing of the author sections.

## FAIL if

- The oversized brief is **not routed** — `plan` plans it as one single milestone
  (no manifest, no fan-out) when the brief plainly spans several releases.
- The manifest is **not a strict partition** (an author section dropped or
  double-assigned; positions with a gap/repeat), or omits the `## Original brief`
  full persist **or its paired `## End original brief` closing delimiter** (or
  truncates the brief at an internal `## ` heading instead of wrapping it in the paired
  markers), or any milestone entry is missing name / slice / position /
  `Plan file:` / change-rationale.
- Fewer than **N plan files** are emitted (a milestone the manifest names is never
  planned), or a `Plan file:` field is left PENDING after the fan-out for a milestone
  that planned successfully.
- The single-milestone-collapse case is treated as an **error** (or papered over with
  a fabricated extra milestone) instead of a clean fall-back to single-milestone
  planning.
- The undecided payment product call is **invented** (a provider/currency/fee value
  guessed) instead of parked; or the park **aborts** the Payments milestone or the
  whole roadmap instead of dropping only the blocked issue and continuing siblings.
- The page-issues (portal / dashboard / report) classify `logic` (uiSurfaceGlobs
  ignored) so the design lens never runs, or drop the `DataTable` / 30-per-page
  directive.
- The sandbox create-loop / verification assertions are **silently dropped** rather
  than designed-and-labeled; or the bash/pwsh parity obligation is neither recorded
  N/A (preview) nor owed to the sandbox run.
