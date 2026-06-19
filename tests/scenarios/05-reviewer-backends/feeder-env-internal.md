# Test environment — 05 config B (internal backend / driver-absent degrade)

- `feeder.json`: `{ "reviewer": "internal" }`  — OR `{ "reviewer": "milestone-driver" }` with the
  driver reviewer agents **absent** from the session (to exercise the runtime degrade-to-internal path).
- Driver shared keys:
  - `sourceGlobs`: `["src/**"]`
  - `uiSurfaceGlobs`: `["src/pages/**", "src/components/**"]`
  - `integrationBranch`: `"develop"`
- No project docs folder needed.
