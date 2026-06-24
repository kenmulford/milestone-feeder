# Design philosophy

<!--
Part of your project docs (.project/). Tools read and cite this file as
`.project/design-philosophy.md#<section>`. Fill every [TBD]. A section left as
[TBD] is treated as "not specified" — tools fall back to inferred repo
convention rather than ground on a placeholder. Humans own this file; tools may
*propose* changes but never rewrite it. Keep the ## headings stable — they are
citation anchors. Add new sections by appending, not renaming.
-->

## Architectural stance
What kind of system is this, and what does it fundamentally optimize for?
A stack-agnostic, generic planning **engine** ships in the plugin; each repo supplies a thin per-repo profile (`.milestone-config/feeder.json`) plus its standing docs (`.project/`). One job: turn a feature brief into a GitHub milestone of small, well-formed issues that `milestone-driver` can build with no human clarification. It optimizes for **issues that pass the driver's triage clean (`GAPS: none`)** — its quality bar *is* the driver's entry gate, reused not redefined. Reads code; never writes it. (Grounded in `SPEC.md` §1 Purpose & scope; `docs/architecture.md` Architecture.)

## Layering & boundaries
The layers and the allowed dependency directions — what may depend on what, and what must never.
`plan` (orchestrator, Steps 0–6) dispatches the `architect` agent **once**, then the `issue-author` agent **per candidate**; the **reviewer gate** (Step 6) vets every generated issue; `plan` emits the plan file at Step 7. `create` deploys the approved plan file to GitHub; `update` reconciles a refreshed plan onto an existing milestone. **Skills orchestrate and perform GitHub writes; agents are read-only and author issue text, never opening issues themselves** (the agent-read-only invariant). The plan file is the **build artifact** — the single source of truth `create`/`update` deploy ("the plan file is the spec; GitHub is the deployment"). (Grounded in `docs/architecture.md` The plan procedure, Plugin contents, The plan file as build artifact; `SPEC.md` §3, §3.1.)

## What we optimize for
Ranked priorities, and the explicit non-goals that follow from them.
1) Issues that pass the driver's triage clean — no second, drifting definition of "well-formed" (reuse the driver's reviewers as the acceptance gate). 2) Grounded design — every recorded decision cites a `.project/<doc>.md#<section>` or a sibling `file:line`; nothing invented. 3) Composability — reuse the driver's reviewer agents and `create`'s write-primitives by reference rather than re-deriving a drifting copy. **Non-goals (refuses on purpose):** writing code, opening PRs, touching branches, and inventing **product** decisions (what to build / user-facing behavior with no conventional default). (Grounded in `SPEC.md` §1; `docs/architecture.md` Reused-not-rebuilt, Modes & autonomy.)

## One-way doors
Decisions that require human sign-off *before* they're made — irreversible or expensive-to-reverse choices.
Product calls (what to build / user-facing behavior with no conventional default) are **parked** to a "needs product input" report, never guessed — the load-bearing park boundary. A new profile key is consumer-driven: **added only when a real consumer needs it, never speculatively**. Adding a dependency is a PAUSE gate (see `library-manifest.md`). Every new feature / config key / behavior change must ship an existing-user **discovery / migration path** (the normative principle, `SPEC.md` §3.1) — non-breaking is necessary but not sufficient. (Grounded in `docs/architecture.md` Pipeline position, Modes & autonomy; `SPEC.md` §2, §3.1; `docs/profile-schema.md` Design principle.)

## Error & failure philosophy
How the system handles and surfaces failure: fail-open vs fail-closed, the user-facing error policy, logging expectations.
The mechanical gate (`no-source-edit` hook) is **fail-open**: if no `sourceGlobs` source resolves, the hook does not block (a robustness measure so a hook bug never bricks the repo). The bootstrap nudge and one-time notices are **best-effort, read-only, non-blocking** — they never stop `plan` and show at most once per clone (marker-gated). The reviewer gate degrades gracefully: `reviewer: "milestone-driver"` falls back to `"internal"` when the driver's reviewers don't resolve (a notice, never a failure); `reviewer: false` skips the gate with a visible 🔴 warning. Standing docs are read **best-effort** — a missing directory or `[TBD]` section is skipped, never grounded on. (Grounded in `docs/architecture.md` The mechanical gate; `docs/profile-schema.md` resolution chains; `CHANGELOG.md` v0.4.4/v0.4.5; `docs/consumer-setup.md` §4.)

## Testing philosophy
What we test, at what level, and what "verified" means before a change is done.
Success is testable: everything the feeder emits passes the same triage that gates the driver. End-to-end **scenarios** live under `tests/scenarios/` (01–06 today, all single-root) — each a `brief.md` + a `.milestone-config/feeder.json` fixture exercising a planning path. The cross-platform contract is verified by shipping every hook/script as a **bash + PowerShell 7+ twin** with identical behavior. `scripts/validate-plugin-structure.py` and `scripts/check-vocabulary.sh` guard structural and vocabulary invariants. (Grounded in `tests/scenarios/` 01–06; issue #118 "existing scenarios … are all single-root"; `scripts/`; `.milestone-config/driver.json` nonNegotiables.)
