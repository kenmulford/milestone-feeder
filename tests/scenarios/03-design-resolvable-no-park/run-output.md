# Milestone plan (PREVIEW) — Account Settings page: edit profile (name, email, avatar) + notification preferences and save

Milestone title (exact): Account Settings page
Self-check: PASS — all 5 issues GAPS: none / Advisory-only (milestone-driver reviewers)
Source brief: inline

## Milestone description (Wave order)
Add an Account Settings page where a signed-in user can edit their profile (name, email, avatar) and notification preferences, and save the changes.

## Waves
- Wave 1: #A
- Wave 2 (parallel): #B (depends on #A), #C (depends on #A), #D (depends on #A)
- Wave 3: #E (depends on #A, #B, #C, #D)

## Issues

### #A — Scaffold AccountSettingsPage shell with two-column layout, sticky Save bar, and empty/error states   [ui, risk:heavy]   [self-check: PASS]
## Summary
Add the Account Settings page shell at `src/pages/AccountSettingsPage.tsx` so a signed-in user has a place to edit their profile and notification preferences. This issue establishes the page structure only — the two-column form layout, the bottom sticky Save bar, the route to reach the page, and the page-level empty and error states. The profile fields, notification toggles, and the save behaviour are added by the issues that depend on this one; this shell is the container they plug into. The page mirrors the existing `AccountSecurityPage` so Settings pages stay visually and structurally consistent.

## Acceptance criteria
- [ ] Happy path: navigating to the Account Settings route renders `AccountSettingsPage` with the two-column form region and a sticky Save bar pinned to the bottom of the page, matching the `AccountSecurityPage` layout. A defined slot/region exists in the form column for fields and toggles to be added by dependent issues, and a Save affordance is present in the Save bar.
- [ ] Empty state: when there is no profile content to display yet (no fields/toggles mounted, or profile data not yet provided), the page renders the empty state region in the form column rather than a blank area, consistent with the empty-state treatment required by conventions.md "States".
- [ ] Error state: when the page fails to load the data it needs to render, the page renders the error state (in place of the form region) consistent with the error-state treatment required by conventions.md "States" and the `AccountSecurityPage` error handling it mirrors.
- [ ] Disabled/edge state: before there are any unsaved changes (the initial, pristine state of the shell), the Save affordance in the sticky Save bar is rendered in a disabled state. (The enable-on-dirty / actual save logic is owned by the dependent save issue; this shell only renders the Save bar with the affordance disabled by default.)

## Design (recorded, consistent)
- Page lives at `src/pages/AccountSettingsPage.tsx` (a `uiSurfaceGlobs` `src/pages/**` path), built with React 18 + TypeScript per the non-negotiable stack.
- Layout, Save bar, and state treatments mirror `AccountSecurityPage`: a two-column form region with a sticky Save bar pinned to the bottom. Reproduce `AccountSecurityPage`'s structure rather than inventing a new layout, so Settings pages stay consistent.
- This issue is the shell only: it defines the page container, the form-column region/slot where fields and toggles mount, the Save bar with its Save affordance, the route, and the empty + error states. Field rendering, toggle rendering, and save submission are out of scope here and are delivered by the dependent issues.
- Empty and error states are required and rendered at the page/form-region level, following the same treatment `AccountSecurityPage` uses (per conventions.md "States"). The empty state shows in the form column when no profile content is mounted; the error state replaces the form region when required data fails to load.
- The Save affordance defaults to disabled in the pristine shell (no unsaved changes yet). Enable-on-dirty behaviour and the optimistic-save / success-toast / rollback-on-error flow belong to the dependent save issue, not this shell.
- Accessibility: the page is reachable as a labeled route/landmark; the Save affordance is a button with an accessible name "Save" (or the equivalent label `AccountSecurityPage`'s Save control uses), and remains focusable/announced as disabled in the pristine state. Mirror the labeling `AccountSecurityPage` already applies to its Save control.
- Convention followed: src/pages/AccountSecurityPage.tsx (Settings pages: mirror AccountSecurityPage layout — two-column form, sticky Save bar at the bottom); project/conventions.md "States" (empty and error states required on every user-facing surface).

## Dependencies
- None — #A is Wave 1 and depends on nothing. Other issues (fields, toggles, save) depend on this shell.

## Classification
- Surface: UI
- Risk: heavy

### #B — Add name and email profile fields to AccountSettingsPage using shared FormField with inline validation   [ui, risk:heavy]   [self-check: PASS]
## Summary
Add editable **name** and **email** profile fields to the Account Settings page so a signed-in user can view and change these values as part of editing their profile. The fields render as shared `FormField` inputs inside the page's form shell, with inline validation on blur (error text shown under each field) so the user gets immediate, in-context feedback before saving.

## Acceptance criteria
- [ ] Happy path: The Account Settings form renders a name input and an email input, each as a shared `FormField`. Editing a field and moving focus away (blur) with a valid value shows no error, and the entered values are held in form state ready to save.
- [ ] Empty state: When a required field (name, email) is left blank, on blur the field shows inline error text under the field indicating the value is required; the field's current value renders as empty rather than `undefined`/`null`.
- [ ] Error / failure path: When the email value is not a valid email address, on blur the email field shows inline error text under the field describing the validation failure, and the field is marked invalid so a parent save flow can treat the form as not submittable.
- [ ] Disabled / edge state: While the parent form's save is in progress (the Save bar's saving state from #A), the name and email inputs are disabled so the user cannot edit values mid-save.

## Design (recorded, consistent)
- Both fields are rendered with the shared `FormField` component (not raw `<input>`), mounted inside the `AccountSettingsPage` form shell introduced by #A.
- Validation is inline: validate on blur, with error text rendered under the field. This follows the established Forms behavior; do not validate on every keystroke and do not surface errors in a separate summary region.
- Field rules: name is required (non-empty after trim); email is required and must be a syntactically valid email address. Required-empty and invalid-format both produce inline error text under the respective field on blur.
- Each `FormField` is a labeled, interactive input — the visible label ("Name", "Email") is the accessible name; the inline error text is associated with its field so assistive technology announces it (mirror how `FormField` wires label and error per its pattern). No standalone affordances are added by this issue (no buttons); the Save action lives in the #A Save bar.
- Disabled state for both inputs is driven by the parent form's in-progress save state owned by #A; this issue only consumes that flag to disable the inputs.
- Convention followed: project/conventions.md "Forms" rule (shared `FormField` with inline validation — validate on blur, error text under the field; pattern: src/components/FormField.tsx). Settings-page form shell + Save bar / saving state: project/conventions.md "Settings pages" rule (pattern: src/pages/AccountSecurityPage.tsx), introduced for this page by #A.

## Dependencies
- Depends on #A — FormField inputs mount inside the AccountSettingsPage form shell + Save bar introduced by #A (src/pages/AccountSettingsPage.tsx)

## Classification
- Surface: UI
- Risk: heavy

### #C — Add avatar upload to the profile section using the shared ImageUploader   [ui, risk:heavy]   [self-check: PASS]
## Summary
Add an avatar field to the profile section of the Account Settings page so a signed-in user can set or change their profile picture. The field reuses the shared `ImageUploader` component and mounts inside the profile section of the page shell, alongside the existing name and email fields.

## Acceptance criteria
- [ ] A signed-in user sees their current avatar in the profile section and can upload a new image via the `ImageUploader`; the chosen image is reflected in the field and persists through the page's existing optimistic save (success toast on save).
- [ ] When the user has no avatar set, the field renders its empty state (no current image) and invites the user to upload one.
- [ ] When an upload or save fails, the field surfaces an error state and the optimistic save rolls back per the settings-page convention (the previous avatar is restored).
- [ ] While an upload is in progress the uploader is in its loading/disabled state so a second upload cannot be triggered until the first resolves.

## Design (recorded, consistent)
- The avatar field reuses the shared `ImageUploader` component rather than introducing a new upload control. This is the established avatar-upload mechanism for this codebase.
  - Convention followed: project/conventions.md "Avatar upload" rule — reuse `ImageUploader` (Pattern: src/components/ImageUploader.tsx).
- The field mounts inside the profile section of the Account Settings page shell, next to the name and email fields.
  - Convention followed: Depends on #A — the profile section of the page shell is introduced there (src/pages, mirrors `AccountSecurityPage`).
- Saving the avatar uses the page's optimistic save with success toast and rollback-on-error; the avatar field does not implement its own save path — it participates in the page-level Save bar.
  - Convention followed: project/conventions.md "Settings pages" rule — mirror `AccountSecurityPage` (optimistic save, success toast, rollback-on-error; Pattern: src/pages/AccountSecurityPage.tsx).
- Empty state (no avatar) and error state (failed upload/save) are both rendered, as required for every user-facing surface.
  - Convention followed: project/conventions.md "States" rule — empty and error states required on every user-facing surface.
- Required states: empty (no avatar set), loading (upload in progress), error (upload/save failure), disabled (uploader locked while an upload is in flight). These are provided by `ImageUploader` and mirror its established behavior.
  - Convention followed: src/components/ImageUploader.tsx (the shared uploader is the pattern for these states).
- Affordances: the upload affordance is the `ImageUploader` control itself; accessibility labels follow the shared component (the uploader's accessible label identifies it as the avatar/profile-picture upload). No destructive operation is introduced by this field, so no separate confirm affordance is required.
  - Convention followed: src/components/ImageUploader.tsx (affordances and accessible labels come from the shared component).

## Dependencies
- Depends on #A — ImageUploader avatar field mounts inside the profile section of the page shell introduced by #A.

## Classification
- Surface: UI
- Risk: heavy

### #D — Add notification preference toggles to the Account Settings form   [ui, risk:light]   [self-check: PASS]
## Summary
Render the user's notification preferences as toggle controls inside the Account Settings form, alongside the profile fields, so a signed-in user can turn each notification preference on or off and save it together with their profile changes. This delivers the "notification toggles" item named as in-scope in the brief.

## Acceptance criteria
- [ ] Happy path: when the Account Settings page loads with notification preferences from the data layer, each preference renders as a toggle in its own section of the two-column form (alongside the profile section); toggling a control and clicking Save in the sticky Save bar persists the new values via optimistic save and shows the success toast.
- [ ] Empty state: when the data layer returns no notification preferences, the toggles section renders its empty state (no toggle rows) rather than an empty/blank panel, consistent with the empty-state requirement for every user-facing surface.
- [ ] Error / failure path: when an optimistic save fails, the toggle values roll back to their pre-save state and an error is surfaced, mirroring the AccountSecurityPage rollback-on-error behavior; a load failure renders the page error state.
- [ ] Disabled / edge state: while a save is in flight the Save bar / toggles reflect the non-interactive (saving) state so the user cannot double-submit, matching the AccountSecurityPage save-bar behavior.

## Design (recorded, consistent)
- Toggles render inside the existing `AccountSettingsPage` two-column form introduced by #A, in their own section adjacent to the profile section (per the candidate sketch and the #A page shell).
- Layout, sticky Save bar, optimistic-save-with-success-toast, and rollback-on-error are inherited by mirroring the `AccountSecurityPage` settings-page pattern — not re-invented here.
- The toggles are rendered generically against whatever notification-preference shape the data layer provides (one toggle control per preference). No notification category taxonomy is defined here, because neither the brief nor conventions.md specifies one; the brief names "notification preferences / notification toggles" as the in-scope unit, which the layout convention fully resolves.
- Each toggle is a labeled interactive control; the visible preference label is its accessible name. Empty and error states are present per the project States convention.
- Convention followed: src/pages/AccountSecurityPage.tsx (settings page: two-column form, sticky Save bar, optimistic save with success toast, rollback-on-error); project/conventions.md States rule (empty and error states required on every user-facing surface).

## Dependencies
- Depends on #A — notification toggles lay out within the two-column form shell introduced by #A.

## Classification
- Surface: UI
- Risk: light

### #E — Wire optimistic save with success toast and rollback-on-error to the Save bar   [logic, risk:heavy]   [self-check: PASS]
## Summary
When a signed-in user edits their account settings and clicks Save in the sticky Save bar, the page must persist their profile fields (name, email), avatar, and notification preferences, then confirm the result. This issue implements the save handler bound to the Save bar: it optimistically applies the change, shows a success toast when persistence succeeds, and rolls the UI back to the prior values if persistence fails. This gives the user immediate feedback while keeping the displayed state honest when a save does not land.

## Acceptance criteria
- [ ] Happy path: with at least one pending edit, clicking Save persists the profile fields (name, email), avatar, and notification preferences; the UI optimistically reflects the saved values and a success toast is shown when persistence resolves.
- [ ] Empty state (nothing to save): when there are no pending changes, the Save action does not issue a persistence request and shows no success toast; the displayed values are unchanged.
- [ ] Error / failure path: when persistence rejects, the optimistic update is rolled back to the values shown before Save and an error state is surfaced to the user (no success toast); the user can retry.
- [ ] Disabled / in-flight edge state: while a save is in flight, the Save affordance is disabled so the same change cannot be submitted twice; it re-enables after the request resolves or rejects.

## Design (recorded, consistent)
- Save behavior mirrors `AccountSecurityPage`: optimistic save, success toast on success, rollback-on-error on failure. This is the authoritative pattern for Settings pages.
- The handler binds to the sticky Save bar affordance owned by #A; it does not introduce its own UI surface.
- On Save, the handler reads and persists the field values owned by #B (name, email), the avatar value owned by #C, and the notification preference values owned by #D — the complete set of editable account-settings state.
- Optimistic flow: snapshot the current persisted values, apply the pending edits to the displayed state immediately, then issue the persistence request. On resolve, keep the optimistic values and show the success toast. On reject, restore the snapshot (rollback) and surface an error state.
- Empty state: if there are no pending edits relative to the last-saved values, Save is a no-op (no request, no toast).
- In-flight: disable the Save affordance for the duration of the request to prevent duplicate submissions, matching the optimistic-save lifecycle.
- Empty and error states are surfaced because they are required on every user-facing surface that this save flow drives.
- Convention followed: project/conventions.md "Settings pages" rule — mirror `AccountSecurityPage` (optimistic save with success toast and rollback-on-error); grounding pattern src/pages/AccountSecurityPage.tsx. Required empty/error states per project/conventions.md "States" rule.

## Dependencies
- Depends on #A — save handler binds to the sticky Save bar affordance introduced by #A
- Depends on #B — save persists the name/email field values owned by #B
- Depends on #C — save persists the avatar value owned by #C
- Depends on #D — save persists the notification preference values owned by #D

## Classification
- Surface: logic
- Risk: heavy

## Project-docs grounding
- #A page shell (two-column form, sticky Save bar, empty/error states; mirror AccountSecurityPage) — grounded in project/conventions.md#settings-pages (src/pages/AccountSecurityPage.tsx) and project/conventions.md#states.
- #B name/email FormField fields (inline validate-on-blur, error text under field, disabled-while-saving) — grounded in project/conventions.md#forms (src/components/FormField.tsx) and project/conventions.md#settings-pages (src/pages/AccountSecurityPage.tsx).
- #C avatar upload (reuse ImageUploader; empty/loading/error/disabled states) — grounded in project/conventions.md#avatar-upload (src/components/ImageUploader.tsx) and project/conventions.md#settings-pages (src/pages/AccountSecurityPage.tsx).
- #D notification toggles (one toggle per data-layer preference; mirror AccountSecurityPage placement + save) — grounded in project/conventions.md#settings-pages (src/pages/AccountSecurityPage.tsx) and project/conventions.md#states; notification taxonomy intentionally NOT invented (derived from the data-layer shape, not parked, not invented).
- #E optimistic save (success toast + rollback-on-error; binds to #A Save bar) — grounded in project/conventions.md#settings-pages (src/pages/AccountSecurityPage.tsx) and project/conventions.md#states.
- Degradations: none (uiSurfaceGlobs present — design-lens distinction drawn; #A/#B/#C/#D ui, #E logic).

## Needs human input
none

---
This plan file is the build artifact — run `/milestone-feeder:create` to deploy it to GitHub (it ensures the labels, creates-or-adopts the milestone by the exact title above, opens each surviving issue, rewrites the slug references to real issue numbers, and patches the milestone description with the Wave order). `plan` wrote no GitHub state.
