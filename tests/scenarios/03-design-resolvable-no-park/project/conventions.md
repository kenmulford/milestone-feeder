# Engineering conventions

- **Forms:** all forms use the shared `FormField` component with **inline validation** (validate on blur; error text under the field). Pattern: `src/components/FormField.tsx`.
- **Settings pages:** mirror the existing `AccountSecurityPage` layout — a two-column form, a sticky Save bar at the bottom, optimistic save with a success toast and rollback-on-error. Pattern: `src/pages/AccountSecurityPage.tsx`.
- **Avatar upload:** reuse the `ImageUploader` component. Pattern: `src/components/ImageUploader.tsx`.
- **States:** empty and error states are required on every user-facing surface.
