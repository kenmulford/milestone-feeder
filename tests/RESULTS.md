# RESULTS — milestone-feeder credibility harness

**What this is.** A dogfooding scorecard: the feeder run against its own `tests/scenarios/` fixtures (each = `brief.md` + a `project/` fixture + `feeder-env.md` + a blind `expected.md` grader contract). It records what the feeder actually produced versus what each scenario asserts.

**Status for v0.9.0.** The detailed scorecard below is the **v0.3.0 preview run (2026-06-19)** — the last full credibility execution. Its per-scenario `run-log.md` / `run-output.md` transcripts have been **removed**: they narrated the pre-v0.9.0 `plan` pipeline (including the in-feeder self-check gate), and a fresh run against the **installed** plugin is the pending follow-up. The suite table just below reflects the **current v0.9.0** fixtures; the historical scorecard is kept as a record and clearly marked.

> **v0.9.0 removed the model this scorecard was written around.** Through v0.8.0 the feeder ran the driver's `triage-reviewer` + `design-reviewer` itself as an in-`plan` **self-check gate** — the "keystone" the historical section below celebrates. v0.9.0 **removes that gate**: the feeder now **drafts** well-formed issues that **target** the driver's triage bar, and the driver's own triage is the single automated entry gate (you still review the plan before `create`). Every "self-check gate" / "real-reviewer gate PASS" note below is therefore **historical** — it describes the v0.3.0 pipeline, not the shipped v0.9.0 one. Product-gap parking (park a no-conventional-default decision; invent nothing) is unchanged.

## Current scenario suite (v0.9.0)

What each fixture asserts — the `expected.md` contract, not a fresh execution verdict:

| # | Scenario | What it asserts |
|---|----------|-----------------|
| 01 | clean-happy-path | small, ordered, correctly-waved milestone; an unspecified value is never invented (park or Advisory-defer) |
| 02 | product-gap-parks | a no-conventional-default decision parks; nothing invented; dependents dropped |
| 03 | design-resolvable-no-park | convention-answerable detail is resolved-and-cited, not over-parked |
| 04 | no-code-refusal | refuses to write code / open PRs; specifies the issue instead |
| 06 | cross-cutting-consistency (flagship) | a directive (the literal "30 rows per page") holds unweakened across ~10 issues |
| 10 | nested-layout | resolves an app in a nested repo layout |
| 11 | roadmap-fan-out | a multi-release brief carves into a sequenced roadmap of milestones |
| 12 | implied-surfaces | a named capability proposes its conventional companion surfaces as reviewable `implied` candidates |
| 13 | layer-aware-breakdown | issues assigned/ordered by the project's `.project` layering convention; degrades to dependency-only when none is declared |
| 14 | config-pointers | a styling issue points at `.project` config by path — a reference, never inlined token/render values |

`05-reviewer-backends` was **removed in v0.9.0** — its subject (the retired `reviewer` config key + reviewer backends) no longer exists.

## Fidelity caveat (applies to any from-repo run)

The feeder's own agents (`milestone-feeder:architect`, `:issue-author`) are not registered as dispatchable subagents when running from-repo (the plugin isn't installed in the harness session), so their *contracts* are executed via `general-purpose` subagents carrying the verbatim `agents/*.md` files — contract-faithful but proxied. A true run **after install** closes this gap. Each runner was **blind** to its `expected.md`; an independent grader scored each run.

---

## Historical scorecard — v0.3.0 preview run (2026-06-19) · superseded

> Kept as a record of the last full execution. Mode: preview-only, prose-direct. The self-check-gate framing here describes the **pre-v0.9.0** pipeline (the gate was removed in v0.9.0, above). Run-now that day: 01, 02, 03, 06.

| # | Scenario | Observed (v0.3.0 pipeline) | Verdict |
|---|----------|----------------------------|---------|
| 01 | clean happy-path | 3 issues (endpoint, rate limit, Download-CSV UI), both dependency edges, correct waves; the unspecified rate-limit *threshold* surfaced as a non-gating Advisory and was **never invented** | ✅ |
| 02 | product-gap-parks | **0 issues emitted**; featured-selection policy parked; dependents dropped; the (then-present) gate caught the author's "renders whatever the source yields" dodge | ✅ |
| 03 | design-resolvable | 5 issues, **0 parks**, every design decision cited to a real convention; the notification-taxonomy over-park trap navigated | ✅ |
| 06 | cross-cutting consistency (flagship) | 10 issues, **10/10 carry the complete unweakened directive** (literal "30" everywhere, no late-issue drift) | ✅ |

Findings from that run that still stand:

1. **`create` zero-survivors is under-specified** (surfaced by 02). When every candidate parks/drops, the `create` write path would still create a bare milestone + labels + report but **no issues** — emergent behavior, not a stated case. Recommend an explicit zero-survivors branch in the `create` write sequence, mirroring the Step-2 STOP rule. *(skill improvement)*
2. **Subagent-registration fidelity** (all from-repo runs). The feeder's own agents aren't dispatchable from-repo, so tests proxy their contracts. A true `create`/`update` run against a throwaway sandbox **after install** closes the last fidelity gap. *(test-infra)*

## Bottom line (v0.9.0)

The `tests/scenarios/` suite above is the current dogfooding contract, expanded for v0.9.0 (13 layer-aware breakdown, 14 config pointers; 05 removed with the retired gate). The last full execution recorded here is the v0.3.0 preview run; its transcripts have been removed pending a fresh run against the installed plugin. **The v0.9.0 pipeline is gate-free** — the feeder drafts issues that target the driver's triage bar rather than running that gate itself; the driver's triage is where the bar is enforced.
