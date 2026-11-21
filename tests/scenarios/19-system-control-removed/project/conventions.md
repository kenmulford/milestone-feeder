# Conventions

<!--
Project doc (.project/). Cite as `.project/conventions.md#<section>`. Keep ## headings
stable: they are citation anchors.
-->

## Naming
Views are `<Name>View` structs, one per file, in `App/`.

## File & folder layout
`App/` holds every view. The root navigation container is `RootSplitView`.

## System behavior over overrides
Prefer the system's behavior to a forced override. A split view keeps the system's column
visibility and its default sidebar toggle. Apple: `/documentation/SwiftUI/NavigationSplitView`.
