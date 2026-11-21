# Brief: fix the contract, free the content (milestone-feeder)

**Goal.**
- The feeder fixes what the driver consumes: the issue-body schema, the return blocks, the GitHub writes, and pass/fail checks run as scripts.
- It leaves the project-context agent to judge the stack, its conventions, and how to break the work down.
- Prose that restates a deterministic rule is replaced by the script that applies it.

**Source.** Anthropic's guidance, read 2026-11-21:
- [Skill authoring best practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices): "Match the level of specificity to the task's fragility and variability", "Prefer scripts for deterministic operations", "Default assumption: Claude is already very smart", and "Build evaluations first".
- [Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents): avoid "hardcoding complex, brittle logic in their prompts".
- [Claude Code best practices](https://code.claude.com/docs/en/best-practices): "Give Claude something it can run that comes back pass or fail."

Verified against `develop` at `6ef4514` on 2026-11-21.

**Constraints to hold across all items:**
- CI stays green: `scripts/check-contract-strings.sh`, `scripts/check-vocabulary.sh`, `scripts/validate-plugin-structure.py`.
- Every new script ships as a `.sh` and `.ps1` pair with the same output, as `scripts/deploy-write-sequence.{sh,ps1}` does, since the feeder runs on Windows hosts without bash.
- `FILE_WORD_CEILINGS` only go down. One issue re-pins every cut file after all of item 4 lands, at its measured word count times 1.05, rounded up to the next 50, with the issue number recorded. A cut file already passes its existing ceiling, and re-pinning file by file would make every cut wait on `scripts/validate-plugin-structure.py`.
- The driver-facing return blocks change only where item 2 says. The issue-body schema stays byte-compatible with the driver's triage.
- Item 1 builds first. Items 2 to 4 are accepted against its scenarios.
- `docs/briefs/2026-11-21-file-a-verified-bug.md` item 1 Step 2 calls item 3's script, so item 3 lands before that brief's item 1.

---

## 1. Evals from real failures, built first

**Evidence:** `tests/scenarios/` holds 13 scenarios, each with `brief.md`, `feeder-env.md`, `expected.grader.md` and a `project/` fixture (`.project/design-philosophy.md`, the "Success is testable" paragraph). None comes from a failure seen in a consumer repo.

**Work:** add three scenarios built from ios-budget-app milestone 99, each with a minimal SwiftUI fixture under `project/` that reproduces the breach:
- `18-convention-sweep-prompt`: from #1759. An amount field holds a typed "0.00" where a `TextField` prompt belongs, at four call sites. The grader passes when the issue names the convention with a `Platform source:` line and its `Sites searched:` grep lists all four sites.
- `19-system-control-removed`: from #1741. A split view forces `.constant(.all)` and removes the sidebar toggle. The grader passes when the issue names the system behavior it restores and cites Apple's doc for it.
- `20-measured-layout`: from #1758. Code feeds a measured width back into layout, which the fixture's `nonNegotiables` forbids. The grader passes when the issue quotes the non-negotiable verbatim and names a size-class API in place of the measurement.

One issue adds all three scenarios, since they share `tests/README.md` and one fixture shape. A second issue records the baseline.

**Acceptance:**
- The three scenarios are in `tests/README.md#Scenario set`.
- `tests/RESULTS.md` carries a dated baseline run of scenarios 01 to 20 on today's feeder.
- Scenarios 18 to 20 are expected to fail on the baseline. They grade the issue-author change in `docs/briefs/2026-11-21-file-a-verified-bug.md` item 2, not this brief.

## 2. One script derives the build order

**Evidence:**
- `agents/architect.md` clause 4 (topological sort), clause 11 (`after` edges from intersecting `edits` lists, with a direction rule and tie-breaks) and the fold tie-break in clause 1 describe deterministic algorithms in prose.
- `skills/plan/SKILL.md` Step 5 takes the architect's `WAVES` as returned.
- No script under `scripts/` sorts the graph.

**Work:**
- Add `scripts/build-order.{sh,ps1}`. Input: a JSON file of candidates (`tag`, `edits`) and the clause 3 and clause 9 edges. Output: the clause 11 `after` edges and the Waves. A cycle exits non-zero and names the tags in it.
- `agents/architect.md` stops emitting `WAVES` and `after` edges. It still judges and returns candidates, `edits`, and clause 3 and 9 edges. Clauses 4 and 11 shrink to the judgment they hold and one line naming the script.
- `skills/plan/SKILL.md` runs the script twice. After Step 3.5, its `after` edges go into each Step 4 brief, since the issue-author writes them into bodies as `Depends on` lines. After the Step 5 drop pass, it runs over the surviving set and supplies the Waves. `docs/incremental-replan.md` runs it over the merged edges.
- `scripts/check-contract-strings.sh` pins neither `WAVES` nor `after` edges (checked 2026-11-21), so this item leaves it unchanged.

**Acceptance:**
- Scenario 17 (`17-shared-file-ordering`) and scenario 01 grade the same as their recorded results.
- A fixture with a cycle exits non-zero.

## 3. One script checks every authored issue body

**Evidence:**
- `skills/plan/SKILL.md` Step 4, "Per-dispatch verify + one bounded retry", runs its substring checks as prose instructions.
- The feeder never runs a citation resolver on what it authors. The citation-format rule ("Wrap the whole reference in one code span") is restated in 3 files under `agents/`.
- The driver resolves citations with `scripts/resolve-citation.sh` (108 lines) against `skills/citation-format.md`.

**Work:** add `scripts/check-issue-body.{sh,ps1} <body-file> <repo-root> [--invariants <file>] [--sections <file>] [--mode plan|bug]`. `--mode` defaults to `plan`. It prints one line per failure, naming what was expected and what was found. It checks:
- Required sections are present.
  - `plan` writes the resolved template's required `## ` headings to the `--sections` file, one per line. Step 0 already translates an Issue Form into `## <label>` sections (`docs/step-0-grounding.md` §5), so the script parses no YAML.
  - Without `--sections`, it checks the built-in default sections (`agents/issue-author.md` "Output format").
- Every `path (anchor)` resolves to exactly one line under `<repo-root>`. This is ported from the driver's `resolve-citation.sh`, because the feeder installs without the driver. A fixture set under `tests/fixtures/citations/` carries the cases from the driver's `skills/citation-format.md` so the two stay in step.
- The `Sites searched:` command is re-run, and every file it prints appears in the body. The script runs the command only when it matches `grep -rnE '<pattern>' <path>...` with every path inside `<repo-root>`, and never passes it to a shell `eval`, since the command is text an agent wrote.
- Every handed-in invariant `value` appears verbatim.
- No banned vocabulary appears. The list moves from `agents/issue-author.md` `## Prose style` rule 4 into the script.
- Under `--mode bug`, the body carries a `Platform source:` line. Plan-mode ui bodies are covered by `docs/briefs/2026-11-21-file-a-verified-bug.md` item 2, which teaches the issue-author to write the line. Enforcing it in plan mode before then would fail every ui body.

`skills/plan/SKILL.md` Step 4 runs it on each return. A failure re-dispatches once, with the script's output, under the existing bounded retry.

**Acceptance:**
- Each check has a failing fixture and a passing fixture under `tests/fixtures/`.
- With the script wired into Step 4, scenarios 01 to 17 grade the same as or better than the baseline.

## 4. Cut the prose the scripts now carry, and what Claude already knows

**Evidence:** word counts at `6ef4514`: `skills/plan/SKILL.md` 9,517, `agents/architect.md` 3,433, `agents/issue-author.md` 3,224.

**Work:** a sentence stays only when one of these holds:
- A script, the driver or a scenario grader depends on it.
- It states a judgment the agent must make.
- It names a project input the agent reads.

Cut, in each of `skills/plan/SKILL.md`, `agents/architect.md`, `agents/issue-author.md`, `agents/remediator.md` and `agents/roadmap-splitter.md`:
- Algorithm text items 2 and 3 replaced, down to one line naming the script.
- Each restated citation-format paragraph, down to: "Cite as `path (anchor)`. `scripts/check-issue-body` reports any citation that does not resolve." `agents/roadmap-splitter.md` keeps only the first sentence, since no step runs the script on the splitter's output.
- `## Prose style` rules that the script checks, or that restate the house style Claude already follows. Rules 2, 3 and 8 and the guardrail stay, since the driver's triage reads the structure they set.
- Explanations of what a section is for, of how Claude Code works, and of why a rule exists when the rule's source is already cited.

**Acceptance:**
- Scenarios 01 to 17 grade the same as or better than the baseline. The results for 18 to 20 are recorded.
- One issue, after every cut lands, re-pins each cut file's `FILE_WORD_CEILINGS` entry to its measured count.

## Open, and fenced

- A PreToolUse hook enforcing the agents' `Read scope.` rule (open follow-up 2). Anthropic's guidance puts a must-hold rule in a hook. This one is Ken's call, because a plugin hook fires in every session where the plugin is enabled, not only inside feeder agents. Recommendation: scope the hook to feeder agent types, or leave the rule in prose.
