# Test environment: 19 system control removed (what the run assumes)

The brief reports a symptom on a SwiftUI budget app: the iPad sidebar cannot be hidden.
`project/App/RootSplitView.swift` forces `NavigationSplitView(columnVisibility: .constant(.all))`
and removes the system toggle with `toolbar(removing: .sidebarToggle)`.
`project/conventions.md#System behavior over overrides` prefers the system's column visibility
and controls to forced overrides. Every file is classified `ui`.

**The existing repo files the run assumes.** This list is EXHAUSTIVE: a path not on it does not
exist in the run's repo, so an `edits:` entry naming it is ungrounded.

- `project/App/RootSplitView.swift` : `RootSplitView`, `SidebarView` and `DetailView`. The
  split view forces `.constant(.all)` and removes the sidebar toggle.

- `feeder.json`: defaults (`projectDocs: project/`).
- Driver shared keys (as if from `.milestone-config/driver.json`):
  - `sourceGlobs`: `["project/App/**"]`
  - `uiSurfaceGlobs`: `["project/App/**"]`   # every candidate classifies `ui`
  - `integrationBranch`: `"develop"`
- Project docs dir: `project/`
