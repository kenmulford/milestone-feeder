# Implied surfaces

A brief names a capability — "add email", "user management", "sync" — and that
name quietly commits to a standard set of companion surfaces (screens, endpoints,
jobs, settings) the brief never spells out. This reference lists those standard
companions so the architect considers them while breaking a brief down — so a plan
that says "here's a Users page" no longer ships with the obvious companions
(activate / deactivate, reset-password, a delivery-failure log) missing not on
purpose, but by omission.

**Read this as a reasoning prompt, not a checklist to run.** It is a *floor* — a
robust start, never a ceiling. When the architect consults it, the review that
follows asks you, out loud: *"this is a starting set for YOUR app — what's
missing?"* Adding the two or three surfaces a curated list can't know about is a
built-in step here, not something you're left to remember on your own.

What this reference is **not**:

- **Not a scope-emitting catalog.** Nothing here is created automatically. Every
  surface it suggests lands in a plan you review and approve *before* any issue
  exists; dropping one you don't want is deleting a line before you approve.
- **Not exhaustive.** The lists are deliberately short and conceptual. A short
  list keeps the focus on *which* companions a capability implies — the driver
  fills in the code-level detail later, against your project's conventions.
  Over-listing here is a defect, not a virtue: a long list reads as "complete" and
  quietly suppresses your own sense of what's still missing.
- **Not where states become issues.** A screen's empty, loading, error, and
  unauthorized states are *considered* here so they're never overlooked — but they
  belong as acceptance criteria *inside that screen's own issue*, where the
  issue-author already enumerates them, never as standalone issues of their own.

## The vocabulary

The surfaces below are written in stack-agnostic terms so this one reference fits
any project. Read each word as your stack's equivalent:

| Term | Means |
|---|---|
| **screen** | a page, view, or component the user sees |
| **endpoint** | a route, handler, or API the client calls |
| **job** | a background or scheduled task |
| **setting** | an admin-configurable value |

The architect maps each to whatever your project actually uses.

## New-entity baseline

Triggered **per entity** the brief introduces — so "create ten entity types" never
ships ten bare pages. For each new entity, consider this cluster:

- **list** — browse the entity (the natural home for search / filter / sort; see
  [Cross-cutting](#cross-cutting))
- **detail** — view one record
- **create / edit / delete** — the write surfaces (or soft-delete + restore where
  the data warrants it)
- **states** — empty / loading / error / unauthorized, carried as acceptance
  criteria on the screens above, not as issues of their own
- **permissions** — who may do each of the above, enforced server-side
- **audit** — who created or changed a record, and when
- **server-side validation** — the rules a write must satisfy, enforced on the
  server

## Named capabilities

A short, curated set of capabilities whose names each imply a predictable
companion cluster. Concept-match the brief against these (not just keyword-match):
"let admins message members" is the email / messaging capability even when the
word "email" never appears. Each cluster is intentionally short — the conceptual
companions, not an implementation checklist.

**Email / outbound messaging**

- composing and sending a message (templates, a preview before send)
- delivery: provider configuration, send, retry on failure
- a delivery-failure log, with resend
- an audit of what was sent, to whom, and when

**User / account management**

- sign-in / sign-out / session
- the account lifecycle: provision, activate, deactivate, reactivate
- roles and scope, enforced server-side
- admin surfaces (a user list and detail, assign a role) and self-service (edit
  your profile, reset a credential the app owns)

**Sync / integration**

- a manual trigger and a scheduled job
- run history, with failure visibility
- a concurrency guard so two runs never overlap
- reconcile rules: how incoming records create, update, or retire existing ones
- the connection's configuration (auth, limits)

## Cross-cutting

App-level concerns, not per-entity — consider these once for the whole app, not
for each entity:

**Search / filter / sort**

- consistent across the app, not reinvented per screen
- the chosen filter / sort state persists across navigation, refresh, and export
- results scoped to what the viewer is allowed to see

**Background / scheduled jobs**

- a worker that runs in every environment, not just locally
- a schedule plus a manual trigger
- run history and failure alerting
- safe to re-run without doubling its effect, and one run at a time

## Project-local overlay

This reference is universal, so it can't hold the capability clusters specific to
your domain — a church app's "giving" (recurring schedules, statements, refunds,
gateway config), say. A project supplies those in an optional overlay file the
architect reads alongside this one.

**This section defines that file's shape; it does not yet wire it up.** Reading and
merging the overlay is built later — what follows is the contract that later work
implements.

**Where it lives.** A fixed path in your suite config directory:

```
.milestone-config/implied-surfaces.md
```

It is discovered by that **fixed path** — there is no `feeder.json` key that points
at it. New profile keys are added only when a real consumer needs one, never
speculatively (`docs/profile-schema.md` Design principle; `.project/design-philosophy.md`
One-way doors), and a fixed conventional location is the same discipline the plan
file and the `.milestone-config/` profiles already follow.

**Its shape.** The same markdown `##`-section shape as this reference: one
capability per `##` heading, its implied surfaces listed beneath. Anyone who can
read this file can write an overlay.

**How it merges — additive only.** An overlay can:

- **add** a capability this reference doesn't carry, and
- **extend** an existing capability with surfaces specific to your project.

It can **never remove** a surface this global reference defines. Dropping a surface
you don't want for a given milestone is the plan review's job — a per-run "trim
this line before approving" call, not a standing deletion baked into config.
Trimming is reversible and reviewed; a config-level delete would silently suppress
a surface on *every* future plan.

**Optional, and absent by default.** Most projects ship no overlay, and that is the
common case — never an error. When a project does add one, it is ordinary committed
configuration, tracked in git like the rest of `.milestone-config/`; it needs **no**
`.gitignore` entry.

**Malformed input is skipped, never grounded on.** The overlay follows the same
best-effort discipline as your standing docs (`docs/consumer-setup.md` §4): stable
`##` anchors, and a section that is empty, malformed, or unrecognized is treated as
not present — skipped quietly, never half-read into a plan. A broken overlay can
never break a plan run (`.project/design-philosophy.md` Error & failure philosophy).

---

For the design rationale behind this reference, see
[`specs/v0.7.0-implied-surfaces.md`](specs/v0.7.0-implied-surfaces.md). For the
internal design reference, see [`architecture.md`](architecture.md).
