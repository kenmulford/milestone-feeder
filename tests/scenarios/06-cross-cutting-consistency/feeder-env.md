# Test environment — 06 (what the run assumes)

- `feeder.json`: defaults (`projectDocs: project/`).
- Driver shared keys:
  - `sourceGlobs`: `["src/**"]`
  - `uiSurfaceGlobs`: `["src/pages/**", "src/components/**"]`  ← **set**, so the 10 pages classify as **UI** and their issues carry the design spec the driver's design lens checks
  - `integrationBranch`: `"develop"`
  - `nonNegotiables`: `["React 18 + TypeScript"]`
- Project docs dir: `project/`

> The brief deliberately does **not** restate the table directive — it lives only in
> `project/design-system.md`. The feeder must pull it from your project's standing docs, apply it to every
> page-issue, and cite it.
