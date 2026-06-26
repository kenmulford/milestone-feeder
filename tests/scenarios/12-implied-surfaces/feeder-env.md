# Test environment — 12 implied-surfaces (what the run assumes)

The brief names a single capability — admins emailing members — and lists only the
literal compose-and-send action. Its companion surfaces are unstated. The fixture's
`project/conventions.md` grounds the stack's email-sending defaults (provider config
+ retry, a delivery-failure log with resend, audit) so the **conventional** companions
have a conventional default and fan out as **implied** review candidates; it
deliberately leaves the suppression / unsubscribe (opt-out) policy **undecided** — a
product call with no conventional default that must **park**, never be invented.

- `feeder.json`: defaults (`reviewer: "milestone-driver"`, `projectDocs: project/`).
- Driver shared keys (as if from `.milestone-config/driver.json`):
  - `sourceGlobs`: `["src/**"]`
  - `uiSurfaceGlobs`: `["src/pages/**", "src/components/**"]`
  - `integrationBranch`: `"develop"`
- Project docs dir: `project/`
