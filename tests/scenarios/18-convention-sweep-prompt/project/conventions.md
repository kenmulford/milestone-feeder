# Conventions

<!--
Project doc (.project/). Cite as `.project/conventions.md#<section>`. Keep ## headings
stable: they are citation anchors.
-->

## Naming
Views are `<Name>View` structs, one per file, in `App/`. Shared controls are named for what
they draw (`AmountTextField`).

## File & folder layout
`App/` holds every view and shared control. One type per file.

## TextField prompts
Guidance for an empty field belongs in the `TextField` prompt, never in the field's value. An
empty field reads as zero and shows its prompt; it never holds the text "0.00". Apple:
`/documentation/SwiftUI/TextField/init(_:value:format:prompt:)`, where the prompt "provides users
with guidance on what to type".
