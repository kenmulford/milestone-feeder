# Brief: prompt-surface repair (milestone-feeder)

**Goal.** The prompt surface (`skills/`, `agents/`, the top-level `docs/*.md` and `.project/*.md` they load) states current behavior only. Every citation resolves to the passage it names, no two files rule differently on the same point, and emphasis marks only the clause that gates behavior. Target models: Claude Opus 5.5 (main thread, `model: opus` agents), Claude Sonnet 5.5 (`model: sonnet` agents). Verified against `develop` @ af786ae on 2026-10-19. Supersedes `docs/briefs/2026-09-05-prompt-audit.md`.

**Constraints on every item:**
- CI stays green on every commit: `scripts/check-contract-strings.sh` (the two byte-exact contract strings and the four presence rows survive verbatim), `scripts/check-vocabulary.sh` (no em dash U+2014 in new text), `scripts/validate-plugin-structure.py` (`FILE_WORD_CEILINGS`, `AGENT_DESCRIPTION_WORD_CEILING`).
- Keep list, never edited: caps protocol literals (`PRODUCT_GAP`, `PRODUCT_GAPS`, `CANDIDATES`, `EDGES`, `WAVES`, `INVARIANTS`, `SCOPE_SPANS_MULTIPLE_MILESTONES`, `STATUS`, `NEEDS_HUMAN`, `ALREADY_APPLIED`, `ISSUE_BODY`, `CORRECTED_BODY`, `ROADMAP`, `LABELS`, `ISSUE_TAG`, `[TBD]`, HTTP verbs, environment variables, table-enumerated values); fenced code blocks; `<example>` blocks; the "Plain English" paragraph in each skill and agent (it matches `docs/style-contracts.md#output-style`); headings the suite resolves by name (`.project/design-philosophy.md#Error & failure philosophy`, `#Layering & boundaries`, `.project/conventions.md#Naming`).
- `byte-unchanged` / `byte-identical` in `skills/update/SKILL.md` are idempotency rules and stay.

---

## 1. Issue bodies are written from a file in `update`

**Evidence:** `skills/update/SKILL.md` Step 4 reconcile table, rows "In plan, NOT on GitHub" and "In BOTH, body DIFFERS", and the Non-negotiables bullet "Reuses `create`'s write primitives" use `gh issue create ... --body "<...>"` and `gh issue edit <n> --body "<...>"`. `skills/remediate/SKILL.md` requires "`--body-file`, never `--body`"; `create` writes through `scripts/deploy-write-sequence.sh` `create-issues` / `apply-bodies`.

**Work:** every issue-body write in `update` uses `--body-file <tmp>` and cites the twin's `create-issues` / `apply-bodies` entry points. `docs/architecture.md` Remediate-skill row: `--body` becomes `--body-file`.

**Acceptance:** `grep -rn -- '--body "' skills docs/*.md` prints nothing.

## 2. Citations point where the content lives

| Citing site | Cites | Repoint to |
|---|---|---|
| `skills/update/SKILL.md` Steps 2, 3a, 3b, Non-negotiables; `skills/plan/SKILL.md` Step 7 "Preserve an existing deploy receipt"; `docs/version-ladder.md` step 1 | `skills/create/SKILL.md` Step 3 pass (b) (env.t resolve, PATCH form, `-f title=`, paginated read, deploy receipt) | `docs/create-deploy-sequence.md` "b. Create-or-adopt the milestone (by EXACT title)" or "Write the deploy receipt (the concluding action of pass b)", plus the `find-milestone` entry point. Drop "bash and PowerShell 7+ forms are both given there" |
| `skills/update/SKILL.md` Step 3a title compare | "plan-file-contract row at `skills/plan/SKILL.md` Step 7" | `docs/plan-file-contract.md` "Plan-file field table", Milestone title (exact) row |
| `skills/create/SKILL.md` Step 0 `autoHandoff` | "`plan` key-extraction table (`skills/plan/SKILL.md` Step 0 ...)" | `docs/profile-schema.md` "Own keys" |
| `skills/plan/SKILL.md` Step 4 cap-4 rule | `milestone-driver` `skills/solve-milestone/SKILL.md` Phase 1 step 2 quote | `milestone-driver` `skills/solve-milestone/parallel-waves.md` Phase 1 step 3, `maxParallelWorkers` (default 4); no quote |
| `.project/environment.md` External services; `.project/library-manifest.md` GitHub row | `docs/consumer-setup.md` Before you start | `README.md` Before you start |

**Acceptance:** `grep -rn 'skills/create/SKILL.md` Step 3 pass (b)' skills docs/*.md` prints nothing. Every repointed heading exists verbatim in its target file.

## 3. Contradictions resolved

- `skills/plan/SKILL.md` callable contract: both optional parameters are absent on a first single-brief plan; `preResolvedVersion` is also set on an incremental re-plan (`docs/incremental-replan.md` §4).
- `skills/setup/SKILL.md` description, "When this runs", Phase 5, and the commit bullet name `plan`, `create`, `update`, and `remediate` as auto-callers and return control to "the calling skill".
- `agents/architect.md` § Communication style and § Return: name all six return keys (`CANDIDATES` / `EDGES` / `WAVES` / `PRODUCT_GAPS` / `SCOPE_SPANS_MULTIPLE_MILESTONES` / `INVARIANTS`).
- `agents/issue-author.md` contract clause 3 (Completeness) adds: "plus an existing-user discovery path when the change touches existing users or config (`SPEC.md` §3.1)." Edit outside the presence-pinned fragments.
- `agents/remediator.md` clause 2: the corrected body adds no section except one the issue-body template names (`## Design (recorded, consistent)`, per `skills/remediate/SKILL.md` "A finding whose fix needs a new section"), and never one named for a correction.

## 4. Stale facts in `docs/` and `.project/`

| Site | Current fact |
|---|---|
| `docs/architecture.md` Hook row, hooks section (both "unconditional ... no subagent carve-out" sites), `hooks/hooks.json` description | The hook denies the main thread and the feeder's own agents (`FEEDER_OWN_AGENTS` in `hooks/no-source-edit.sh`); a positively identified non-feeder subagent passes |
| `docs/architecture.md` write-order table and "not a sixth write pass" | Add row `f`: Mirror the milestone to Trello (best-effort, only with `integrations.trello`). The handoff is Step 4, after passes a-f |
| `docs/architecture.md` Update-skill row; `docs/consumer-setup.md` §3 | `update` creates missing issues and deletes none |
| `docs/consumer-setup.md` "Check coverage" row | Delete the row (`create` runs no coverage audit) |
| `docs/roadmap-fan-out.md` 3.7.g | The user runs `/milestone-feeder:create` once; it deploys every milestone in build order |
| `docs/profile-schema.md` `sourceGlobs` row and the "Every key except `versioning`" sentence | `sourceGlobs` default: *(none: the hook fails open)*. Keys without a default: `versioning`, `issueSize`, `sourceGlobs` |
| `.project/conventions.md` scenarios bullet; `.project/design-philosophy.md` scenarios sentence | Scenarios 01-04, 06, 10-15, 12b, 17 exist; 07-09 and 16 are not yet run; each carries `brief.md`, `feeder-env.md`, `expected.grader.md`, and a `project/` fixture except 04 |
| `.project/conventions.md` carve-outs; `docs/create-deploy-sequence.md` Conv 7 rows and the Trello skip line | The driver spans read `#<n> - <issue title>` and `Trello: <operation> skipped - <error>`. Recast both to ASCII hyphen, remove their two `ALLOWLIST_ROWS` entries from `scripts/check-vocabulary.sh`, and the carve-out names the two remaining quotes |
| `docs/never-claims-audit.md` occurrence counts | Delete the counts and their date; keep the grep that produces them |

## 5. Current behavior only, no version history

Rewrite each site to state the current rule. Content stays; the before/after framing goes.

- `skills/plan/SKILL.md`: § Procedure single-brief bullet, § inner routine paragraph ("unchanged by this refactor"), Step 3.6 `none` row, Step 3.7 opening paragraph ("acceptance criterion: ...").
- `skills/update/SKILL.md`: Step 1R opening ("exactly as today", "the one thing that was missing"), "new twin pair" (2 sites), Step 3b heading and body ("the v0.3.0 path", "as v0.3.0 did").
- `skills/create/SKILL.md` Step 3 opening ("the v0.2.0 apply write-sequence, preserved verbatim").
- `agents/architect.md` inputs ("exactly as today").
- `docs/update-reconcile-parent.md`: headings drop "(new logic ...)", "(new twin)", "(reused by reference, unchanged)"; `skills/update/SKILL.md` citations match the renamed headings.
- `docs/` and `.project/` sites using "as today", "today's", "as before", "no longer", "now", "relocated byte-for-byte", "the prior behavior", "(already on develop)", "(issue #NNN)": `architecture.md`, `profile-schema.md`, `plan-file-contract.md`, `create-deploy-sequence.md`, `consumer-setup.md`, `step-0-grounding.md`, `version-ladder.md`, `style-contracts.md`, `implied-surfaces.md`, `never-claims-audit.md`, `.project/library-manifest.md`, `.project/conventions.md`, `.project/design-philosophy.md`.
- Delete the "How each acceptance criterion is met" tables in `docs/create-deploy-sequence.md` (3) and `docs/update-reconcile-parent.md` (1). Keep the "Accepted trade-off" paragraphs; drop "Correction N" labels from them.

**Acceptance:** `grep -rnE 'unchanged by this refactor|acceptance criterion:|new logic|new twin|as v0\.[0-9]|the v0\.[0-9.]+ (path|apply)|exactly as today|How each acceptance criterion' skills agents docs/*.md .project` prints nothing.

## 6. Emphasis register

**Scope:** `skills/*/SKILL.md`, `agents/*.md`, `.project/*.md`, `docs/create-deploy-sequence.md`, `docs/step-0-grounding.md`, `docs/roadmap-fan-out.md`, `docs/file-map.md`, `docs/version-ladder.md`.

**Work:** at most one bold run per line (paragraph, list item, or table row), on the clause that gates behavior; a line with no gating clause carries no bold. Caps on ordinary English words (`NOT`, `AND`, `MUST`, `ONLY`, `NEVER`, `ONCE`, `ONE`, `BOTH`, `THIS`, `ALWAYS`, `EXACTLY`, `ANY`, `EVERY`, `OUTER`, `ALL`, `SKIPPED`, `IN PLACE`) go lowercase. One issue per skill directory (its `SKILL.md` plus the docs it loads); `agents/` plus `.project/` is one issue.

**Acceptance:** with `nocode() { awk '/^```/{c=!c;next} !c' "$1"; }`, for every file in scope: `nocode <file> | grep -cE '(\*\*[^*]+\*\*.*){2,}'` prints 0 and `nocode <file> | grep -owE 'NOT|AND|MUST|ONLY|NEVER|ONCE|ONE|BOTH|THIS|ALWAYS|EXACTLY|ANY|EVERY|OUTER|ALL'` prints nothing.

## 7. Ratchet the word ceilings

In the same PR as each trim, lower the `FILE_WORD_CEILINGS` entry of every governed file that shrank, by the rule in the comment block above `FILE_WORD_CEILINGS` in `scripts/validate-plugin-structure.py`.

## Out of scope

- `docs/specs/**`, `docs/briefs/**`, `CHANGELOG.md`, `tests/**`.
- `milestone-coherence-reviewer` citations into `skills/plan/SKILL.md` (that repo's work).

## Open, and fenced

- Whether `superpowers` stays a hard dependency. No skill, agent, hook, or script invokes it; `README.md`, `docs/architecture.md`, `docs/consumer-setup.md`, and `.project/` say it is required. Leave all five as they are.
