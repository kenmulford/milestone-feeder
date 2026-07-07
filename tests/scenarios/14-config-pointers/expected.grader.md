# Expected contract — 14 config pointers  (GRADER ONLY)

A small styling brief (add a `danger` variant to the existing button component) is
authored against a project whose `.project` states its colors in a **token doc**
(`project/tokens.json` — `color.danger` = `#D62828`) and its button rules in a
**design-system doc** (`project/design-system.md#Buttons`), with a styling convention
(`project/conventions.md#Styling`) that mirrors the existing button component at
`src/ui/Button.tsx` and forbids hard-coded hex in a component.

The claim under test: **the issue-author POINTS a styling-touching issue at the token +
design-system docs BY PATH in its `## Design (recorded, consistent)` block — a reference,
never a pre-solved design — so the resolved color values (the hex in `tokens.json`) are
NOT copied or parsed into the issue body; a grounded design decision with a conventional
default (mirror `src/ui/Button.tsx`) is still recorded via `Convention followed:`; and a
project missing the token / design-system docs simply omits that pointer, byte-for-byte,
with no error and no fabricated reference.**

This is a **plan-side, preview-only** scenario (zero GitHub writes), mirroring the
plan-side portion of scenarios 11, 12, and 13.

The expected candidate set (local tags; exact titles may vary):

| Tag | Candidate | Surface | Touches |
|---|---|---|---|
| #A | Add a `danger` variant to the button component | `ui` | styling / theming (color token) |

Path form: the pointer names the token / design-system docs at the path `projectDocs`
resolves — here `project/tokens.json` / `project/design-system.md#Buttons` (canonically
`.project/tokens.json` / `.project/design-system.md#Buttons` when `projectDocs` is the
default `.project/`). The grader accepts either prefix; what matters is that the doc is
named BY PATH, not that its values are copied in.

---

## MUST — (a) the styling issue POINTS at the token + design-system docs by path  (AC1)

- The authored `#A` §4 `ISSUE_BODY` carries a **config-pointer** that references the
  color-token doc and the design-system doc BY PATH — e.g.
  `Config pointers: colors: project/tokens.json / project/design-system.md#Buttons`
  (or the canonical `.project/…` prefix). The pointer names WHERE the color lives; it
  does not state the color's value.

## MUST — (b) the pointer lands in the EXISTING `## Design` block — no new §4 section  (triage advisory)

- The pointer is recorded inside the **existing `## Design (recorded, consistent)`
  block** — the same block that carries `Convention followed:` and (when present)
  `Layer:` (`agents/issue-author.md`). The author invents **no new §4 section header**
  for it.

## MUST — (c) reference, not pre-solve: the body inlines NO resolved value  (AC3)

- The `#A` issue body contains **no resolved hex value** — not `#D62828` (the danger
  color), not `#2F6FED`, not any `#RRGGBB`/`#RGB` literal — and **no parsed token
  value** copied out of `tokens.json` (e.g. the raw `6px` radius). The render / tokens
  are the driver's to consume at build time; the feeder only names where they live.
- A design decision that HAS a conventional default is still **recorded** (grounded, not
  pointed-at): the body carries a `Convention followed:` line citing the existing button
  component to mirror — `src/ui/Button.tsx` (per `project/conventions.md#Styling` /
  `project/design-system.md#Buttons`). "Reference the token" narrows to the render /
  token values; it does **not** hollow out the grounded design the author has always
  recorded.

## MUST — (d) absent config degrades: no pointer, no error, no fabrication  (AC4)

- **Asserted alternate.** The **same brief** authored against a project whose `.project`
  is **missing the token + design-system docs** (`tokens.json` and `design-system.md`
  absent, `conventions.md` still present) produces the **same issue MINUS the token /
  design-system pointer**, byte-for-byte:
  - **No** `Config pointers:` line naming `tokens.json` / `design-system.md` — the docs
    do not exist, so the author omits the pointer.
  - Still **no** inlined hex or token value (there is nothing to inline, and nothing is
    fabricated).
  - The grounded `Convention followed:` line still records the styling convention it CAN
    ground (mirror `src/ui/Button.tsx`, from `conventions.md#Styling`).
  - **No error, no fabricated reference** — a missing doc is an asserted **success**
    outcome, not a park and not a failure (the feeder's degrade rule, `SPEC.md` §4
    config pointers; the same error philosophy scenarios 11–13 degrade under).

## METRIC for this scenario

- The styling issue carries a config-pointer naming `tokens.json` AND
  `design-system.md#<section>` by path, inside the existing `## Design` block (yes/no).
- The issue body inlines **no** resolved hex value and **no** parsed token value (yes/no)
  — the anti-pre-solve proof.
- The grounded design decision (mirror `src/ui/Button.tsx`) is still recorded via
  `Convention followed:` (yes/no).
- CONTROL: the absent-config alternate omits the token / design-system pointer, inlines
  no value, keeps the groundable convention, and errors on nothing (yes/no).

## FAIL if

- The styling issue carries **no** pointer to the token / design-system docs when they
  exist — the driver is left without the source of truth for the color.
- The body **inlines a resolved value** — any `#RRGGBB`/`#RGB` hex (esp. `#D62828`), or
  a token value copied / parsed out of `tokens.json` — i.e. it pre-solves the render
  instead of pointing at it.
- The author records the pointer under a **new §4 section header** instead of the
  existing `## Design (recorded, consistent)` block.
- The grounded design is dropped — no `Convention followed:` line recording the existing
  button component to mirror — i.e. "reference the token" was mis-read as "record no
  design at all".
- The CONTROL (absent-config) alternate nonetheless emits a token / design-system
  pointer, fabricates a reference to a doc that does not exist, inlines a value, or
  errors instead of degrading.

## Disabled / edge — bash/pwsh parity

- This scenario is **plan-side, preview-only** and **prose-direct** — the config-pointer
  authoring / anti-inline / degrade flow is prose the runner follows; it touches no
  scenario-specific scripted (bash/pwsh) twin. **Cross-platform parity is recorded N/A**
  for this scenario (mirroring scenarios 11, 12, and 13's plan-side preview portion).
- `expected.grader.md` is **grader-only** (the runner never sees it). Appended at **NN=14**
  (on-disk 01–06, 10–13; 07–09 reserved for the sandbox `create` / `update` scenarios).
