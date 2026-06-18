# Architecture

A generic decompose engine ships in the plugin; each repo supplies a thin profile
(`.milestone-config/feeder.json`) plus a substrate (the project-constitution docs
under `substrateDir`). The engine turns a feature brief into a milestone of small,
well-formed issues; the profile and substrate carry the stack, the conventions,
and the design defaults the engine grounds its decomposition in.

## Plugin contents

The as-built v0.2.0 components. The self-check gate, the `--apply` GitHub-write
path, and the `refine` skill all shipped in v0.2.0 (see
[The self-check gate](#the-self-check-gate) and [The decompose procedure](#the-decompose-procedure)).

| Component | Path | Purpose |
|---|---|---|
| Setup skill | `skills/setup/SKILL.md` | First-run profile bootstrap: infer keys from repo signals, write `.milestone-config/feeder.json`, provision the label taxonomy aligned to the driver's. Auto-invoked by `decompose` when the profile is absent. Mirrors `milestone-driver:setup`. |
| Decompose skill | `skills/decompose/SKILL.md` | Orchestrator: brief → milestone + issues. Runs Steps 0–6 (incl. the self-check gate) and emits at Step 7 — a reviewable plan file (preview, default) or the GitHub artifacts (`--apply`). `/milestone-feeder:decompose <brief>`. |
| Decomposer agent | `agents/decomposer.md` | Architect lens: brief + substrate + repo → candidate issue set + dependency edges + Wave order. One heavy reasoning step, dispatched once. Read-only. |
| Issue-author agent | `agents/issue-author.md` | Per-issue subagent: authors one issue's full spec to the §4 output contract so it passes the driver's triage clean. Read-only; returns issue text, never opens the issue. |
| Hook: `no-source-edit` | `hooks/` (`hooks.json`, `run-hook.cmd`, `.sh`, `.ps1`) | `PreToolUse` (`Write`/`Edit`/`MultiEdit`/`NotebookEdit`): unconditionally deny edits to the feeder's own `sourceGlobs`. The only mechanical gate the feeder needs — it authors no code and opens no PRs. See [The mechanical gate](#the-mechanical-gate). |
| Manifest + registration | `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `hooks/hooks.json` | Plugin metadata (incl. the `superpowers` dependency), marketplace registration, and Claude-side hook registration. |
| Refine skill | `skills/refine/SKILL.md` | Idempotent re-run against an existing milestone: re-triage live issues through the self-check gate, patch gapped bodies, fill missing edges, re-render the Wave order. `/milestone-feeder:refine <milestone>`. Creates and deletes no issues; a clean milestone is a no-op. Reuses decompose's gate (Step 6) and `--apply` write-primitives (§7-apply) by reference. |
| Self-check gate | (in `decompose`, Step 6 §6.1–§6.6; `SPEC.md` §5) | Dispatches the driver's `triage-reviewer` / `design-reviewer` against each generated issue before any emit; runs in preview too (it writes no GitHub state). Three backends — `"milestone-driver"`, `"internal"`, `false`. See [The self-check gate](#the-self-check-gate). |
| `--apply` GitHub write path | (in `decompose`, Step 7 §7-apply) | Ensures the labels idempotently, creates-or-adopts the milestone by title, opens each gate-surviving issue, rewrites slug→`#n` references, PATCHes the Wave-encoded milestone description, and files the needs-product-input report (epic comment on apply / local file otherwise). Idempotent re-apply via adopt + match-by-title. |

**Reused, not rebuilt (composability):** the self-check dispatches
`milestone-driver:triage-reviewer` and `:design-reviewer` directly against the
generated issue text (no `gh` call of their own), so the feeder's quality bar *is*
the driver's entry gate — no second, drifting definition of "well-formed"
(`SPEC.md` §3, §5). `refine` reuses the same gate and the `--apply` write-primitives
by reference rather than re-deriving a drifting copy.

## Plugin version

The plugin version lives only in `.claude-plugin/plugin.json` (currently `0.2.0`)
as the single source of truth. There is **no per-PR version machinery** — the
feeder opens no PRs and touches no branches, so the driver's bump-rides-the-PR
mechanism has nothing to ride. The version is bumped by hand when a release is cut.
`.claude-plugin/marketplace.json` carries no `version` field (Claude Code resolves
`plugin.json` first).

## Pipeline position

The feeder is the driver's direct predecessor: it produces the input the driver
assumes already exists — a milestone whose issues each pass the driver's triage
clean (`GAPS: none`). Product gaps are parked, never invented (`SPEC.md` §2).

```
feature brief (file / inline / GitHub epic issue)
        │   reads substrate (.project/) + .milestone-config/driver.json (shared keys)
        ▼
   ┌───────────────┐   milestone + issues    ┌──────────────────┐
   │ milestone-feeder │ ──────────────────────▶ │ milestone-driver │ ──▶ merged PRs
   └───────────────┘  (pass triage clean)     └──────────────────┘
        │
        └── parks PRODUCT gaps → "needs product input" report (never invents scope)
```

The park boundary is the load-bearing constraint: the feeder makes *design and
implementation* calls when the substrate or a stated repo convention supplies the
answer, and parks *product* calls — what to build, or user-facing behavior with no
conventional default — to a "needs product input" report rather than guessing them.

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
`sourceGlobs` that the feeder reads from the driver config when decomposing a target
repo (`SPEC.md` §7; `docs/profile-schema.md`).

## The decompose procedure

The `decompose` skill runs `SPEC.md` §6 Steps 0–6 (the self-check gate is Step 6)
and emits at Step 7 — a preview plan file by default, or the GitHub artifacts on
`--apply`. The self-check gate runs on **both** paths (it writes no GitHub state);
only Step 7 `--apply` writes GitHub state.

| Step | Action |
|---|---|
| 0 | Read `.milestone-config/feeder.json` (absent → auto-invoke `setup`); read the substrate under `substrateDir` (best-effort); resolve the shared keys (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`) from the driver config, plus `nonNegotiables` (the additional reviewer-profile input the gate passes through). |
| 1 | Ingest the brief — a GitHub epic issue (`#<n>`), a file path, or inline text — and normalize it internally first. |
| 2 | **Product-gap check (the park boundary):** separate product decisions (no conventional default) from design/implementation decisions (resolvable from substrate/convention). Product gaps are recorded, not guessed. |
| 3 | Dispatch the `decomposer` **once**: candidate issue set + dependency edges + Wave order, with local tags (not GitHub numbers). |
| 4 | Dispatch the `issue-author` **per candidate** (parallelizable) → each issue's full §4 spec. |
| 5 | Assemble the dependency graph; render the milestone description to the §4 Wave template (local slugs). |
| 6 | **Self-check gate** (the keystone): vet every generated issue against the same gate that fronts the driver's build loop. Iterate each FAILed issue to clean (≤2 `issue-author` re-dispatches) or park it. Runs in preview too — **no GitHub writes.** See [The self-check gate](#the-self-check-gate). |
| 7 | **Emit.** Preview (default) writes a reviewable plan file to `.milestone-feeder/plan-<slug>.md`, plus a "needs product input" report when product gaps remain — **no GitHub writes**. `--apply` runs the preview emit first (the local audit record), then creates the GitHub artifacts. |

### The Step 7 `--apply` write order

On `--apply`, the skill itself (never a dispatched agent — the agent-read-only
invariant holds) performs the GitHub writes in a fixed order. Only the
**gate-surviving** issues are created; parked and dropped issues are never created.

| Pass | Write |
|---|---|
| a | **Ensure labels idempotently** (`gh label create --force`) before any issue references them — the four-label taxonomy (`ui`/`logic`/`risk:light`/`risk:heavy`). |
| b | **Create-or-adopt the milestone by exact title** (quote-safe `env.t` resolve): no match → create; one match → adopt (reopen if closed); multiple → adopt the first and log. Never deletes. |
| c | **Create each gate-surviving issue** in Wave order, applying its `ui`/`logic` + `risk:*` labels; build the slug→`#n` map. On adopt, title-matched open issues are reused (no duplicate) and their bodies left as-is. |
| d | **Second pass — rewrite slug→`#n`** (substring-safe) in each newly-created issue body and in the milestone description, then `gh issue edit`/`gh api PATCH`. Two passes are required because numbers don't exist until pass (c). |
| e | **File the needs-product-input report** — epic comment on `--apply` when the brief was a GitHub epic, else a local file. |

Idempotent re-apply relies on stable, exact, open issue titles: the adopt +
match-by-title path reuses existing issues rather than duplicating them, and pass
(d) is a no-op against already-numeric bodies/descriptions.

## The self-check gate

Before emitting, `decompose` vets **every generated issue** with the same gate
that fronts the driver's build loop, so what the feeder emits passes the driver's
triage clean (`SPEC.md` §5; Step 6 §6.1–§6.6). Each reviewer is dispatched
**read-only against the generated text** — no `gh` call of its own. `refine` runs
the same gate against a milestone's **live** issues (real comments, the live
description, real `#n`).

### Backends (`selfCheck`)

| `selfCheck` | Backend |
|---|---|
| `"milestone-driver"` (default) | Dispatch `milestone-driver:triage-reviewer` per generated issue (and `:design-reviewer` when its triage returns `NEEDS_DESIGN_REVIEW: yes`). If the reviewers do not resolve at dispatch time, **degrade to `"internal"`** for the run (a notice, never a failure); a later single-issue non-resolution falls back to the internal checklist for that one issue. |
| `"internal"` | Run the built-in checklist mirroring the five triage criteria (consistency, buildability, completeness, dependencies, UI flag). Same pass/Blocker verdict shape, so the gate logic is backend-agnostic. |
| `false` | **Skip the gate** with a visible 🔴 warning to the user, recorded as `SKIPPED (selfCheck:false)` in the plan-file status line. Generated issues are NOT vetted. |

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
| Decompose (preview) | `/milestone-feeder:decompose <brief>` | Full procedure, Steps 0–6 (incl. the self-check gate); stops at a reviewable plan file. **No GitHub writes.** Shipped (v0.2.0). |
| Decompose (apply) | `… --apply` | Same, then creates the milestone + issues + labels (and an epic comment for a GitHub-epic brief). Shipped (v0.2.0). |
| Refine | `/milestone-feeder:refine <milestone>` | Re-triage an **existing** milestone's live issues through the self-check gate, patch gapped bodies, fill missing edges, re-render the Wave order. Preview (default) writes a diff-style patch plan; `--apply` edits the live issues. Creates and deletes no issues; a clean milestone is a true no-op (writes nothing). Shipped (v0.2.0). |

**Authoring-autonomy boundary.** The feeder makes design/implementation calls
grounded in the substrate or a stated repo convention — and cites the grounding
(`.project/<doc>.md#<section>` or a sibling `file:line`). It parks product calls —
decisions with no conventional default — to the "needs product input" report. It
authors no code, opens no PRs, and never touches branches (`SPEC.md` §8).

## Output style

The skills and agents follow a concise, tabular output norm: status and outcomes
are stated flatly, steps / gates / lists / options are presented as tables rather
than inline prose, and any item that needs a human is marked with 🔴.

---

For the product overview, see the [README](../README.md). For the full profile
reference, see [`profile-schema.md`](profile-schema.md). For adopting the feeder in
a repository, see [`consumer-setup.md`](consumer-setup.md).
