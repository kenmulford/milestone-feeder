# Architecture

A generic planning engine ships in the plugin; each repo supplies a thin profile
(`.milestone-config/feeder.json`) plus your project's standing docs (the
constitution docs under `projectDocs`). The engine turns a feature brief into a
milestone of small, well-formed issues; the profile and standing docs carry the
stack, the conventions, and the design defaults the engine grounds the breakdown in.

## Plugin contents

The as-built components. `plan` previews to a plan file, `create` deploys the
approved plan, and `update` reconciles a refreshed plan onto an existing milestone
(see [The reviewer gate](#the-reviewer-gate) and [The plan procedure](#the-plan-procedure)).
The plan file is the **build artifact** (see [The plan file as build artifact](#the-plan-file-as-build-artifact)).

| Component | Path | Purpose |
|---|---|---|
| Setup skill | `skills/setup/SKILL.md` | First-run profile bootstrap: infer keys from repo signals, write `.milestone-config/feeder.json`, provision the label taxonomy aligned to the driver's. Auto-invoked by `plan`/`create` when the profile is absent. Mirrors `milestone-driver:setup`. |
| Plan skill | `skills/plan/SKILL.md` | Orchestrator preview: brief → a reviewable plan file. Runs Steps 0–6 (incl. the reviewer gate) and emits at Step 7 — the plan file at `.milestone-feeder/plan-<slug>.md`. **No GitHub writes.** `/milestone-feeder:plan <brief>`. |
| Create skill | `skills/create/SKILL.md` | Deploys the approved plan: reads the plan file and performs the GitHub writes (labels, create-or-adopt milestone, issues, slug→`#n` rewrite, description PATCH). Runs `plan` first only if no plan file exists. `/milestone-feeder:create <brief>`. See [The create deploy / write order](#the-create-deploy--write-order). |
| Build-roadmap skill | `skills/build-roadmap/SKILL.md` | **Internal** (invoked by `plan` Step 3.6 on an oversized whole-app brief, never a user command): dispatch `roadmap-splitter` once, surface the proposed split for confirm / merge / split / reorder / reject, and on confirmation write a roadmap manifest to `.milestone-feeder/roadmap-<slug>.md`. **No GitHub writes.** See [The roadmap](#the-roadmap). |
| Architect agent | `agents/architect.md` | Architect lens: brief + standing docs + repo → candidate issue set + dependency edges + Wave order. One heavy reasoning step, dispatched once. Read-only. Raises `SCOPE_SPANS_MULTIPLE_MILESTONES` — the signal that triggers the roadmap route. |
| Issue-author agent | `agents/issue-author.md` | Per-issue subagent: authors one issue's full spec to the §4 output contract so it passes the driver's triage clean. Read-only; returns issue text, never opens the issue. |
| Roadmap-splitter agent | `agents/roadmap-splitter.md` | Roadmap lens: an oversized whole-app brief + standing docs → a strict, build-ordered partition into named milestones (the `ROADMAP` block). Dispatched once by `build-roadmap`. Read-only. Supersedes the architect's passive multi-milestone advisory with a real, ordered split. |
| Brief-coverage-verifier agent | `agents/brief-coverage-verifier.md` | Coverage-audit lens: audits the read-back content of every created milestone + issue against the **original** brief and returns a coverage punch-list. Dispatched once by `create` Step 3V. Read-only; runs no `gh` of its own — `create` does the read-back and hands it the content. See [The create deploy / write order](#the-create-deploy--write-order). |
| Hook: `no-source-edit` | `hooks/` (`hooks.json`, `run-hook.cmd`, `.sh`, `.ps1`) | `PreToolUse` (`Write`/`Edit`/`MultiEdit`/`NotebookEdit`): unconditionally deny edits to the feeder's own `sourceGlobs`. The only mechanical gate the feeder needs — it authors no code and opens no PRs. See [The mechanical gate](#the-mechanical-gate). |
| Manifest + registration | `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `hooks/hooks.json` | Plugin metadata (incl. the `superpowers` dependency), marketplace registration, and Claude-side hook registration. |
| Update skill | `skills/update/SKILL.md` | Plan-driven reconcile against an existing milestone: re-triage live issues through the reviewer gate, patch gapped bodies, fill missing edges, re-render the Wave order. `/milestone-feeder:update <brief>`. Creates and deletes no issues; a clean milestone is a no-op. Reuses the reviewer gate (Step 6) and `create`'s write-primitives by reference. |
| Reviewer gate | (in `plan`, Step 6 §6.1–§6.6; `SPEC.md` §5) | Dispatches the driver's `triage-reviewer` / `design-reviewer` against each generated issue before any emit; it writes no GitHub state. Three backends — `"milestone-driver"`, `"internal"`, `false`. See [The reviewer gate](#the-reviewer-gate). |
| `create` GitHub write path | (in `create`, §7-apply deploy sequence) | Ensures the labels idempotently, creates-or-adopts the milestone by title, opens each gate-surviving issue, rewrites slug→`#n` references, PATCHes the Wave-encoded milestone description, and files the needs-product-input report (epic comment for a GitHub-epic brief / local file otherwise). Idempotent re-run via adopt + match-by-title. |

**Reused, not rebuilt (composability):** the reviewer gate dispatches
`milestone-driver:triage-reviewer` and `:design-reviewer` directly against the
generated issue text (no `gh` call of their own), so the feeder's quality bar *is*
the driver's entry gate — no second, drifting definition of "well-formed"
(`SPEC.md` §3, §5). `update` reuses the same gate and `create`'s write-primitives
by reference rather than re-deriving a drifting copy.

## The plan file as build artifact

The plan file is the **build artifact** — the single source of truth `create` and
`update` deploy (`SPEC.md`; spec §3). The mental model: **the plan file is the
spec; GitHub is the deployment.** `plan` compiles it; `create` deploys it fresh;
`update` re-deploys it onto an existing milestone.

`plan` writes it to a gitignored scratch path, named by a **deterministic slug** of
the milestone goal so `create`/`update` can find it from the same brief:

```
.milestone-feeder/plan-<slug>.md
```

The plan file carries, unambiguously: the exact milestone title + one-line goal;
the wave-encoded milestone description (local slugs `#A`/`#B`); per surviving issue
its slug, title, full §4 body, labels, and surface/risk; the parked and dropped
issues (marked, never created); the reviewer-gate verdict line; and the source-brief
reference. `create` reads it and deploys **exactly** it — no pipeline re-run, no
re-vet (it trusts the recorded gate verdict). The slug→`#n` rewrite still happens at
write time, because issue numbers do not exist until creation; what changed from
v0.2.0 is **only** the source of the issue bodies/labels/waves — read from the plan
file, not regenerated.

## Plugin version

The plugin version's single source of truth is `.claude-plugin/plugin.json`.
There is **no per-PR version machinery** — the
feeder opens no PRs and touches no branches, so the driver's bump-rides-the-PR
mechanism has nothing to ride. The version is bumped by hand when a release is cut.
`.claude-plugin/marketplace.json` carries no `version` field (Claude Code resolves
`plugin.json` first).

When this repo is itself built by `milestone-driver`, the driver bumps
`plugin.json` on the milestone's first PR — its standard behavior; the by-hand
bump above is for a release cut outside a driver run.

### Release checklist

When a release is cut, bump `.claude-plugin/plugin.json` `version` — the single
source of truth. The `SPEC.md` as-built header carries no version, so there is
nothing to re-sync there.

Any other hand-maintained in-doc version reference (e.g. the `README.md` status
line) should be re-synced to match `plugin.json`. A future releaser — a human, or
the driver's per-release docs-sweep issue — should run this re-sync as part of
cutting the release.

## Pipeline position

The feeder is the driver's direct predecessor: it produces the input the driver
assumes already exists — a milestone whose issues each pass the driver's triage
clean (`GAPS: none`). Product gaps are parked, never invented (`SPEC.md` §2).

```
feature brief (file / inline / GitHub epic issue)
        │   reads your project's standing docs (.project/) + .milestone-config/driver.json (shared keys)
        ▼
   ┌───────────────┐   milestone + issues    ┌──────────────────┐
   │ milestone-feeder │ ──────────────────────▶ │ milestone-driver │ ──▶ merged PRs
   └───────────────┘  (pass triage clean)     └──────────────────┘
        │
        └── parks PRODUCT gaps → "needs product input" report (never invents scope)
```

The park boundary is the load-bearing constraint: the feeder makes *design and
implementation* calls when your project's standing docs or a stated repo convention
supplies the answer, and parks *product* calls — what to build, or user-facing
behavior with no conventional default — to a "needs product input" report rather
than guessing them.

## The mechanical gate

One `PreToolUse` hook, registered in `hooks/hooks.json` and invoked via the
bash-first / pwsh-fallback `run-hook.cmd` launcher (fail-open). The feeder reads
code and authors issue text — it never writes source — so the deny is
**unconditional** (no subagent carve-out, unlike the driver's `force-subagent`).

| Gate | Matcher | Mechanism |
|---|---|---|
| `no-source-edit` | `Write` / `Edit` / `MultiEdit` / `NotebookEdit` | Unconditionally denies edits to the resolved `sourceGlobs`. Resolution: `<repo>/.milestone-config/feeder.json` first (self-protection of the feeder's own repo), then the driver config (`.milestone-config/driver.json` → root `milestone-driver.json`), else **fail-open**. `docs/**`, `.claude/**`, and `Obsidian/**` are always exempt. Escape hatch: `CLAUDE_HOOK_DISABLE_NO_SOURCE_EDIT=1`. |

The `sourceGlobs` this gate reads is **self-protection only** — the feeder guarding
its own repo — and is semantically distinct from the *consumer's* shared
`sourceGlobs` that the feeder reads from the driver config when planning a target
repo (`SPEC.md` §7; `docs/profile-schema.md`).

## The plan procedure

The `plan` skill runs `SPEC.md` §6 Steps 0–6 (the reviewer gate is Step 6) and
emits the plan file at Step 7. It writes **no GitHub state** — the reviewer gate
writes none either. `create` then deploys the emitted plan file (see
[The create deploy / write order](#the-create-deploy--write-order)).

| Step | Action |
|---|---|
| 0 | Read `.milestone-config/feeder.json` (absent → auto-invoke `setup`); read your project's standing docs under `projectDocs` (best-effort); resolve the shared keys (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`) from the driver config, plus `nonNegotiables` (the additional reviewer-profile input the gate passes through). |
| 1 | Ingest the brief — a GitHub epic issue (`#<n>`), a file path, or inline text — and normalize it internally first. |
| 2 | **Product-gap check (the park boundary):** separate product decisions (no conventional default) from design/implementation decisions (resolvable from the standing docs/convention). Product gaps are recorded, not guessed. |
| 3 | Dispatch the architect (`architectAgent`) **once**: candidate issue set + dependency edges + Wave order, with local tags (not GitHub numbers). |
| 4 | Dispatch the `issue-author` **per candidate** (parallelizable) → each issue's full §4 spec. |
| 5 | Assemble the dependency graph; render the milestone description to the §4 Wave template (local slugs). |
| 6 | **Reviewer gate** (the keystone): vet every generated issue against the same gate that fronts the driver's build loop. Iterate each FAILed issue to clean (≤2 `issue-author` re-dispatches) or park it. **No GitHub writes.** See [The reviewer gate](#the-reviewer-gate). |
| 7 | **Emit the plan file.** Write the reviewable plan file to `.milestone-feeder/plan-<slug>.md` — the build artifact `create`/`update` deploy — plus a "needs product input" report when product gaps remain. **No GitHub writes.** |

### The roadmap

Steps 1–7 above are a **callable single-milestone inner routine**; Step 0 is the
once-per-run outer boundary. `plan` wraps the routine in a **conditional outer
loop**:

- **Single / normal brief (the default).** The architect's
  `SCOPE_SPANS_MULTIPLE_MILESTONES` signal is `none` — `plan` runs the inner
  routine **exactly once** on the whole brief. Byte-for-byte the prior behavior.
- **Oversized whole-app brief.** The architect raises the signal, and `plan`'s
  front-door (Step 3.6) routes the brief into the internal **`build-roadmap`**
  skill: it dispatches `roadmap-splitter` once for a build-ordered partition of the
  brief into named milestones, surfaces the split for the user to **confirm / merge
  / split / reorder / reject** (one up-front sign-off, before anything is written),
  and on confirmation writes a **roadmap manifest**
  (`.milestone-feeder/roadmap-<slug>.md`) carrying the milestone build order and the
  full original brief. `plan` (Step 3.7) then runs the inner routine **once per
  milestone, in build order**, fanning the per-milestone planning out in parallel —
  each milestone's version + title resolved once on the main thread before the
  fan-out, and emitted to its own plan file.

The signal is the **sole arbiter** of "oversized" — the front-door adds no second
threshold. Steps 3.6/3.7 are outer orchestration; a dispatched per-milestone routine
never re-enters them, so the fan-out cannot recurse. A user who declines the split,
or a brief the splitter resolves to a single milestone, falls straight back to the
single-milestone plan. **No new config key** — the roadmap reuses the existing
`projectDocs` grounding; a one-time per-clone notice in `plan` Step 0 announces the
routing to existing users (`SPEC.md` §3.1, the discovery-path principle).

### The create deploy / write order

`create` reads the plan file (running `plan` first only when no plan file exists)
and deploys it. The skill itself (never a dispatched agent — the agent-read-only
invariant holds) performs the GitHub writes in a fixed order. Only the
**gate-surviving** issues are created; parked and dropped issues are never created.

| Pass | Write |
|---|---|
| a | **Ensure labels idempotently** (`gh label create --force`) before any issue references them — the four-label taxonomy (`ui`/`logic`/`risk:light`/`risk:heavy`). |
| b | **Create-or-adopt the milestone by exact title** (quote-safe `env.t` resolve): no match → create; one match → adopt (reopen if closed); multiple → adopt the first and log. Never deletes. |
| c | **Create each gate-surviving issue** in Wave order, applying its `ui`/`logic` + `risk:*` labels; build the slug→`#n` map. On adopt, title-matched open issues are reused (no duplicate) and their bodies left as-is. |
| d | **Second pass — rewrite slug→`#n`** (substring-safe) in each newly-created issue body and in the milestone description, then `gh issue edit`/`gh api PATCH`. Two passes are required because numbers don't exist until pass (c). |
| e | **File the needs-product-input report** — epic comment when the brief was a GitHub epic, else a local file. |

Idempotent re-run relies on stable, exact, open issue titles: the adopt +
match-by-title path reuses existing issues rather than duplicating them, and pass
(d) is a no-op against already-numeric bodies/descriptions.

**A roadmap of N milestones (Step 1R).** When `plan`'s roadmap flow left a **roadmap
manifest** for the brief, `create` deploys **all N** milestones in one run by
**looping the per-plan deploy above** (passes a–e, unchanged) over the manifest's
milestones in build order — adding only the outer loop. Each milestone's description
gains one canonical `build order: milestone X of N` line (the cross-milestone
position the driver reads to build the roadmap in sequence), ridden inside pass (d)'s
REPLACE-form PATCH so it stays idempotent — the count never grows. The single-plan
path is the **N=1** case, byte-for-byte unchanged; a mid-loop failure stops and
reports, deletes nothing, and a re-run resumes (already-deployed milestones adopted
by exact title, the rest deployed).

**Closing verification — coverage against the original brief (Step 3V).** After the
deploy loop (single-plan Step 3 / roadmap Step 1R) and before the optional Step-4
handoff, `create` reads **every** deployed milestone + issue back from live GitHub
and dispatches `brief-coverage-verifier` once against the **original** brief
(resolved in-session, else from the persisted `## Original brief` … `## End original
brief` copy — the roadmap manifest on a roadmap run, the plan file otherwise; else a
non-blocking "original brief unavailable" notice, never a fabricated brief). It surfaces a coverage
punch-list — uncovered / duplicated / distorted brief parts, plus any read-errors —
routed exactly like the needs-input report. It is **always-on** (every `create`,
single-milestone included) and **best-effort / non-blocking**: it never blocks
`create`, the handoff, or any merge, and never auto-fixes, edits, reopens, or
comments-to-fix any deployed issue or milestone (`SPEC.md` §3.1).

After the write sequence (a–e) and the closing verification, `create` runs a
top-level **Step 4 — the driver handoff**. It is **not** a GitHub write and is **not** part of the pass-(d)
idempotent-re-run guarantee — it is a post-deploy skill invocation; see
[The create → driver handoff](#the-create--driver-handoff).

### The create → driver handoff

After a **clean** deploy, `create` can hand the milestone straight to
`milestone-driver` to start building — invoking
`/milestone-driver:solve-milestone "<exact milestone title>"`, the title `create`
deployed. This is a **post-deploy skill invocation, not a GitHub write** — it
authors nothing on GitHub; it kicks off the driver. Because it is not a write, it
is **not** part of the pass-(d) idempotent-re-run guarantee: re-running `create`
after a handoff fired would **re-offer** (or, under `"auto"`, re-fire) the handoff,
not no-op. It is modelled as `create`'s top-level **Step 4**, run after the pass
a–e write sequence, not as a sixth write pass.

The `autoHandoff` own-key (default `"prompt"`) governs it: `"prompt"`
asks first, `"auto"` kicks off immediately, `"off"` never offers. Three gates must
all hold: the run is **clean** — no product gap, nothing parked/dropped (the
`## Needs human input` pointer is "none") **AND** the self-check actually ran (the
plan file's `Self-check:` verdict is a real `PASS` / `INTERNAL`, **not**
`SKIPPED(reviewer:false)` — a `reviewer: false` run skips the gate, leaving its
issues unvetted, so it is a clean-run fail even with a "none" pointer); the driver
resolves in this session (absent → **silently skipped**, no prompt / no error); and
the handoff is **build-kickoff only** — `solve-milestone` merges to the integration
branch and `develop → main` stays a manual human call. It never auto-merges to a
protected branch and never removes the release gate.

## The reviewer gate

Before emitting, `plan` vets **every generated issue** with the same gate
that fronts the driver's build loop, so what the feeder emits passes the driver's
triage clean (`SPEC.md` §5; Step 6 §6.1–§6.6). Each reviewer is dispatched
**read-only against the generated text** — no `gh` call of its own. `update` runs
the same gate against a milestone's **live** issues (real comments, the live
description, real `#n`).

### Backends (`reviewer`)

| `reviewer` | Backend |
|---|---|
| `"milestone-driver"` (default) | Dispatch `milestone-driver:triage-reviewer` per generated issue (and `:design-reviewer` when its triage returns `NEEDS_DESIGN_REVIEW: yes`). If the reviewers do not resolve at dispatch time, **degrade to `"internal"`** for the run (a notice, never a failure); a later single-issue non-resolution falls back to the internal checklist for that one issue. |
| `"internal"` | Run the built-in checklist mirroring the five triage criteria (consistency, buildability, completeness, dependencies, UI flag). Same pass/Blocker verdict shape, so the gate logic is backend-agnostic. |
| `false` | **Skip the gate** with a visible 🔴 warning to the user, recorded as `SKIPPED (reviewer:false)` in the plan-file status line. Generated issues are NOT vetted. |

### Result → action (`SPEC.md` §5)

| Aggregated result | Action |
|---|---|
| `GAPS: none` for every dispatched block | **PASS** — the issue clears the gate; proceed to emit (Step 7). |
| Blocker, design/implementation-resolvable | **Re-dispatch `issue-author`** to fix, bounded to **≤2** re-dispatches per issue (the same cap the driver uses on every gate), then re-run the gate. |
| Blocker, genuine **product** gap | **Park** to the "needs product input" report; never invented. |
| Still-Blocker after 2 retries | **Park as needs-human-direction** (the candidate's design is likely wrong). |

`severity: Advisory` entries do **not** fail the gate — they are recorded as notes,
not retried. An `undeclared-dependency` Blocker is absorbed into the graph and the
Wave order re-rendered (§6.6), not routed through the re-author path. A parked issue
and every issue that transitively depends on it are dropped from the emitted
milestone.

## Modes & autonomy

| Mode | Trigger | Behavior |
|---|---|---|
| Plan | `/milestone-feeder:plan <brief>` | Full procedure, Steps 0–6 (incl. the reviewer gate); stops at the plan file. **No GitHub writes.** |
| Create | `/milestone-feeder:create <brief>` | Deploys the approved plan: ensures the labels, creates the milestone + issues (and an epic comment for a GitHub-epic brief). Runs `plan` first only when no plan file exists. |
| Update | `/milestone-feeder:update <brief>` | Reconcile a refreshed plan onto an **existing** milestone (matched by exact title) through the reviewer gate — patch gapped bodies, fill missing edges, re-render the Wave order, showing the diff before it writes. **Never closes/deletes**; a live issue absent from the plan is flagged for your decision; a clean milestone is a true no-op (writes nothing). |

**Authoring-autonomy boundary.** The feeder makes design/implementation calls
grounded in your project's standing docs or a stated repo convention — and cites
the grounding (`.project/<doc>.md#<section>` or a sibling `file:line`). It parks
product calls — decisions with no conventional default — to the "needs product
input" report. It authors no code, opens no PRs, and never touches branches
(`SPEC.md` §8).

## Output style

The skills and agents follow a concise, tabular output norm: status and outcomes
are stated flatly, steps / gates / lists / options are presented as tables rather
than inline prose, and any item that needs a human is marked with 🔴.

---

For the product overview, see the [README](../README.md). For the full profile
reference, see [`profile-schema.md`](profile-schema.md). For adopting the feeder in
a repository, see [`consumer-setup.md`](consumer-setup.md).
