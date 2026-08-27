# Test environment: 17 shared-file ordering (what the run assumes)

The brief adds CSV exports to a TypeScript/Node backend whose `.project` states a **single-registry
convention** (`project/conventions.md#Registries`): every HTTP path is bound in one route registry
`src/routes/index.ts`, and every service, job, and migration is registered in one module registry
`src/app/modules.ts`. Several candidates therefore modify the SAME existing file, and no dependency
edge records that: the overlap is invisible to a breakdown keyed only on the artifacts one candidate
introduces and another consumes.

The project states **no** layering convention (it ships `project/conventions.md` only), so the
clause-9 layer pass is a no-op and the ordering under test is the clause-11 shared-file ordering
alone (`agents/architect.md` clause 11). The run must declare each candidate's `edits:` list and
order two overlapping candidates into successive Waves. The CONTROL alternate (see
`expected.grader.md`) runs the same brief against a project whose convention gives each surface its
own registration file, so no two `edits:` lists intersect, and must degrade to the order the
concrete dependency edges alone produce.

**The existing repo files the run assumes.** This list is EXHAUSTIVE: a path not on it does not
exist in the run's repo, so an `edits:` entry naming it is ungrounded.

- `src/routes/index.ts` : the route registry. Every HTTP path is bound here.
- `src/app/modules.ts` : the module registry. Every service, job, and migration is registered here.
- `src/config/defaults.ts` : the default value for every config key.
- `src/db/migrations/index.ts` : the migration registry. Every migration is listed here, in order.
- `src/telemetry/events.ts` : the event-name registry the metrics pipeline reads.
- `src/services/ArchiveService.ts`, `src/jobs/RebuildIndexJob.ts`, `src/util/formatBytes.ts` : the
  canonical exemplars `project/conventions.md#Canonical exemplars (mirror these)` names. Patterns to
  mirror, not files this feature modifies.

`src/jobs/manifest.ts`, which the brief names, is **not** on that list and does not exist. The
convention resolves it without any candidate introducing a file: `project/conventions.md#Registries`
registers every job in `src/app/modules.ts`, so the candidate that ships the export job edits
`modules.ts`, and `manifest.ts` is neither listed under `edits:` nor introduced. The brief's path is
a stale name for a registry this project already has.

- `feeder.json`: defaults (`projectDocs: project/`).
- Driver shared keys (as if from `.milestone-config/driver.json`):
  - `sourceGlobs`: `["src/**"]`
  - `uiSurfaceGlobs`: `["src/web/**"]`   # no glob match in this backend feature and no candidate carries an affordance → every candidate classifies `logic`
  - `integrationBranch`: `"develop"`
- Project docs dir: `project/`
