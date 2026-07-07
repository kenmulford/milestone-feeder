# Expected contract — 10 nested-layout  (GRADER ONLY)

A clean, well-specified brief against a **nested monorepo** layout. The source/UI globs are the
root-absolute globs the bootstrapper (v0.2.0) baked from `appRoots: ["siteroot/web",
"siteroot/api"]`. The feeder consumes those globs verbatim — it has no `appRoot` key of its own.
The claim under test: issue file scope lands **inside the nested app roots**, and nothing
resolves to the bare repo root.

## Why this scenario is adversarial
`project/conventions.md` describes the two app roots and the role of each (web owns pages /
components / client; api owns routes / handlers) but **deliberately does NOT hand the feeder
copy-paste, repo-prefixed file paths for this feature** — there is no "pages under
`siteroot/web/src/pages/`" lookup table to transcribe. The only authoritative source for *where
file scope lands* is the baked `sourceGlobs` / `uiSurfaceGlobs` in `feeder-env.md`. A feeder that
ignored the nested globs and assigned scope from prose alone would have nothing to copy — so the
scope assignment must be **glob-driven** to land correctly. That is the mechanism this scenario
isolates: a glob-ignoring feeder FAILS here; it cannot pass by prose-transcription.

## MUST
- 2 issues (3 acceptable if it splits sensibly): the **status endpoint** (in `siteroot/api`) and
  the **dashboard export-status banner** (in `siteroot/web`). ~1 PR each.
- **Nested path scope — the load-bearing assertion (glob-driven, not transcribed):**
  - **Every assigned path falls inside a baked nested glob** — inside `siteroot/api/**` for the
    endpoint issue, inside `siteroot/web/**` for the banner issue — and is consistent with the
    matching glob, NOT merely copied from a prefix that also appears in prose.
  - The api-endpoint issue's file scope is **inside `siteroot/api/**`** (e.g. a route under
    `siteroot/api/src/routes/`, a handler under `siteroot/api/src/handlers/`).
  - The web-banner issue's file scope is **inside `siteroot/web/**`** and its **primary surface is
    a page or component under `uiSurfaceGlobs`** — i.e. under `siteroot/web/src/pages/**` or
    `siteroot/web/src/components/**`. It MAY *secondarily* touch the shared API client at
    `siteroot/web/src/api/client.ts`, but that secondary path does not stand in for the
    page/component surface and is not the basis of the classification.
  - **NOTHING resolves to a bare repo-root path** — no top-level `src/**`, no top-level file scope,
    no path that omits the `siteroot/web` or `siteroot/api` prefix.
- Dependency edge: the web banner **depends on** the endpoint (the banner polls it). Endpoint =
  Wave 1; banner = Wave 2.
- Classification: the web-banner issue classifies **`ui`** **because its primary page/component
  surface matches `uiSurfaceGlobs`** under `siteroot/web` (not because of the API-client path,
  which is under `siteroot/web/src/api/` and is NOT in `uiSurfaceGlobs`); the api-endpoint issue
  classifies **`logic`**.
- Each issue body has all five §4 sections. Acceptance criteria include empty/error states (per
  convention). The web-banner issue records the shared API-client + `useToast()` conventions.
- The milestone description encodes the Wave order (§4 template).
- Every emitted issue is drafted to pass the driver's triage clean (`GAPS: none`) — well-formed,
  ready for the driver to triage.
- ZERO parks; needs-product-input report absent or "none" — the brief is fully specified and the
  conventions ground every design call.

## SHOULD
- Convention citations point at the provided `project/conventions.md` (real grounding), not invented.
- The split mirrors the nested layout: one issue per app root, not one issue spanning both roots.

## FAIL if
- **Any issue's file scope resolves to the repo root** instead of a nested app root (e.g. a bare
  `src/**`, a top-level file, or a path missing the `siteroot/web` / `siteroot/api` prefix) — the
  primary failure mode this scenario hunts.
- **The scope assignment is not glob-driven** — an assigned path falls outside every baked nested
  glob, or the scope is justified only by prose transcription rather than by the baked
  `sourceGlobs` / `uiSurfaceGlobs`. Merely reusing a prefix that also appears in the conventions
  text does NOT demonstrate the routing claim; the grader confirms every assigned path falls
  within a baked nested glob and none falls outside them or at the repo root.
- The web-banner issue's primary surface is NOT a page/component under `uiSurfaceGlobs` (e.g. it is
  scoped only at the API client `siteroot/web/src/api/`), so the `ui` classification is unfounded
  or the design lens never engages.
- The nested globs are ignored (file scope assigned without honoring `siteroot/web/**` /
  `siteroot/api/**`).
- Misses the banner→endpoint dependency edge; invents scope not in the brief; parks something a
  convention answers; or produces issues missing error/empty states.
