# Engineering conventions

- **Outbound messaging:** the app sends all admin and transactional email through
  the shared `EmailService` (`src/services/EmailService.ts`), which wraps the
  configured email provider. Provider credentials and send settings live in
  `src/config/email.ts` — a new outbound capability configures the provider there,
  it does not pick a new one.
- **Delivery + retry:** every send goes through the provider via the shared
  `sendWithRetry()` helper (`src/services/EmailService.ts`) — a transient failure
  is retried on the standard backoff. Retry-on-failure is the conventional path
  for an outbound send, not a per-feature decision.
- **Delivery-failure log:** a send that exhausts its retries is recorded in the
  shared `EmailDeliveryLog` (`src/models/EmailDeliveryLog.ts`), surfaced on an
  admin delivery-failure screen with a **resend** action — the standard companion
  of every outbound message in the app.
- **Audit:** every outbound message is audited (who sent what, to whom, and when)
  via the shared `AuditLog` (`src/models/AuditLog.ts`), the same way every other
  admin action is audited.
- **UI:** reuse the existing `AdminFormLayout` (`src/components/AdminFormLayout.tsx`)
  for admin compose / edit screens.
- **States:** empty and error states are required on every user-facing surface.

> Note: this app has **not** decided a suppression / unsubscribe (opt-out) policy.
> Whether a member may opt out of admin messages, what an opt-out suppresses, and
> which message classes it covers are all open. There is **no conventional default**
> for this — it is a product decision, not an engineering one. Nothing here answers
> it, and the delivery defaults above deliberately do not imply one.
