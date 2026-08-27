# Conventions

<!--
Project doc (.project/). Cite as `.project/conventions.md#<section>`. Prefer pointing
at a canonical exemplar in the codebase (path:line) over prose. Keep ## headings
stable: they are citation anchors.
-->

## Naming
Files, types, functions.
Services: `src/services/<Name>Service.ts` (type `<Name>Service`). Background jobs:
`src/jobs/<Name>Job.ts`. Pure helpers: `src/util/<name>.ts`, one exported helper per file.
Migrations: `src/db/migrations/<timestamp>-<name>.ts`. A pipeline that owns a write path is a
service, not a job: the job is the thin wrapper the queue runs.

## File & folder layout
Where things go, and the shape of a feature.
`src/util/` (pure helpers) · `src/services/` (business logic) · `src/jobs/` (queue wrappers) ·
`src/db/migrations/` (one file per migration) · `src/routes/` · `src/app/` (app wiring) ·
`src/config/` · `src/telemetry/`. A feature adds one file per thing it introduces, in the folder
that thing belongs to, and registers each of them in the registries below.

## Registries
The five shared files a feature edits rather than adds to.
This app registers centrally, never by convention-over-configuration scanning:

- **Routes.** Every HTTP path is bound in `src/routes/index.ts`. Adding an endpoint edits that
  file. There is no per-route registration file.
- **Modules.** Every service, job, and migration is registered in `src/app/modules.ts`. Adding
  any of the three edits that file.
- **Config defaults.** Every config key's default value lives in `src/config/defaults.ts`. A
  feature that reads a new key edits that file.
- **Migrations.** Every migration is listed, in order, in `src/db/migrations/index.ts`. A
  migration ships with the module that owns its table, never as work of its own.
- **Telemetry.** Every event name is declared in `src/telemetry/events.ts` before it is emitted.

## Canonical exemplars (mirror these)
The reference implementations to copy when building something similar. Point at real code.

| For… | Mirror | Notes |
|---|---|---|
| A service that writes files | `src/services/ArchiveService.ts` | Owns its write path end to end; registered in `src/app/modules.ts`. |
| A queue job | `src/jobs/RebuildIndexJob.ts` | Thin wrapper: validates the payload, calls one service, reports the outcome. |
| A pure helper | `src/util/formatBytes.ts` | One exported function, no imports from `src/services/` or `src/data/`. |
| An endpoint | `src/routes/index.ts` | Path, auth guard, handler, in one bound entry per path. |
| A retention setting | `src/config/defaults.ts` | Days as an integer key; the sweep reads the default, never a literal. |
