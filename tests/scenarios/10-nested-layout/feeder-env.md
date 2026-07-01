# Test environment — 10 nested layout (what the run assumes)

The repo is a nested monorepo: a web frontend at `siteroot/web` and an API backend at
`siteroot/api`. The bootstrapper (v0.2.0) baked the app roots into the glob keys at scaffold
time — its `plan` Step 4 prefixes each `appRoots` entry onto the source/UI globs and writes
the already-resolved, **root-absolute** globs into `.milestone-config/driver.json`. The feeder
consumes those globs verbatim; it has no `appRoot` key of its own (that's why feeder #112 was
closed as superseded — the prefix is resolved upstream, not re-applied by the feeder).

- `feeder.json`: defaults (`projectDocs: project/`).
- Driver shared keys (as if from `.milestone-config/driver.json`, baked from
  `appRoots: ["siteroot/web", "siteroot/api"]`):
  - `sourceGlobs`: `["siteroot/web/**", "siteroot/api/**"]`  ← root-absolute nested roots; NO bare repo-root glob
  - `uiSurfaceGlobs`: `["siteroot/web/src/components/**", "siteroot/web/src/pages/**"]`  ← UI lives only under the web root
  - `integrationBranch`: `"develop"`
  - `nonNegotiables`: `["Node web frontend in siteroot/web; Node API backend in siteroot/api"]`
- Project docs dir: `project/`

> The globs above are **root-absolute** — every path the feeder assigns must fall inside one
> of the nested app roots (`siteroot/web/**` or `siteroot/api/**`). Nothing should resolve to a
> bare repo-root path (no top-level `src/**`, no top-level file scope).
