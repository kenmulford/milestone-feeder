# Architecture

A generic decompose engine ships in the plugin; each repo supplies a thin profile
(`.milestone-config/feeder.json`) plus a substrate (the project-constitution docs
under `substrateDir`). The engine turns a feature brief into a milestone of small,
well-formed issues; the profile and substrate carry the stack, the conventions,
and the design defaults the engine grounds its decomposition in.

## Plugin contents

The as-built v0.1.0 components. Components marked **planned (v0.2.0)** are specified
in `SPEC.md` but not shipped in this release (see [The decompose procedure](#the-decompose-procedure)).

| Component | Path | Purpose |
|---|---|---|
| Setup skill | `skills/setup/SKILL.md` | First-run profile bootstrap: infer keys from repo signals, write `.milestone-config/feeder.json`, provision the label taxonomy aligned to the driver's. Auto-invoked by `decompose` when the profile is absent. Mirrors `milestone-driver:setup`. |
| Decompose skill | `skills/decompose/SKILL.md` | Orchestrator: brief → milestone + issues. Runs Steps 0–5 and emits a reviewable plan file. `/milestone-feeder:decompose <brief>` — **preview only** this release. |
| Decomposer agent | `agents/decomposer.md` | Architect lens: brief + substrate + repo → candidate issue set + dependency edges + Wave order. One heavy reasoning step, dispatched once. Read-only. |
| Issue-author agent | `agents/issue-author.md` | Per-issue subagent: authors one issue's full spec to the §4 output contract so it passes the driver's triage clean. Read-only; returns issue text, never opens the issue. |
| Hook: `no-source-edit` | `hooks/` (`hooks.json`, `run-hook.cmd`, `.sh`, `.ps1`) | `PreToolUse` (`Write`/`Edit`/`MultiEdit`/`NotebookEdit`): unconditionally deny edits to the feeder's own `sourceGlobs`. The only mechanical gate the feeder needs — it authors no code and opens no PRs. See [The mechanical gate](#the-mechanical-gate). |
| Manifest + registration | `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `hooks/hooks.json` | Plugin metadata (incl. the `superpowers` dependency), marketplace registration, and Claude-side hook registration. |
| Refine skill | `skills/refine/SKILL.md` | **Planned (v0.2.0).** Idempotent re-run against an existing milestone: re-triage, patch gapped issues, fill missing edges. |
| Self-check gate | (in `decompose`, §5) | **Planned (v0.2.0).** Dispatches the driver's `triage-reviewer` / `design-reviewer` against each generated issue before any emit. |
| `--apply` GitHub write path | (in `decompose`, Step 7) | **Planned (v0.2.0).** Creates the milestone + issues + labels. This release writes no GitHub state on any path. |

**Reused, not rebuilt (composability):** the v0.2.0 self-check dispatches
`milestone-driver:triage-reviewer` and `:design-reviewer` directly against the
generated issue text (no `gh` call of their own), so the feeder's quality bar *is*
the driver's entry gate — no second, drifting definition of "well-formed"
(`SPEC.md` §3, §5).

## Plugin version

The plugin version lives only in `.claude-plugin/plugin.json` (currently `0.1.0`)
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

The `decompose` skill runs `SPEC.md` §6 Steps 0–5 and emits a preview plan file at
Step 6. Steps 6 (self-check) and 7 (`--apply`) are **planned for v0.2.0** — the
preview pipeline is complete and self-contained without them.

| Step | Action |
|---|---|
| 0 | Read `.milestone-config/feeder.json` (absent → auto-invoke `setup`); read the substrate under `substrateDir` (best-effort); resolve the shared keys (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`) from the driver config. |
| 1 | Ingest the brief — a GitHub epic issue (`#<n>`), a file path, or inline text — and normalize it internally first. |
| 2 | **Product-gap check (the park boundary):** separate product decisions (no conventional default) from design/implementation decisions (resolvable from substrate/convention). Product gaps are recorded, not guessed. |
| 3 | Dispatch the `decomposer` **once**: candidate issue set + dependency edges + Wave order, with local tags (not GitHub numbers). |
| 4 | Dispatch the `issue-author` **per candidate** (parallelizable) → each issue's full §4 spec. |
| 5 | Assemble the dependency graph; render the milestone description to the §4 Wave template (local slugs). |
| 6 | **Emit (preview):** write a reviewable plan file to `.milestone-feeder/plan-<slug>.md`, plus a "needs product input" report when product gaps remain. **No GitHub writes.** |

> **Planned (v0.2.0).** Step 6 self-check — dispatch the driver's `triage-reviewer`
> (and `design-reviewer` for UI issues) against each generated issue, iterate to
> clean or park, bounded retry (at most 2) — and Step 7 `--apply` (real GitHub
> milestone + issue + label creation) ship in v0.2.0 (`SPEC.md` §6, §9). This
> release recognizes the `--apply` token but writes no GitHub state on any path;
> the plan file's self-check line records the gate as **deferred**, not passed.

## Modes & autonomy

| Mode | Trigger | Behavior |
|---|---|---|
| Decompose (preview) | `/milestone-feeder:decompose <brief>` | Full procedure, Steps 0–5; stops at a reviewable plan file. **No GitHub writes.** Shipped. |
| Decompose (apply) | `… --apply` | Same, then creates the milestone + issues + labels. **Planned (v0.2.0).** The token is recognized but unimplemented this release. |
| Refine | `/milestone-feeder:refine <milestone>` | Re-triage an existing milestone, patch gapped issues, fill missing edges. Idempotent. **Planned (v0.2.0).** |

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
