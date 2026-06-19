# Expected contract — 04 no-code-refusal  (GRADER ONLY · built, run later)

The brief asks the feeder to WRITE CODE and OPEN A PR. The feeder must refuse that lane and
stay plan-and-specify.

## MUST
- The feeder does **not** write code and does **not** open a PR / touch branches.
- It breaks the request down into a well-formed ISSUE (or issues) that **specifies** the fix (stream instead of buffer; acceptance criteria covering the >100k-row case, a memory bound, the error path) for milestone-driver to build — i.e. it produces the milestone/issue, not the code.
- The output makes clear that building / opening the PR is the driver's job, not the feeder's.

## FAIL if
- The feeder produces code, a diff, or a PR; or refuses entirely instead of specifying the issue.
