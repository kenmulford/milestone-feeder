# tests/ — milestone-feeder credibility harness

This is not a unit-test suite — milestone-feeder has no executable code; its skills are
prose procedures an agent follows. This harness measures whether those procedures, when
**executed**, actually behave the way the README and `plugin.json` description claim.

**The scorecard is the metric.** Every concrete claim in the description must map to a
scenario that demonstrates it. A claim with no passing scenario gets dialed back. The
point is a description that is *real, tangible, and accurate* — a lighter, fully-backed
description beats a confident, unproven one.

## The one rule that makes the metric honest

The scenario **runner never sees `expected.md`.** It runs the brief blind — given only the
plan procedure and the scenario's inputs. A separate **grader** compares observed
output against `expected.md`. No teaching to the test.

## Execution model (preview-only, prose-direct)

The feeder plugin is not installed as slash commands in the harness session, so a scenario
is executed by **following the prose directly**:

1. A **runner** subagent acts as the `plan` orchestrator, following
   `skills/plan/SKILL.md` Steps 0–6 + the preview emit (the preview is `plan`'s job; `create` is the write path).
2. It dispatches subagents for the **architect** and **issue-author** roles, briefed from
   `agents/architect.md` and `agents/issue-author.md` (their contracts).
3. The **self-check gate** dispatches the **real** `milestone-driver:triage-reviewer` and
   `:design-reviewer` — the actual reviewers the claim depends on.
4. **PREVIEW only** — zero GitHub writes. The run emits the plan file (and a
   needs-product-input report when applicable) as text artifacts under the scenario folder.
5. A **grader** subagent scores observed-vs-`expected.md` → ✅ pass / ⚠️ partial / ❌ fail,
   with the observed behavior recorded.

`create` and `update` make real GitHub writes, so their scenarios (07–09) are designed
here but run later against a throwaway sandbox repo — labeled, not silently skipped.

## Layout

```
tests/
  README.md                      # this file (design + how to run + how to read RESULTS)
  scenarios/
    01-clean-happy-path/          { brief.md, project/, feeder-env.md, expected.md }
    02-product-gap-parks/         { ... }
    03-design-resolvable-no-park/ { ... }
    04-no-code-refusal/           { ... }
    05-reviewer-backends/         { ... }
    06-cross-cutting-consistency/ { ... }
    10-nested-layout/             { brief.md, project/, feeder-env.md, expected.md }
  RESULTS.md                      # scorecard + claim→evidence map (the metric)
```

Per scenario:
- `brief.md` — the input brief (the runner's only task input besides the procedure).
- `project/` — the `.project/`-style project docs the run grounds on (optional per scenario).
- `feeder-env.md` — the test config the run assumes: the `feeder.json` keys and the driver
  shared keys (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`) the run reads.
- `expected.md` — the behavioral contract (grader-only; the runner never sees it).

`tests/` is outside `sourceGlobs` and the `skills/` load path — no hook friction, never
loaded as plugin skills.

## Scenario set

| # | Scenario | Adversarial intent | Claim under test | Run now? |
|---|----------|--------------------|------------------|----------|
| 01 | clean happy-path | well-specified brief, a few independent features + one real dependency | "small, well-formed issues"; Wave/dependency order encoded; self-check passes; output passes the driver's triage clean | ✅ |
| 02 | product-gap-parks | bury a decision with no conventional default | **parks product decisions to a report, never invents scope**; dependents dropped | ✅ |
| 03 | design-resolvable, no park | vague on a detail a stated convention *can* answer | park-boundary precision — resolves + cites grounding, does **not** park and does **not** invent | ✅ |
| 06 | cross-cutting consistency at scale | a standing table directive in the project docs; a brief asking for ~10 table-bearing pages, **not** restating the directive | **flagship:** the directive propagates into all ~10 issues consistently (Consistency criterion); the `design-reviewer` flags any issue that drops it; each issue cites the convention | ✅ |
| 04 | no-code refusal | brief says "implement it and open a PR" | authors no code, opens no PRs, never touches branches — stays in plan-and-specify | built, later |
| 05 | reviewer backends | run with `reviewer: false` and `reviewer: "internal"` (driver-absent degrade) | the three backends + the runtime degrade-to-internal path | built, later |
| 07 | `create` idempotency | create, then re-run | create-or-adopt by title; idempotent re-run (no dupes); never delete | sandbox follow-up |
| 08 | update no-op / not-found / patch | clean milestone; missing milestone; gapped issue | update is idempotent (clean → no-op); milestone-not-found → error-and-stop; gapped body patched | sandbox follow-up |
| 09 | slug→#n at scale | >26 candidates | substring-safe slug rewrite (`#A` not corrupting `#AB`) | sandbox follow-up |
| 10 | nested layout | a nested monorepo (`siteroot/{web,api}`) where source lives only under app roots, never the repo root | bootstrapper-v0.2.0-baked nested `sourceGlobs` route issue file scope into the nested app roots, never the repo root | ✅ |

### 06 — the flagship, in detail

- **Project docs** (`project/`): a design-system / conventions doc stating, e.g.,
  *"All data tables: columns sortable and filterable except an Actions column; pagination
  at 30 rows per page."* This is a **standing convention**, the natural home for it.
- **Brief**: "Build these ~10 pages, each listing <entities> in a table" — and **does not
  restate** the table directive. The feeder must pull it from the project docs, apply it to
  every page-issue, and cite it.
- **Config**: `uiSurfaceGlobs` **must be set** so the page-issues classify as UI and the
  `design-reviewer` engages (absent → everything is logic and the design lens is skipped).
- **Expected** (grader): every page-issue carries the full directive (sortable + filterable
  except actions + pagination 30/page) in its acceptance criteria, verbatim-equivalent (no
  drift, no silent weakening of "30/page"), cites the convention, and any issue that omits
  it is flagged by the `design-reviewer` and re-authored. Drift past the first few issues is
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
