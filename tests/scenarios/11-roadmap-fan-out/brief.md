# Brief: build the invoicing & client-portal app (whole product)

Build the whole product: a small-business app where an owner manages clients,
sends invoices, takes payment, and gives each client a portal to view and pay.
This is a from-scratch, multi-release build — far more than one milestone.

The sections below are the author's own grouping. They are the natural seams the
build splits along; the split may merge, reorder, or keep them as it sees fit.

## Accounts & access
- Email/password sign-up and login, password reset.
- Two roles: **owner** (full access) and **staff** (no billing settings).
- Every API route requires auth; sessions expire.

## Data model
- Core entities: `Client`, `Invoice`, `LineItem`, `Payment`, `User`.
- An `Invoice` belongs to a `Client` and has many `LineItem`s and `Payment`s.
- Every entity is owner-scoped (an owner sees only their own records).

## Client management
- Create, view, edit, and archive client records (name, email, address, notes).
- A searchable client list.

## Invoicing
- Create an invoice for a client: add line items (description, qty, unit price),
  see the computed total, save as draft, then send.
- An invoice has a status: draft → sent → paid → overdue.

## Payments & billing
- Let clients pay an invoice online, and bill the owner on a recurring plan for
  using the app.
- Record each payment against its invoice and flip the invoice to **paid** when
  fully covered.
- (The brief does not name a payment provider, a currency, or how tax/processor
  fees are handled — those are left open.)

## Client portal (screens)
- A client signs in to a portal and sees a list of their invoices with status.
- A client opens an invoice and pays it from that screen.

## Admin dashboard & reporting (screens)
- An owner dashboard: outstanding total, paid-this-month, overdue count.
- A revenue report table: one row per invoice, sortable and filterable.

## Notifications
- Email a client when an invoice is sent and again when it is overdue.
- Email the owner a weekly summary.

## Out of scope
- Multi-currency, tax jurisdictions, mobile apps, and a public marketing site.
