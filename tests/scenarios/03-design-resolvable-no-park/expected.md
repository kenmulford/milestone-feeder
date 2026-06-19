# Expected contract — 03 design-resolvable-no-park  (GRADER ONLY)

The brief is vague ("use the usual patterns") on DESIGN details — layout, validation, save
behavior, avatar upload — but the project docs conventions ANSWER all of them. This is the
opposite of 02: the gaps are design-resolvable, not product gaps.

## MUST
- The feeder RESOLVES the vague details from the cited conventions and does **not** park:
  - validation → inline via `FormField` (cited),
  - layout / save → mirror `AccountSecurityPage` (cited: two-column, sticky Save, optimistic save + toast + rollback),
  - avatar → reuse `ImageUploader` (cited).
- Each design decision is recorded in the issue's Design section with a `Convention followed:` citation to the provided pattern — not invented from scratch and not parked.
- needs-product-input report is absent / "none" — there is no product gap here.
- Self-check passes (`GAPS: none`).

## FAIL if
- The feeder PARKS any of these (treats a convention-answerable detail as a product gap — **over-parking**); OR invents a design with no citation; OR leaves a required detail unspecified for the implementer to guess.
