# Expected contract — 02 product-gap-parks  (GRADER ONLY)

The brief contains a genuine PRODUCT decision with no conventional default: **how featured
items are selected** (editorial / admin-curated? algorithmic by popularity or recency?
manual pinning? paid placement?). The project docs and conventions do NOT answer this.

## MUST
- The feeder **parks** the selection-policy decision to the "needs product input" report. It does **not** invent a policy (no silent "we'll feature the most recent / most popular").
- The report names the undecided decision precisely (the featured-selection policy), why it has no conventional default, and what it blocks.
- The display half (a Featured section reusing `ProductCardGrid`) MAY be authored as a decidable issue **only if** it can be specified without the policy; if the section's core (what it shows / how items arrive) hinges on the undecided policy, parking it too is correct.
- Any candidate that transitively depends on the parked decision is **dropped** from the emitted milestone — not authored from a fabricated body.

## FAIL if
- The feeder invents a selection policy to make the issue buildable; authors a "Featured" issue whose acceptance criteria silently assume a policy; or fails to surface the decision in the report.
