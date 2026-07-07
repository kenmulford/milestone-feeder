# Expected contract — 13 layer-aware breakdown  (GRADER ONLY)

A small backend brief (list + create notes, with a slug helper) is broken down against
a project whose `.project` states a **strict layering convention**
(`project/design-philosophy.md#Layering & boundaries`): `util/` ← `data/` ←
`services/` ← `controllers/` ← `routes/`, with CRUD in `data/`, request validation in
`controllers/`, and formatting/slug helpers in `util/`.

The claim under test: **the architect reads the project's stack + layering convention,
assigns each candidate its architectural layer, and derives the issue order + edges
from the layer dependency — not only from ad-hoc type references — grounding every
layer assignment in the stated architecture, threading the layer through to each issue
body; and a project stating no layering convention degrades to today's dependency-only
breakdown, byte-for-byte.**

This is a **plan-side, preview-only** scenario (zero GitHub writes), mirroring the
plan-side portion of scenarios 11 and 12.

The expected candidate set (local tags; exact titles may vary):

| Tag | Candidate | Layer | Layer file (per conventions) |
|---|---|---|---|
| #A | Note repository — list a user's notes, insert a note (CRUD) | `data` | `src/data/NoteRepository.ts` |
| #B | Slug helper — URL-safe slug from a title | `util` | `src/util/slug.ts` |
| #C | Notes service — build + persist a note, list a user's notes | `services` | `src/services/NoteService.ts` |
| #D | Notes controller — validate the request, handle list + create | `controllers` | `src/controllers/NoteController.ts` |
| #E | Notes routes — bind GET/POST /notes to the controller | `routes` | `src/routes/note.ts` |

---

## MUST — (a) the architect reads the layering convention and assigns each candidate a layer  (AC1)

- The architect **consults the stated architecture** — primarily
  `.project/design-philosophy.md#Layering & boundaries` (handed in via the digest,
  named by `plan` Step 3's stack + layering anchors bullet), with
  `.project/conventions.md#File & folder layout` for file placement.
- **Every** candidate carries a `layer` field naming the architectural layer its
  convention dictates: #A → `data`, #B → `util`, #C → `services`, #D → `controllers`,
  #E → `routes`. The **CRUD** task (#A) lands in `data`; the **helper** (#B) lands in
  `util`; **request validation** rides the controller layer (#D) — each placed where
  the convention dictates, not where the brief happened to mention it.

## MUST — (b) the Wave order is keyed by the LAYER dependency, not only ad-hoc type references  (AC2)

- The architect emits **layer-keyed edges** (`agents/architect.md` clause 9,
  same `EDGES` shape) so a layer precedes the layers that depend on it. The resulting
  Wave order respects the layer dependency `util`/`data` → `services` → `controllers`
  → `routes`, e.g.:
  - **Wave 1 (parallel):** #A (`data`), #B (`util`) — both leaves.
  - **Wave 2:** #C (`services`) — after #A and #B.
  - **Wave 3:** #D (`controllers`) — after #C.
  - **Wave 4:** #E (`routes`) — after #D.
- **The load-bearing check:** the edge **#C depends_on #A** is present and is grounded
  as a **layer** edge (`layer: services depends on data per
  .project/design-philosophy.md#Layering & boundaries`), NOT as a concrete type
  reference — because the service receives its repository by constructor injection (an
  interface) and never names the concrete `NoteRepository` type. This is the edge a
  naive "references a type another candidate introduces" heuristic would MISS; the
  layer convention is what orders #C after #A. Its presence is the proof that the order
  reflects the **layer** dependency, not only ad-hoc type references.
- Concrete artifact edges still hold and stay **authoritative**: #C depends_on #B (the
  service calls the slug helper), #D depends_on #C (the controller references the
  service), #E depends_on #D (the route binds the controller). A layer edge only orders
  candidates that are otherwise independent; it never contradicts a concrete edge.

## MUST — (c) each layer assignment is grounded, never invented  (AC3)

- Every candidate's `layer` field, and every layer edge, **cites the project's stated
  architecture** — `.project/design-philosophy.md#Layering & boundaries` (or the
  sibling `.project/conventions.md#File & folder layout` / a `file:line` exemplar such
  as `src/services/UserService.ts`). A `layer` with no such citation is a failure.
- No layer is **invented**: the architect assigns only the layers the convention names
  (`util` / `data` / `services` / `controllers` / `routes`) — it does not manufacture a
  layer the docs do not state.

## MUST — (d) the layer threads through to the issue body  (AC5)

- For each surviving issue, the `plan` run threads the candidate's `layer` into the
  issue-author brief, and the authored §4 `ISSUE_BODY` records it as a **`Layer:` line
  inside the existing `## Design (recorded, consistent)` block** (`agents/issue-author.md`
  — no new §4 section header is invented). The line names the layer and carries the
  stated-architecture citation — e.g. for #C: `Layer: services —
  .project/design-philosophy.md#Layering & boundaries`.
- Because `plan` renders each surviving issue's full §4 body verbatim in the plan
  file's `## Issues`, the `Layer:` line is visible in the plan file per issue — so the
  driver sees which layer the work sits in.

## MUST — CONTROL / negative: no layering convention → degrade to today's dependency-only breakdown  (AC4)

- **Asserted alternate.** The **same brief** run against a project whose `.project`
  states **no** layering convention (the `Layering & boundaries` section absent or
  `[TBD]`, or an unlayered stack) produces the **dependency-only** breakdown it does
  today, byte-for-byte:
  - **No** candidate carries a `layer` field; **no** issue body carries a `Layer:`
    line.
  - **No** layer-keyed edge is emitted. In particular the edge **#C depends_on #A is
    ABSENT** — with no layering convention and the repository injected (no concrete type
    reference), nothing relates #C to #A, exactly as today. The Wave order is built from
    concrete artifact edges only (#C→#B, #D→#C, #E→#D).
  - No error, no fabricated layering. This is an asserted **success** outcome, not a
    park and not a failure (`.project/design-philosophy.md#Error & failure philosophy`).

## METRIC for this scenario

- Every candidate assigned its correct layer, each with a stated-architecture citation
  (target: #A `data`, #B `util`, #C `services`, #D `controllers`, #E `routes` — record
  which were correct and cited).
- The **layer** edge #C depends_on #A present and grounded as a layer edge (yes/no) —
  the ad-hoc-type-reference-miss proof.
- The Wave order respects `util`/`data` → `services` → `controllers` → `routes`
  (yes/no).
- Each surviving issue body carries a grounded `Layer:` line in its `## Design` block
  (yes/no).
- CONTROL: the no-layering alternate carries no `layer` field, no `Layer:` line, no
  layer edge (#C depends_on #A absent), and errors on nothing (yes/no).

## FAIL if

- A layer is **invented** — assigned with no citation to a stated layering convention,
  or naming a layer the `.project` docs do not state.
- The Wave order ignores the layer dependency — e.g. #D (`controllers`) or #E
  (`routes`) is placed in Wave 1, or #C (`services`) is not ordered after #A (`data`)
  when the layering convention is present.
- The `layer` never reaches the issue body — no `Layer:` line in the `## Design` block
  of a surviving issue — or the author invents a **new §4 section** for it instead of
  recording it in the existing Design block.
- The layer edge #C depends_on #A is emitted as (or mislabeled as) a **concrete type
  reference** rather than a grounded **layer** edge — hiding that the ordering came from
  the layering convention, not a textual reference.
- The CONTROL (no-layering) alternate nonetheless emits a `layer` field, a `Layer:`
  line, or a layer edge — i.e. it does **not** degrade to today's dependency-only
  breakdown — or it errors instead of degrading.

## Disabled / edge — bash/pwsh parity

- This scenario is **plan-side, preview-only** and **prose-direct** — the layer
  assignment / ordering / threading flow is prose the runner follows; it touches no
  scenario-specific scripted (bash/pwsh) twin. **Cross-platform parity is recorded
  N/A** for this scenario (mirroring scenarios 11 and 12's plan-side preview portion).
- `expected.grader.md` is **grader-only** (the runner never sees it). Appended at **NN=13**
  (on-disk 01–06, 10, 11, 12; 07–09 reserved for the sandbox `create` / `update`
  scenarios).
