# Engineering conventions

- **UI:** reuse the existing `ProductCardGrid` component for any product listing. Pattern: `src/components/ProductCardGrid.tsx`.
- **Data:** read models live in `src/models/`; a new persisted field requires a migration.
- **States:** empty and error states are required on every user-facing surface.

> Note: nothing here states a product policy for HOW featured items are chosen. That is a
> product decision with no conventional default.
