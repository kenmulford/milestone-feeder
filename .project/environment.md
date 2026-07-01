# Environment

<!--
Project doc (.project/). Cite as `.project/environment.md#<section>`. Declares what the
project's runtime and production environment looks like — the facts downstream tools ground
their data, test, and caching decisions in. It does NOT provision anything; it records the
model so issues don't drift. Fill every [TBD]; a section left [TBD] is treated as "not
specified." Humans own this file; tools propose, never rewrite. Keep the ## headings stable
— they are citation anchors.
-->

## Environments
Which environments exist (production, staging, test, local) and how they differ.
No runtime/deploy environments — milestone-feeder is a Claude Code plugin that runs inside the user's Claude Code session against their local repo and GitHub via `gh`. "Environments" = the consumer repos that adopt it; the plugin itself ships via a marketplace (`.claude-plugin/marketplace.json`) and is dev-installable via `claude --plugin-dir`. (Grounded in `docs/consumer-setup.md` §1; `.claude-plugin/marketplace.json`.)

## Data stores
Databases and other persistent stores: the engine(s), and the **topology** — separate prod / staging / test databases, or a shared one. **Test-data isolation:** how tests get a clean, isolated database (a dedicated test DB, a per-worker DB suffix, transactional rollback, truncate-on-start). This is the single biggest drift source if left unstated.
None. The plugin holds no database. Its only persisted state is local **scratch** under `.milestone-feeder/` (the plan file `plan-<slug>.md`, gitignored via a `*` drop on first write) and per-clone runtime markers under `.milestone-config/.runtime/` (one-time-notice gates). Tracked config lives in `.milestone-config/feeder.json` and `.milestone-config/driver.json`. Test-data isolation: each `tests/scenarios/NN-*/` is a self-contained fixture. (Grounded in `docs/architecture.md` The plan file as build artifact; `CHANGELOG.md` v0.4.4 marker note; `.milestone-config/.gitignore`.)

## Caching
Whether caching exists and, if so, the layer and technology (in-memory, Redis, CDN), what is cached, and the invalidation policy. **"None" is a valid, drift-preventing answer** — record it explicitly.
None — no caching layer.

## Async & messaging
Background jobs, queues, streams, schedulers — or "none."
None. Synchronous skill execution; agents are dispatched as subagents within a `plan` run (architect once, issue-author per candidate, parallelizable). No queues, schedulers, or background jobs. (Grounded in `docs/architecture.md` The plan procedure Steps 3–4.)

## External services & integrations
Third-party services the app depends on: auth / identity, payments, email / SMS, object storage, analytics, other APIs.
**GitHub** via the `gh` CLI (the only external service) — `gh label create`, `gh api .../milestones` (POST/PATCH), `gh issue create/edit/list/view/comment`. Optional sibling plugins: `milestone-driver` (the build engine whose triage bar the feeder drafts to) and `milestone-coherence-reviewer` (post-build review). Hard dependency: `superpowers`. No auth / payments / email / storage. (Grounded in `docs/consumer-setup.md` Before you start, §1; `README.md` Before you start.)

## Runtime & hosting
Where it runs and the runtime/version targets (hosting platform, language-runtime versions, regions). For mandated frameworks and packages, cross-reference `library-manifest.md`.
Runs in the user's Claude Code CLI session; no hosting. Requires `gh` installed and signed in, `git`, and **bash with `jq`** or **PowerShell 7+** (for the `no-source-edit` hook). Cross-platform: macOS, Linux, WSL, git-bash, Windows (pwsh 7+). (Grounded in `README.md` Before you start; `.gitattributes`.)
