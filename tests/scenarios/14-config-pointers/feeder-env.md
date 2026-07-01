# Test environment — 14 config pointers (what the run assumes)

The brief adds a styling change (a `danger` button variant) to a project whose
`.project` states its colors in a **token doc** (`project/tokens.json`) and its button
rules in a **design-system doc** (`project/design-system.md#Buttons`), with a styling
convention in `project/conventions.md#Styling` that says components read color from the
tokens and never hard-code a hex value. The danger color's resolved value lives ONLY in
the token doc (`color.danger`); it is the driver's to consume at build time.

The claim under test: **a styling-touching issue POINTS at the token + design-system
docs by path in its `## Design (recorded, consistent)` block — a reference, never a
pre-solved design — so the issue body does NOT inline the resolved hex / token values;
a grounded design decision with a conventional default (mirror the existing button
component) is still recorded; and a project missing the token / design-system docs
simply omits that pointer, no error, no fabricated reference.**

This is a **plan-side, preview-only** scenario (zero GitHub writes), mirroring the
plan-side portion of scenarios 11, 12, and 13.

- `feeder.json`: defaults (`projectDocs: project/`).
- Driver shared keys (as if from `.milestone-config/driver.json`):
  - `sourceGlobs`: `["src/**"]`
  - `uiSurfaceGlobs`: `["src/ui/**"]`   # the button component lives here → the candidate classifies `ui`
  - `integrationBranch`: `"develop"`
- Project docs dir: `project/`
