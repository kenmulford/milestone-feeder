🔴 Needs human input — Add user-facing CSV export to the Reports page

These items blocked the milestone and were NOT guessed. Resolve each, then re-run decompose.

| # | Kind | Item | Why blocked | Blocks |
|---|---|---|---|---|
| 1 | product-gap | Per-user rate-limit threshold for the CSV export endpoint: how many exports per user per window, the window length, and any burst allowance | The substrate fixes the rate-limit *mechanism* (shared `RateLimiter` token-bucket middleware; 429 + `Retry-After`; pattern `src/middleware/rate_limit.py` — project/conventions.md#engineering-conventions) but specifies no default threshold. The numeric limit is a product decision with no conventional default — exports being "expensive" (brief) does not imply a specific number. | #B (per-user rate limit on the export endpoint). No other candidate depends on #B, so #A and #C still ship. |
