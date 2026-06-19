# Milestone plan (PREVIEW) — Account Settings page: edit profile (name, email, avatar) + notification preferences and save

Self-check: PASS — all 6 issues GAPS: none / Advisory-only (milestone-driver reviewers; #C cleared a design Blocker on retry 1 of ≤2)
Source brief: inline

## Milestone description (preview)
Add an Account Settings page where a signed-in user can edit their profile (name, email, avatar) and notification preferences, and save the changes.

## Waves
- Wave 1: #A
- Wave 2: #B (depends on #A)
- Wave 3 (parallel): #C, #D, #E, #F (all depend on #B; #C/#D/#E also depend on #A)

## Issues

### #A — Add ProfileSettings data model and save service for profile and notification preferences   [logic, risk:heavy]   [self-check: PASS]
## Summary
Introduce the `ProfileSettings` data model (profile fields and notification-preference shape) and the save service that the Account Settings page mutates against. This is the logic substrate the settings page depends on: per conventions.md, settings pages perform an optimistic save with a success toast and rollback-on-error, which requires a typed service contract the page can call, await, and roll back when the call fails. Out of scope: password/security settings (handled by the existing AccountSecurityPage).

## Acceptance criteria
- [ ] Happy path: `saveProfileSettings(next: ProfileSettings)` persists the provided profile fields (`name`, `email`, `avatar`) and notification preferences and resolves with the saved `ProfileSettings` so the page can confirm and show its success toast.
- [ ] Empty state: an absent/never-saved profile is representable — `avatar` is optional (`string | null`) and `notifications` defaults to all toggles `false`; a `defaultProfileSettings` factory returns this empty-but-valid shape so the page can render before any save has occurred.
- [ ] Error / failure path: when persistence fails the returned Promise rejects with a typed error (does not resolve), so the page's rollback-on-error path can revert optimistic state; the prior persisted value is left unchanged.
- [ ] Disabled / edge state: `saveProfileSettings` rejects with the same typed validation error without attempting persistence when `name` is empty or `email` is not a valid email, so the page can keep Save disabled / surface the field error rather than persisting an invalid record.

## Design (recorded, consistent)
- Model lives in `src/services/` (or `src/types/`) as a TypeScript module, exporting:
  - `ProfileSettings` — `{ name: string; email: string; avatar: string | null; notifications: NotificationPreferences }`. `avatar` is `string | null` (URL/asset reference produced by `ImageUploader`), null when unset.
  - `NotificationPreferences` — a flat record of named boolean toggles, all `false` by default. Exact toggle keys are a presentation concern resolved by the settings-page issue; the model types it as `Record<string, boolean>`.
  - `defaultProfileSettings(): ProfileSettings` — factory returning the empty-but-valid shape (`name: ''`, `email: ''`, `avatar: null`, `notifications: {}`).
- Save service contract: `saveProfileSettings(next: ProfileSettings): Promise<ProfileSettings>` — async; resolves with the persisted value; rejects with a typed error on validation failure or transport failure. This is the contract the optimistic-save flow (success toast on resolve, rollback on reject) mutates against, as AccountSecurityPage's save does.
- Validation lives in the service: `name` non-empty after trim; `email` matches a standard email shape. The page mirrors the same checks inline via `FormField`'s validate-on-blur (src/components/FormField.tsx), but the service is authoritative.
- Transport: persists over the stack's standard async transport for React 18 + TypeScript (same path AccountSecurityPage's save uses). No new transport introduced.
- Convention followed: conventions.md "Settings pages: mirror AccountSecurityPage layout ... optimistic save with success toast and rollback-on-error" (src/pages/AccountSecurityPage.tsx); conventions.md Forms validation pattern (src/components/FormField.tsx); conventions.md Avatar upload via ImageUploader (src/components/ImageUploader.tsx); conventions.md "empty and error states required on every user-facing surface".

## Dependencies
- (none — #A is in Wave 1 with no unmet dependency)

## Classification
- Surface: logic
- Risk: heavy

### #B — Scaffold Account Settings page shell mirroring AccountSecurityPage layout   [ui, risk:heavy]   [self-check: PASS]
## Summary
Add the Account Settings page shell at `src/pages/**` so a signed-in user has a dedicated surface for editing profile and notification preferences and saving changes. This issue delivers only the page scaffold: the two-column form layout, the bottom sticky Save bar, and the optimistic-save wiring (success toast on commit, rollback on error). It does not implement the individual profile fields, avatar upload, or notification toggles — those are added by the sibling issues that depend on this shell. The shell mirrors `AccountSecurityPage` so the new page is structurally consistent with the existing settings surface.

## Acceptance criteria
- [ ] Happy path: a signed-in user navigates to the Account Settings page and sees the two-column form layout with a sticky Save bar pinned to the bottom mirroring `AccountSecurityPage`; editing a wired field enables Save, clicking Save applies the change optimistically and a success toast confirms the save.
- [ ] Empty state: when there are no changes to save (form is in its initial/unedited state), the page renders the full two-column layout and sticky Save bar with the Save action in its disabled state; no toast is shown.
- [ ] Error / failure path: when the save service rejects, the optimistic update is rolled back to the pre-save values, an error state is surfaced to the user (per the substrate error-state convention), and the Save action returns to an actionable (enabled) state so the user can retry.
- [ ] Disabled / edge state: the Save action is disabled while the form is unedited and while a save is in flight (loading); during an in-flight save the Save bar reflects the loading state and re-enables on settle (success or error).

## Design (recorded, consistent)
This is a UI page shell. It is built by mirroring the existing settings-page pattern; no new layout primitives are introduced.
- Pattern to mirror: `AccountSecurityPage` — two-column form, sticky Save bar pinned to the bottom, optimistic save with success toast and rollback-on-error. Mirror its structure verbatim for layout and save flow. (src/pages/AccountSecurityPage.tsx)
- Save flow: optimistic apply on Save; on service success show the success toast; on service rejection roll back to pre-save values and surface the error state. The save service and profile-settings model are provided by #A — this shell wires against them and owns no save logic of its own.
- Required states: empty (unedited form rendered with disabled Save, no toast); error (service rejection → rollback + error state surfaced per substrate convention); loading (Save in flight → Save disabled, loading reflected on the Save bar); disabled (Save disabled while unedited and while saving). The substrate requires empty and error states on every user-facing surface (project/conventions.md "States: empty and error states required on every user-facing surface"); loading and disabled are required by the save flow this shell wires.
- Affordances: a single Save action in the sticky Save bar (mirroring `AccountSecurityPage`). Save is non-destructive (it commits the user's own edits), so no confirm affordance is required; the optimistic-apply-then-rollback flow is the only commit path. No destructive operation exists in this shell.
- Form fields: this shell renders no concrete fields; field content (profile fields via shared `FormField`, avatar via `ImageUploader`, notification toggles) is added by sibling issues. The shell provides the two-column form container those issues populate.
- Accessibility: the Save action is a labeled button ("Save", accessible name "Save"); the page exposes a heading/label identifying it as "Account Settings"; the error state is surfaced as an accessible status message and the success toast as an accessible notification, consistent with `AccountSecurityPage`'s patterns. Interactive elements added by sibling issues carry their own labels per the `FormField`/`ImageUploader` conventions.
- Stack: React 18 + TypeScript (non-negotiable).
- Convention followed: project/conventions.md "Settings pages: mirror AccountSecurityPage layout — two-column form, sticky Save bar at bottom, optimistic save with success toast and rollback-on-error" (src/pages/AccountSecurityPage.tsx); project/conventions.md "States: empty and error states required on every user-facing surface".

## Dependencies
- Depends on #A — page shell wires optimistic save / rollback against the ProfileSettings save service and model from #A

## Classification
- Surface: UI
- Risk: heavy

### #C — Build profile name and email fields using shared FormField with inline validation   [ui, risk:heavy]   [self-check: PASS (cleared design Blocker on retry 1)]
## Summary
Render the profile name and email inputs on the Account Settings page using the shared `FormField` component so a user can edit their name and email as part of editing their profile. Both fields use inline validation (validate on blur, error text under the field), bind to the profile model, and live inside the settings page shell, matching the established forms and settings-page conventions. The fields surface their validity into the page shell's shared Save-enablement contract; the sticky Save bar, optimistic save/rollback, and Save-enablement rule are owned by the page-shell issue #B (per conventions.md "Settings pages: mirror AccountSecurityPage").

## Acceptance criteria
- [ ] Happy path: With a loaded profile, the name and email fields render inside the settings page shell pre-populated from the profile model; editing a value and blurring with valid input updates the bound profile model and shows no error text.
- [ ] Empty state: When the profile model has no name and/or no email, the corresponding field renders empty (showing its placeholder) with no error text until the user interacts; a required field left empty and blurred shows its required-error text under the field.
- [ ] Error/failure path: On blur with invalid input (empty required name, or malformed email), the field shows inline error text directly under the field via `FormField` and is marked invalid (aria-invalid="true") so the value is not treated as valid for save; the invalid field surfaces its aria-invalid state into the page shell's Save-enablement contract owned by #B (Save disabled while any field is aria-invalid).
- [ ] Disabled/edge state: While the profile is loading (not yet available) the name and email fields render in a disabled state and accept no input until the profile model resolves.

## Design (recorded, consistent)
Render two `FormField` instances — Name and Email — inside the Account Settings page shell (the `src/pages/**` surface created by #B). The two fields follow the two-column form layout of the settings page shell; that layout is inherited from #B (mirroring src/pages/AccountSecurityPage.tsx, conventions.md "Settings pages: mirror AccountSecurityPage — two-column form"). Each `FormField` mirrors the shared component's inline-validation behavior: validation runs on blur and error text is rendered under the field by `FormField` itself. Field values bind to the profile model from #A.
Save-enablement: this issue does not own the Save bar. The sticky Save bar at the bottom of the settings page, the optimistic save with success toast and rollback-on-error, and the Save-enablement rule (Save disabled while any field is aria-invalid) are all owned by the page-shell issue #B, mirroring src/pages/AccountSecurityPage.tsx. This issue's responsibility is to surface each field's validity into that shared contract: a field that is invalid on blur sets aria-invalid="true", which #B's Save-enablement rule consumes to keep Save disabled while any field is aria-invalid.
Required states: Empty (placeholder, no error until interaction); Loading (model not resolved → fields disabled, reject input); Error (on-blur invalid → inline error text under the field, aria-invalid="true"); Disabled (during loading).
Accessibility: each field has an associated visible label rendered by `FormField` ("Name", "Email") programmatically tied to its input; email input uses `type="email"`; invalid fields set `aria-invalid="true"` and the error text is associated with the input.
- Convention followed: project/conventions.md "Forms: shared FormField with inline validation (validate on blur; error text under the field)" — src/components/FormField.tsx.
- Convention followed: project/conventions.md "States: empty and error states required on every user-facing surface."
- Convention followed: project/conventions.md "Settings pages: mirror AccountSecurityPage — two-column form, sticky Save bar at bottom, optimistic save with success toast and rollback-on-error" — src/pages/AccountSecurityPage.tsx.

## Dependencies
- Depends on #B — name/email FormField inputs render inside the settings page shell (src/pages/** surface) created by #B; the two-column form layout, sticky Save bar, optimistic save/rollback, and Save-enablement contract (Save disabled while any field is aria-invalid) are owned by #B.
- Depends on #A — name/email field values bind to the profile model from #A.

## Classification
- Surface: UI
- Risk: heavy

### #D — Add avatar upload field using ImageUploader component   [ui, risk:heavy]   [self-check: PASS]
## Summary
Add an avatar upload control to the Account Settings page by reusing the shared `ImageUploader` component (src/components/ImageUploader.tsx), rendered inside the settings page shell and wired into the profile save flow. The control reads and writes the avatar value on the profile model so that a saved avatar persists through the page's optimistic save (success toast + rollback-on-error), consistent with how the settings page mirrors `AccountSecurityPage`.

## Acceptance criteria
- [ ] Happy path: User selects an image; `ImageUploader` uploads it and the resulting avatar value binds to the profile model; on Save the avatar persists optimistically with a success toast.
- [ ] Empty state: When the profile has no avatar value, the control renders `ImageUploader`'s empty/placeholder state prompting the user to add an avatar (no broken image, no error).
- [ ] Error / failure path: If the upload fails, an inline error state is shown on the control and the avatar value is not bound; if Save fails, the optimistic avatar change rolls back per the page's rollback-on-error pattern.
- [ ] Disabled / edge state: While an upload is in progress the control shows its uploading (loading) state and the sticky Save bar's Save action is disabled until the upload settles (success or error).

## Design (recorded, consistent)
Render the avatar field within the Account Settings page shell (the two-column form created by #B that mirrors `AccountSecurityPage`), reusing the shared `ImageUploader` component rather than a bespoke uploader. The control's value binds to the avatar property of the profile model from #A, participating in the same optimistic save (success toast + rollback-on-error) the settings page inherits from `AccountSecurityPage`.
UI Design:
- Pattern to mirror: `ImageUploader` at src/components/ImageUploader.tsx (the upload control itself); page-level form/save structure mirrors `AccountSecurityPage` at src/pages/AccountSecurityPage.tsx (two-column form, sticky Save bar, optimistic save with success toast + rollback-on-error).
- Required states:
  - empty — no avatar value: `ImageUploader` placeholder/empty state inviting upload (convention: empty state required on every user-facing surface).
  - loading — uploading: `ImageUploader` in-progress/uploading state while the file uploads.
  - error — upload-error and save-error: inline error on the control for a failed upload (convention: error state required on every user-facing surface); save failure surfaces via the page's rollback-on-error + error feedback.
  - disabled — Save action disabled while an upload is in progress; control disabled from accepting a new file mid-upload.
- Affordances: a clickable upload trigger (button/dropzone) provided by `ImageUploader`; a way to replace an existing avatar; current avatar preview when a value is present.
- Accessibility labels: the upload control has an accessible name (e.g., aria-label "Upload avatar" / "Change avatar"); the upload status (uploading, upload-error) is exposed to assistive tech (e.g., aria-live status / aria-busy during upload, descriptive error text associated with the control).
- Convention followed: project/conventions.md "Avatar upload: reuse the `ImageUploader` component. Pattern: src/components/ImageUploader.tsx"; project/conventions.md "Settings pages: mirror `AccountSecurityPage` ... Pattern: src/pages/AccountSecurityPage.tsx"; project/conventions.md "States: empty and error states required on every user-facing surface."

## Dependencies
- Depends on #B — avatar ImageUploader field renders inside the settings page shell created by #B
- Depends on #A — avatar value binds to the profile model from #A

## Classification
- Surface: UI
- Risk: heavy

### #E — Build notification preference toggles section   [ui, risk:heavy]   [self-check: PASS]
## Summary
Render the notification-preference toggles section on the Account Settings page, placed inside the settings page shell from #B and wired into the shared save flow alongside the profile fields. One toggle is rendered per field in the notification-preference shape defined by #A; the section does not define its own category taxonomy — the set of toggles is derived entirely from #A's shape. Placement, two-column layout, sticky Save bar, and optimistic-save behavior mirror `AccountSecurityPage` per conventions.md.

## Acceptance criteria
- [ ] Happy path: the section renders one labeled toggle per field in the notification-preference shape from #A; changing a toggle marks the form dirty and, on Save, persists optimistically with a success toast (mirroring `AccountSecurityPage` save behavior). Toggle order follows the field order of the #A shape.
- [ ] Empty state: when the notification-preference shape from #A yields no fields (empty preference set), the section renders its heading with a convention-required empty state (no orphaned Save affordance for this section), per conventions.md "empty ... states required on every user-facing surface."
- [ ] Error / failure path: when the optimistic save fails, the section's toggle values roll back to their pre-save state and an error state/toast is shown, matching the rollback-on-error behavior of `AccountSecurityPage`; per-toggle inline validation surfaces via the shared `FormField` pattern if a value is rejected.
- [ ] Disabled / edge state: while a save is in flight, toggles are disabled (non-interactive) to prevent concurrent edits, consistent with the sticky Save bar's pending state; a toggle whose underlying preference is unavailable from #A's shape is not rendered (never rendered in an indeterminate/undefined state).

## Design (recorded, consistent)
- Placement & save wiring: the toggles section lives inside the settings page shell created by #B and participates in the same form/save lifecycle as the profile fields. Layout mirrors `AccountSecurityPage` — two-column form, sticky Save bar, optimistic save with success toast and rollback-on-error.
- Category content: NOT invented here. Toggles are generated by iterating the notification-preference shape from #A (one toggle per field). This avoids defining a notification taxonomy that the substrate does not assert; the shape is the single source of truth for which categories exist and their labels.
- States: empty state (no fields from #A) and error state are required per convention; loading/disabled state is driven by the in-flight save from the shared Save bar.
- Affordances: a labeled toggle control per preference field; the shared sticky Save bar (owned by the page shell, not duplicated by this section); success toast on save; error toast + value rollback on failure.
- Accessibility labels: each toggle exposes an accessible label derived from its preference field (e.g. `aria-label`/associated `<label>` naming the notification category and on/off semantics via the toggle's checked state); the section is introduced by a heading element so assistive tech can navigate to it; disabled-while-saving state is conveyed via the control's disabled/`aria-disabled` attribute.
- Stack: React 18 + TypeScript (non-negotiable). Reuse shared form primitives (`FormField`) for inline validation consistency.
- Convention followed: project/conventions.md "Settings pages: mirror `AccountSecurityPage` — two-column form, sticky Save bar, optimistic save with success toast + rollback-on-error" (src/pages/AccountSecurityPage.tsx); "Forms: shared `FormField`, inline validation" (src/components/FormField.tsx); "States: empty and error states required on every user-facing surface."

## Dependencies
- Depends on #B — notification toggles section renders inside the settings page shell created by #B.
- Depends on #A — notification toggles bind to the notification-preference shape from #A (the shape also determines which toggles/categories are rendered).

## Classification
- Surface: UI
- Risk: heavy

### #F — Add empty and error states to the Account Settings page   [ui, risk:light]   [self-check: PASS]
## Summary
The Account Settings page (created by #B) lets a user edit profile + notification preferences and save. Per the project convention "empty and error states are required on every user-facing surface," this issue adds the load-failure error state, the empty/initial state, and the loading state to the Account Settings surface, mirroring the state treatment already established by `AccountSecurityPage`. Scope is the non-happy-path rendering of the existing settings surface; it does not introduce new form fields or the save behavior itself (owned by #B).

## Acceptance criteria
- [ ] Happy path: when the user's settings load successfully, the populated two-column form renders as it does today and no empty/error/loading affordance is shown.
- [ ] Empty state: when settings load successfully but no profile/notification values are set yet (initial/empty account), the page renders the empty/initial state mirroring `AccountSecurityPage` rather than a blank form region, with an `aria-label` on the empty-state container describing the state.
- [ ] Error / failure path: when the settings load request fails, the page renders an error state (matching `AccountSecurityPage`'s load-failure treatment) with a retry affordance; the error message is announced to assistive tech via `role="alert"` and the form/Save bar is not interactive.
- [ ] Disabled / edge state: while settings are loading, the page renders a loading state and the Save bar is disabled (non-submittable); the disabled Save control carries an `aria-disabled="true"` label so it is announced as unavailable.

## Design (recorded, consistent)
Mirror the state treatment of the existing settings surface, `AccountSecurityPage`, which is the canonical settings page per conventions.md. The Account Settings page is a two-column form with a sticky Save bar; this issue layers the load-state branches over that surface:
- Pattern to mirror: `src/pages/AccountSecurityPage.tsx` — replicate its empty, error (load-failure), and loading state treatment and place them on the Account Settings surface from #B.
- Required states: loading (initial fetch in flight; Save bar disabled), empty (load succeeded, no values set yet), error (load failed; retry affordance, Save bar non-interactive), and the existing populated/happy state (unchanged).
- Error state uses optimistic-save's existing rollback-on-error convention only for save failures (owned by #B); this issue covers the load-failure error state for the surface.
- Accessibility: empty-state container gets a descriptive `aria-label`; error-state messaging uses `role="alert"` so failures are announced; the disabled Save control during loading carries `aria-disabled="true"`. Labels mirror those used by `AccountSecurityPage`.
- Form fields, inline validation, and avatar upload remain via shared `FormField` (`src/components/FormField.tsx`) and `ImageUploader` (`src/components/ImageUploader.tsx`) — unchanged by this issue; no new fields introduced.
- Convention followed: project/conventions.md "States: empty and error states required on every user-facing surface" and "Settings pages: mirror `AccountSecurityPage` … Pattern: src/pages/AccountSecurityPage.tsx".

## Dependencies
- Depends on #B — empty/error states attach to the Account Settings page surface created by #B.

## Classification
- Surface: UI
- Risk: light

## Substrate grounding
- #A profile model + save service (optimistic save, success toast, rollback-on-error; service-authoritative validation) — grounded in project/conventions.md#settings-pages (mirror AccountSecurityPage, src/pages/AccountSecurityPage.tsx) and project/conventions.md#forms (FormField validation, src/components/FormField.tsx).
- #B page shell (two-column form, sticky Save bar, optimistic save + rollback, Save-enablement) — grounded in project/conventions.md#settings-pages (src/pages/AccountSecurityPage.tsx) and project/conventions.md#states.
- #C name/email FormField fields (inline validate-on-blur, error text under field, aria-invalid; two-column layout inherited from #B; Save-enablement contract owned by #B) — grounded in project/conventions.md#forms (src/components/FormField.tsx) and project/conventions.md#settings-pages (src/pages/AccountSecurityPage.tsx).
- #D avatar upload (reuse ImageUploader; empty/uploading/upload-error/disabled states) — grounded in project/conventions.md#avatar-upload (src/components/ImageUploader.tsx) and project/conventions.md#settings-pages.
- #E notification toggles (set derived from #A's notification-preference shape, not invented; mirror AccountSecurityPage placement + save) — grounded in project/conventions.md#settings-pages (src/pages/AccountSecurityPage.tsx) and project/conventions.md#forms; notification taxonomy intentionally NOT invented (derived from #A's shape).
- #F empty/error/loading states on the page surface (mirror AccountSecurityPage load-state treatment) — grounded in project/conventions.md#states and project/conventions.md#settings-pages (src/pages/AccountSecurityPage.tsx).
- Degradations: none (uiSurfaceGlobs present — design-lens distinction drawn; #A logic, #B–#F ui).

## Needs human input
none

---
To create these on GitHub, re-run with `--apply` — it ensures the labels, creates-or-adopts the milestone, opens each gate-surviving issue, rewrites the slug references to real issue numbers, and patches the milestone description with the Wave order. This preview wrote no GitHub state.
