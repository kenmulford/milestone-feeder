# Expected contract: 17 shared-file ordering  (GRADER ONLY)

A small backend brief (queue an export, list exports, the pipeline behind them, a filename
helper, lifecycle telemetry) is broken down against a project whose `.project` states a
**single-registry convention** (`project/conventions.md#Registries`): every HTTP path is
bound in `src/routes/index.ts`, and every service, job, and migration is registered in
`src/app/modules.ts`. Several candidates therefore modify the same existing file. The
project states no layering convention, so the clause-9 layer pass is a no-op and the
ordering under test is clause 11's alone.

The claim under test: **each candidate declares the existing files it modifies as a
grounded `edits:` list; two candidates whose lists intersect get an ordering edge
`#B after #A - edits: <path>` naming every shared path, which the Wave sort consumes like
any other edge, so they land in successive Waves rather than one parallel Wave; a clause 3
or clause 9 edge already relating a pair orders it and suppresses the `after` edge; the
`edits:` list threads through to each issue body's `Edits:` line; and a breakdown whose
`edits:` lists are all disjoint produces the `EDGES` set and Wave order the concrete
dependency edges alone produce.**

This is a **plan-side, preview-only** scenario (zero GitHub writes), mirroring the
plan-side portion of scenarios 11, 12, and 13.

The expected candidate set (local tags; exact titles may vary):

| Tag | Candidate | Introduces | `edits:` |
|---|---|---|---|
| #A | Export filename helper: URL-safe filename from a report title | `src/util/exportName.ts` | (no `edits:` field) |
| #B | Export pipeline: write the CSV, record the export row, retention default | `src/services/ExportPipeline.ts`, the `exports` migration, plus `src/jobs/RunExportJob.ts` when the queue job rides #B | `src/app/modules.ts`, `src/config/defaults.ts`, `src/db/migrations/index.ts` |
| #C | `POST /exports`: queue an export, refuse past the in-flight cap | `src/jobs/RunExportJob.ts` when the queue job rides #C (otherwise it rides #B per `project/conventions.md#Naming`, "the job is the thin wrapper the queue runs") | `src/routes/index.ts`, `src/config/defaults.ts`, plus `src/app/modules.ts` when the job rides #C |
| #D | `GET /exports`: list a user's exports | (none) | `src/routes/index.ts` |
| #E | Export lifecycle telemetry events | (none) | `src/telemetry/events.ts` |

Concrete clause 3 edges: `#B depends_on #A` (the pipeline calls the filename helper),
`#C depends_on #B` (the queue job invokes the pipeline), `#D depends_on #B` (the list
endpoint reads the `exports` table the pipeline's migration adds).

`EDGES` **may** also carry one telemetry edge (`#B depends_on #E` or `#C depends_on #E`),
grounded in `project/conventions.md#Registries`: every event name is declared in
`src/telemetry/events.ts` before it is emitted. Its presence or absence changes no Wave
assertion below (#E has no dependency of its own and stays in Wave 1 either way).

Wave order under the concrete edges alone: Wave 1 `#A, #E` · Wave 2 `#B` · Wave 3 `#C, #D`.
**#C and #D share Wave 3 and both edit `src/routes/index.ts`**: that collision is the
defect this scenario exists to catch.

---

## MUST: (a) two candidates editing the same path, no other relation, land in successive Waves  (AC2, AC3)

- #C and #D both carry `src/routes/index.ts` in `edits:`, and **no** clause 3 edge relates
  the pair (neither consumes an artifact the other introduces; each depends on #B only).
  The project states no layering convention, so no clause 9 edge relates them either.
- The architect emits exactly one ordering edge for the pair, in the `EDGES` block, in the
  clause 11 shape. Direction: the sort over clause 3 and clause 9 edges alone puts #C and
  #D in the **same** Wave (both depend on #B, nothing else relates them), so the tie breaks
  on list size: **`#D` first**, its `edits:` list being the smaller. The reason **names the
  shared path**: `#C after #D - edits: src/routes/index.ts`.
- #C's list is the larger **independent of where the queue job lands**: the in-flight cap
  makes `POST /exports` read a new config key, which `project/conventions.md#Registries`
  puts in `src/config/defaults.ts`. #C therefore carries at least `src/routes/index.ts` and
  `src/config/defaults.ts` against #D's single path.
- Clause 4's topological sort consumes it like any other edge, so the two land in
  **successive** Waves: **Wave 3 `#D`**, **Wave 4 `#C`**. The full order is Wave 1 `#A, #E`
  · Wave 2 `#B` · Wave 3 `#D` · Wave 4 `#C`.
- **The load-bearing check:** the edge exists at all. Nothing in the artifact-reference
  heuristic relates #C to #D; only the intersecting `edits:` lists do. Its presence is the
  proof that the order reflects the shared file, not only the artifacts one candidate
  introduces.

## MUST: (b) a clause 3 edge already relating the pair orders it  (AC2)

- #B and #C both carry `src/config/defaults.ts` in `edits:` (the 30-day retention default;
  the in-flight cap), and, when the queue job rides #C, `src/app/modules.ts` as well. A
  concrete clause 3 edge already relates them: `#C depends_on #B`.
- **No `after` edge is emitted for that pair, in either direction.** The pair's order is
  the clause 3 edge's: #B first. The pair carries exactly one edge, not two.
- List size never gets a vote here: clause 11 derives direction from the clause 3 / clause 9
  order first, so an `after` edge can neither be emitted for this pair nor point against
  `#C depends_on #B`.

## MUST: (c) disjoint `edits:` lists produce no edge and no Wave change  (AC2, AC3)

- #E's `edits:` list (`src/telemetry/events.ts`) intersects no other candidate's, and #A
  carries no `edits:` field at all. **No `after` edge names #A or #E.**
- #A and #E stay **parallel in Wave 1**, exactly as the concrete-edge breakdown places
  them. A candidate with no shared file is ordered by its concrete edges alone. An optional
  telemetry `depends_on #E` edge does not move #E: it has no dependency of its own.
- Every non-overlapping pair is treated the same way: the `after` edge is emitted
  **pairwise over overlapping pairs only** (here #C/#D), never over the candidate set at
  large.

## MUST: (d) every `edits:` path names a file that exists, grep-verified  (AC1, AC5)

- Every path in every `edits:` list is one of the existing files `feeder-env.md` declares
  (`src/routes/index.ts`, `src/app/modules.ts`, `src/config/defaults.ts`,
  `src/db/migrations/index.ts`, `src/telemetry/events.ts`). That list is exhaustive.
- **`src/jobs/manifest.ts` appears in NO `edits:` list, and NO candidate introduces it.**
  The brief names it as the queue manifest, but it does not exist, and
  `project/conventions.md#Registries` registers every job in `src/app/modules.ts`. The
  correct move is therefore to edit `src/app/modules.ts` on the candidate that ships the
  export job. Two tempting failures: listing the brief's path under `edits:` (ungrounded,
  the file does not exist), or introducing it as a new file (a second job registry, against
  the stated convention).
- A file a candidate itself introduces is never in its own `edits:` list: not
  `src/util/exportName.ts` on #A, not `src/services/ExportPipeline.ts` on #B, not
  `src/jobs/RunExportJob.ts` on whichever candidate introduces it.
- The canonical exemplars (`src/services/ArchiveService.ts`, `src/jobs/RebuildIndexJob.ts`,
  `src/util/formatBytes.ts`) exist and are patterns to mirror. They are in no `edits:` list.

## MUST: (e) the `edits:` list threads through to the issue body  (AC4)

- For each surviving issue whose candidate carried `edits:`, the `plan` run threads the
  list into the issue-author brief, and the authored §4 `ISSUE_BODY` records it as an
  **`Edits:` line inside the existing `## Design (recorded, consistent)` block**
  (`agents/issue-author.md`: no new §4 section header is invented), the paths transcribed
  verbatim. For #D: `Edits: src/routes/index.ts`.
- **#A carries no `Edits:` line**, because its candidate carried no `edits:` field.
- Because `plan` renders each surviving issue's full §4 body verbatim in the plan file's
  `## Issues`, the `Edits:` line is visible per issue, so the driver's triage and
  implementer see the file scope before the branch is cut.

## MUST: CONTROL / negative: no overlapping `edits:` lists → the concrete-edge order  (AC2)

- **Asserted alternate.** The **same brief** run against a project whose convention gives
  each surface its own registration file (one file per route, per-module self-registration,
  a per-migration folder scan, one file per config key), so no two candidates' `edits:`
  lists intersect, produces the `EDGES` set and Wave order the **concrete edges alone**
  produce, byte-for-byte:
  - **No `after` edge is emitted.** `EDGES` carries the three named clause 3 edges, may
    also carry the telemetry `depends_on #E` edge, and carries no clause 11 edge.
  - The Wave order is Wave 1 `#A, #E` · Wave 2 `#B` · **Wave 3 `#C, #D` (parallel)**: #C
    and #D are back in one Wave, because no shared file separates them.
  - Candidates still carry their `edits:` fields where they modify an existing file. The
    byte-for-byte claim binds `EDGES` and the Wave order, never `CANDIDATES`: the field is
    emitted; only the edge is absent.
  - No error, no fabricated overlap. This is an asserted **success** outcome, not a park
    and not a failure.

## METRIC for this scenario

- Every candidate that modifies an existing file carries an `edits:` list, every path in
  it declared to exist (record which candidates carried one and whether every path was
  grounded).
- The `after` edge `#C after #D - edits: src/routes/index.ts` present, its reason naming
  the shared path (yes/no): the shared-file-collision proof.
- The Wave order places #C and #D in successive Waves, #C last (yes/no).
- No `after` edge emitted for the #B/#C pair, which a clause 3 edge already relates
  (yes/no).
- `src/jobs/manifest.ts` in no `edits:` list and introduced by no candidate, the export job
  registered by an edit to `src/app/modules.ts` instead, on whichever candidate ships the job
  (yes/no).
- Each surviving affected issue body carries an `Edits:` line in its `## Design` block, and
  #A carries none (yes/no).
- CONTROL: the disjoint-`edits:` alternate emits no `after` edge, returns #C and #D to one
  parallel Wave, and errors on nothing (yes/no).

## FAIL if

- An `after` edge is emitted for a pair a **clause 3 or clause 9 edge already relates** (an
  edge `#C after #B` or `#B after #C` alongside `#C depends_on #B`), or a clause 11 edge
  points against the order those clauses set.
- An `edits:` path names a file the environment does not declare, `src/jobs/manifest.ts`
  above all, or names a file the candidate itself introduces.
- A candidate **introduces** `src/jobs/manifest.ts` instead of editing `src/app/modules.ts`.
- An `after` edge's reason **omits a shared path**, or carries a citation or a rationale in
  place of the path list.
- The `edits:` list never reaches the issue body (no `Edits:` line in the `## Design` block
  of a surviving affected issue), or the author invents a **new §4 section** for it instead
  of recording it in the existing Design block.
- #C and #D stay in the **same Wave** despite both editing `src/routes/index.ts`, i.e. the
  topological sort ignored the `after` edge.
- The CONTROL (disjoint) alternate nonetheless emits an `after` edge, splits #C and #D
  across Waves, or errors instead of producing the concrete-edge order.

## Disabled / edge: bash/pwsh parity

- This scenario is **plan-side, preview-only** and **prose-direct**: the `edits:` capture /
  edge emission / ordering / threading flow is prose the runner follows; it touches no
  scenario-specific scripted (bash/pwsh) twin. **Cross-platform parity is recorded N/A**
  for this scenario (mirroring scenarios 11, 12, and 13's plan-side preview portion).
- `expected.grader.md` is **grader-only** (the runner never sees it). Appended at **NN=17**
  (16 is the remediate sandbox follow-up, designed in `tests/README.md` with no directory
  on disk).
