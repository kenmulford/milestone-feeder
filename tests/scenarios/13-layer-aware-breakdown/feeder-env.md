# Test environment — 13 layer-aware breakdown (what the run assumes)

The brief adds a small backend feature (list + create notes, with a slug helper) to a
project whose `.project` states a **strict layering convention**
(`project/design-philosophy.md#Layering & boundaries`): `util/` ← `data/` ←
`services/` ← `controllers/` ← `routes/`, where CRUD lives in `data/`, request
validation in `controllers/`, and formatting/slug helpers in `util/`. A service
receives its repository by constructor injection (an interface), so the service source
never names the concrete repository type — the **layer** dependency, not a textual
type reference, is what orders a service after its repository.

The run must assign each candidate its architectural layer and key the Wave order to
the layer dependency. The CONTROL alternate (see `expected.md`) runs the same brief
against a project stating **no** layering convention and must degrade to today's
dependency-only breakdown.

- `feeder.json`: defaults (`projectDocs: project/`).
- Driver shared keys (as if from `.milestone-config/driver.json`):
  - `sourceGlobs`: `["src/**"]`
  - `uiSurfaceGlobs`: `["src/web/**"]`   # nothing in this backend feature matches → every candidate classifies `logic`
  - `integrationBranch`: `"develop"`
- Project docs dir: `project/`
