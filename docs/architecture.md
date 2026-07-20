# Architecture

A generic planning engine ships in the plugin; each repo supplies a thin profile
(`.milestone-config/feeder.json`) plus your project's standing docs (the
constitution docs under `projectDocs`). The engine turns a feature brief into a
milestone of small, well-formed issues; the profile and standing docs carry the
stack, the conventions, and the design defaults the engine grounds the breakdown in.

## Plugin contents

The as-built components. `plan` previews to a plan file, `create` deploys the
approved plan, and `update` reconciles a refreshed plan onto an existing milestone
(see [The quality bar](#the-quality-bar) and [The plan procedure](#the-plan-procedure)).
The plan file is the **build artifact** (see [The plan file as build artifact](#the-plan-file-as-build-artifact)).

| Component | Path | Purpose |
|---|---|---|
| Setup skill | `skills/setup/SKILL.md` | First-run profile bootstrap: infer keys from repo signals, write `.milestone-config/feeder.json`, provision the label taxonomy aligned to the driver's. Auto-invoked by `plan`/`create` when the profile is absent. Mirrors `milestone-driver:setup`. |
| Plan skill | `skills/plan/SKILL.md` | Orchestrator preview: brief → a reviewable plan file. Runs Steps 0–5 and emits at Step 7 — the plan file at `.milestone-feeder/plan-<slug>.md`. **No GitHub writes.** `/milestone-feeder:plan <brief>`. |
| Create skill | `skills/create/SKILL.md` | Deploys the approved plan: reads the plan file and performs the GitHub writes (labels, create-or-adopt milestone, issues, slug→`#n` rewrite, description PATCH). Runs `plan` first only if no plan file exists. `/milestone-feeder:create <brief>`. See [The create deploy / write order](#the-create-deploy--write-order). |
| Build-roadmap skill | `skills/build-roadmap/SKILL.md` | **Internal** (invoked by `plan` Step 3.6 on an oversized whole-app brief, never a user command): dispatch `roadmap-splitter` once, surface the proposed split for confirm / merge / split / reorder / reject, and on confirmation write a roadmap manifest to `.milestone-feeder/roadmap-<slug>.md`. **No GitHub writes.** See [The roadmap](#the-roadmap). |
| Architect agent | `agents/architect.md` | Architect lens: brief + standing docs + repo → candidate issue set + dependency edges + Wave order. One heavy reasoning step, dispatched once. Read-only. Raises `SCOPE_SPANS_MULTIPLE_MILESTONES` — the signal that triggers the roadmap route. Also consults the implied-surfaces reference and labels each conventional companion surface it proposes with the `disposition: implied` field (see [Implied surfaces](#implied-surfaces)). When the project states a layering convention, assigns each candidate its architectural `layer` and keys the Wave order to the layer dependency (see [Layer-aware breakdown](#layer-aware-breakdown)). |
| Issue-author agent | `agents/issue-author.md` | Per-issue subagent: authors one issue's full spec to the §4 output contract so it passes the driver's triage clean. Read-only; returns issue text, never opens the issue. |
| Roadmap-splitter agent | `agents/roadmap-splitter.md` | Roadmap lens: an oversized whole-app brief + standing docs → a strict, build-ordered partition into named milestones (the `ROADMAP` block). Dispatched once by `build-roadmap`. Read-only. Supersedes the architect's passive multi-milestone advisory with a real, ordered split. |
| Hook: `no-source-edit` | `hooks/` (`hooks.json`, `run-hook.cmd`, `.sh`, `.ps1`) | `PreToolUse` (`Write`/`Edit`/`MultiEdit`/`NotebookEdit`): unconditionally deny edits to the feeder's own `sourceGlobs`. The only mechanical gate the feeder needs — it authors no code and opens no PRs. See [The mechanical gate](#the-mechanical-gate). |
| Manifest + registration | `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `hooks/hooks.json` | Plugin metadata (`superpowers` is a documented prerequisite, not a manifest dependency — see `README.md`), marketplace registration, and Claude-side hook registration. |
| Update skill | `skills/update/SKILL.md` | Plan-driven reconcile against an existing milestone: reconcile the recorded plan onto the live milestone — patch gapped bodies, fill missing edges, re-render the Wave order. `/milestone-feeder:update <brief>`. Creates and deletes no issues; a clean milestone is a no-op. Reuses `create`'s write-primitives by reference. |
| Implied-surfaces reference | `docs/implied-surfaces.md` | The stack-agnostic implied-surfaces **reasoning reference** the architect consults during breakdown — the standard companion surfaces a capability or a new entity implies, framed as a reviewable floor (a robust start, never a scope-emitting catalog). Also **defines** the project-local overlay shape (`.milestone-config/implied-surfaces.md`, additive-merge: add / extend, never delete a global surface). PR-able; shipped so the capability set grows by community PR. |
| One-time-notices reference | `docs/one-time-notices.md` | The canonical source for seven one-time Step-0 units (a self-heal + six notices) shared across `plan`, `create`, and `update` — each announces a self-heal one of them performed, flags a repo-state problem to fix by hand, points at a new/optional capability, or announces a behavior change — shown at most once per clone via a per-clone marker. Reference content only; the live emitters are `skills/plan/SKILL.md`, `skills/create/SKILL.md`, and `skills/update/SKILL.md` Step 0, each iterating the sections whose `Skills` field names it. |
| Plan-file-contract reference | `docs/plan-file-contract.md` | The shared definition of the plan file's fields and output templates — the field table, the plan-file output template, and the needs-product-input report template that `create` and `update` parse. Copied verbatim from `skills/plan/SKILL.md` Step 7 so downstream skills cite one contract, not each their own. |
| Roadmap-manifest reference | `docs/roadmap-manifest-format.md` | The exact shape of the roadmap manifest `build-roadmap` writes to `.milestone-feeder/roadmap-<slug>.md` — the cross-milestone build artifact recording which milestones to plan, in what order, plus the full original brief. Read on demand by `build-roadmap` (Step 4) and its downstream `plan` / `create` consumers. |
| Create-deploy-sequence reference | `docs/create-deploy-sequence.md` | The full mechanics of `create`'s heavy deploy steps (Step 1R, the Step 3 write-sequence passes a–d, Step 4), relocated byte-for-byte from `skills/create/SKILL.md` so the skill keeps a lean orchestration skeleton. `create` reads it on demand; behavior-neutral. |
| `create` GitHub write path | (in `create`, §7-apply deploy sequence) | Ensures the labels idempotently, creates-or-adopts the milestone by title, opens each surviving issue, rewrites slug→`#n` references, PATCHes the Wave-encoded milestone description, and files the needs-product-input report (epic comment for a GitHub-epic brief / local file otherwise). Idempotent re-run via adopt + match-by-title. |

**Targets the driver's triage, does not run it.** The feeder authors every issue
to the same five criteria `milestone-driver`'s `triage-reviewer` / `design-reviewer`
check (`SPEC.md` §4), so its quality bar *is* the driver's entry gate — no second,
drifting definition of "well-formed" (`SPEC.md` §3, §5). The feeder runs **no**
reviewer of its own; the driver's triage is the single automated gate. `update`
reuses `create`'s write-primitives by reference rather than re-deriving a drifting copy.

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
issues (marked, never created); and the source-brief
reference. `create` reads it and deploys **exactly** it — no pipeline re-run, no
re-check. The slug→`#n` rewrite still happens at
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

The `plan` skill runs `SPEC.md` §6 Steps 0–5 and
emits the plan file at Step 7. It writes **no GitHub state**. `create` then deploys the emitted plan file (see
[The create deploy / write order](#the-create-deploy--write-order)).

| Step | Action |
|---|---|
| 0 | Read `.milestone-config/feeder.json` (absent → auto-invoke `setup`); read your project's standing docs under `projectDocs` (best-effort); resolve the shared keys (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`) from the driver config. |
| 1 | Ingest the brief — a GitHub epic issue (`#<n>`), a file path, or inline text — and normalize it internally first. |
| 2 | **Product-gap check (the park boundary):** separate product decisions (no conventional default) from design/implementation decisions (resolvable from the standing docs/convention). Product gaps are recorded, not guessed. |
| 3 | Dispatch the architect (`architectAgent`) **once**: candidate issue set + dependency edges + Wave order, with local tags (not GitHub numbers). |
| 3.5 | **Park candidates blocked by a shared product gap** before the fan-out, and drop their dependents (no doomed author dispatches). |
| 4 | Dispatch the `issue-author` **per candidate** (parallelizable) → each issue's full §4 spec. |
| 5 | **Drop parked issues + their dependents**; assemble the dependency graph; render the milestone description to the §4 Wave template (local slugs). |
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

### Implied surfaces

A brief that names a capability — "add email", "user management", "sync" — or
introduces a new entity quietly commits to a standard set of companion surfaces
(screens, endpoints, jobs, settings) it never spells out. So during breakdown the
architect consults the bundled **implied-surfaces reference**
([`implied-surfaces.md`](implied-surfaces.md)) — a stack-agnostic *reasoning prompt*,
not a checklist — and considers the companions each named capability or new entity
implies. It then sorts each one with the **same grounded-vs-product-gap judgment it
already applies** (`agents/architect.md` clause 8):

- A **conventional companion** with a conventional default (e.g. email → a
  delivery-failure log; a Users entity → reset-password) rides `CANDIDATES` with the
  architect's optional `disposition: implied` field — proposed as a **default-in
  candidate for review**, never committed scope.
- A **genuine product-call** with no conventional default (e.g. a suppression /
  unsubscribe policy) still **parks** via `PRODUCT_GAPS`, never silently
  pre-included. The never-invent floor (the park boundary) holds for implied
  surfaces too.

`plan` threads the `disposition` field from the architect (Step 3) through the
issue-author brief (Step 4) to the plan file (Step 7); a candidate the architect did
not mark is recorded `grounded`, byte-for-byte as before. At Step 7 `plan` renders
each `implied` candidate **distinctly** — carrying the
`[implied — review / trim / augment]` marker on its issue heading — and, **only when
the plan carries at least one implied candidate**, fires a structural
**anti-fixation prompt** at the same
confirm/override moment the user already sees the milestone identity:
`this is a starting set for YOUR app — what's missing?`. It is advisory and
non-blocking — the user reviews, trims, or augments the implied candidates before
running `create`, and every proposed surface lands in a plan reviewed before any
issue exists. When no candidate is implied, nothing here surfaces — no marker, no
prompt — exactly as before.

**The reference is a floor, not a ceiling.** It is deliberately short and
conceptual: it ensures the architect *considers* the conventional set, and never
guarantees completeness — the anti-fixation prompt is the built-in step that asks
for what a curated list can't know. A project extends it with an optional
**project-local overlay** at the fixed path `.milestone-config/implied-surfaces.md`,
which `plan` Step 0 resolves and merges into the bundled reference **additively** —
an overlay can add a capability and extend an existing one, but never remove a
surface the global reference defines (per-run trimming is the plan review's job). The
overlay is discovered by that fixed path — **no new config key**
([`profile-schema.md`](profile-schema.md)); an absent overlay (the common case) is
never an error. A one-time per-clone notice in `plan` / `update` Step 0 announces the
overlay to existing users (`SPEC.md` §3.1, the discovery-path principle).

### Layer-aware breakdown

When the project's standing docs state a **stack + layering convention**, the
architect assigns each candidate its architectural **layer** and derives the issue
order from the **layer dependency** — not only from ad-hoc type references
(`agents/architect.md` clause 9). It consults the stated architecture — primarily
`.project/design-philosophy.md#Layering & boundaries` (the layers and their allowed
dependency directions), with `.project/conventions.md#File & folder layout` (where
each layer's files live) and `.project/library-manifest.md#Runtime & frameworks`
(the stack) — places each CRUD / helper task in the layer the convention dictates,
records it as an optional per-candidate `layer` field, and emits a dependency **edge
keyed by layer** so a layer precedes the layers that depend on it. The layer edge
rides the **same Waves / topological sort** the dependency graph already uses; a
concrete artifact `depends_on` edge stays **authoritative**, and a layer edge only
orders candidates that are otherwise independent — the two compose, never conflict.

Every layer assignment and layer edge **cites the project's stated architecture**
(the same rigor gate every design call clears); a layer that cannot be grounded is
**not** assigned. A project that states **no** layering convention (the section
absent / `[TBD]`, or an unlayered stack) produces the **dependency-only** breakdown
it does today — no `layer` field, no layer edge, byte-for-byte unchanged, no
fabricated layering. `plan` threads the optional `layer` from the architect (Step 3)
through the issue-author brief (Step 4), and the issue-author **records** it as a
`Layer:` line in the issue's existing `## Design` block — so the driver sees which
layer the work sits in. The field is additive: every downstream consumer reads
`tag` / `title` / `surface` / `risk` / `sketch` and is unaffected by its presence,
and it reuses the existing `projectDocs` grounding — **no new config key** (`SPEC.md`
§3.1, layer-aware breakdown).

### Config pointers (reference, not pre-solve)

With the feeder no longer reviewing (the driver's triage is the single automated entry
gate), its job is to make sure the driver has the right config — so the issue-author
also POINTS each issue at the `.project` config the driver reads at **build time**. In
the same `## Design` block that carries `Convention followed:` and `Layer:`, keyed to
what the issue touches: styling → `.project/tokens.json` / `.project/design-system.md#<section>`;
deployment/env → `.project/environment.md` (a touched convention already rides the
`Convention followed:` line). The pointer **names the path**; it never copies or parses
the values into the body — no resolved hex, no parsed token values, no pre-solved
render. The render and tokens are the **driver's** to consume at build time; the feeder
only reminds the driver where they live. The line is additive: an issue touching none
of these, or a project missing the doc, carries no pointer, byte-for-byte as today — a
missing doc is no error and no fabricated reference. It reuses the existing `projectDocs`
grounding — **no new config key** (`SPEC.md` §4, config pointers).

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
by exact title, the rest deployed) — now short-circuited for already-fully-deployed
milestones by a per-run deploy checkpoint (`docs/create-deploy-sequence.md` → "The
deploy checkpoint (resume short-circuit, roadmap-only)").

After the write sequence (a–e), `create` runs a
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
`## Needs human input` pointer is "none"); the driver
resolves in this session (absent → **silently skipped**, no prompt / no error); and
the handoff is **build-kickoff only** — `solve-milestone` merges to the integration
branch and `develop → main` stays a manual human call. It never auto-merges to a
protected branch and never removes the release gate.

## The quality bar

The feeder's quality bar *is* the driver's entry gate: every issue it drafts is
authored to pass the driver's `triage-reviewer` (and `design-reviewer` for UI
issues) clean (`GAPS: none`) — one shared definition of "well-formed," never a
second drifting copy (`SPEC.md` §5). But the feeder runs **no** reviewer gate of its
own: it **DRAFTS** issues that **TARGET** that bar; the driver's own triage is the
**single automated entry gate**, run once after `create` when the driver picks the
milestone up. Between them stands the human, who reviews the plan file before
`create` deploys.

The `reviewer` own-key and its `"milestone-driver" | "internal" | false` backends
are **retired** — there is no in-feeder gate to configure. An existing profile that
still carries a `reviewer` key is ignored gracefully (unknown key → no error).

### How the feeder targets the bar (`SPEC.md` §5)

| Concern in the issue | How the feeder targets the bar |
|---|---|
| Design / implementation decision with a conventional default | Recorded and cited (`.project/<doc>.md#<section>` or a sibling `file:line`), so the driver's Buildability check clears. |
| Genuine **product** gap (no conventional default) | Parked to the "needs product input" report; never invented (`SPEC.md` §2 park boundary). |
| UI issue | Carries the states, affordances, accessibility, and existing pattern to mirror that the driver's `design-reviewer` checks. |

A parked (product-gap) issue and every issue that transitively depends on it are
dropped from the emitted milestone (`plan` Step 5 drop pass).

## Modes & autonomy

| Mode | Trigger | Behavior |
|---|---|---|
| Plan | `/milestone-feeder:plan <brief>` | Full procedure, Steps 0–5; stops at the plan file. **No GitHub writes.** |
| Create | `/milestone-feeder:create <brief>` | Deploys the approved plan: ensures the labels, creates the milestone + issues (and an epic comment for a GitHub-epic brief). Runs `plan` first only when no plan file exists. |
| Update | `/milestone-feeder:update <brief>` | Reconcile a refreshed plan onto an **existing** milestone (matched by exact title) — patch gapped bodies, fill missing edges, re-render the Wave order, showing the diff before it writes. **Never closes/deletes**; a live issue absent from the plan is flagged for your decision; a clean milestone is a true no-op (writes nothing). |

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
