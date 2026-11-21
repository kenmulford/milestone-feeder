# Brief: file a verified bug (milestone-feeder)

**Goal.** A bug found in UAT and verified becomes one ready-to-build issue in an existing milestone in under 5 minutes. It goes through the same issue-author contract `plan` uses, without the architect, a plan file, or `create`.

**Why.** The feeder is the project's PM. `plan` breaks a brief down into work packages, and the issue-author writes each package to the Definition of Ready that the driver's triage checks. A verified bug is already a work package, so breaking it down again buys nothing. Today such bugs skip the feeder and are filed by hand, so they also skip the Definition of Ready. All 21 issues in ios-budget-app milestone 99 were filed by hand. Its sweeps (#1759, #1760, #1761) took 3 to 4 review rounds each, because their site lists and replacement APIs were only found during the build.

**Measured** from subagent transcripts, 2026-10-27 to 2026-11-17: the architect's median run is 10.7 min (n=15) and the issue-author's is 1.2 min (n=324). For a bug, one issue-author run is the part worth keeping.

Verified against `develop` at `6ef4514` on 2026-11-21.

**Constraints to hold across all items:**
- CI stays green: `scripts/check-contract-strings.sh`, `scripts/check-vocabulary.sh`, `scripts/validate-plugin-structure.py`.
- `skills/file/SKILL.md` enters `FILE_WORD_CEILINGS` at its as-authored word count times 1.05, rounded up to the next 50. This is how #343 pinned `skills/remediate/SKILL.md`. The `agents/issue-author.md` ceiling rises only by measured growth, recorded with the issue number.
- No em dash in new text.
- On Codex, the new skill reads `skills/runtime-codex.md` first, like every other skill.

---

## 1. `/milestone-feeder:file`

**Evidence:** `skills/plan/SKILL.md` Step 3 always dispatches the architect, Step 7 always writes a plan file, and only `create` writes to GitHub. `skills/remediate/SKILL.md` already has the single-issue shape: one agent run, one bounded retry, mechanical checks, then one write.

**Work:** add `skills/file/SKILL.md`. Its steps:

- **Arguments.** The bug report as text: what was seen, on which device and in which state, the steps to reproduce, and what was expected. Plus an optional `--milestone "<title>"`.
  - Without `--milestone`, if exactly one milestone is open, use it. UAT bugs belong to the milestone under test.
  - If several are open, ask once and list them.
- **Step 0: read config.**
  - If `feeder.json` is absent, invoke `setup`, as `remediate` Step 0 does.
  - Resolve `projectDocs`. From the driver config, resolve `sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`, `nonNegotiables` and `domainSkills`.
  - Apply `plan` Step 0's grounding-root rule: a dirty tree grounds on a fresh worktree of `integrationBranch`, since implementers may be building in the checkout.
  - Assemble no digest. Hand over the `projectDocs` root, as `remediate` does.
- **Step 1: author the issue.**
  - Dispatch `milestone-feeder:issue-author` once, in `mode: bug`, with a one-candidate brief: tag `#A`, the report verbatim as the sketch, and no edges or invariants. `nonNegotiables` and `domainSkills` are handed in as item 2 describes.
  - A malformed return gets one re-dispatch, under `plan`'s "Per-dispatch verify + one bounded retry" rule.
- **Step 2: verify mechanically before writing.** Run `scripts/check-issue-body.{sh,ps1} <body-file> <grounding-root> --mode bug` (`docs/briefs/2026-11-21-fixed-contract-free-content.md` item 3). It covers citations, `Sites searched:`, banned vocabulary and the `Platform source:` line.
  - A failed check gets one re-dispatch, briefed with the check that failed. If it still fails, stop and write nothing.
- **`STATUS: PRODUCT_GAP`:** write nothing and print the gap as one 🔴 line. The rerun carries the answer in the report.
- **Step 3: write the issue.**
  - Use `scripts/deploy-write-sequence.{sh,ps1} create-issues <job-file>` with one issue and `adopt: true`, so a rerun with the same title reuses the issue instead of filing a duplicate.
  - Labels: the issue-author's `LABELS`, plus GitHub's default `bug` label.
  - Leave the milestone description alone. Triage rebuilds the Waves from each issue's own edges (milestone-driver `skills/triage/SKILL.md`, "Rebuild `dependencyGraph.waves`"), and driver 1.31.0 built milestone 99's hand-filed issues that way.
- **Report:** one line with the issue URL, the convention it names, and the number of sites.

**Acceptance:**
- On this repo, `/milestone-feeder:file "<one-paragraph report>"` files one issue in under 5 minutes of wall-clock time.
- `/milestone-driver:triage <n>` on that issue returns `GAPS: none`.
- A rerun with the same report creates no second issue.

## 2. issue-author: bug mode and framework conformance

**Evidence:**
- `Convention followed:` (`agents/issue-author.md` Rigor gate) can only cite `.project/` or existing app code.
- Site coverage (`agents/issue-author.md` clause 3) is required only when a change makes behavior conditional, renames a symbol, or changes a contract.
- A grep of `agents`, `skills` and `docs` for `nonNegotiables` and `domainSkills` returns nothing, while the driver's `agents/triage-reviewer.md` and `agents/planner.md` read both keys.

**Work:** in `agents/issue-author.md`:

- **New inputs.** It receives `nonNegotiables` and `domainSkills`, and invokes each `domainSkills` name with the Skill tool before any read, as the driver's planner does (milestone-driver `agents/planner.md`, "First, always"). Framework conventions then come from the skills, not from memory.
- **The stack is detected, never assumed from config.** The issue-author names the platform and framework with their versions in this order:
  1. `.project/library-manifest.md#Runtime & frameworks`, which the bootstrapper writes.
  2. Otherwise, the repo's manifest files: `Package.swift` or `*.xcodeproj`, `package.json`, `*.csproj`, `pyproject.toml`, `Gemfile`.

  An empty `domainSkills` list does not switch the framework rules off. `domainSkills` is project-specific and reactive: a project adds a skill when its own work shows the need (Ken, 2026-11-21), so an empty list is the normal case.
- **Doc source for the detected framework:**
  1. `domainSkills` when it lists any.
  2. Otherwise the framework vendor's own documentation, through a doc tool the session has (Xcode `DocumentationSearch`, Microsoft Learn), or else a web search limited to the vendor's domain.
- **Grounding order for `Convention followed:`** is the default for every project, whatever the config says. A project departs from it only through a recorded `nonNegotiables` entry or a `.project/` decision that names the departure:
  1. The detected framework, through the doc source above.
  2. `nonNegotiables`.
  3. `projectDocs`.
  4. Existing app code.

  Existing code that contradicts the framework is recorded as a site to fix, never as the pattern to mirror.
- **`Platform source:` line.** Every ui issue and every bug-mode issue gets this Design line. It names the framework doc that states the convention, quotes the documented behavior, and names the API that implements it. In bug mode, the convention is the one the bug breaks. With no doc found, the line reads `Platform source: none found: <what was searched>`.
- **Non-negotiables.** Every non-negotiable that the issue's sites touch is quoted verbatim in the Design section, the way invariants are.
- **Site coverage.** Clause 3's trigger list gains "fixes or enforces a convention or a non-negotiable". The `Sites searched:` pattern searches for the convention's API and every way code can bypass it, not for the reported symptom. A sweep's work package covers 100% of its sites. #1759's grep searched for the symptom's form and missed sites.
- **Bug mode.**
  - The Summary states what was seen, where (device, size class or pose), and the convention broken.
  - The acceptance criteria are: the reported repro passes on the named device, every site in `Sites searched:` conforms, and the four states are covered as today.
- **Layout variants.** A ui issue's Design section lists the layout variants that the consumer's project docs name, with each variant's behavior. For ios-budget-app these are compact and regular width, portrait and landscape, and sidebar or inspector shown. A project whose docs name no variants gets no line.

**Acceptance:**
- The Output format and the Rigor gate carry `Platform source:`, the new trigger, and the bug-mode criteria.
- `scripts/check-contract-strings.sh` exits 0.

## 3. `plan` passes the same two keys

**Evidence:** `skills/plan/SKILL.md` Step 0 states "The shared keys are exactly three". `SPEC.md` §7 and `docs/profile-schema.md` §2 say the same.

**Work:**
- `skills/plan/SKILL.md` Step 0 also resolves `nonNegotiables` and `domainSkills` from the driver config and passes them to the architect and the issue-author. `plan` and `file` author through one issue-author contract, so they hand it the same inputs.
- `agents/architect.md` clause 10 records a non-negotiable that binds two or more candidates as an `INVARIANTS` entry.
- `SPEC.md` §7, `docs/profile-schema.md` §2 and `docs/step-0-grounding.md` state that the feeder reads five driver keys and writes none. An absent key degrades to a no-op, under the shared Step-0 contract.

**Acceptance:**
- `grep -rn "exactly three" SPEC.md docs skills` prints nothing.
- `python3 scripts/validate-plugin-structure.py` exits 0.

## Driver side (milestone-driver repo, handed to the driver session)

- `agents/triage-reviewer.md` criterion 3 gains the same convention trigger, in the same release as item 2. The issue-author contract mirrors triage criterion for criterion (`agents/issue-author.md`, "The contract").
- Triage treats a missing `Platform source:` line on a ui or bug issue as a Blocker. Without that check, an issue filed by hand skips the framework check entirely.
- `skills/setup/SKILL.md` drops its "Inferred domainSkills candidate" table (MAUI, Angular, plugin-dev) and stops offering an inferred value. `domainSkills` is project-specific and reactive (Ken, 2026-11-21). Setup asks for the key with an empty default.

## Open, and fenced

- `plan`'s own run time. In 10 plans measured from 2026-11-03 to 2026-11-17, no plan re-ran its architect. A plan takes 19 to 94 minutes from the plan call to `create`. Agent time is 11 to 86 minutes: one serial architect (8.5 to 21 minutes), then issue-authors capped at 4 in flight (Step 4, "cap W = 4"), so 67 candidates took 22 minutes. Most of the rest is time waiting at the designed human gate before `create`. Raising W is the one lever on large plans, and it would need its own brief.
