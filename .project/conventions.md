# Conventions

<!--
Project doc (.project/). Cite as `.project/conventions.md#<section>`. This is the file the
implementer and coherence-reviewer lean on hardest — "reuse conventions" and
"does this fit the app?" both resolve here. Prefer pointing at a canonical
exemplar in the codebase (path:line) over prose. Keep ## headings stable — they
are citation anchors.
-->

## Naming
Files, types, functions, tests, branches.
Skills live at `skills/<verb>/SKILL.md` (verbs: `plan`, `create`, `update`, `setup`); agents at `agents/<name>.md` (ids `milestone-feeder:architect`, `milestone-feeder:issue-author`); hooks at `hooks/` (`hooks.json`, `run-hook.cmd`, `<name>.sh`, `<name>.ps1`). Issue labels: `ui`/`logic` + `risk:light`/`risk:heavy` (the feeder's taxonomy, aligned to the driver's). Plan files: `.milestone-feeder/plan-<slug>.md` where `<slug>` is the lowercased milestone goal with non-alphanumeric runs collapsed to single hyphens, trimmed. Branches: `develop` (integration) / `main` (protected). (Grounded in `docs/architecture.md` Plugin contents, The plan file as build artifact; `SPEC.md` §3, §3.1.)

## File & folder layout
Where things go, and the shape of a feature.
`skills/` (one folder per verb, each a `SKILL.md`) · `agents/` (one `.md` per agent) · `hooks/` (the `no-source-edit` gate + polyglot launcher) · `.claude-plugin/` (`plugin.json` + `marketplace.json`) · `docs/` (architecture, profile-schema, consumer-setup, `specs/`) · `tests/scenarios/NN-*/` (end-to-end fixtures) · `scripts/` (validation helpers) · `.milestone-config/` (`feeder.json`, `driver.json`, nested `.gitignore`). SPEC.md + README.md + CHANGELOG.md at the root. (Grounded in repo layout; `docs/architecture.md` Plugin contents table.)

## Test patterns
Where tests live, how they're named, fixtures/factories, and what a good test looks like.
End-to-end scenarios under `tests/scenarios/NN-<slug>/`: each carries a `brief.md` (the input) plus a `project/` fixture, a `feeder-env.md`, and an `expected.grader.md`, exercising one planning path (01-clean-happy-path, 02-product-gap-parks, 03-design-resolvable-no-park, 04-no-code-refusal, 06-cross-cutting-consistency). The scenarios index `tests/README.md` lists planned 07–09 and documents how to run them and how to read `tests/RESULTS.md`. New scenarios append, and `tests/README.md` is updated to list them. Cross-platform parity is itself a test obligation: bash and pwsh twins must produce identical findings on degenerate inputs. (Grounded in `tests/README.md`; `tests/scenarios/` 01–06; issue #118 acceptance criteria; `CHANGELOG.md` v0.4.5 "cross-platform-parity-hardened".)

## Canonical exemplars (mirror these)
The reference implementations to copy when building something similar. Point at real code.

| For… | Mirror | Notes |
|---|---|---|
| A new skill (orchestrator verb) | `skills/plan/SKILL.md` | Frontmatter name/description, "Announce first", numbered Procedure, output style, non-negotiables block — the suite's SKILL shape. |
| A new read-only agent | `agents/architect.md`, `agents/issue-author.md` | Read-only; returns structured text; never writes repo files or opens issues. |
| A cross-platform hook | `hooks/no-source-edit.sh` + `hooks/no-source-edit.ps1` + `hooks/run-hook.cmd` | Bash-first / pwsh-fallback twins via the polyglot launcher; fail-open. |
| A one-time discovery notice | `docs/one-time-notices.md` (`CHANGELOG.md` v0.4.4/v0.4.5) | Best-effort, read-only, marker-gated to show at most once per clone; honors configurable `projectDocs`. |

## Commits & PRs
Message format and PR expectations.
Feature branch → PR → `develop` (the integration branch); `develop` → `main` is the human-owned release, done by hand. `main` is protected (never push directly; never open a PR to it from automation). Conventional-commit-style messages. The feeder itself opens **no** PRs and touches **no** branches — the version is bumped by hand at release time (no per-PR version machinery, because the feeder has no PR to ride). A release re-syncs the version-bearing locations together (see Versioning). (Grounded in `.milestone-config/driver.json` integrationBranch/protectedBranch; `docs/architecture.md` Plugin version, Modes & autonomy.)

## Versioning
Does the project follow semantic versioning? If so, **where the version lives** (e.g. `pyproject.toml`, `package.json`, `*.csproj`, a `VERSION` file) and the **bump cadence** (per feature / milestone). When semver is on, `milestone-driver` applies the bump per PR and `milestone-feeder` names milestones as versions so the driver can derive the target.
**SemVer.** The single source of truth is `.claude-plugin/plugin.json` `version`. There is **no per-PR version machinery** for the feeder **as a tool** — when it plans a consumer's milestone it opens no PRs, so the driver's bump-rides-the-PR mechanism has nothing to ride; the version is bumped **by hand** when a release is cut. (Distinct case — grounded in `milestone-driver` `solve-issue` step 6.4, not in this repo's as-a-tool stance: when the feeder **repo itself** is built by `milestone-driver`, that step bumps `plugin.json` on the milestone's first PR — the driver's standard behavior — so that run's bump rides that PR.) `.claude-plugin/marketplace.json` carries no `version` field (Claude Code resolves `plugin.json` first). **Release checklist:** bump `plugin.json` first, then re-sync any other hand-maintained in-doc version reference. (The `SPEC.md` as-built header carries no version — `plugin.json` is the single source of truth, so the header has nothing to drift from (resolved in #143).) (Grounded in `docs/architecture.md` Plugin version + Release checklist for the feeder-as-a-tool stance; `milestone-driver` `solve-issue` step 6.4 for the driver-built distinct case; `.claude-plugin/plugin.json`; issue #143.)
