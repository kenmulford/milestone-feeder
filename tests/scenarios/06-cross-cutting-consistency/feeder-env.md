# Test environment — 06 (what the run assumes)

- `feeder.json`: defaults (`selfCheck: "milestone-driver"`, `substrateDir: project/`).
- Driver shared keys:
  - `sourceGlobs`: `["src/**"]`
  - `uiSurfaceGlobs`: `["src/pages/**", "src/components/**"]`  ← **set**, so the 10 pages classify as **UI** and the `design-reviewer` engages
  - `integrationBranch`: `"develop"`
  - `nonNegotiables`: `["React 18 + TypeScript"]`
- Substrate dir: `project/`

> The brief deliberately does **not** restate the table directive — it lives only in
> `project/design-system.md`. The feeder must pull it from the substrate, apply it to every
> page-issue, and cite it.
