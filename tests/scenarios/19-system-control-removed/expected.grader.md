# Expected contract: 19 system-control-removed  (GRADER ONLY)

A brief reports a symptom on a SwiftUI budget app: the iPad sidebar cannot be hidden and has no
collapse button. `RootSplitView` builds `NavigationSplitView(columnVisibility: .constant(.all))`
and removes the system toggle with `toolbar(removing: .sidebarToggle)`.
`project/conventions.md#System behavior over overrides` prefers the system's behavior to forced
overrides and names `/documentation/SwiftUI/NavigationSplitView`.

The claim under test (the pass condition of the brief `docs/briefs/2026-11-21-fixed-contract-free-content.md`
item 1): **the issue names the system behavior it restores and cites Apple's doc for it.**

This scenario is **plan-side, preview-only** (zero GitHub writes). It grades
`docs/briefs/2026-11-21-file-a-verified-bug.md` item 2.

## MUST

- The issue names the system behavior it restores: the system-managed column visibility
  (`NavigationSplitViewVisibility.automatic`, "the default leading column visibility for the
  current device") and the default sidebar toggle `NavigationSplitView` provides.
- The issue cites Apple's `NavigationSplitView` doc, `/documentation/SwiftUI/NavigationSplitView`,
  for that behavior (a `Platform source:` line or an equivalent citation).
- `RootSplitView.swift` is recorded as the site to fix: the forced `.constant(.all)` and the
  `toolbar(removing: .sidebarToggle)` call are what the change removes.
- Every `edits:` path names a file `feeder-env.md` declares, and the list is exhaustive.
- The brief states the symptom only; the issue, not the brief, names the fix.

## FAIL if

- The body cites the forced `.constant(.all)` or the removed toggle as `Convention followed:`
  or as the pattern to mirror.
- The body names no system behavior being restored, or cites no Apple doc.
- The body fixes the symptom by adding a custom collapse control while keeping the forced
  `.constant(.all)`.

A body that lists the forced `.constant(.all)` and the `toolbar(removing:)` call as code to fix
passes this check.

## Expected on today's feeder

This scenario fails on today's feeder: it grades
`docs/briefs/2026-11-21-file-a-verified-bug.md` item 2, the issue-author change that names the
platform behavior a fix restores and cites its source, which has not landed. The baseline run is
recorded by #555.

## METRIC for this scenario

- The system column-visibility and sidebar-toggle behavior named (yes/no).
- Apple's `NavigationSplitView` doc cited (yes/no).
- The forced `.constant(.all)` recorded as code to fix, not a pattern (yes/no).

## Disabled / edge: bash/pwsh parity

Plan-side, preview-only, prose-direct: no scripted twin. Cross-platform parity is N/A.
`expected.grader.md` is grader-only (the runner never sees it). Appended at NN=19.
