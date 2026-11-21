# Expected contract: 18 convention-sweep-prompt  (GRADER ONLY)

A brief reports a symptom on a SwiftUI budget app: the amount field opens with a typed
"0.00" the user must delete. `project/conventions.md#TextField prompts` states the convention
(guidance belongs in a `TextField` prompt, never in the value). `AmountTextField` has a
`.required` form that draws a zero as the text "0.00" and an `.optional` form that reads empty
as zero and shows a `prompt:`. Four call sites (`AddExpenseView`, `EditExpenseView`,
`BudgetLimitView`, `TransferView`) use `.required`; a fifth (`SavingsGoalView`) already uses
`.optional`.

The claim under test (the pass condition of the brief `docs/briefs/2026-11-21-fixed-contract-free-content.md`
item 1): **the issue names the convention with a `Platform source:` line and its
`Sites searched:` grep lists all four defective sites.**

This scenario is **plan-side, preview-only** (zero GitHub writes). It grades
`docs/briefs/2026-11-21-file-a-verified-bug.md` item 2.

## MUST

- The issue body carries a `Platform source:` line naming the `TextField` prompt convention,
  citing `.project/conventions.md#TextField prompts` and
  `/documentation/SwiftUI/TextField/init(_:value:format:prompt:)`.
- The issue body carries a `Sites searched:` line holding a grep over `AmountTextField(` whose
  listed hits are exactly the four defective sites: `AddExpenseView.swift`,
  `EditExpenseView.swift`, `BudgetLimitView.swift`, `TransferView.swift`. Each is recorded as a
  site to fix.
- `SavingsGoalView.swift` is **not** listed as a site to fix. It may appear only as the one hit
  already on the `.optional` form.
- Every `edits:` path names a file `feeder-env.md` declares, and the list is exhaustive.
- The brief states the symptom only; the issue, not the brief, names the fix.

## FAIL if

- The body cites a `.required` site (any of the four) as `Convention followed:` or as the
  pattern to mirror.
- `Platform source:` is absent, or names no Apple doc or `conventions.md` section.
- `Sites searched:` omits any of the four sites, or lists `SavingsGoalView.swift` as a fifth
  site to fix.
- The body lists the four `.required` sites as the example to copy and `SavingsGoalView.swift`
  as the defect.

A body that lists the four `.required` sites as sites to fix passes this check.

## Expected on today's feeder

This scenario fails on today's feeder: it grades
`docs/briefs/2026-11-21-file-a-verified-bug.md` item 2, the issue-author change that adds the
`Platform source:` line and the `Sites searched:` sweep, which has not landed. The baseline run
is recorded by #555.

## METRIC for this scenario

- `Platform source:` line present and naming the convention (yes/no).
- `Sites searched:` lists exactly the four defective sites (yes/no).
- `SavingsGoalView.swift` absent from the sites to fix (yes/no).
- No defective site cited as the convention followed (yes/no).

## Disabled / edge: bash/pwsh parity

Plan-side, preview-only, prose-direct: no scripted twin. Cross-platform parity is N/A.
`expected.grader.md` is grader-only (the runner never sees it). Appended at NN=18.
