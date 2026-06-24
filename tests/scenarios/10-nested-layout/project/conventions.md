# Engineering conventions

This is a nested monorepo. The application is split into two app roots; nothing
application-level sits at the repo root — the root holds only config and tooling.

## App roots
- **Web frontend** (`siteroot/web`): the user-facing app. Owns every page, component, and the
  client code that talks to the backend. All web work belongs to this root.
- **API backend** (`siteroot/api`): the HTTP service. Owns every route and request handler. All
  backend work belongs to this root.

Each root is self-contained: the web app and the API are developed and scoped independently, and
a single piece of work lives entirely inside one root. Where exactly a given file lands inside its
root is governed by the project's baked source/UI globs, not restated here.

## API
- REST endpoints under `/api/v1/`; JSON bodies; auth required; errors return `{ "error": "..." }`
  with the correct HTTP status.

## Web
- Pages call the backend through the shared API client — never `fetch` directly from a page.
- User-facing surfaces: show a success/error toast via the shared `useToast()` hook; empty and
  error states are required on every surface.
