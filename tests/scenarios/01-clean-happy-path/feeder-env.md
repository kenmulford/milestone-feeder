# Test environment (what the run assumes)

- `feeder.json`: defaults (empty `{}` → `selfCheck: "milestone-driver"`, `substrateDir: project/`).
- Driver shared keys (as if from `.milestone-config/driver.json`):
  - `sourceGlobs`: `["src/**"]`
  - `uiSurfaceGlobs`: `["src/pages/**", "src/components/**"]`
  - `integrationBranch`: `"develop"`
  - `nonNegotiables`: `["Python 3.11 backend; React 18 frontend"]`
- Substrate dir for this scenario: `project/`
