# /milestone-feeder:plan - preview emit

## Announce first

> Standing by while I turn the brief into a milestone + issues. This is read-only on GitHub: I'll write a reviewable plan file and create nothing on GitHub. Run `/milestone-feeder:create` afterward to deploy the plan.

## Step 0: one-time notices (`docs/one-time-notices.md`, iterated in file order)

| # | Section | Skills | Triggered | Outcome |
|---|---|---|---|---|
| 1 | Self-heal the nested `.milestone-config/.gitignore` | plan | Yes (file absent) | 🔴 Write SUPPRESSED: preview run, no write into the consumer repo. See "Recorded limitations". |
| 2 | Legacy-blanket root `.gitignore` notice | plan | No (no root `.gitignore`) | Silent, as specified. |
| 3 | Bootstrap-nudge notice | plan | Yes (`.milestone-config/driver.json` missing) | Printed below. Marker write SUPPRESSED. |
| 4 | Roadmap-routing notice | plan | Yes (marker absent) | Printed below. Marker write SUPPRESSED. |
| 5 | Implied-surfaces notice | plan, update | Yes (overlay absent, marker absent) | Printed below. Marker write SUPPRESSED. |
| 6 | md-epic parent notice | create, update | n/a | Never evaluated by `plan`. |
| 7 | Consumer issue-template notice | plan | Yes (marker absent) | Printed below. Marker write SUPPRESSED. |

Emitted text, byte-exact from each section's recorded bash emitter twin:

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
```

```text
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
```

```text
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
```

```text
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

Note on the bootstrap-nudge text: its emitter resolves `projectDocs` in-block from `.milestone-config/feeder.json`, which does not exist on disk here, so it prints the `.project/` fallback. The run's resolved `projectDocs` is `project/`, taken from the run's declared preview config.

## Step 0: resolved inputs

| Input | Resolved to | Source |
|---|---|---|
| `projectDocs` | `project/` | Run's declared preview config (no `feeder.json` on disk) |
| `architectAgent` | `milestone-feeder:architect` (proxied) | Default |
| `issueAuthorAgent` | `milestone-feeder:issue-author` (proxied) | Default |
| `issueSize` | unset → ~1 PR each, independently buildable | Default |
| Grounding digest | 2 slices: `project/conventions.md#Lists`, `project/conventions.md#Test patterns` | `project/conventions.md` |
| Global implied-surfaces reference | `${CLAUDE_PLUGIN_ROOT}/docs/implied-surfaces.md` | Plugin-bundled |
| Project-local overlay | Absent → merged reference equals global | `.milestone-config/implied-surfaces.md` not present |
| Consumer issue-template | Rung 3: nothing resolved → built-in §4 default | No `agentIssueTemplate`, no `.github/ISSUE_TEMPLATE/` |
| `sourceGlobs` | `["src/**"]` | Run's declared driver keys |
| `uiSurfaceGlobs` | ABSENT → every candidate treated as `logic` | Run's declared driver keys |
| `integrationBranch` | `develop` | Run's declared driver keys |

## Steps 1-5: run trace

| Step | Outcome |
|---|---|
| 1 Ingest | Form: file. `epicIssueNumber` omitted, `milestoneLine` omitted. |
| 2 Product-gap check | No product gap. No STOP. |
| 3 Architect (1 dispatch) | 1 candidate (#A), `EDGES: []`, `PRODUCT_GAPS: none`, `SCOPE_SPANS_MULTIPLE_MILESTONES: none`, `INVARIANTS: none`. No `disposition`, no `layer`. |
| 3.5 Pre-park | Nothing to pre-park (no gap names a candidate). |
| 3.6 Front-door | Signal `none` → no route. `roadmapRouteTaken = false`. |
| 3.7 Fan-out | SKIPPED (`roadmapRouteTaken` false). |
| 4 Issue-author (1 dispatch) | `STATUS: AUTHORED`. Verify passed on first attempt; no retry. Invariant substring test is a no-op (empty list handed in). |
| 5 Graph + description | Surviving set = {#A}. 0 parked, 0 dropped. `Wave 1 (parallel): #A`. |
| 5.1 Version ladder | Rung 1 no, rung 2 no, rung 3 no, rung 4 unavailable → 🔴 unresolved. |
| 7 Plan file | Written. No needs-product-input report (`productGaps[]` empty). |

## Step 7: surfaced identity, confirm or override before `create`

🔴 **The milestone identity did not resolve, and was not fabricated.**

| Field | Value |
|---|---|
| Milestone title (exact) | 🔴 UNRESOLVED |
| Version provenance | 🔴 UNRESOLVED |

The Step 5.1 ladder ran every rung it could:

| Rung | Source | Result |
|---|---|---|
| 1 Explicit | `milestoneLine` from Step 1 | No `Milestone:` line in the brief, no inline statement. |
| 2 Declaration | `versioning` in `.milestone-config/feeder.json` | File absent → treated as absent → continue. |
| 3 Infer | Highest semver among existing milestone titles, else latest `vX.Y.Z` git tag | `gh` unavailable and no network → no milestone read. No `.git` in the repo → no tag read. Neither signal yielded anything. |
| 4 Prompt | The one sanctioned interactive moment | 🔴 No human available in this run. Not asked, not answered, not guessed. |

🔴 Resolve `Milestone title (exact)` and `Version provenance` in the plan file before running `create`. `create` resolves the milestone by that exact string.

## Multi-milestone advisory

Not surfaced. `SCOPE_SPANS_MULTIPLE_MILESTONES` is `none`, so nothing is emitted here.

## Implied-surfaces review prompt

Not surfaced. No surviving candidate carries `disposition: implied`, so no anti-fixation prompt and no marker.

## Written artifacts

| Artifact | Canonical path the procedure would write | This run wrote it to |
|---|---|---|
| Plan file | `.milestone-feeder/plan-add-a-paginated-activity-log-list-to-the-account-area.md` | `/private/tmp/app-run-out-7f3a2c/plan-file.md` |
| Needs-product-input report | `.milestone-feeder/needs-product-input-<slug>.md` | Not produced: `productGaps[]` is empty. |

GitHub writes this run: **zero**. Milestones created: 0. Issues opened: 0. Labels applied: 0. Comments posted: 0.

## Recorded limitations

| # | Where | Limitation |
|---|---|---|
| 1 | Step 0 | `.milestone-config/feeder.json` is absent. The procedure says absent → invoke `milestone-feeder:setup`. `setup` is an interactive first-run bootstrap and no human is available, so it was not run. The run proceeded on the preview config the run environment declares (`projectDocs: project/`, driver shared keys as listed above). No profile was written and no value was invented. |
| 2 | Step 0 | The section-1 self-heal would create `.milestone-config/.gitignore`, and sections 3, 4, 5, and 7 would each write a marker under `.milestone-config/.runtime/`. All five writes were SUPPRESSED: this is a preview run and its artifacts are redirected outside the consumer repo. Each notice's trigger check ran for real against live repo state, and the printed text above is the emitters' own output, so it is byte-exact. Consequence: on a real run these notices would not fire a second time; here they would. |
| 3 | Step 0 | No driver config exists on disk (`.milestone-config/driver.json` and root `milestone-driver.json` both absent), so the shared keys came from the run's declared preview config rather than a resolved file. `uiSurfaceGlobs` is genuinely absent either way, so its documented degradation is in force. |
| 4 | Step 5.1 | The version ladder could not resolve. `gh` is unavailable and there is no network (rung 3, milestone titles); the consumer repo has no `.git` (rung 3, tags); no human is available (rung 4). The title and provenance fields carry an explicit unresolved marker instead of a fabricated value. |
| 5 | Step 7 | The plan file was written to the run's output directory instead of `.milestone-feeder/plan-<slug>.md`, so the scratch-dir self-ignore step (`mkdir -p .milestone-feeder` plus a `*` `.gitignore`) did not run against the consumer repo. The slug was still derived deterministically from the one-line goal and is recorded above. |
| 6 | Steps 3, 4 | Both agents were dispatched as `general-purpose` proxies, briefed to read their contract file in full and follow it exactly, because the registered `milestone-feeder:*` agent types resolve against an older installed build. Each was additionally required to return an itemized path list, which its contract's "return only the block" rule would otherwise forbid. That is the one bounded deviation from each agent contract. |
