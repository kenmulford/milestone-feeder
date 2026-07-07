# RESULTS — milestone-feeder scenario fixture catalog

**What this is.** `tests/scenarios/` holds executable fixtures (each = `brief.md` + a `project/` fixture + `feeder-env.md` + a blind `expected.md` grader contract) that specify what the feeder is supposed to do when run. This file catalogs those fixtures and what each asserts. It is deliberately **not** framed as an automated scorecard: `.github/workflows/ci.yml` runs exactly two static gates (vocabulary-purge, plugin-structure) and neither dispatches an agent runner or grader, so repeatable, machine-verified re-execution of this suite is not something CI can do — any confidence this file records comes from whichever manual run is named below, never from an automated re-run.

**Status (as of 2026-07-06).** Four scenarios have now been executed against the **installed** plugin with the real `milestone-feeder:architect` and `milestone-feeder:issue-author` agents dispatched (not proxied): **02, 03, 06 PASS; 12 PARTIAL** (see the dated run record below). This is the first execution of the current post-v0.9.0, gate-free pipeline, and it closes the old from-repo fidelity gap for those four fixtures. The other six (01, 04, 10, 11, 13, 14) remain **unexecuted**, plus the `create`/`update` sandbox scenarios. The **v0.3.0 preview run (2026-06-19)**, kept in the historical section, still backs **none** of the current claims: it exercised the removed pre-v0.9.0 pipeline through proxied `general-purpose` subagents, and its per-scenario transcripts were removed.

> **v0.9.0 removed the model this catalog's historical run was written around.** Through v0.8.0 the feeder ran the driver's `triage-reviewer` + `design-reviewer` itself as an in-`plan` **self-check gate** — the "keystone" the historical section below celebrates. v0.9.0 **removes that gate**: the feeder now **drafts** well-formed issues that **target** the driver's triage bar, and the driver's own triage is the single automated entry gate (you still review the plan before `create`). Every "self-check gate" / "real-reviewer gate PASS" note below is therefore **historical** — it describes the v0.3.0 pipeline, not the shipped v0.9.0 one. Product-gap parking (park a no-conventional-default decision; invent nothing) is unchanged.

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

## Run record: 2026-07-06 (installed plugin, real agents)

First real execution of the current pipeline. Each runner followed `skills/plan/SKILL.md` **blind to `expected.md`** and dispatched the real `milestone-feeder:architect` (once) and `milestone-feeder:issue-author` (once per surviving candidate) agents; an independent grader then scored the observed plan against `expected.md`. PREVIEW-only (zero GitHub writes). Version-ladder rungs 3-4 could not resolve offline (no live repo) and were recorded as preview-limitations, not fabricated.

| # | Scenario | Verdict | Observed |
|---|----------|---------|----------|
| 02 | product-gap-parks | ✅ PASS | 0 issues emitted; the selection-policy decision parked and cited to the scenario's own convention doc; the dependent dropped; no scope invented; no parked value leaked into a body |
| 03 | design-resolvable-no-park | ✅ PASS | 4 issues, 0 parks; the convention-answerable detail resolved-and-cited (not over-parked); every design decision cites a real convention; run resisted an injected over-park nudge |
| 06 | cross-cutting-consistency (flagship) | ✅ PASS | 9/9 authored page-issues carry the table directive complete and unweakened (literal "30" intact, each cited); the 10th parked on a genuine product gap, not fabricated |
| 12 | implied-surfaces | ⚠️ PARTIAL | product-call parked + verbatim anti-fixation prompt both correct; **but** companions that already exist as app-wide infra were absorbed as grounded rather than marked `implied`, and the control case (no-capability slice) was never exercised |

Observed artifacts live beside each fixture as `observed-2026-07-06.md`. The two `12` gaps plus two harness-integrity gaps found mid-run (a blind-run violation and a brief-contamination, both caught and re-run clean) are filed under milestone **v0.11.2**: #284 (implied-marking design call), #285 (control-case coverage), #286 (blind-runner isolation).

## Fidelity caveat (applies to any from-repo run)

The feeder's own agents (`milestone-feeder:architect`, `:issue-author`) are not always registered as dispatchable subagents when running from-repo (when the plugin isn't installed in the harness session), in which case their *contracts* are executed via `general-purpose` subagents carrying the verbatim `agents/*.md` files, contract-faithful but proxied. **Update (2026-07-06):** in the run recorded above the plugin WAS installed and the real agents dispatched, so 02/03/06/12 close this gap; the remaining six fixtures have not yet had a real-agent run. Each runner was **blind** to its `expected.md`; an independent grader scored each run.

---

## Historical run record — v0.3.0 preview run (2026-06-19) · superseded, does not back current claims

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

The `tests/scenarios/` suite above is the current dogfooding contract, expanded for v0.9.0 (13 layer-aware breakdown, 14 config pointers; 05 removed with the retired gate). This file is a **fixture catalog with a partial scorecard**: as of 2026-07-06, four scenarios (02, 03, 06 PASS; 12 PARTIAL) have run against the installed plugin (the run record above); the other six remain asserted-not-demonstrated. **The current pipeline is gate-free**: the feeder drafts issues that target the driver's triage bar rather than running that gate itself; the driver's triage is where the bar is enforced.

**The skills' "never" claims are classified in `docs/never-claims-audit.md`.** That audit maps each of the ~191 `never`/`always` occurrences in `skills/` to what backs it (write-path code fact, hook, structural invariant, error-philosophy branch, or scenario fixture). The one backing that is behavioral rather than deterministic is the scenario-asserted class, and the 2026-07-06 run **demonstrated** three of its load-bearing claims (never-invents-scope via 02, resolve-and-cite-not-over-park via 03, directive-consistency via 06); the implied-surfaces claim graded **PARTIAL** (12), tracked as #284.
