# tests/: milestone-feeder credibility harness

The scenario harness tests prose procedures an agent follows. The plugin also ships
executable hooks and helper scripts. This harness measures whether the procedures, when
**executed**, actually behave the way the README and `plugin.json` description claim.

**The scorecard is the metric.** Every concrete claim in the description must map to a
scenario that demonstrates it. A claim with no passing scenario gets dialed back. The
point is a description that is *real, tangible, and accurate*. A lighter, fully-backed
description beats a confident, unproven one.

## Hook regression tests

Run the deterministic hook and launcher fixtures independently of the scenarios:

```powershell
pwsh -NoProfile -File tests/hook-regressions.ps1 -Leg ps1
pwsh -NoProfile -File tests/hook-regressions.ps1 -Leg sh -BashPath 'C:/Program Files/Git/bin/bash.exe'
```

The runner needs PowerShell, Bash and jq. On Unix, omit `-BashPath` to resolve Bash
from PATH. Each leg tests Claude edit payloads, Codex `apply_patch` patches,
normalized paths, actor policy, profile fallback and launcher exits 0/2/7. The
Codex cases load real Codex 0.163.0 `PreToolUse` payloads from `tests/fixtures/`
(`codex-pretooluse-main.json`, `codex-pretooluse-child.json`) and expect a Codex
deny as stdout `permissionDecision: "deny"` JSON with exit 0. The Windows launcher
test uses the installed interpreter selected by its normal Bash-first discovery;
Unix tests execute the polyglot shell path through Bash. The runner creates and
removes an isolated temporary fixture. It does not run planning scenarios or GitHub
writes. CI runs both legs on every pull request (`hook regression tests`).

`pwsh -NoProfile -File tests/run-hook.test.ps1` checks that `hooks/run-hook.cmd` returns its gate's exit code (0, 2, 7) through every interpreter branch. CI runs it on Windows and Ubuntu (`launcher exit-code test`).

`pwsh -NoProfile -File tests/build-order.test.ps1` runs `scripts/build-order.sh` and `scripts/build-order.ps1` over every case under `tests/fixtures/build-order/` and requires each twin's stdout, stderr and exit code to equal the case's `expected.stdout`, `expected.stderr` and `expected.exit` byte for byte. CI runs it on Windows and Ubuntu (`build-order fixtures`).

## The one rule that makes the metric honest

The scenario **runner never sees `expected.grader.md`**: it is **not part of the runner
input set**. The runner input set is exactly `{ brief.md, project/, feeder-env.md }`,
plus `src/` when the scenario has one; the runner runs the brief blind on those inputs and
the plan procedure alone. A separate
**grader** compares observed output against `expected.grader.md`. No teaching to the test.

A key may assert byte equality only over script output, never over agent-authored text. A clause over agent text names the lines or blocks it requires present or absent.

## Runner brief (neutral template)

A runner is dispatched with this brief, which is reusable across scenarios and
deliberately neutral so the inputs never bias the architect:

> You are the `plan` runner for one scenario. Your **only** inputs are the scenario's
> runner input set: `{ brief.md, project/, feeder-env.md }`, plus `src/` when the scenario has one.
> Follow `skills/plan/SKILL.md` on those inputs and the plan procedure alone.
>
> **Never open `expected.grader.md`**: not this scenario's, and not any
> `expected.grader.md` under `tests/scenarios/`. It is the grader's answer key, it sits
> outside your input set, and reading it invalidates the run.
>
> Judge candidate gaps on their own merits. Where the brief leaves a decision
> underspecified, weigh it neutrally against the project's stated conventions: do not
> assume a verdict, and treat no example as a cue for how to decide.

## Grader brief (neutral template)

A grader is dispatched with this brief, which is reusable across scenarios and
deliberately neutral, with `<scenario>` standing for the per-run scratch folder for
scenario `<id>`, holding `input/` (the runner input set copied from
`tests/scenarios/<id>/`) and `observed/` (every file the runner wrote):

> You grade one blind scenario run. You took no part in it.
>
> - Answer key: `tests/scenarios/<id>/expected.grader.md`
> - Observed output: every file under `<scenario>/observed/`. The plan file and any needs-product-input report are what is graded. The `raw-*` files are the agents' raw returns, useful as evidence of what an agent returned.
> - Runner input set, for reference: `<scenario>/input/`.
> - Do not read any other scenario's files, any `observed-*` file under `tests/scenarios/`, or `tests/RESULTS.md`. Prior verdicts must not anchor yours.
>
> Rules:
> - Score against the answer key exactly as written: each `MUST`, each `FAIL if`, and any PASS or PARTIAL rule it states. Where it has a CONTROL or alternate case the run did not exercise, record that case as not exercised. Do not count it as passed.
> - A verdict is ✅ PASS, ⚠️ PARTIAL or ❌ FAIL. When a reading of a clause is contested, record the worse verdict and name the clause.
> - Quote observed text for every clause you score. Never paraphrase a quote. Replace any U+2014 em dash in a quote with ` - `, and say so once.
> - Read-only. Write nothing.
>
> Return:
>
> ```
> SCENARIO: <id>
> VERDICT: ✅ PASS | ⚠️ PARTIAL | ❌ FAIL
> OBSERVED: <one paragraph, at most 5 sentences: what the run produced and the cause of the verdict, in the shape of a tests/RESULTS.md "Observed" cell>
> CLAUSES:
>   - <clause, quoted or named> : met | not met | not exercised : <evidence quote>
>   - ...
> ```

## Execution model (preview-only, prose-direct)

The feeder plugin is not installed as slash commands in the harness session, so a scenario
is executed by **following the prose directly**:

1. A **runner** subagent acts as the `plan` orchestrator, following
   `skills/plan/SKILL.md` Steps 0–5 + the preview emit (the preview is `plan`'s job; `create` is the write path).
2. It dispatches the **architect** and **issue-author** stand-ins, briefed from
   `agents/architect.md` and `agents/issue-author.md` (their contracts). Each stand-in
   dispatch passes the `model` its agent file's frontmatter declares (`agents/architect.md`
   opus, `agents/issue-author.md` sonnet). The runner and the grader run on the session
   model, because `plan` runs on the main thread in production.
3. **PREVIEW only**: zero GitHub writes. The run emits the plan file (and a
   needs-product-input report when applicable) as text artifacts under the scenario folder.
4. A **grader** subagent scores observed-vs-`expected.grader.md` → ✅ pass / ⚠️ partial / ❌ fail,
   with the observed behavior recorded.

`create` and `update` make real GitHub writes, so their scenarios (07–09, and the
create-loop portion of 11) are designed here but run later against a
throwaway sandbox repo. They are labeled, not silently skipped.

## Layout

```
tests/
  README.md                      # this file (design + how to run + how to read RESULTS)
  scenarios/
    # runner input set = { brief.md, project/, feeder-env.md }, plus src/ when the scenario has one;
    # expected.grader.md is grader-only: it exists in each dir but is outside the input set.
    01-clean-happy-path/          { brief.md, project/, feeder-env.md }  + expected.grader.md
    02-product-gap-parks/         { ... }
    03-design-resolvable-no-park/ { ... }
    04-no-code-refusal/           { ... }
    06-cross-cutting-consistency/ { ... }
    10-nested-layout/             { brief.md, project/, feeder-env.md }  + expected.grader.md
    11-roadmap-fan-out/           { brief.md, project/, feeder-env.md }  + expected.grader.md
    12-implied-surfaces/          { brief.md, project/, feeder-env.md }  + expected.grader.md
    12b-implied-surfaces-control/ { brief.md, project/, feeder-env.md }  + expected.grader.md
    13-layer-aware-breakdown/     { brief.md, project/, feeder-env.md }  + expected.grader.md
    14-config-pointers/           { brief.md, project/, feeder-env.md, src/ }  + expected.grader.md
    15-prose-style/               { brief.md, project/, feeder-env.md, src/ }  + expected.grader.md
    17-shared-file-ordering/      { brief.md, project/, feeder-env.md, src/ }  + expected.grader.md
    18-convention-sweep-prompt/   { brief.md, project/, feeder-env.md }  + expected.grader.md
    19-system-control-removed/    { brief.md, project/, feeder-env.md }  + expected.grader.md
    20-measured-layout/           { brief.md, project/, feeder-env.md }  + expected.grader.md
  RESULTS.md                      # scorecard + claim→evidence map (the metric)
```

Per scenario:
- `brief.md`: the input brief (the runner's only task input besides the procedure).
- `project/`: the `.project/`-style project docs the run grounds on (optional per scenario).
- `src/`: the source tree the keys cite and `sourceGlobs` matches, present only in a scenario whose keys cite source files (14, 15, 17).
- `feeder-env.md`: the test config the run assumes, namely the `feeder.json` keys and the
  driver shared keys (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`) the run reads.
- `expected.grader.md`: the behavioral contract (grader-only, outside the runner input
  set; the runner never sees it).

`tests/` is outside `sourceGlobs` and the `skills/` load path: no hook friction, never
loaded as plugin skills.

## Scenario set

| # | Scenario | Adversarial intent | Claim under test | Run now? |
|---|----------|--------------------|------------------|----------|
| 01 | clean happy-path | well-specified brief, a few independent features + one real dependency | "small, well-formed issues"; Wave/dependency order encoded; issues drafted to pass the driver's triage clean | ✅ |
| 02 | product-gap-parks | bury a decision with no conventional default | **parks product decisions to a report, never invents scope**; dependents dropped | ✅ |
| 03 | design-resolvable, no park | vague on a detail a stated convention *can* answer | park-boundary precision: resolves + cites grounding, does **not** park and does **not** invent | ✅ |
| 06 | cross-cutting consistency at scale | a standing table directive in the project docs; a brief asking for ~10 table-bearing pages, **not** restating the directive | **flagship:** the directive propagates into all ~10 issues consistently (Consistency criterion) and each issue cites the convention. The feeder drafts each to the driver's triage bar, which would catch drift, but the feeder runs no gate itself | ✅ |
| 04 | no-code refusal | brief says "implement it and open a PR" | authors no code, opens no PRs, never touches branches. Stays in plan-and-specify | built, later |
| 07 | `create` idempotency | create, then re-run | create-or-adopt by title; idempotent re-run (no dupes); never delete | sandbox follow-up |
| 08 | update no-op / not-found / patch | clean milestone; missing milestone; gapped issue | update is idempotent (clean → no-op); milestone-not-found → error-and-stop; gapped body patched | sandbox follow-up |
| 09 | slug→#n at scale | >26 candidates | substring-safe slug rewrite (`#A` not corrupting `#AB`) | sandbox follow-up |
| 10 | nested layout | a nested monorepo (`siteroot/{web,api}`) where source lives only under app roots, never the repo root | bootstrapper-v0.2.0-baked nested `sourceGlobs` route issue file scope into the nested app roots, never the repo root | ✅ |
| 11 | roadmap fan-out | an oversized whole-app brief (auth, data model, invoicing, billing, screens) that spans several milestones, seeded from its own author sections | a whole-app brief routes into `build-roadmap`: **split → confirm → parallel-plan** emits the roadmap manifest + N per-milestone plan files; the **create deploy-loop** deploys them; single-milestone collapse falls back cleanly; an undecided product call parks one issue and siblings continue | plan-side ✅ now / create-loop sandbox follow-up |
| 12 | implied surfaces | a terse brief names a capability (admins emailing members) but never spells out its companion surfaces; one companion (suppression/unsubscribe) is a genuine product-call with no conventional default | the architect consults the implied-surfaces reference, fans the conventional companions (delivery-failure log + retry + audit) out as **`implied`-labeled review candidates**, **parks** the genuine product-call to needs-product-input instead of inventing it, and `plan` surfaces the implied set with the verbatim anti-fixation prompt. No auto-dump, no invented scope; a control slice with no capability/entity triggers neither | ✅ |
| 12b | implied surfaces control | a brief that names **no capability and introduces no new entity** (a plain reword of existing copy, no email/user-management/sync, etc.) | the control sibling to 12, demonstrated by its own run: the architect's clause-8 consult is a genuine no-op, zero `implied`-disposition candidates, no `[implied - review / trim / augment]` marker, no anti-fixation prompt; breakdown proceeds grounded and dependency-only | ✅ |
| 13 | layer-aware breakdown | a small backend brief (list + create notes + a slug helper) against a project stating a strict layering convention (`util` ← `data` ← `services` ← `controllers` ← `routes`); the service's repository is constructor-injected, so no textual type reference relates them | the architect assigns each candidate its architectural `layer` (CRUD→`data`, helper→`util`, validation→`controllers`), grounds each in the stated architecture, and keys the Wave order to the **layer** dependency (the `#C depends_on #A` layer edge a type-reference heuristic would miss), threading the `layer` into each issue body's Design block; a no-layering control emits no `layer` field, no `Layer:` line and no layer-keyed edge (`#C depends_on #A` absent) | ✅ |
| 14 | config pointers | a styling brief (add a `danger` button variant) against a project whose colors live in a token doc (`tokens.json`, `color.danger` = a hex) and button rules in `design-system.md#Buttons`; the tempting shortcut is to resolve the color into the issue body | the issue-author POINTS the styling issue at the token + design-system docs BY PATH in its existing `## Design` block. That is a reference, never a pre-solved design, so the body inlines **no** resolved hex / token value; a grounded design decision with a conventional default (mirror `src/ui/Button.tsx`) is still recorded via `Convention followed:`; an absent-config control omits the pointer, inlines nothing, keeps the groundable convention, and errors on nothing | ✅ |
| 15 | prose style | a paginated-list brief carrying a literal "30 rows per page" directive; the tempting failure is to pad the authored issue to sound confident | the issue-author's authored `ISSUE_BODY` obeys the prose-style ruleset (`## Prose style` in `agents/issue-author.md`): Summary 2–3 plain sentences, no banned filler / hedges, one declarative line per criterion / decision, no template narration. The content-preservation guardrail meanwhile keeps every completeness state, the literal "30 rows per page" directive, and the grounded `Convention followed:` citation verbatim; a padded rewrite CONTROL fails the prose assertions, and a content-dropping trim fails the guardrail | ✅ |
| 16 | remediate: in-place correction | a parked issue whose `🔴 Triage` comment names a contradiction between two recorded design statements, plus a second finding that needs a product call; the tempting shortcut is to append a "Correction" section restating the right answer under the wrong text | the corrected body edits the named text IN PLACE: the superseded wording is **gone** (string search, not judgment), no correction / addendum section was added, and each decision has exactly one statement. The product-call finding stays `NEEDS_HUMAN` with the issue parked and its labels untouched, and a re-run against the already-corrected issue is a no-op that writes nothing | sandbox follow-up |
| 17 | shared-file ordering | a CSV-export brief against a project whose convention binds every route in one route registry and registers every service, job, and migration in one module registry, so several candidates modify the same existing file while no artifact reference relates them; the brief also names a queue-manifest path that does not exist and that the registry convention resolves to an edit of the module registry | each candidate declares a grounded `edits:` list of the existing files it modifies, and two candidates whose lists intersect get an ordering edge (`#C after #D - edits: src/routes/index.ts`) the Wave sort consumes like any other, so they land in successive Waves instead of colliding in one parallel Wave. A pair a concrete dependency edge already relates carries no second edge, the undeclared path is neither listed nor introduced, the list threads into each issue body's `Edits:` line, and a disjoint control returns the Wave order the concrete edges alone produce | ✅ |
| 18 | convention sweep prompt | an amount field that holds a typed "0.00" where a `TextField` prompt belongs, at four call sites (ios-budget-app #1759), plus a fifth site already on the empty-reads-as-zero form that a sweep must not list; the tempting failure is to cite a `.required` site as the convention followed | the issue carries a `Platform source:` line naming the `TextField` prompt convention, and its `Sites searched:` grep lists exactly the four defective sites; grades `docs/briefs/2026-11-21-file-a-verified-bug.md` item 2, so it fails on today's feeder | ✅ |
| 19 | system control removed | a split view that forces `.constant(.all)` and removes the sidebar toggle, so the iPad sidebar cannot be hidden (ios-budget-app #1741); the tempting failure is to cite the forced `.constant(.all)` as the pattern to mirror | the issue names the system column-visibility and sidebar-toggle behavior it restores and cites Apple's `NavigationSplitView` doc for it; grades `docs/briefs/2026-11-21-file-a-verified-bug.md` item 2, so it fails on today's feeder | ✅ |
| 20 | measured layout | code that feeds a measured width back into layout, which the fixture's `nonNegotiables` forbids (ios-budget-app #1758); the sibling view that does the same is the tempting pattern to copy | the issue quotes the non-negotiable verbatim and names a size-class API in place of the measurement; grades `docs/briefs/2026-11-21-file-a-verified-bug.md` item 2, so it fails on today's feeder | ✅ |

### 06: the flagship, in detail

- **Project docs** (`project/`): a design-system / conventions doc stating, e.g.,
  *"All data tables: columns sortable and filterable except an Actions column; pagination
  at 30 rows per page."* This is a **standing convention**, the natural home for it.
- **Brief**: "Build these ~10 pages, each listing <entities> in a table". It **does not
  restate** the table directive. The feeder must pull it from the project docs, apply it to
  every page-issue, and cite it.
- **Config**: `uiSurfaceGlobs` is **set**, mirroring the driver's own config, so the glob half
  of the classification engages alongside the affordance half and the page-issues carry the
  design spec (states / affordances / pattern) the driver's design lens checks (absent → no
  glob-based UI match; the affordance test still classifies these pages `ui`).
- **Expected** (grader): every page-issue carries the full directive (sortable + filterable
  except actions + pagination 30/page) in its acceptance criteria, verbatim-equivalent (no
  drift, no silent weakening of "30/page"), and cites the convention. Every issue is drafted
  to the same bar, with no in-feeder re-author loop. Drift past the first few issues is
  the failure mode being hunted.

## The metric (RESULTS.md)

Two tables:

1. **Scorecard**: `# | scenario | expected | observed | verdict (✅/⚠️/❌) | run?`
2. **Claim → evidence map**: each concrete claim in `plugin.json` description + README
   intro → the scenario(s) that exercise it → **Demonstrated / Designed-not-run / Unbacked**.

The metric is (a) the run-now pass rate, and (b) how many claims are Demonstrated vs
Designed-not-run vs Unbacked.

## After the metric: right-size the copy

Using the claim→evidence map, rewrite the `plugin.json` description and the README intro so
each claim is either **Demonstrated** or honestly framed as design intent, never a tested
guarantee it hasn't earned. Unbacked or failing claims are removed or softened. This step is
contingent on the metric, not done up front.
