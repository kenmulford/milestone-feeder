# Expected contract: 12b implied-surfaces-control  (GRADER ONLY)

This is the CONTROL sibling scenario 12's own `expected.md` calls for but cannot
demonstrate from inside scenario 12's brief: scenario 12's brief always names the
email capability, so "no anti-fixation prompt" can never be observed there (see
the gap recorded on #285). `12b`'s brief is capability-free and entity-free, a
plain reword of existing copy, so a run of `12b` produces the checkable evidence
scenario 12's control assertion needs, without folding a control slice into
scenario 12's own brief (a slice there would never be capability-free, since that
brief already yields an implied candidate).

The claim under test: when a brief names no capability and introduces no new
entity, the architect's clause-8 implied-surfaces consult (`agents/architect.md`
clause 8) is a genuine no-op. Zero candidates carry `disposition: implied`, no
`[implied — review / trim / augment]` marker is rendered, and `plan` never fires
the anti-fixation prompt. Plan behaves byte-for-byte as today.

This is a **plan-side, preview-only** scenario (zero GitHub writes), mirroring
scenario 12's own execution model.

---

## MUST: no implied fan-out, no anti-fixation prompt (the control / negative case)

- The brief names **no capability** (no email / outbound messaging, no user /
  account management, no sync / integration; `docs/implied-surfaces.md#named-capabilities`)
  and introduces **no new entity** (`docs/implied-surfaces.md#new-entity-baseline`):
  it only reworks the text already on an existing screen. The architect's clause-8
  implied-surfaces consult therefore has nothing to concept-match against and is a
  genuine no-op.
- **Zero** candidates in the observed breakdown carry `disposition: implied`.
- **Zero** occurrences of the verbatim marker `[implied — review / trim / augment]`
  anywhere in the plan file's `## Issues` section.
- The plan does **not** fire the anti-fixation prompt: the verbatim string
  `this is a starting set for YOUR app — what's missing?` does not appear anywhere
  in the observed plan file.
- No scope is invented beyond the brief's literal reword (no new screen, endpoint,
  job, or setting proposed alongside it).
- Breakdown proceeds normally: a small, grounded issue (or a small grounded set, if
  the runner splits the text change from a states/verification note), a
  dependency-only Wave order, each design decision citing `project/conventions.md`,
  and no needs-product-input report produced (there is no product gap here).

## METRIC for this scenario

- Any `implied`-disposition candidate present (yes/no). Target: no.
- The `[implied — review / trim / augment]` marker present anywhere in `## Issues`
  (yes/no). Target: no.
- The anti-fixation prompt (`this is a starting set for YOUR app — what's
  missing?`) present anywhere in the plan file (yes/no). Target: no.
- A needs-product-input report produced (yes/no). Target: no.
- Every issue cites `project/conventions.md` for its design decision (yes/no).
  Target: yes.

## FAIL if

- Any candidate carries `disposition: implied`, or the `[implied — review / trim /
  augment]` marker appears anywhere in the observed plan.
- The anti-fixation prompt fires (its verbatim string appears anywhere in the plan
  file) for a brief that names no capability and introduces no new entity.
- The breakdown invents scope beyond the literal reword (a new screen, setting, or
  entity nobody asked for).
- The breakdown parks the reword as a product gap: there is no undecided decision
  here, so parking it would itself be a failure, an over-park in the direction
  scenario 03 already guards against.

## Disabled / edge: bash/pwsh parity

- Like scenario 12, this scenario is **plan-side, preview-only** and
  **prose-direct**: no scenario-specific scripted (bash/pwsh) twin exists to hold
  parity with, so parity is **N/A**.
- `expected.md` is **grader-only** (the runner never sees it). This fixture is a
  **sibling** to `12-implied-surfaces`, not a renumbering of the on-disk sequence,
  per the human decision recorded on #285: the control lives in its own
  directory, `12b-implied-surfaces-control/`, because the anti-fixation prompt is
  plan-scoped and scenario 12's own brief already yields an implied candidate, so
  the negative case can never be shown from inside 12's brief.
