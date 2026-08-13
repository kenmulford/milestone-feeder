🔴 Needs human input — Admin-to-member email messaging

These items blocked the milestone and were NOT guessed. Resolve each, then re-run plan.

| # | Item | Why blocked | Blocks |
|---|---|---|---|
| 1 | The suppression / unsubscribe (opt-out) policy for admin messages: whether a member may opt out, what an opt-out suppresses, and which message classes it covers. | `project/conventions.md#Engineering conventions` states the app has not decided this, that there is no conventional default for it, and that the delivery defaults deliberately do not imply one. It is a product decision, not an engineering one, so neither the docs nor a repo convention can resolve it. Brief reference: "sends it to a selected set of members" (goal line), and the in-scope line "pick the member recipients". | #B (send an admin message through the shared EmailService), #C (select member recipients) directly; #D, #E, #F, #G dropped as dependents |
