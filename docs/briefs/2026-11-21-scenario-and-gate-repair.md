# Brief: repair the scenarios and close the v1.2.0 gate gaps (milestone-feeder)

**Goal.**
- Every scenario key grades the feeder rule it names, so a FAIL means the feeder failed.
- The v1.2.0 scripts check the cases they skip today.
- The six scenarios that stay below PASS on v1.2.0 (03, 10, 13, 14, 15, 17) and the 06 regression each get one fix.

**Source.** `tests/RESULTS.md` `## Run record: 2026-11-21 (#564)`, the #564 grades, and the PR #567 reviews. Verified against `develop` at `2feb107` on 2026-11-21.

**Constraints to hold across all items:**
- CI stays green: `scripts/check-contract-strings.sh`, `scripts/check-vocabulary.sh`, `scripts/validate-plugin-structure.py`, and the `build-order-fixtures` job, which also runs the `check-issue-body` fixtures.
- Script changes ship in both twins with byte-identical output, and the bash leg stays bash 3.2 safe, because the feeder runs on Windows hosts without bash and on stock macOS.
- `FILE_WORD_CEILINGS` only go down. A file that grows stays under its current ceiling.
- The issue-body schema stays byte-compatible with the driver's triage.

---

## 1. Scenario keys and fixtures that grade the rule they name

**Evidence:** five scenarios fail or are PARTIAL because of their own inputs, not the feeder:
- `03-design-resolvable-no-park`: `brief.md` puts "notification toggles" in scope, and nothing in the input names the toggle set. The run can only invent the toggles (a FAIL-if clause) or park them (which breaks the no-park MUST).
- `10-nested-layout`: the brief asks for a banner that "polls that endpoint", and `project/conventions.md` states no interval. The architect parks the interval, and the key requires zero parks.
- `14-config-pointers` and `15-prose-style`: the keys expect citations of `src/ui/Button.tsx` and `src/lists/ActivityListService.ts`, and neither fixture has a `src/`. The grep-before-cite rule then forbids the citation. This is also the cause of 5 of the 7 #564 retries.
- `17-shared-file-ordering`: the key fixes a full Wave order and "#A and #E parallel in Wave 1". That holds only for one candidate cut, while the shared-file mechanism under test passed every clause.

**Work:**
- 03: the brief names the toggle set: "email on a new sign-in, email on a password change, weekly summary email".
- 10: `project/conventions.md` states the polling convention: "Status endpoints are polled every 5 s by the shared `usePoll()` hook."
- 14 and 15: add each cited file under `project/src/`, with the declaration the key cites.
- 17: the key grades the `after` edges `scripts/build-order` derives for the cut the run produces, and the Waves those edges imply. It no longer fixes a full Wave order.

**Acceptance:** each of the five keys names only clauses an input makes satisfiable.

## 2. An implied candidate that spans layers is split by layer

**Evidence:** `agents/architect.md` clause 9 assigns one `layer` per candidate and says nothing about a candidate whose work crosses stated layers. In scenario 13 the implied get-by-id #F crosses four layers and survives with no `layer` and no `Layer:` line, on both the baseline and #564.

**Work:** clause 9 says that when the project states a layering convention, a candidate whose work crosses stated layers is split into one candidate per layer, joined by layer edges. This matches how the key's five main candidates are cut.

**Acceptance:** scenario 13 grades PASS.

## 3. A handed-in invariant is an acceptance criterion, and the script checks where it sits

**Evidence:**
- Scenario 06 requires every page issue to carry the full directive in its acceptance criteria. On #564, `DataTable` reuse was in all 10 Design sections but missing from 4 of 10 acceptance criteria.
- `agents/issue-author.md` tells the author to "record it once" with no section named.
- `scripts/check-issue-body` `--invariants` passes a value found anywhere in the body.

**Work:**
- `agents/issue-author.md` records each handed-in invariant `value` verbatim as an `## Acceptance criteria` line. A Design section can restate it. Reason: the driver verifies acceptance criteria.
- `scripts/check-issue-body.{sh,ps1}` `--invariants` requires each value under `## Acceptance criteria` when the body has that heading, and anywhere in the body otherwise.
- Add fixtures for a value found only in Design (exit 1) and a value under Acceptance criteria (exit 0).

**Acceptance:** scenario 06 grades 10/10 on its metric.

## 4. The drop pass drops real dependents only

**Evidence:**
- `skills/plan/SKILL.md` Step 5 says "the walk covers `EDGES` plus the Step 3.5 `after` edges". An `after` edge only orders two candidates that edit the same file. A candidate that shares a file with a parked one is therefore dropped, though it is buildable.
- Walking `EDGES` alone, which a PR #567 reviewer proposed, would leave the survivor's body with the `Depends on #<parked tag> - <shared path list>` line that `agents/issue-author.md` clause 4 writes for an `after` edge.

**Work:**
- The Step 5 walk covers `EDGES` only.
- For each survivor, `plan` deletes every `Depends on #<tag>` line in `## Dependencies` whose tag is parked or dropped. Reason: a `depends_on` edge to a parked tag would have dropped the survivor, so any such line left is an `after` line.
- The clause 4 re-run over the survivors supplies the Waves, as it does today.

**Acceptance:**
- Scenario 17's brief adds one in-scope item that edits a file a pre-parked candidate also edits, with no `depends_on` edge between them. No scenario exercises this case today: 17's #H is dropped for a real dependency on parked #I. The key requires the new candidate to survive with no `Depends on` line naming the parked tag.
- No survivor body names a parked or dropped tag.

## 5. The section check runs on every body

**Evidence:** `skills/plan/SKILL.md` Step 4 passes `--sections <file>` "only when a template resolved". Without it, each `check-issue-body` twin falls back to its own hard-coded list of the four required SPEC §4 headings: `## Summary`, `## Acceptance criteria`, `## Design (recorded, consistent)`, `## Dependencies`. `## Non-goals` is optional, because SPEC §4 omits it "when the issue records no scope boundary". The list has three copies (SPEC and both twins), and nothing fails when they drift.

**Work:**
- Ship `scripts/issue-body-sections.txt` with those four required headings, one per line.
- Step 4 passes it as `--sections` when no consumer template resolves.
- `scripts/check-contract-strings.sh` fails when the file, the SPEC §4 required headings, and either twin's built-in list differ.

**Acceptance:**
- A default-template body that lacks `## Dependencies` makes `check-issue-body` exit 1 with `--sections scripts/issue-body-sections.txt`.
- A body that omits `## Non-goals` passes.
- Editing one twin's built-in list fails `scripts/check-contract-strings.sh`.

## 6. remediate checks the body it writes

**Evidence:** `skills/remediate/SKILL.md` verifies only "that each superseded span is gone" before `apply-body`. A corrected body can carry an unresolved citation or a missing section that `plan` Step 4 would have caught.

**Work:**
- `remediate` runs `scripts/check-issue-body.{sh,ps1}` on the corrected body before `apply-body`, with item 5's sections file or the resolved consumer template, and no `--invariants`.
- Exit 1 re-dispatches the remediator once with the printed findings verbatim. A second exit 1 takes the existing `NEEDS_HUMAN` park path.
- Exit 2 stops the run and reports the stderr line.

**Acceptance:** a corrected body with an anchor that matches no line never reaches `apply-body`.

## 7. CI rejects a path Windows cannot check out

**Evidence:** PR #567's Windows jobs failed at checkout on `tests/fixtures/check-issue-body/*/src/nul.bin`, because `NUL` is a reserved device name. Ubuntu CI passed, and milestone granularity pushes once, so the first Windows run was at milestone end.

**Work:** `scripts/validate-plugin-structure.py` fails on any tracked path with a reserved basename (`CON`, `PRN`, `AUX`, `NUL`, `COM1`-`COM9`, `LPT1`-`LPT9`, any case, with or without an extension), a character from `<>:"|?*`, or a component that ends in a space or a dot.

**Acceptance:** a tracked `src/nul.bin` fails the check, and the tree as merged passes it.

---

## Acceptance run, scoped to the rule

Re-run scenarios 03, 06, 10, 13, 14, 15 and 17 once each, blind, and record them in `tests/RESULTS.md` against the #564 record. The other scenarios grade rules this brief does not touch. Estimate: about 1.8M subagent tokens, from the #564 runner-plus-grader cost of those seven.

The rule: none of the seven grades worse than #564, and each of 03, 10, 13, 14, 15 and 17 grades PASS.

---

## 8. The check reads `## Dependencies` against the handed edges

**Evidence:** `scripts/check-issue-body` runs six stages (sections, invariants, citations, sites searched, vocabulary, platform source), and none reads `## Dependencies`. On this brief's own plan run, #E's body listed three edges of other issues (`#F depends_on #E`, `#H depends_on #E`, `#D after #E`) under its own `## Dependencies` and exited 0. The driver's triage reads each line there as an edge of that issue.

**Work:**
- `scripts/check-issue-body.{sh,ps1}` gains `--edges <file>`: one tag this issue depends on per line (`#A`), from the `EDGES` and `after` edges whose first tag is this issue. An empty file means the issue depends on nothing.
- With `--edges`, the stage requires one `Depends on #<tag>` line under `## Dependencies` for each listed tag, and fails on a `Depends on` line for an unlisted tag and on any other line in that section that names a `#<tag>`.
- `skills/plan/SKILL.md` Step 4 writes `check-<tag>-edges.txt` and passes it on every check. `remediate` passes no `--edges`, because it has no handed edges.
- Fixtures: an unlisted tag exits 1, a listed tag with no line exits 1, a downstream edge written as `#F depends_on #E` exits 1, and the matching set exits 0.

**Acceptance:** the #E body from this plan run, checked with an empty `--edges` file, exits 1.

## 9. The `Sites searched:` pattern holds no backtick

**Evidence:** `agents/issue-author.md` clause 3 puts the search in one code span. On this brief's plan run, 2 of 8 first returns (#B, #D) put a backtick inside the grep pattern, so the span closed early and `check-issue-body` read a truncated command. Both took a retry.

**Work:** clause 3 and the `Sites searched:` line in the Output format say the pattern holds no backtick, because a backtick closes the code span.

**Acceptance:** a body whose `Sites searched:` pattern holds a backtick still exits 1, and the rule is stated in both places.

## 10. `plan` saves the architect's return

**Evidence:** `skills/plan/SKILL.md` Step 3 captures the architect's return block in the run's context only. On this brief's plan run, the context compacted between Step 3 and Step 4, and the return had to be recovered from the session transcript.

**Work:** Step 3 writes the return block byte for byte to `.milestone-feeder/architect-<slug>.md` before Step 3.5. A full dispatch overwrites the file, and an incremental dispatch appends its return under `## Incremental dispatch <n>`. A run that resumes after compaction reads the file instead of re-dispatching.

**Acceptance:** after Step 3 the file holds the return byte for byte, and Step 4's candidate fields match it.
