# Test environment: 18 convention sweep prompt (what the run assumes)

The brief reports a symptom on four forms of a SwiftUI budget app: an amount field opens with a
typed "0.00". `project/conventions.md#TextField prompts` states the convention: placeholder
guidance belongs in a `TextField` prompt, never in the field's value. Four call sites sit on the
`.required` form of `AmountTextField`, which draws a zero as the text "0.00"; a fifth site
(`SavingsGoalView`) is already on the `.optional` form and is not defective. Every file is
classified `ui`.

**The existing repo files the run assumes.** This list is EXHAUSTIVE: a path not on it does not
exist in the run's repo, so an `edits:` entry naming it is ungrounded.

- `project/App/AmountTextField.swift` : the shared amount field with its `.required` and
  `.optional` forms.
- `project/App/AddExpenseView.swift`, `project/App/EditExpenseView.swift`,
  `project/App/BudgetLimitView.swift`, `project/App/TransferView.swift` : the four call sites on
  the `.required` form.
- `project/App/SavingsGoalView.swift` : a call site already on the `.optional` form.

- `feeder.json`: defaults (`projectDocs: project/`).
- Driver shared keys (as if from `.milestone-config/driver.json`):
  - `sourceGlobs`: `["project/App/**"]`
  - `uiSurfaceGlobs`: `["project/App/**"]`   # every candidate classifies `ui`
  - `integrationBranch`: `"develop"`
- Project docs dir: `project/`
