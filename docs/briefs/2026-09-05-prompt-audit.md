# Brief: prompt-audit remediation (milestone-feeder)

**Goal.** Remove text written for older models from the prompt surface (`skills/`, `agents/`, the `docs/` files skills load): migration-relative phrasing, refactor notes, and the emphasis register. Cruft is not length: no load-bearing instruction is shortened, and `skills/plan/SKILL.md` keeps its accepted size. Target models: Opus 5 (main thread, `model: opus` agents), Sonnet 5 (`model: sonnet` agents). Counts below measured 2026-09-05.

**Constraints to hold across all items:**
- CI stays green on every commit: `scripts/check-contract-strings.sh` (the two byte-exact contract strings and the presence rows in `agents/architect.md` and `agents/issue-author.md` survive verbatim), `scripts/check-vocabulary.sh` (no em dash U+2014, no retired token), `scripts/validate-plugin-structure.py` (`FILE_WORD_CEILINGS`, `AGENT_DESCRIPTION_WORD_CEILING` 150).
- Keep list, never edited under this brief: caps protocol literals (`PRODUCT_GAP`, `PRODUCT_GAPS`, `CANDIDATES`, `EDGES`, `WAVES`, `INVARIANTS`, `SCOPE_SPANS_MULTIPLE_MILESTONES`, `STATUS`, `NEEDS_HUMAN`, `ALREADY_APPLIED`, `ISSUE_BODY`, `CORRECTED_BODY`, `ROADMAP`, `LABELS`, `ISSUE_TAG`, `[TBD]`, HTTP verbs, environment variables, any value a table column enumerates); numbered step choreography; fenced code blocks; `<example>` blocks inside agent bodies.
- Every edit is line-for-line. No line count moves, so no line-number citation is re-derived (`skills/plan/SKILL.md` § Step 3.7 cites `plan/SKILL.md:23`; `milestone-coherence-reviewer/skills/{review,sweep}/SKILL.md` cite `plan/SKILL.md:182`).
- No em dash in new text. Existing sanctioned spans stay as `scripts/check-vocabulary.sh` allows them.

---

## 1. Migration-relative text in `skills/plan/SKILL.md`

**Evidence:** three passages describe the current design as a diff against the version before the roadmap fan-out existed.
- § Procedure, the bullet beginning `**The single-brief path is the default and is unchanged`: "is unchanged", "nothing about the emitted plan file changes on that `none`-signal path", "is added separately".
- § The single-milestone inner routine (Steps 1–7): callable contract, the paragraph beginning `The routine body is Steps`: closes with "The body is otherwise unchanged by this refactor."
- § Step 3.7: Parallel per-milestone planning fan-out, the paragraph beginning `This is the **roadmap branch**`: "(the single-milestone pipeline **unchanged**)" and the pasted acceptance criterion "(acceptance criterion: disabled/edge state, single-milestone planning is unchanged)". Seven bold runs in one sentence.

**Work:** replace each passage with the text below, verbatim.

§ Procedure bullet:

> - **The single-brief path is the default**: it invokes the inner routine exactly once, with the whole brief as the lone brief-slice and its sole build-order position. The oversized-brief roadmap route lives at the front door, Step 3.6, fires only when the architect raises the multi-milestone signal, and ships its own one-time discovery notice (Step 0) per `SPEC.md` §3.1.

§ The single-milestone inner routine paragraph:

> The routine body is Steps 1, 2, 3, 3.5, 4, 5, 7 (exactly as written below). Steps 3.6 (front-door routing) and 3.7 (the roadmap fan-out) are outer, run-level orchestration and are **not part of this per-milestone routine** (like Step 0): a dispatched per-milestone inner routine runs Steps 1 → 2 → 3 → 3.5 → 4 → 5 → 7 and never re-enters Step 3.6 or Step 3.7, so the fan-out cannot recurse into itself. (Step 5.1's ADOPT branch (`docs/version-ladder.md`) and Step 7's `assignedSlug` branch are the optional-parameter seams the fan-out drives; they live inside the routine.)

§ Step 3.7 paragraph:

> This is the roadmap branch. It runs **only when Step 3.6 set `roadmapRouteTaken` = true** (a confirmed manifest path). On every other Step-3.6 outcome (signal `none`, degrade, decline, single-milestone-after-all) `roadmapRouteTaken` is false, this step is skipped, and control has already fallen through to Step 4 on the whole brief. The fan-out lives only here; the normal-sized-brief path never reaches it.

**Acceptance:** `grep -c 'is unchanged: it invokes\|unchanged by this refactor\|acceptance criterion:' skills/plan/SKILL.md` prints 0. The three sections read as the current design with no reference to a prior version.

## 2. "(new logic)" in `docs/update-reconcile-parent.md` headings and the citation in `update`

**Evidence:** `docs/update-reconcile-parent.md` carries the headings `## Step 4: diff-gate the body write (new logic, the fix this issue's advisory called for)` and `## Step 5: detect a removed milestone (new logic)`. `skills/update/SKILL.md` § Step 1R, step 5, cites the Step 5 heading by its full text; step 4 says "invoke the new twin pair's `diff-gate` entry point".

**Work:** rename the headings to `## Step 4: diff-gate the body write` and `## Step 5: detect a removed milestone`. In `skills/update/SKILL.md` § Step 1R: step 5's citation becomes `docs/update-reconcile-parent.md` "Step 5: detect a removed milestone"; step 4's "the new twin pair's" becomes "the twin pair's".

**Acceptance:** `grep -rn 'new logic\|new twin pair' skills docs` returns only the sentence beginning `No new logic is needed` in `docs/update-reconcile-parent.md`, which stays. `python3 scripts/validate-plugin-structure.py` exits 0.

## 3. Emphasis register

**Evidence:** lines carrying two or more bold runs (`grep -cE '(\*\*[^*]+\*\*.*){2,}' <file>`): `skills/plan/SKILL.md` 76 of 326 lines, `skills/update/SKILL.md` 49, `skills/create/SKILL.md` 43, `skills/remediate/SKILL.md` 31, `skills/build-roadmap/SKILL.md` 14, `skills/setup/SKILL.md` 7, `agents/remediator.md` 6, `agents/architect.md` 3, `agents/roadmap-splitter.md` 2, `agents/issue-author.md` 2. 98 caps-emphasis words across `skills/` and `agents/` (`NOT` 38, `NEVER` 15, `ONLY` 12, `AND` 10, `ONCE` 9, `OUTER` 7, and `ONE`, `EXACTLY`, `ANY`, `EVERY`).

**Work:**
- At most one bold run per line. A line is a paragraph, a list item, or a table row. The run marks the clause that gates behavior; where no clause gates behavior, the line carries no bold.
- Caps on ordinary English words (`NOT`, `AND`, `MUST`, `ONLY`, `NEVER`, `ONCE`, `ONE`, `BOTH`, `THIS`, `ALWAYS`, `EXACTLY`, `ANY`, `EVERY`, `OUTER`, `ALL`) go lowercase. Protocol literals on the keep list stay.
- Rewording is allowed except inside the contract strings and presence rows `scripts/check-contract-strings.sh` names.
- Fenced code blocks are exempt.
- Slicing: one issue per skill directory (its `SKILL.md` plus any sibling reference it loads); `agents/` is one issue.

**Acceptance:** with `nocode() { awk '/^```/{c=!c;next} !c' "$1"; }`, for every file under `skills/` and `agents/`: `nocode <file> | grep -cE '(\*\*[^*]+\*\*.*){2,}'` prints 0 and `nocode <file> | grep -owE 'NOT|AND|MUST|ONLY|NEVER|ONCE|ONE|BOTH|THIS|ALWAYS|EXACTLY|ANY|EVERY|OUTER|ALL'` prints nothing. `scripts/check-contract-strings.sh` and `scripts/check-vocabulary.sh` exit 0.

## 4. Ratchet the word ceilings

**Evidence:** `scripts/validate-plugin-structure.py` `FILE_WORD_CEILINGS` governs every file items 1 to 3 touch (`skills/plan/SKILL.md` 9550, `skills/update/SKILL.md` 6550, `skills/create/SKILL.md` 4650, `skills/remediate/SKILL.md` 3450, `skills/build-roadmap/SKILL.md` 2650, `skills/setup/SKILL.md` 2400, `agents/architect.md` 3250, `agents/issue-author.md` 3100, `agents/roadmap-splitter.md` 1850, `agents/remediator.md` 1550, `docs/update-reconcile-parent.md` 2450). Ceilings only go down.

**Work:** in the same PR as each trim, lower the ceiling of every governed file that shrank, derived by the rule in that script's comment block above `FILE_WORD_CEILINGS`.

**Acceptance:** no governed file that shrank keeps its old ceiling; `python3 scripts/validate-plugin-structure.py` exits 0.

## 5. Verification run

After the `plan` issue merges: run `/milestone-feeder:plan` once on a brief that planned clean before this milestone. Record in the milestone PR: candidate count, Wave count, `PRODUCT_GAPS` count, before and after. A delta is a finding for the PR, not a blocker.

## 6. `.project/` docs

**Evidence:** the five `.project/*.md` files are loaded into every plan, remediate, and review dispatch. Lines with two or more bold runs: `design-philosophy.md` 6, `conventions.md` 4, `environment.md` 2, `library-manifest.md` 1. Caps: `NEVER` in `conventions.md`, `NOT` in `environment.md`. Issue IDs as provenance: `conventions.md` "issue #118 acceptance criteria", "(resolved in #143)", and two `#387` sites; `design-philosophy.md` "issue #118".

**Work:** apply item 3's register rules; drop the issue IDs, the sentence keeps its content. Headings are anchors the suite resolves by name (`.project/design-philosophy.md#Error & failure philosophy`, `#Layering & boundaries`, `.project/conventions.md#Naming`): no heading changes. Line-for-line.

**Acceptance:** for every `.project/*.md`, item 3's two greps print nothing and `nocode <file> | grep -nE '(^|[^A-Za-z0-9_/`])#[0-9]{2,3}([^0-9]|$)'` prints nothing. `git diff` touches no heading line.

## Out of scope

- § The single-milestone inner routine and § Step 3.7 both state that the inner routine never re-enters Steps 3.6 and 3.7. They agree. Leave both.
- `docs/specs/**`, `CHANGELOG.md`, `tests/**`: records, not prompt surface.
