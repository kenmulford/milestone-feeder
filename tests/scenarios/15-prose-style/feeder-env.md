# Test environment — 15 prose style (what the run assumes)

The brief adds a paginated activity-log list to a project whose `.project` states a
list convention in `project/conventions.md#Lists` — lists paginate at 30 rows per page
and mirror the existing list pattern at `src/lists/ActivityListService.ts`. The "30 rows
per page" figure is a **literal directive with a conventional default**: the issue-author
records it verbatim, and it is the content the prose-style guardrail must protect through
a concision pass.

The claim under test: **the issue-author's authored `ISSUE_BODY` obeys the prose-style
ruleset (`agents/issue-author.md` → `## Prose style`) — a Summary of 2–3 plain sentences,
no banned filler vocabulary or hedges, one declarative line per acceptance criterion and
per recorded design decision (the citation is the rationale, no appended sentence), and no
template narration — while the content-preservation guardrail keeps every completeness
state, the literal "30 rows per page" directive, and the grounded `Convention followed:`
citation present verbatim; a deliberately padded rewrite of the same body FAILS those prose
assertions, and a rewrite that trims prose by dropping a state or weakening the directive
FAILS the guardrail.**

This is a **plan-side, preview-only** scenario (zero GitHub writes), mirroring the
plan-side portion of scenarios 11–14.

- `feeder.json`: defaults (`projectDocs: project/`).
- Driver shared keys (as if from `.milestone-config/driver.json`):
  - `sourceGlobs`: `["src/**"]`
  - `uiSurfaceGlobs`: absent   # no UI surface matched → the candidate classifies `logic`
  - `integrationBranch`: `"develop"`
- Project docs dir: `project/`
