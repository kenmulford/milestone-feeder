# Design philosophy

<!--
Project doc (.project/). Tools read and cite this file as
`.project/design-philosophy.md#<section>`. Keep the ## headings stable — they are
citation anchors.
-->

## Architectural stance
What kind of system is this, and what does it fundamentally optimize for?
A TypeScript/Node HTTP backend, built as a **strictly layered** service. Each layer
has one responsibility and may depend only on the layers beneath it. The layering is
the primary design constraint: a change is placed in the layer its responsibility
belongs to, and the build order follows the layer dependency.

## Layering & boundaries
The layers and the allowed dependency directions — what may depend on what, and what must never.
The layers, innermost-first, and the allowed dependency directions:

- **`util/`** — pure helpers (formatting, slugs, id generation). Depends on nothing;
  any layer may use it.
- **`data/`** — repositories: **all CRUD / persistence** lives here. May use `util/`.
  **Never** depends on a service, controller, or route.
- **`services/`** — business logic. Depends on `data/` (repositories, **injected via
  the constructor as an interface** — a service never imports a concrete repository
  class) and on `util/`. **Never** depends on a controller or route.
- **`controllers/`** — HTTP request/response handlers and **request validation**.
  Depends on `services/`. **Never** depends on a route.
- **`routes/`** — wiring only: bind an HTTP path to a controller. Depends on
  `controllers/`.

A layer may depend only on the layers listed above it; the reverse is a boundary
violation. **CRUD / persistence operations live in `data/`; request validation lives
in `controllers/`; formatting and slug helpers live in `util/`.** Because a service
receives its repository by constructor injection (an interface), the service source
does **not** name the concrete repository type — the layer dependency (`services/`
depends on `data/`) is what orders a service after its repository, not a textual type
reference.

## Error & failure philosophy
How the system handles and surfaces failure.
Repositories translate storage errors into typed domain errors; services and
controllers never swallow them. A missing layering call is grounded in the layer
convention above, never guessed.
