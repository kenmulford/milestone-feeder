# Brief: gradable scenarios at a lower acceptance cost (milestone-feeder)

**Goal.**
- Scenarios 13, 14 and 17 can reach PASS: every clause in their keys is one a correct run can meet, and every asserted alternate is run.
- An acceptance run tests the models that ship, and costs less because the issue-author stand-ins run on sonnet.

**Source.** `tests/RESULTS.md` `## Run record: 2026-11-21 (#584)`, the #584 grades in `.milestone-config/.runtime/run-584/verdicts.md`, and the m36 subagent transcripts. Verified against `develop` at `b6fecc4` on 2026-11-21.

**Constraints to hold across all items:**
- CI stays green: `scripts/check-contract-strings.sh`, `scripts/check-vocabulary.sh`, `scripts/validate-plugin-structure.py`, and the `build-order-fixtures` job, which also runs the `check-issue-body` fixtures.
- Script changes ship in both twins with byte-identical output, and the bash leg stays bash 3.2 safe, because the feeder runs on Windows hosts without bash and on stock macOS.
- `FILE_WORD_CEILINGS` only go down. A file that grows stays under its current ceiling.
- The issue-body schema stays byte-compatible with the driver's triage.

---

## 1. Acceptance stand-ins run on the model their agent declares

**Evidence:** the m36 runners dispatched 41 issue-author and 8 architect stand-ins as `general-purpose` agents, which inherit the session's opus. `agents/issue-author.md` declares `model: sonnet`. The run graded opus output for a role that ships on sonnet, and the stand-ins were 46% of the m36 acceptance spend.

**Work:**
- `tests/README.md` `## Execution model (preview-only, prose-direct)` step 2: each stand-in dispatch passes the `model` its agent file's frontmatter declares (`agents/architect.md` opus, `agents/issue-author.md` sonnet). The runner and the grader run on the session model, because `plan` runs on the main thread in production.
- `tests/README.md` gains a `## Grader brief (neutral template)` section after `## Runner brief (neutral template)`, carrying the #584 grader brief (`.milestone-config/.runtime/run-584/grader-brief.md`) with its paths made scenario-relative, so the next run reuses a committed brief instead of a scratch one.

## 2. No key compares free text across two runs

**Evidence:** five keys assert byte-for-byte equality between model runs: `12-implied-surfaces` ("Plan behaves **byte-for-byte as today**"), `12b-implied-surfaces-control`, `13-layer-aware-breakdown` (the summary line and the CONTROL alternate), and `14-config-pointers` MUST (d). Two independent runs never produce identical bodies, so these clauses cannot be met. `17-shared-file-ordering`'s byte-for-byte clause binds `scripts/build-order` output (edges and Waves), which is deterministic.

**Work:**
- Rewrite each byte-for-byte clause in 12, 12b, 13 and 14 as a structural assertion: the lines or blocks that clause names are present or absent, and every other MUST in the key still holds. 14 MUST (d) becomes: no `Config pointers:` line, no inlined hex or token value, a `Convention followed:` line citing `src/ui/Button.tsx`, and no error.
- 17's clause stays as written.
- `tests/README.md` states the rule once: a key may assert byte equality only over script output, never over agent-authored text.

## 3. Every asserted alternate has its own input and is run

**Evidence:** the #584 graders split on alternates the run never exercised: 15 graded PASS with one, 13 and 14 graded PARTIAL. 13's and 17's CONTROL alternates need a different `project/`, and none is committed. 14's alternate was built by hand at run time.

**Work:**
- Each asserted alternate gets a committed input at `tests/scenarios/<id>/alternate/project/`: 13 without the layering convention, 14 without `tokens.json` and `design-system.md`, 17 with the disjoint-edits convention the CONTROL clause describes.
- The grader template (item 1) states: a clause the run did not exercise caps the verdict at ⚠️ PARTIAL.
- `tests/README.md` `## Execution model` states that a scenario run includes one runner per committed alternate.

## 4. Fixture inputs match what the keys cite

**Evidence:**
- 13: the architect parked the controllers on "how a request identifies the signed-in user". `brief.md` names a signed-in user, and `project/` states no identity convention. The park was correct, and it removed four of the 10 candidates, leaving MUST (b) and (d) with nothing to grade.
- 14 and 15: the cited files sit under `project/src/`, so the citations read `project/src/ui/Button.tsx` while the keys cite `src/ui/Button.tsx`, and `sourceGlobs: ["src/**"]` matches nothing.
- 17: `feeder-env.md` lists eight existing files (`src/routes/index.ts`, `src/app/modules.ts`, and six more) as exhaustive, and none is on disk. `check-issue-body` then rejects a `Sites searched:` path under `src`, which caused the one 17 retry.

**Work:**
- 13: `project/conventions.md` gains an identity convention: "Every request carries `req.userId`, set upstream by the auth gateway. Controllers read it and never parse a token."
- 14 and 15: move `project/src/` to `src/` at the scenario root.
- 17: add each file `feeder-env.md` lists as existing under `src/` at the scenario root, as a stub carrying the role `feeder-env.md` gives it. `src/jobs/manifest.ts` stays absent, because MUST (d) requires it absent.
- `tests/README.md` `## The one rule that makes the metric honest`: the runner input set becomes `{ brief.md, project/, feeder-env.md }` plus `src/` when the scenario has one.

## 5. An `Edits:` line names a file

**Evidence:** 17 MUST (e) failed because #A's body carries "Edits: none; this issue modifies no existing file.", against `agents/issue-author.md` "A candidate with no `edits` gets no `Edits:` line". The rule is prose, and nothing checks it.

**Work:**
- `scripts/check-issue-body.{sh,ps1}`: an `Edits:` line in `## Design (recorded, consistent)` that names no path fails with `Edits: line names no file: omit the line when the candidate edits no existing file`.
- A fixture under `tests/fixtures/check-issue-body/` for the failing case, and the existing passing fixtures still pass.

## Acceptance run, scoped to the rule

Re-run 13, 14 and 17, each with its committed alternate, blind, per `tests/README.md` after items 1 to 4 land. Record a `## Run record` in `tests/RESULTS.md` against the #584 record. The rule: 13, 14 and 17 grade ✅ PASS, and the record states the run's token use summed per turn from the subagent transcripts, split into runners, stand-ins and graders. Other scenarios are not re-run, because no item here changes a rule they grade.
