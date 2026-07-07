# Test environment: 12b implied-surfaces-control (what the run assumes)

This is the CONTROL sibling to scenario 12: the brief is a plain reword of
existing copy, no new capability (no email / outbound messaging, no user /
account management, no sync / integration, etc.) and no new entity. The
architect's clause-8 implied-surfaces consult has nothing to concept-match
against here, so it must be a genuine no-op. Everything else in this fixture
mirrors scenario 12's environment, so the one variable under test is the
brief's content, not the config.

- `feeder.json`: defaults (`projectDocs: project/`).
- Driver shared keys (as if from `.milestone-config/driver.json`):
  - `sourceGlobs`: `["src/**"]`
  - `uiSurfaceGlobs`: `["src/pages/**", "src/components/**"]` (set: the change
    touches an existing UI surface, a page component, so this keeps
    classification behavior identical to scenario 12's environment; only the
    brief's content varies between the two fixtures)
  - `integrationBranch`: `"develop"`
- Project docs dir: `project/`
