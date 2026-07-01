# Conventions

<!--
Project doc (.project/). Cite as `.project/conventions.md#<section>`. Prefer pointing
at a canonical exemplar in the codebase (path:line) over prose. Keep ## headings
stable — they are citation anchors.
-->

## Naming
Files, types, functions.
Repositories: `src/data/<Entity>Repository.ts` (type `<Entity>Repository`). Services:
`src/services/<Entity>Service.ts` (type `<Entity>Service`). Controllers:
`src/controllers/<Entity>Controller.ts`. Routes: `src/routes/<entity>.ts`. Helpers:
`src/util/<name>.ts`. A slug helper is `src/util/slug.ts` exporting `toSlug()`.

## File & folder layout
Where things go, and the shape of a feature.
`src/util/` (pure helpers) · `src/data/` (repositories — CRUD / persistence) ·
`src/services/` (business logic) · `src/controllers/` (HTTP handlers + request
validation) · `src/routes/` (path→controller wiring). A feature adds one file per
layer it touches, each in the folder its layer owns above.

## Canonical exemplars (mirror these)
The reference implementations to copy when building something similar. Point at real code.

| For… | Mirror | Notes |
|---|---|---|
| A repository (CRUD / persistence) | `src/data/UserRepository.ts` | Owns all persistence for its entity; exposes list/get/insert/update/delete. |
| A service (business logic) | `src/services/UserService.ts` | Receives its repository via the constructor (`constructor(private repo: UserRepository)`); never imports the concrete repository class. |
| A controller (HTTP + validation) | `src/controllers/UserController.ts` | Validates the request body, calls the service, maps the result to a response. |
| A route (wiring) | `src/routes/user.ts` | Binds `GET`/`POST` paths to the controller; no logic. |
