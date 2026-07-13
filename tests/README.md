# tests/ — milestone-feeder credibility harness

This is not a unit-test suite — milestone-feeder has no executable code; its skills are
prose procedures an agent follows. This harness measures whether those procedures, when
**executed**, actually behave the way the README and `plugin.json` description claim.

**The scorecard is the metric.** Every concrete claim in the description must map to a
scenario that demonstrates it. A claim with no passing scenario gets dialed back. The
point is a description that is *real, tangible, and accurate* — a lighter, fully-backed
description beats a confident, unproven one.

## The one rule that makes the metric honest

The scenario **runner never sees `expected.grader.md`** — it is **not part of the runner
input set**. The runner input set is exactly `{ brief.md, project/, feeder-env.md }`; the
runner runs the brief blind on those inputs and the plan procedure alone. A separate
**grader** compares observed output against `expected.grader.md`. No teaching to the test.

## Runner brief (neutral template)

A runner is dispatched with this brief — reusable across scenarios, and deliberately
neutral so the inputs never bias the architect:

> You are the `plan` runner for one scenario. Your **only** inputs are the scenario's
> runner input set: `{ brief.md, project/, feeder-env.md }`. Follow `skills/plan/SKILL.md`
> on those inputs and the plan procedure alone.
>
> **Never open `expected.grader.md`** — not this scenario's, and not any
> `expected.grader.md` under `tests/scenarios/`. It is the grader's answer key, it sits
> outside your input set, and reading it invalidates the run.
>
> Judge candidate gaps on their own merits. Where the brief leaves a decision
> underspecified, weigh it neutrally against the project's stated conventions — do not
> assume a verdict, and treat no example as a cue for how to decide.

## Execution model (preview-only, prose-direct)

The feeder plugin is not installed as slash commands in the harness session, so a scenario
is executed by **following the prose directly**:

1. A **runner** subagent acts as the `plan` orchestrator, following
   `skills/plan/SKILL.md` Steps 0–5 + the preview emit (the preview is `plan`'s job; `create` is the write path).
2. It dispatches subagents for the **architect** and **issue-author** roles, briefed from
   `agents/architect.md` and `agents/issue-author.md` (their contracts).
3. **PREVIEW only** — zero GitHub writes. The run emits the plan file (and a
   needs-product-input report when applicable) as text artifacts under the scenario folder.
4. A **grader** subagent scores observed-vs-`expected.grader.md` → ✅ pass / ⚠️ partial / ❌ fail,
   with the observed behavior recorded.

`create` and `update` make real GitHub writes, so their scenarios (07–09, and the
create-loop portion of 11) are designed here but run later against a
throwaway sandbox repo — labeled, not silently skipped.

## Layout

```
tests/
  README.md                      # this file (design + how to run + how to read RESULTS)
  scenarios/
    # runner input set = { brief.md, project/, feeder-env.md };
    # expected.grader.md is grader-only — it exists in each dir but is outside the input set.
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
    14-config-pointers/           { brief.md, project/, feeder-env.md }  + expected.grader.md
    15-prose-style/               { brief.md, project/, feeder-env.md }  + expected.grader.md
  RESULTS.md                      # scorecard + claim→evidence map (the metric)
```

Per scenario:
- `brief.md` — the input brief (the runner's only task input besides the procedure).
- `project/` — the `.project/`-style project docs the run grounds on (optional per scenario).
- `feeder-env.md` — the test config the run assumes: the `feeder.json` keys and the driver
  shared keys (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`) the run reads.
- `expected.grader.md` — the behavioral contract (grader-only, outside the runner input
  set; the runner never sees it).

`tests/` is outside `sourceGlobs` and the `skills/` load path — no hook friction, never
loaded as plugin skills.

## Scenario set

| # | Scenario | Adversarial intent | Claim under test | Run now? |
|---|----------|--------------------|------------------|----------|
| 01 | clean happy-path | well-specified brief, a few independent features + one real dependency | "small, well-formed issues"; Wave/dependency order encoded; issues drafted to pass the driver's triage clean | ✅ |
| 02 | product-gap-parks | bury a decision with no conventional default | **parks product decisions to a report, never invents scope**; dependents dropped | ✅ |
| 03 | design-resolvable, no park | vague on a detail a stated convention *can* answer | park-boundary precision — resolves + cites grounding, does **not** park and does **not** invent | ✅ |
| 06 | cross-cutting consistency at scale | a standing table directive in the project docs; a brief asking for ~10 table-bearing pages, **not** restating the directive | **flagship:** the directive propagates into all ~10 issues consistently (Consistency criterion) and each issue cites the convention — the feeder drafts each to the driver's triage bar, which would catch drift, but the feeder runs no gate itself | ✅ |
| 04 | no-code refusal | brief says "implement it and open a PR" | authors no code, opens no PRs, never touches branches — stays in plan-and-specify | built, later |
| 07 | `create` idempotency | create, then re-run | create-or-adopt by title; idempotent re-run (no dupes); never delete | sandbox follow-up |
| 08 | update no-op / not-found / patch | clean milestone; missing milestone; gapped issue | update is idempotent (clean → no-op); milestone-not-found → error-and-stop; gapped body patched | sandbox follow-up |
| 09 | slug→#n at scale | >26 candidates | substring-safe slug rewrite (`#A` not corrupting `#AB`) | sandbox follow-up |
| 10 | nested layout | a nested monorepo (`siteroot/{web,api}`) where source lives only under app roots, never the repo root | bootstrapper-v0.2.0-baked nested `sourceGlobs` route issue file scope into the nested app roots, never the repo root | ✅ |
| 11 | roadmap fan-out | an oversized whole-app brief (auth, data model, invoicing, billing, screens) that spans several milestones, seeded from its own author sections | a whole-app brief routes into `build-roadmap`: **split → confirm → parallel-plan** emits the roadmap manifest + N per-milestone plan files; the **create deploy-loop** deploys them; single-milestone collapse falls back cleanly; an undecided product call parks one issue and siblings continue | plan-side ✅ now / create-loop sandbox follow-up |
| 12 | implied surfaces | a terse brief names a capability (admins emailing members) but never spells out its companion surfaces; one companion (suppression/unsubscribe) is a genuine product-call with no conventional default | the architect consults the implied-surfaces reference, fans the conventional companions (delivery-failure log + retry + audit) out as **`implied`-labeled review candidates**, **parks** the genuine product-call to needs-product-input instead of inventing it, and `plan` surfaces the implied set with the verbatim anti-fixation prompt — no auto-dump, no invented scope; a control slice with no capability/entity triggers neither | ✅ |
| 12b | implied surfaces control | a brief that names **no capability and introduces no new entity** (a plain reword of existing copy, no email/user-management/sync, etc.) | the control sibling to 12, demonstrated by its own run: the architect's clause-8 consult is a genuine no-op, zero `implied`-disposition candidates, no `[implied — review / trim / augment]` marker, no anti-fixation prompt; breakdown proceeds grounded and dependency-only, byte-for-byte as today | ✅ |
| 13 | layer-aware breakdown | a small backend brief (list + create notes + a slug helper) against a project stating a strict layering convention (`util` ← `data` ← `services` ← `controllers` ← `routes`); the service's repository is constructor-injected, so no textual type reference relates them | the architect assigns each candidate its architectural `layer` (CRUD→`data`, helper→`util`, validation→`controllers`), grounds each in the stated architecture, and keys the Wave order to the **layer** dependency — the `#C depends_on #A` layer edge a type-reference heuristic would miss — threading the `layer` into each issue body's Design block; a no-layering control degrades to today's dependency-only breakdown byte-for-byte | ✅ |
| 14 | config pointers | a styling brief (add a `danger` button variant) against a project whose colors live in a token doc (`tokens.json`, `color.danger` = a hex) and button rules in `design-system.md#Buttons`; the tempting shortcut is to resolve the color into the issue body | the issue-author POINTS the styling issue at the token + design-system docs BY PATH in its existing `## Design` block — a reference, never a pre-solved design — so the body inlines **no** resolved hex / token value; a grounded design decision with a conventional default (mirror `src/ui/Button.tsx`) is still recorded via `Convention followed:`; an absent-config control omits the pointer, inlines nothing, keeps the groundable convention, and errors on nothing | ✅ |
| 15 | prose style | a paginated-list brief carrying a literal "30 rows per page" directive; the tempting failure is to pad the authored issue to sound confident | the issue-author's authored `ISSUE_BODY` obeys the prose-style ruleset (`## Prose style` in `agents/issue-author.md`) — Summary 2–3 plain sentences, no banned filler / hedges, one declarative line per criterion / decision, no template narration — while the content-preservation guardrail keeps every completeness state, the literal "30 rows per page" directive, and the grounded `Convention followed:` citation verbatim; a padded rewrite CONTROL fails the prose assertions, and a content-dropping trim fails the guardrail | ✅ |

### 06 — the flagship, in detail

- **Project docs** (`project/`): a design-system / conventions doc stating, e.g.,
  *"All data tables: columns sortable and filterable except an Actions column; pagination
  at 30 rows per page."* This is a **standing convention**, the natural home for it.
- **Brief**: "Build these ~10 pages, each listing <entities> in a table" — and **does not
  restate** the table directive. The feeder must pull it from the project docs, apply it to
  every page-issue, and cite it.
- **Config**: `uiSurfaceGlobs` **must be set** so the page-issues classify as UI and carry the
  design spec (states / affordances / pattern) the driver's design lens checks (absent →
  everything is logic and the design spec is never authored).
- **Expected** (grader): every page-issue carries the full directive (sortable + filterable
  except actions + pagination 30/page) in its acceptance criteria, verbatim-equivalent (no
  drift, no silent weakening of "30/page"), and cites the convention — every issue drafted to
  the same bar, with no in-feeder re-author loop. Drift past the first few issues is
  the failure mode being hunted.

## The metric (RESULTS.md)

Two tables:

1. **Scorecard** — `# | scenario | expected | observed | verdict (✅/⚠️/❌) | run?`
2. **Claim → evidence map** — each concrete claim in `plugin.json` description + README
   intro → the scenario(s) that exercise it → **Demonstrated / Designed-not-run / Unbacked**.

The metric is (a) the run-now pass rate, and (b) how many claims are Demonstrated vs
Designed-not-run vs Unbacked.

## After the metric: right-size the copy

Using the claim→evidence map, rewrite the `plugin.json` description and the README intro so
each claim is either **Demonstrated** or honestly framed as design intent — never a tested
guarantee it hasn't earned. Unbacked or failing claims are removed or softened. This step is
contingent on the metric, not done up front.
