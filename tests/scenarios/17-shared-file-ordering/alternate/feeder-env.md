# Test environment: 17 shared-file ordering, CONTROL alternate (what the run assumes)

The brief adds CSV exports to a TypeScript/Node backend whose `.project` states a **per-surface
registration convention** (`project/conventions.md#Registration`): each HTTP path, service, job,
migration, config key and telemetry event registers in its own file. No two candidates' `edits:`
lists intersect, so the run degrades to the order the concrete dependency edges alone produce.

The project states **no** layering convention (it ships `project/conventions.md` only), so the
clause-9 layer pass is a no-op.

**The existing repo files the run assumes.** This list is EXHAUSTIVE: a path not on it does not
exist in the run's repo, so an `edits:` entry naming it is ungrounded.

- `src/services/ArchiveService.ts`, `src/jobs/RebuildIndexJob.ts`, `src/util/formatBytes.ts` : the
  canonical exemplars `project/conventions.md#Canonical exemplars (mirror these)` names. Patterns to
  mirror, not files this feature modifies.

`src/jobs/manifest.ts`, which the brief names, is **not** on that list and does not exist. The export
job registers itself from its own job file, so `manifest.ts` is neither listed under `edits:` nor
introduced.

- `feeder.json`: defaults (`projectDocs: project/`).
- Driver shared keys (as if from `.milestone-config/driver.json`):
  - `sourceGlobs`: `["src/**"]`
  - `uiSurfaceGlobs`: `["src/web/**"]`   # no glob match in this backend feature and no candidate carries an affordance → every candidate classifies `logic`
  - `integrationBranch`: `"develop"`
- Project docs dir: `project/`
