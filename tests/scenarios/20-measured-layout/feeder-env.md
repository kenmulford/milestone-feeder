# Test environment: 20 measured layout (what the run assumes)

The brief reports a symptom on a SwiftUI budget app: the Transactions table draws wider than its
column. `project/App/TransactionsView.swift` holds a measured width in `@State` (written by
`onGeometryChange`) and picks a `Table` or a `List` from it; `project/App/AccountsView.swift`
does the same and is the sibling a run is tempted to mirror. The fixture's `nonNegotiables`
forbids feeding a measured width back into layout. `project/conventions.md` carries naming and
folder layout only: the rule under test arrives through `nonNegotiables`. Every file is
classified `ui`.

**The existing repo files the run assumes.** This list is EXHAUSTIVE: a path not on it does not
exist in the run's repo, so an `edits:` entry naming it is ungrounded.

- `project/App/TransactionsView.swift` : the Transactions screen; chooses `Table` or `List` from
  a measured width.
- `project/App/AccountsView.swift` : the Accounts screen; the same measured-width choice. A
  sibling with the same breach, not a pattern to mirror.

- `feeder.json`: defaults (`projectDocs: project/`).
- Driver shared keys (as if from `.milestone-config/driver.json`):
  - `sourceGlobs`: `["project/App/**"]`
  - `uiSurfaceGlobs`: `["project/App/**"]`   # every candidate classifies `ui`
  - `integrationBranch`: `"develop"`
  - `nonNegotiables`: ``["Never measure a width and feed it back into layout; use size classes or `ViewThatFits`."]``
- Project docs dir: `project/`
