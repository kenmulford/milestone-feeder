🔴 Needs human input — Build the admin list pages

These items blocked the milestone and were NOT guessed. Resolve each, then re-run plan.

| # | Item | Why blocked | Blocks |
|---|---|---|---|
| 1 | Whether Audit Log rows should expose fully-interactive edit/delete row actions like every other entity, given audit-log entries are conventionally immutable for compliance/integrity | The brief states row actions (view/edit/delete) uniformly for "each page" with no per-entity carve-out, and no project doc addresses audit-log mutability or compliance requirements; resolving this silently either breaks the brief's literal universal spec or ships a destructible audit trail. | #J (Build Audit Log admin list page) — parked, not authored |
| 2 | Whether a "create new record" entry point belongs in this milestone for any of the 10 entities, or is deferred alongside detail/edit to the follow-on milestone | The brief's out-of-scope note names only "the detail / edit pages behind the row actions"; create is not a row action and is not mentioned in-scope or out-of-scope; no project doc states a default for whether create ships with list pages. | Whole scope (not tied to a specific candidate) |
| 3 | Whether destructive row actions (delete) on these list pages should write an entry to the Audit Log entity, and whether that wiring belongs in this milestone | No project doc defines an audit-logging hook/convention for admin mutations; the brief includes an Audit Log entity itself but does not state whether the other 9 entities' deletes feed it. | Whole scope (not tied to a specific candidate) |
| 4 | Whether any of the 10 list pages require role/permission-scoped access beyond generic admin access (e.g., Refunds/Invoices restricted to Finance, Support Tickets to Support) | No permissions/roles convention exists in the project docs; the brief does not mention roles or access scoping at all. | Whole scope (not tied to a specific candidate) |

Note: gaps 2-4 are NOT tied to specific candidate tags (architect emitted `blocks: []`) — they ride along here for human awareness but pre-parked nothing at Step 3.5. Only gap 1 (`blocks: [#J]`) triggered a Step-3.5 pre-park.
