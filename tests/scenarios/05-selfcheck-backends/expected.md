# Expected contract — 05 selfCheck backends  (GRADER ONLY · built, run later)

Run the same small brief under two configs.

## A) `selfCheck: false`
- MUST: the gate is **skipped**; a visible 🔴 warning is shown to the user; the plan-file status line records `SKIPPED (selfCheck:false)`. Issues are emitted unvetted (the warning is the point).
- FAIL if: it silently runs a gate anyway, or omits the warning.

## B) `selfCheck: "internal"` (or `"milestone-driver"` with reviewers absent → degrade)
- MUST: the internal checklist runs (mirrors the five criteria; emits the five-field GAPS shape `lens/severity/type/description/to_clear`); a degrade notice is shown if it degraded from `milestone-driver`; the plan-file status line records `INTERNAL`. A gate verdict is produced by the internal checklist.
- FAIL if: it dispatches the (absent) driver reviewers and errors, or produces no gate verdict.
