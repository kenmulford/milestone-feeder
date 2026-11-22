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
that thing belongs to, and registers each of them in its own file as `## Registration` states.

## Registration
Every surface registers in its own file. No file lists the surfaces of a kind.

- **Routes.** Each HTTP path is bound in its own `src/routes/<route>.ts`, loaded by a folder scan. Adding an endpoint adds that file and edits no other.
- **Modules.** Each service, job and migration registers itself from its own file. Adding one edits no other file.
- **Config defaults.** Each config key's default lives in its own `src/config/<key>.ts`. A feature that reads a new key adds that file.
- **Migrations.** Each migration is a file in `src/db/migrations/`, discovered by a folder scan in timestamp order. A migration ships with the module that owns its table, never as work of its own.
- **Telemetry.** Each event name is declared in its own `src/telemetry/<event>.ts` before it is emitted.

## Canonical exemplars (mirror these)
The reference implementations to copy when building something similar. Point at real code.

| For… | Mirror | Notes |
|---|---|---|
| A service that writes files | `src/services/ArchiveService.ts` | Owns its write path end to end; registers itself from its own file. |
| A queue job | `src/jobs/RebuildIndexJob.ts` | Thin wrapper: validates the payload, calls one service, reports the outcome. |
| A pure helper | `src/util/formatBytes.ts` | One exported function, no imports from `src/services/` or `src/data/`. |
| An endpoint | `src/routes/<route>.ts` | One file per path: path, auth guard, handler. Adding an endpoint adds that file. |
| A retention setting | `src/config/<key>.ts` | One file per key holding its default, days as an integer; the sweep reads that file, never a literal. |
