# /milestone-feeder:plan preview emit

## Announce (printed before any work)

> Standing by while I turn the brief into a milestone + issues. This is read-only on GitHub: I'll write a reviewable plan file and create nothing on GitHub. Run `/milestone-feeder:create` afterward to deploy the plan.

## Step 0: one-time notices (emitter twins run verbatim, in file order)

| # | Section | Skills | Fired | Why |
|---|---|---|---|---|
| 1 | Self-heal the nested `.milestone-config/.gitignore` | plan | yes (silent) | File absent, so it was created. This unit prints nothing. |
| 2 | Legacy-blanket root `.gitignore` notice | plan | no | The consumer repo has no root `.gitignore`, so the trigger did not hold. |
| 3 | Bootstrap-nudge notice | plan | yes | `.milestone-config/driver.json` is missing and the resolved detect path has no readable files. |
| 4 | Roadmap-routing notice | plan | yes | Marker absent; the notice is otherwise unconditional. |
| 5 | Implied-surfaces notice | plan, update | yes | The overlay `.milestone-config/implied-surfaces.md` is absent and the marker was absent. |
| 6 | md-epic parent notice | create, update | not evaluated | Its Skills field does not include `plan`. |
| 7 | Consumer issue-template notice | plan | yes | Marker absent; the notice is otherwise unconditional. |

### Printed notice output (stdout, verbatim)

```text
🟡 This repo isn't bootstrapped: your plan's grounding will be weak

| What | This repo has no .project/ standing docs and/or no
|      | .milestone-config/driver.json. Without them, plan has no project
|      | constitution to ground issue design on and no driver profile to
|      | resolve shared keys from, so it falls back to thin inferred
|      | conventions and the issues it writes are weaker.
| Fix  | Run milestone-bootstrapper first to scaffold your .project/ docs and
|      | driver profile, then re-run /milestone-feeder:plan. We won't do this
|      | for you and we won't block: config is optional and plan will
|      | continue with best-effort grounding.
| Note | This notice shows at most once per clone.
🟡 New: an oversized brief now routes into a roadmap flow

| What | When you give plan a whole-app brief that spans several
|      | releases, plan now hands it to a roadmap step first: it
|      | proposes a sequenced set of milestones and asks you to
|      | confirm, merge, split, reorder, or reject the split before
|      | it plans any single milestone.
| When | Only when the brief reads as several milestones. A normal,
|      | single-release brief is unchanged: no roadmap step, no
|      | extra prompt.
| Note | This notice shows at most once per clone.
🟡 Optional: add project-specific implied surfaces

| What | You can add an optional overlay file at
|      | .milestone-config/implied-surfaces.md. The architect reads it
|      | alongside the plugin's bundled implied-surfaces reference when it
|      | breaks your brief into issues.
| Why  | The bundled reference is universal, so it can't carry capability
|      | clusters specific to your domain (a church app's "giving", say).
|      | Your overlay merges in additively: it can add a new capability
|      | and extend an existing one, but never removes a surface the
|      | bundled reference already defines.
| How  | Create .milestone-config/implied-surfaces.md and write one
|      | capability per ## heading with its implied surfaces beneath, the
|      | same shape as the bundled reference. Leave it out and the bundled
|      | reference is used as-is; an absent overlay is never an error.
| Note | This notice shows at most once per clone.
🟡 New: plan now adopts your repo's issue template

| What | plan now authors each issue to your repo's own issue template
|      | instead of its own built-in structure. It uses the template your
|      | driver config records as agentIssueTemplate; with no such key, the
|      | single template under .github/ISSUE_TEMPLATE/ (the reserved
|      | config.yml is not counted, so bug.yml + config.yml counts as one).
|      | No key and no single template keeps the built-in structure.
| When | Every plan run. The built-in structure authors four sections:
|      | Summary, Acceptance criteria, Design (recorded, consistent),
|      | and Dependencies, plus Non-goals when the issue records a scope
|      | boundary.
| Note | This notice shows once per clone, and again after an upgrade
|      | that revises it.
```

🔴 Notice 3 printed the path `.project/`, not the `project/` this run planned against. The emitter resolves `projectDocs` from `.milestone-config/feeder.json`, which is absent on disk, so it fell back to its documented `.project/` default. The notice still fires correctly on its `driver.json`-missing limb.

## Run status

| Step | Outcome |
|---|---|
| 0 (outer boundary) | Config read best-effort; notices run; grounding digest, merged implied-surfaces reference, consumer issue-template, and shared keys resolved once. |
| 1 Ingest brief | `file:brief.md`, normalized. No `epicIssueNumber`, no `Milestone:` line. |
| 2 Product-gap check | No product gap. No STOP. |
| 3 Architect (dispatched once) | 1 candidate, `EDGES` `[]`, 1 Wave, `PRODUCT_GAPS` none, `SCOPE_SPANS_MULTIPLE_MILESTONES` none, `INVARIANTS` none. |
| 3.5 Pre-park | Nothing to pre-park (no gap names a candidate). |
| 3.6 Front-door | Signal `none` → no route. `roadmapRouteTaken` = false. |
| 3.7 Roadmap fan-out | Skipped (`roadmapRouteTaken` false). |
| 4 Issue-author (1 dispatch) | `#A` returned `STATUS: AUTHORED`, wrapper well-formed on the first attempt. No retry. |
| 5 Graph + description | Surviving set `{#A}`. Nothing parked, nothing dropped. Wave 1 (parallel): #A. |
| 5.1 Version ladder | 🔴 Unresolved. See below. |
| 7 Plan file | Written to `.milestone-feeder/plan-add-a-paginated-activity-log-list-to-the-account-area.md`. |

## Step 7: surfaced for confirm or override before `create`

| Field | Value |
|---|---|
| Milestone title (exact) | 🔴 UNRESOLVED. Nothing invented. |
| Version provenance | 🔴 UNRESOLVED (rung 4 prompt). |

🔴 **The version ladder could not resolve a milestone title, and this run did not invent one.** Every rung was run and every rung came up empty:

| Rung | Source | Result in this run |
|---|---|---|
| 1 Explicit | The `milestoneLine` captured at Step 1 | No `Milestone: <name> vX.Y.Z` line in the brief, and no inline statement. No match. |
| 2 Declaration | `versioning` in `.milestone-config/feeder.json` | The file is absent, so the key is absent. Treated as absent. Continue to rung 3. |
| 3 Infer (a) | Highest semver among existing milestone titles, read-only `gh api` | `gh api repos/{owner}/{repo}/milestones` returned `unable to expand placeholder in path: failed to run git: fatal: not a git repository`. No repo context, no signal. |
| 3 Infer (b) | Latest `vX.Y.Z` git tag | `git tag --list 'v*'` returned `fatal: not a git repository`. No signal. |
| 4 Prompt | The one sanctioned interactive moment | **Cannot run.** This run is non-interactive and no human is available to answer. Recorded as a limitation, never filled with a guess. |

Type the exact title, with its semver inside the string, on the `Milestone title (exact):` line of the plan file, and set `Version provenance:` to `explicit`, before running `create`.

## Surfaces deliberately NOT printed

| Surface | Condition | This run |
|---|---|---|
| Multi-milestone advisory | Architect raised `SCOPE_SPANS_MULTIPLE_MILESTONES` AND `roadmapRouteTaken` is false | Signal is `none`, so nothing is surfaced and the plan file omits the section entirely. |
| Implied-surfaces review prompt (`this is a starting set for YOUR app — what's missing?`) | One or more surviving candidates carry `disposition: implied` | No candidate is implied, so nothing is surfaced and no `[implied — review / trim / augment]` marker is rendered. |
| Needs-product-input report | `productGaps[]` non-empty | Empty. No report was written; the plan file's `## Needs human input` reads `none`. |

## Recorded limitations of this preview run

| Limitation | Effect |
|---|---|
| `.milestone-config/feeder.json` is absent | Step 0 would auto-invoke `milestone-feeder:setup`, an interactive bootstrap. No human was available, so setup did not run. The feeder own-keys took their bundled defaults, with `projectDocs` = `project/` per the run environment. |
| No driver config on disk | The three shared keys came from the run environment's declared values: `sourceGlobs` `["src/**"]`, `uiSurfaceGlobs` absent, `integrationBranch` `"develop"`. |
| `uiSurfaceGlobs` absent | `plan` draws no UI-vs-logic design-lens distinction. Recorded in the plan file's grounding section. The issue-author still classified `#A` on the issue's own facts under its own clause 5 and returned `LABELS: [ui, risk:heavy]`; `plan` records what the author returned and regenerates nothing. |
| No `.github/ISSUE_TEMPLATE/`, no `agentIssueTemplate` | Rung 3 of the four-rung template selection: nothing resolved. The issue-author authored to the built-in §4 template. Never blocking. |
| No `src/` on disk | The sibling `src/lists/ActivityListService.ts` that `project/conventions.md#Lists` names could not be grep-verified, so both agents cited the convention section that names it rather than an unverifiable `file:line`. |
| Zero GitHub writes | No milestone, no issue, no label, no comment. The run's entire output is local scratch. |

---
Plan file: `.milestone-feeder/plan-add-a-paginated-activity-log-list-to-the-account-area.md`
Needs-product-input report: not produced (no product gap).
