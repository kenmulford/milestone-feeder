# Conventions

<!--
Project doc (.project/). Cite as `.project/conventions.md#<section>`. This is the file the
implementer and coherence-reviewer lean on hardest: "reuse conventions" and
"does this fit the app?" both resolve here. Prefer pointing at a canonical
exemplar in the codebase (path:line) over prose. Keep ## headings stable: they
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
| A new skill (orchestrator verb) | `skills/plan/SKILL.md` | Frontmatter name/description, "Announce first", numbered Procedure, output style, non-negotiables block. The suite's SKILL shape. |
| A new read-only agent | `agents/architect.md`, `agents/issue-author.md` | Read-only; returns structured text; never writes repo files or opens issues. |
| A cross-platform hook | `hooks/no-source-edit.sh` + `hooks/no-source-edit.ps1` + `hooks/run-hook.cmd` | Bash-first / pwsh-fallback twins via the polyglot launcher; fail-open. |
| A one-time discovery notice | `docs/one-time-notices.md` (`CHANGELOG.md` v0.4.4/v0.4.5) | Best-effort, read-only, marker-gated to show at most once per clone; honors configurable `projectDocs`. |

## Commits & PRs
Message format and PR expectations.
Feature branch → PR → `develop` (the integration branch); `develop` → `main` is the human-owned release, done by hand. `main` is protected (never push directly; never open a PR to it from automation). Conventional-commit-style messages. The feeder itself opens **no** PRs and touches **no** branches: the version is bumped by hand at release time (no per-PR version machinery, because the feeder has no PR to ride). A release re-syncs the version-bearing locations together (see Versioning). (Grounded in `.milestone-config/driver.json` integrationBranch/protectedBranch; `docs/architecture.md` Plugin version, Modes & autonomy.)

## Versioning
Does the project follow semantic versioning? If so, **where the version lives** (e.g. `pyproject.toml`, `package.json`, `*.csproj`, a `VERSION` file) and the **bump cadence** (per feature / milestone). When semver is on, `milestone-driver` applies the bump per PR and `milestone-feeder` names milestones as versions so the driver can derive the target.
**SemVer.** The single source of truth is `.claude-plugin/plugin.json` `version`. There is **no per-PR version machinery** for the feeder **as a tool**: when it plans a consumer's milestone it opens no PRs, so the driver's bump-rides-the-PR mechanism has nothing to ride; the version is bumped **by hand** when a release is cut. (Distinct case, grounded in `milestone-driver` `solve-issue` step 6.4, not in this repo's as-a-tool stance: when the feeder **repo itself** is built by `milestone-driver`, that step bumps `plugin.json` on the milestone's first PR, which is the driver's standard behavior, so that run's bump rides that PR.) `.claude-plugin/marketplace.json` carries no `version` field (Claude Code resolves `plugin.json` first). **Release checklist:** bump `plugin.json` first, then re-sync any other hand-maintained in-doc version reference. (The `SPEC.md` as-built header carries no version: `plugin.json` is the single source of truth, so the header has nothing to drift from (resolved in #143).) (Grounded in `docs/architecture.md` Plugin version + Release checklist for the feeder-as-a-tool stance; `milestone-driver` `solve-issue` step 6.4 for the driver-built distinct case; `.claude-plugin/plugin.json`; issue #143.)

## Em-dash ban
The banned mark, the closed set that replaces it, and the two carve-outs.
**Never author U+2014.** Its replacement comes from this CLOSED set and nothing outside it: **PERIOD, SEMICOLON, PAREN PAIR, COLON, COMMA.** A bare hyphen standing between two spaces is not in the set and never satisfies the ban. Rank, strongest to weakest: **PERIOD > SEMICOLON > PAREN PAIR > COLON > COMMA.** A replacement must be at least as strong as the em-dash it replaces, because a weaker mark lets the phrase the em-dash fenced fall into whatever sits beside it. The construction table below picks the mark. The rank breaks a tie where the table admits more than one.

The rank is context-dependent at one point. A SEMICOLON outranks a COMMA only where the surrounding series is ALREADY semicolon-delimited. In a plain comma series with no internal commas, a semicolon lands INSIDE the series as a super-comma and promotes the fenced phrase to a member of it, preserving the defect the recast is removing. There, only a PERIOD or a PAREN PAIR escapes. Worked example: `Background jobs, queues, streams, schedulers` is a plain comma series, closed by an em-dash and then `or "none."`, and the em-dash is what lifts `or "none."` out of the series as a meta-answer about the whole list. Recast that separator to a semicolon and `or "none."` reads as the last alternative IN the list, because `; or` is precisely how a final series alternative is written. Only a PERIOD, giving `. Or "none."`, restores the meta reading. The example names that separator in words rather than reproducing the glyph, because this file is on the scanned surface named under Enforcement below.

| Construction | Mark |
|---|---|
| A fenced ASIDE | PARENTHESES |
| A PIVOT to a contrast or a consequence | PERIOD or SEMICOLON |
| An appositive or trailing qualifier | COMMA, only where the sentence carries no other comma delimiting a series or joining independent clauses at the same level |
| A gloss on what precedes | COLON, only where what follows genuinely introduces, explains, or lists it |
| An ATX heading line | ATTACHED COLON, unconditionally |

**Closing mark.** When a paired em-dash is split into an opening colon or paren, the CLOSING mark is a PERIOD, a SEMICOLON, or a CLOSING PAREN, never a comma. A closing comma ranks below the em-dash it replaces, so the fenced phrase collapses into the nearest series and attaches to the wrong noun or clause. Two corollaries follow. A fenced phrase is an ASIDE only if the sentence still directs the same thing without it, so a METHOD, a required criterion, or a reason is not an aside and parentheses DEMOTE it. A COLON is wrong where what follows is a COORDINATE rather than a gloss, including a colon placed after a list's final item, which re-scopes a statement about the whole list into a gloss on that one item.

**Headings.** Recasting a heading's em-dash CHANGES its GitHub anchor slug: the em-dash sits alone between two spaces, and any attached replacement leaves one space where there were two. Re-pin every inbound reference to that heading in the same change.

**Carve-outs, and only these two.** The first is the plan-file issue heading form and its `[parked ...]` and `[dropped ...]` markers at `docs/plan-file-contract.md (## Plan-file output template)`. The second is the two canonical contract strings pinned at `scripts/check-contract-strings.sh (The two contract strings)`. Both are matched byte-exact rather than read, so whatever separator each carries there is authoritative and is never swept. Changing either is a contract change that re-pins every consumer in the same commit, never a punctuation pass.

**Before recasting a space-hyphen-space, look for a recorded decision.** The v0.13.2 sweep converted em-dashes to hyphens across the repo. Most of those are substitutions this ban requires you to recast, and outside the two carve-outs a bare hyphen never satisfies it. One was pinned as a hyphen on purpose: the issue-author's `Depends on` edge separator, at `CHANGELOG.md (## v0.13.2: prose compression & contract-string fix)`. Neither the mark's shape nor `git log` separates the two, so find the recorded decision before you sweep. `agents/architect.md (description)` is the live specimen to recast, not to copy.

**Enforcement.** This ban's gate is `scripts/check-vocabulary.sh (PATTERN=)`. A gate is a backstop and not the rule, so authors hold the ban directly. The ban does not reach five pathspecs: `CHANGELOG.md`, `tests/**/*observed-*.md`, `docs/specs/**`, `scripts/**`, and `.github/**`. (Grounded in `docs/plan-file-contract.md (## Plan-file output template)`; `scripts/check-contract-strings.sh (The two contract strings)`; `scripts/check-vocabulary.sh (PATTERN=)`; `agents/architect.md (description)`; `CHANGELOG.md (## v0.13.2: prose compression & contract-string fix)` for the one pinned separator; issue #387.)

## Out-of-scope corrections
When a build may step outside its issue's stated file scope.
Step outside an issue's stated file scope or non-goals only to correct a statement that is already false or that this diff makes false, on a line the diff already touches or in a fact the diff derives. A factual correction is NEVER covered by a "punctuation or vocabulary only" non-goal: that non-goal fences the sweep, not the truth of the line being swept. Fix it in the same pass rather than filing it. The one exception: where the correction is true only once a SIBLING issue lands, declare a `Depends on #<n>` edge instead of writing it forward, because a parallel wave can park that sibling and strand an untracked false claim on the integration branch. (Grounded in `agents/issue-author.md (## The contract)` clause 4 for the dependency-edge form; `.project/design-philosophy.md#One-way doors` for the park boundary; issue #387.)
