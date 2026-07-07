# Expected contract — 12 implied-surfaces  (GRADER ONLY)

A terse brief names **one capability** — admins emailing members — and lists only
the literal compose-and-send action. The capability name quietly commits to a set
of companion surfaces the brief never spells out. The fixture's
`project/conventions.md` grounds the stack's email-sending defaults (provider config
+ retry, a delivery-failure log with resend, audit) so the **conventional**
companions have a conventional default; it leaves the suppression / unsubscribe
(opt-out) policy **undecided** — the one genuine product call.

The claim under test: **`plan` consults the implied-surfaces reference for a named
capability, fans the conventional companions out as `implied`-labeled review
candidates, parks the genuine product-call to the needs-product-input report instead
of inventing one, and surfaces the implied set with the anti-fixation prompt** —
without auto-dumping every conceivable surface and without inventing product scope.

This is a **plan-side, preview-only** scenario (zero GitHub writes), mirroring the
plan-side portion of scenario 11.

---

## MUST — (a) the reference is consulted for the email capability

- The architect **concept-matches** the brief to the **Email / outbound messaging**
  capability (`docs/implied-surfaces.md#named-capabilities`) and consults the
  implied-surfaces reference for it — even though the brief says "email" only in the
  literal compose/send action and never names its companions (`agents/architect.md`
  clause 8; the consult is **per named capability or new entity**, concept-matched,
  not keyword-matched).
- The consult is **observable in the breakdown**: the companion surfaces the
  capability implies appear as candidates that were not in the brief's literal text
  (the delivery-failure log, provider config + retry, the send audit) — evidence the
  reference was read, not skipped.

## MUST — (b) the conventional companions fan out as `implied`-labeled candidates

- The conventional companions — at minimum the **delivery-failure log** (with
  resend), and the **provider configuration + retry** and **send audit** surfaces —
  ride `CANDIDATES` with the architect's **`disposition: implied`**
  (`agents/architect.md` clause 8, the conventional-surface branch).
- Each `implied` candidate renders **distinctly** in the plan's `## Issues`,
  carrying the **verbatim** marker `[implied — review / trim / augment]` on its
  heading (`skills/plan/SKILL.md` — the bracketed marker; #180 as-built). The
  literal words `implied — review / trim / augment` must appear inside the brackets.
- These companions are grounded on the fixture's conventions (the delivery-failure
  log, retry, and audit defaults `project/conventions.md` states) — so they are
  proposed because they have a **conventional default**, but they are **proposed for
  review**, not silently pre-included: an `implied` candidate is reversible (trim the
  line before approving) and is **not** rendered as a plain grounded candidate that
  hides its implied origin.
- The implied set is presented as a **floor, not a ceiling** — a short, conceptual
  start, never framed as the complete or exhaustive set of companions.

## MUST — (c) the genuine product-call PARKS, never invented

- The **suppression / unsubscribe (opt-out) policy** has **no conventional default**
  in the fixture (`project/conventions.md` explicitly leaves it undecided). The
  candidate that needs that decision must **PARK** to the **needs-product-input**
  report via the architect's `PRODUCT_GAPS` (`agents/architect.md` clause 8, the
  genuine-product-call branch; clause 2 never-invent floor).
- The report names the undecided decision precisely (the suppression / unsubscribe
  policy — who may opt out, what an opt-out suppresses, which message classes it
  covers), why it has no conventional default, and what it blocks.
- The opt-out policy is **never pre-included** as an `implied` candidate and **never
  invented** as a plausible-sounding default (no silent "members can unsubscribe via
  a link in the footer"). A surface with no conventional default parks — it never
  proceeds as an implied guess.

## MUST — (d) plan surfaces the implied set with the anti-fixation prompt

- Because the plan carries one or more `implied` candidates, `plan` fires the
  structural **anti-fixation prompt** at the milestone-identity confirm/override
  moment, with the **verbatim** string `this is a starting set for YOUR app — what's missing?`
  (`skills/plan/SKILL.md` — the implied-surfaces review prompt; #180 as-built). It is
  **advisory and non-blocking** — it never gates the run; the plan stays fully
  deployable as-is.

## MUST — CONTROL / negative: no capability, no entity → no fan-out, no prompt

- **Asserted alternate.** A brief slice that names **no capability and introduces no
  new entity** — e.g. "reword the copy on the existing admin settings page" or
  "rename a label" — triggers **NO** implied fan-out: the architect's clause-8
  consult is a **no-op**, **no** candidate carries `disposition: implied`, no
  `[implied — review / trim / augment]` marker is rendered, and `plan` surfaces **NO**
  anti-fixation prompt. Plan behaves **byte-for-byte as today**. This is an asserted
  success outcome, not an error and not a park.

## METRIC for this scenario

- Conventional companions correctly fanned out as `implied`-labeled candidates
  (target: the delivery-failure log + provider/retry + audit all present, all
  marked). Record which companions surfaced and whether each carried the marker.
- The opt-out policy parked (yes/no) and named precisely in the report.
- The anti-fixation prompt present, verbatim (yes/no).

## FAIL if

- The product-call (suppression / unsubscribe policy) is **silently pre-included** —
  authored as a candidate (implied or grounded) instead of parked — or **invented**
  with a fabricated opt-out default.
- The anti-fixation prompt is **absent** when the plan carries `implied` candidates,
  or its string is not verbatim `this is a starting set for YOUR app — what's missing?`.
- The implied candidates are **unlabeled** (no `[implied — review / trim / augment]`
  marker) or rendered as plain grounded candidates hiding their implied origin; or
  the implied set is framed as **complete / exhaustive / a ceiling** rather than a
  floor.
- An **exhaustive auto-dump** of every conceivable surface is emitted (false
  completeness) — the reference is over-listed instead of read as a short, conceptual
  prompt.
- The CONTROL slice (no capability, no new entity) nonetheless triggers an implied
  fan-out or the anti-fixation prompt.

## Disabled / edge — bash/pwsh parity

- This scenario is **plan-side, preview-only** and **prose-direct** — the implied
  consult / fan-out / anti-fixation flow is prose the runner follows; it touches no
  scenario-specific scripted (bash/pwsh) twin. **Cross-platform parity is recorded
  N/A** for this scenario (mirroring scenario 11's plan-side preview portion).
- `expected.grader.md` is **grader-only** (the runner never sees it). Appended at **NN=12**
  (on-disk 01–06, 10, 11; 07–09 reserved for the sandbox `create` / `update`
  scenarios).
