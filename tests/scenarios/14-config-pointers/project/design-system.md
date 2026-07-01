# Design system

<!--
Project doc (.project/). Tools read and cite this file as
`.project/design-system.md#<section>`. Keep the ## headings stable — they are citation
anchors. Resolved color values live in tokens.json, never here.
-->

## Colors
How color is applied. Every color comes from a named token in `tokens.json`; a
component reads the token, never a literal hex value. A destructive / danger affordance
uses the `color.danger` token.

## Buttons
The button component and its variants. One component (`src/ui/Button.tsx`) renders every
variant; a variant sets its background from a named color token — it never hard-codes a
color. The existing `primary` variant reads `color.primary`; a `secondary` variant reads
`color.surface`. A new variant adds a `variant` prop value and maps it to the color token
its meaning dictates (a destructive variant → `color.danger`). Mirror the existing
`primary` variant when adding one.
