# RESULTS — milestone-feeder scenario fixture catalog

**What this is.** `tests/scenarios/` holds executable fixtures (each = `brief.md` + a `project/` fixture + `feeder-env.md` + a blind `expected.grader.md` grader contract) that specify what the feeder is supposed to do when run. This file catalogs those fixtures and what each asserts. It is deliberately **not** framed as an automated scorecard: `.github/workflows/ci.yml` runs exactly three static gates (vocabulary-purge, plugin-structure, contract-strings) and none dispatches an agent runner or grader, so repeatable, machine-verified re-execution of this suite is not something CI can do — any confidence this file records comes from whichever manual run is named below, never from an automated re-run.

**Status (as of 2026-08-13).** Scenario **06 was re-run on 2026-08-13 against the v0.14.0 tree and graded ❌ FAIL** (see the dated run record below). Its 2026-07-06 PASS stands only for the tree that run executed against, and the flagship consistency claim is **not currently demonstrated**. Four scenarios were executed on 2026-07-06 against the **installed** plugin with the real `milestone-feeder:architect` and `milestone-feeder:issue-author` agents dispatched (not proxied): **02, 03, 06 PASS; 12 PARTIAL** (see that record below). That was the first execution of the current post-v0.9.0, gate-free pipeline, and it closes the old from-repo fidelity gap for those four fixtures. The other eight (01, 04, 10, 11, 12b, 13, 14, 15) remain **unexecuted**, plus the `create`/`update` sandbox scenarios. The **v0.3.0 preview run (2026-06-19)**, kept in the historical section, still backs **none** of the current claims: it exercised the removed pre-v0.9.0 pipeline through proxied `general-purpose` subagents, and its per-scenario transcripts were removed.

> **v0.9.0 removed the model this catalog's historical run was written around.** Through v0.8.0 the feeder ran the driver's `triage-reviewer` + `design-reviewer` itself as an in-`plan` **self-check gate** — the "keystone" the historical section below celebrates. v0.9.0 **removes that gate**: the feeder now **drafts** well-formed issues that **target** the driver's triage bar, and the driver's own triage is the single automated entry gate (you still review the plan before `create`). Every "self-check gate" / "real-reviewer gate PASS" note below is therefore **historical** — it describes the v0.3.0 pipeline, not the shipped v0.9.0 one. Product-gap parking (park a no-conventional-default decision; invent nothing) is unchanged.

## Current scenario suite (v0.9.0)

What each fixture asserts — the `expected.grader.md` contract, not a fresh execution verdict:

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
| 12b | implied-surfaces-control | a capability-free, entity-free brief makes the implied-surfaces consult a no-op: zero `implied` disposition, no `[implied — review / trim / augment]` marker, no anti-fixation prompt |
| 13 | layer-aware-breakdown | issues assigned/ordered by the project's `.project` layering convention; degrades to dependency-only when none is declared |
| 14 | config-pointers | a styling issue points at `.project` config by path — a reference, never inlined token/render values |
| 15 | prose-style | the authored issue reads concise per the prose-style ruleset while every completeness state, the literal "30 rows per page" directive, and the `Convention followed:` citation survive verbatim |

`05-reviewer-backends` was **removed in v0.9.0** — its subject (the retired `reviewer` config key + reviewer backends) no longer exists.

## Run record: 2026-08-13 (v0.14.0 tree, proxied agents)

Scenario 06 only, re-run to measure the cross-issue invariants mechanism #388 activated. The run executed against `develop` at `c1bf097`, the commit that merged #388. The runner followed `skills/plan/SKILL.md` Steps 0 through 5 plus the preview emit **blind to `expected.grader.md`**, and an independent grader that took no part in the run scored the observed plan against it. PREVIEW-only (zero GitHub writes). The version ladder's rungs 3 and 4 could not resolve offline and were recorded as preview-limitations, not fabricated.

**Two variables changed against the 2026-07-06 baseline, not one.** The tree moved (v0.11.x to v0.14.0), and so did the agent-dispatch mode. The installed plugin is `0.13.2` and its `agents/architect.md` and `agents/issue-author.md` carry no invariants clause, so dispatching the registered `milestone-feeder:architect` / `:issue-author` types would have executed the pre-#388 contract against the wrong tree. Both roles were run instead as `general-purpose` subagents briefed to read the worktree's contract file in full and follow it exactly. The 2026-07-06 baseline dispatched the real registered agents. This record therefore **cannot isolate** the FAIL to the tree: proxied is not equivalent to real, which is why the "Fidelity caveat" section exists at all. This run's proxy trigger also differs from the one that section describes, since the plugin WAS installed here and was bypassed as stale rather than being absent.

| # | Scenario | Verdict | Observed |
|---|----------|---------|----------|
| 06 | cross-cutting-consistency (flagship) | ❌ FAIL | **#C (Products) drops the pagination directive outright:** its four acceptance criteria state no page size at all, so the literal "30" does not survive, and they state only the Actions exception without the positive sortable-plus-filterable rule. 13 candidates returned, 12 authored, #J (Audit Log) pre-parked. All 12 authored candidates are classified `ui` and none is `logic`, so the third FAIL trigger did not fire; #J is a marker line with no body, carrying no classification at all |

**Two fractions, because the grader contract defines the directive twice.** `expected.grader.md ("each carries the FULL directive in its acceptance criteria")` lists FIVE elements (sortable plus filterable except Actions, pagination literally "30", empty state, loading skeleton, reuse `DataTable`), while `("carries the COMPLETE, unweakened directive")` and `(FAIL if)` name only the first two. Both figures are recorded so a future run is comparable either way:

- **8/9 on the FAIL-triggering directive** (sortable/filterable plus the literal "30"). This is the verdict's basis, and the tiering it uses is the one recorded on issue #389, not a narrowing invented here.
- **5/9 on the full five-element MUST list.** Only #A, #B, #F, #G, #I carry all five in their acceptance criteria. #C misses three; #D and #E miss the loading skeleton; #H misses the skeleton and `DataTable` reuse.

The denominator is the 9 authored page-issues, per issue #389's recorded rule that the fraction runs over authored page-issues with a genuinely parked candidate excluded. `expected.grader.md (METRIC for this scenario)` instead fixes the denominator at 10; against that denominator the two figures are 8/10 and 5/10. #K, #L, and #M are excluded because they are not among the brief's 10 entity list pages, not because they are not page surfaces: #L and #M both add row actions to the Users list page.

**Not behavior-neutral against the 2026-07-06 baseline** (9/9 authored, PASS). Drift is binary per `expected.grader.md (FAIL if)`, so one dropped directive is the verdict whatever the count.

**The finding is live, not an artifact of the tree the run executed against.** #391 recast `skills/plan/SKILL.md` after this run, rewriting 244 lines. The Step 4 invariant check is byte-identical at `c1bf097` and after that recast, so the mechanism that produced this FAIL is unchanged on current `develop`. The branch carrying this record was merged up to `develop` after the run, so its HEAD sits past `c1bf097`. Reproduce against `c1bf097` itself, never against the branch tip.

**The mechanism did fire, and it did work once.** #D's first return paraphrased the row-actions invariant rather than transcribing it; the substring test caught that, the single bounded re-dispatch fired, and the retry passed all six invariant tests. #388's check is not inert. It has a specific blind spot.

**Why that check did not catch #C.** Step 4's invariant verify is a whole-`ISSUE_BODY` substring test. #C's `## Design` block carries both the sort/filter rule and the 30-rows page size verbatim, which satisfies that test while the acceptance criteria a builder is held to vary freely. A directive can therefore sit in a body and be absent from every criterion, which is exactly what #C is.

**The emit's own grounding block over-counts, and is not a check.** Its six invariant lines report application to "all 13 candidates" (sortable/filterable and `DataTable`), "all 11 table-rendering candidates" (pagination), and "all 10 entity list pages" (empty and loading states). Only 12 candidates have bodies and only 9 entity list pages were authored, so three of those denominators are wrong. Treat that section as a self-report, never as verification.

**The #J park is contested.** The grader read it as over-parked rather than a clean product gap: the audit-mutability question fences to the row-actions column, not to the page, and everything this scenario measures on that page is fully determined by `project/design-system.md`. The same run treated an equally unresolved delete-semantics gap as non-blocking for the other nine entities. Recorded as an observation; it does not change the verdict, which #C already forces. No counterfactual fraction is stated, because the two available ones (an authored #J carrying the directive, or an unauthored #J counted as a miss) point opposite ways and neither is observed.

**Record-integrity defect: the `Brief line:` chain.** Three compounding alterations in `needs-product-input-observed-2026-08-13.md` put normalized text under a label that reads as a quotation from `brief.md`. First, Step 1's normalization expanded "Build the admin list pages" into "the admin app's list pages, one page per admin entity"; that content appears in neither `brief.md` nor the emitted plan file, so it exists only in the architect's `brief_ref` and the report's render. Second, `Brief line:` / `Brief lines:` is itself a composition, folding `brief_ref` into a column the report template does not define. Third, two strings were altered at render time: gap 4's separator, an em-dash in the normalization, renders as a comma, and gaps 2 AND 3 both carry the same paraphrase ("each row carries row actions: view / edit / delete" against the brief's "plus row actions (view / edit / delete)"). The architect transcribed faithfully; the drift is upstream and downstream of it.

Only gap 4's separator needs the architect's return to settle, and this record does not hold that return. The paraphrase in gaps 2 and 3 is a direct diff against `brief.md` and takes one command to re-check, as does the absent normalization string. The artifacts sit under `tests/scenarios/06-cross-cutting-consistency/`.

The artifacts are left byte-verbatim as evidence and are deliberately NOT corrected in place. Editing a run's output so the record reads clean would falsify the record and erase the finding. Every citation inside the plan file itself checks out, and the directive text transcribed into the issue bodies is byte-faithful to the design-system doc, so the defect is confined to the sibling report.

**Blindness, and its disclosed exposures.** The runner opened neither `expected.grader.md` nor the prior run's observed artifacts, and was briefed with the neutral template at `tests/README.md (## Runner brief (neutral template))`, so neither discard trigger fired. The run made **15** dispatches: 1 architect plus 14 issue-author calls (12 candidates, with #D and #G each dispatched twice). The observed artifact's own attestation says "fourteen" and itemizes 13; **#A and #D's retry are attested nowhere**. That gap is recorded here rather than papered over, because this is the one claim in a blind-run record that has to be exact.

**Eight exposures were self-disclosed, one of them material.** The architect and the first #B, #C, #D, #E, and #F dispatches each ran an `ls` or `find` that printed the three prohibited filenames, filenames only. The first `#G` dispatch ran a worktree-wide `grep -l` whose process read the bytes of three `observed-2026-07-06.md` files as a pattern test; that return was discarded and `#G` re-dispatched clean, matching the remediation at `tests/scenarios/03-design-resolvable-no-park/observed-2026-07-06.md (Preview-run notes)`. The first `#F` dispatch read a historical plan file in the host repo's scratch dir and **its body was retained**; the two bodies were compared afterward and diverge substantively (opposite calls on the delete-confirm dialog, different risk class), and neither string that prompted the check traces to that file. Detection is self-report throughout, the standing convention here.

## Run record: 2026-07-06 (installed plugin, real agents)

First real execution of the current pipeline. Each runner followed `skills/plan/SKILL.md` **blind to `expected.grader.md`** and dispatched the real `milestone-feeder:architect` (once) and `milestone-feeder:issue-author` (once per surviving candidate) agents; an independent grader then scored the observed plan against `expected.grader.md`. PREVIEW-only (zero GitHub writes). Version-ladder rungs 3-4 could not resolve offline (no live repo) and were recorded as preview-limitations, not fabricated.

| # | Scenario | Verdict | Observed |
|---|----------|---------|----------|
| 02 | product-gap-parks | ✅ PASS | 0 issues emitted; the selection-policy decision parked and cited to the scenario's own convention doc; the dependent dropped; no scope invented; no parked value leaked into a body |
| 03 | design-resolvable-no-park | ✅ PASS | 4 issues, 0 parks; the convention-answerable detail resolved-and-cited (not over-parked); every design decision cites a real convention; run resisted an injected over-park nudge |
| 06 | cross-cutting-consistency (flagship) | ✅ PASS | 9/9 authored page-issues carry the table directive complete and unweakened (literal "30" intact, each cited); the 10th parked on a genuine product gap, not fabricated |
| 12 | implied-surfaces | ⚠️ PARTIAL (cause fixed in v0.11.2 clause 8; re-run pending) | product-call parked + verbatim anti-fixation prompt both correct; **but** companions that already exist as app-wide infra were absorbed as grounded rather than marked `implied` (rule (a), recorded on #284: mark `implied` regardless of reused infra, corrected in `agents/architect.md` clause 8; a confirming re-run of scenario 12 is pending); the control case (no-capability slice) was never exercised |

Observed artifacts live beside each fixture as `observed-2026-07-06.md`. The two `12` gaps plus two harness-integrity gaps found mid-run (a blind-run violation and a brief-contamination, both caught and re-run clean) are filed under milestone **v0.11.2**: #284 (implied-marking design call), #285 (control-case coverage), #286 (blind-runner isolation).

## Fidelity caveat (applies to any from-repo run)

The feeder's own agents (`milestone-feeder:architect`, `:issue-author`) are not always registered as dispatchable subagents when running from-repo (when the plugin isn't installed in the harness session), in which case their *contracts* are executed via `general-purpose` subagents carrying the verbatim `agents/*.md` files, contract-faithful but proxied. **Update (2026-07-06):** in the run recorded above the plugin WAS installed and the real agents dispatched, so 02/03/06/12 close this gap; the remaining eight fixtures have not yet had a real-agent run. **Update (2026-08-13): 06 reopens it.** That re-run proxied both agents deliberately, on a trigger this section does not otherwise describe: the plugin was installed but pinned at `0.13.2`, a build predating the mechanism under test, so the registered agents would have measured the wrong contract. 06 therefore no longer has a current real-agent run, and its FAIL carries the proxy caveat with it. Each runner was **blind** to its `expected.grader.md`; an independent grader scored each run.

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

The `tests/scenarios/` suite above is the current dogfooding contract, expanded for v0.9.0 (13 layer-aware breakdown, 14 config pointers; 05 removed with the retired gate). This file is a **fixture catalog with a partial scorecard**: four scenarios (02, 03, 06 PASS; 12 PARTIAL) ran against the installed plugin on 2026-07-06, and **06 was re-run on 2026-08-13 against the v0.14.0 tree and graded FAIL** (both run records above); the other eight remain asserted-not-demonstrated. **The current pipeline is gate-free**: the feeder drafts issues that target the driver's triage bar rather than running that gate itself; the driver's triage is where the bar is enforced.

**The skills' "never" claims are classified in `docs/never-claims-audit.md`.** That audit maps each of the ~191 `never`/`always` occurrences in `skills/` to what backs it (write-path code fact, hook, structural invariant, error-philosophy branch, or scenario fixture). The one backing that is behavioral rather than deterministic is the scenario-asserted class, and the 2026-07-06 run **demonstrated** three of its load-bearing claims (never-invents-scope via 02, resolve-and-cite-not-over-park via 03, directive-consistency via 06). Two of those three still stand. **Directive-consistency does not:** the 2026-08-13 re-run of 06 against the v0.14.0 tree graded FAIL on one issue dropping the pagination directive from its acceptance criteria, so that claim is currently **asserted, not demonstrated**. The implied-surfaces claim graded **PARTIAL** (12), tracked as #284.
