# Conventions

<!--
Project doc (.project/). Cite as `.project/conventions.md#<section>`. Prefer pointing at
a canonical exemplar in the codebase (path:line) over prose. Keep ## headings stable —
they are citation anchors.
-->

## Styling
How components are styled. Components read design tokens from `tokens.json`; a component
NEVER hard-codes a hex value. A new button variant mirrors the existing button component
at `src/ui/Button.tsx` and maps its `variant` prop to the color token its meaning
dictates.

## Canonical exemplars (mirror these)
The reference implementations to copy when building something similar. Point at real code.

| For… | Mirror | Notes |
|---|---|---|
| A button variant | `src/ui/Button.tsx` | One component renders every variant; each variant reads a named color token, never a literal hex. |
