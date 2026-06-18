# milestone-feeder — build-ready spec

A Claude Code plugin that turns a feature brief into a **GitHub milestone + small, well-formed issues** that `milestone-driver` can build with no human clarification. The direct predecessor of the driver.

Sibling of `milestone-driver`, same design DNA (see the suite plan: [`../dev-tools/SUITE-PLAN.md`](../dev-tools/SUITE-PLAN.md) §1). Separate plugin, separate config. Status: spec — implementation starting.

Decisions already locked: name `milestone-feeder`; config at `.milestone-config/feeder.json`; separate plugin in its own repo (suite/marketplace linkage deferred). Decisions taken as sensible defaults below are marked **Decision (default)** — veto any.

---

## 1. Purpose & scope

One job: **decompose and specify.** Input a brief; output a milestone whose issues each pass the driver's triage clean (`GAPS: none`).

Refuses, on purpose: writing code, opening PRs, touching branches, and **inventing product decisions** (what to build / user-facing behavior with no conventional default). It will make *implementation and design* decisions when the substrate or repo convention supplies the answer; it will not make *product* calls.

Success criterion is testable: everything it emits passes the same triage that gates the driver. The feeder reuses the driver's actual reviewer agents as its own acceptance gate (§5), so its quality bar *is* the driver's entry gate — no second, drifting definition of "well-formed."

---

## 2. Pipeline position

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

---

## 3. Plugin contents

| Component | Path | Purpose |
|---|---|---|
| Decompose skill | `skills/decompose/SKILL.md` | Orchestrator: brief → milestone + issues. `/milestone-feeder:decompose <brief>` |
| Refine skill | `skills/refine/SKILL.md` | Idempotent re-run against an existing milestone: re-triage, patch gapped issues, fill missing edges. `/milestone-feeder:refine <milestone>` |
| Setup skill | `skills/setup/SKILL.md` | Bootstrap `.milestone-config/feeder.json`; ensure the label taxonomy aligns with the driver's. Mirrors `milestone-driver:setup`. |
| Decomposer agent | `agents/decomposer.md` | Architect lens: brief + substrate + repo → candidate issue breakdown + dependency graph + Wave order. One heavy reasoning step, dispatched once. |
| Issue-author agent | `agents/issue-author.md` | Per-issue subagent: authors one issue's full spec to the output contract (§4). Keeps each authoring ask small — the decomposition-for-quality principle applied to writing, not just building. |
| Manifest + registration | `.claude-plugin/plugin.json`, `hooks/hooks.json` | Plugin metadata + hook registration. |
| Hook: `no-source-edit` | `hooks/` | PreToolUse (`Write`/`Edit`/`MultiEdit`/`NotebookEdit`): deny edits to `sourceGlobs`. The feeder reads code, never writes it. Only mechanical gate it needs (it authors no code and opens no PRs, so the driver's other gates don't apply). |

**Reused, not rebuilt (composability):** `milestone-driver:triage-reviewer` and `:design-reviewer` are dispatched directly as the self-check (§5). They review *provided issue text* (no `gh` call of their own — verified against their agent contracts), so the feeder runs them against generated issues **before any GitHub write**.

---

## 4. Output contract — the interface to the driver

Maps 1:1 to the five criteria the driver's triage checks. The issue-author guarantees each.

| Triage criterion | What the feeder guarantees |
|---|---|
| Consistency | Each issue's recorded design is internally non-contradictory. |
| Buildability | Every decision the criteria require is recorded, or resolvable by a *stated* repo convention — nothing left for the implementer to invent. |
| Completeness | Acceptance criteria enumerate states, branches, and error / empty / disabled paths — not just the happy path. |
| Dependencies | Hard dependencies are declared as edges, and the **milestone description encodes the Wave order** (the source triage reads via `gh api .../milestones .description`). |
| UI flag | Each issue is classified UI vs logic; UI issues carry the spec the design-reviewer needs (states, affordances, accessibility, the existing pattern to mirror). |

### Issue body template

```markdown
## Summary
<one paragraph: what changes and why, in product terms>

## Acceptance criteria
- [ ] <happy path, observable>
- [ ] <empty state>
- [ ] <error / failure path>
- [ ] <disabled / edge state>

## Design (recorded, consistent)
<the decisions an implementer would otherwise have to invent — grounded in the
substrate or a cited sibling pattern. No contradictions.>
- Convention followed: <conventions.md ref or file:line of the sibling pattern>

## Dependencies
- Depends on #<n> — <one-line reason / the exact reference>

## Classification
- Surface: UI | logic
- Risk: light | heavy   (sets the driver's risk:* override; default heavy when unsure)
```

Labels applied on `--apply`: a UI/logic label, and `risk:light` / `risk:heavy` when the feeder is confident — aligned with the driver's existing taxonomy so triage and solve read them natively.

### Milestone description template (encodes the Wave order)

```markdown
<one-paragraph milestone goal>

## Waves
- Wave 1 (parallel): #A, #B, #C
- Wave 2: #D (depends on #A, #B)
- Wave 3: #E (depends on #D)
```

Human-readable and the exact ordering source `solve-milestone` and triage consume.

---

## 5. The self-check gate (the keystone)

Before creating anything, the feeder dispatches the driver's own `triage-reviewer` (and `design-reviewer` for UI issues) against each generated issue's text plus the generated milestone description.

| Result | Action |
|---|---|
| `GAPS: none` for all issues | Proceed to emit (§6). |
| Blocker, design/implementation-resolvable | Re-dispatch `issue-author` to fix, bounded retry (**at most 2**, same cap the driver uses on every gate). |
| Blocker, genuine **product** gap | Park to the "needs product input" report; do not invent. |

**Decision (default):** self-check uses the driver's reviewers when `milestone-driver` is installed; degrades to an internal checklist mirroring the five criteria when it is absent (`selfCheck: "milestone-driver" | "internal" | false`). Reusing the real reviewers guarantees parity with the driver's entry gate.

---

## 6. Procedure (the decompose skill)

| Step | Action |
|---|---|
| 0 | Read `.milestone-config/feeder.json`; read the substrate (`.project/`); read `.milestone-config/driver.json` for shared keys (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`). Absent config → `setup`. |
| 1 | Ingest the brief (file path, inline text, or a GitHub epic issue). |
| 2 | **Product-gap check** (the park boundary): separate product decisions (no conventional default) from design/implementation decisions (resolvable from substrate/convention). Product gaps are recorded, not guessed. |
| 3 | Dispatch `decomposer`: candidate issue set (small, independently-buildable, ~one PR each) + dependency edges + Wave order. |
| 4 | Dispatch `issue-author` per issue (parallelizable) → full spec to §4. |
| 5 | Assemble the dependency graph; render the milestone description (§4). |
| 6 | **Self-check** (§5): iterate to clean or park product gaps. |
| 7 | **Emit.** Dry-run preview by default (writes a plan file for human review); `--apply` creates the milestone + issues + labels. |

**Decision (default):** dry-run preview is the default; issue creation requires `--apply`. Issue creation is consequential and the feeder is exactly the stage where human product input matters most, so preview-then-commit beats fully autonomous creation. (The driver's "park, don't prompt" is for *unattended build*; authoring scope is a deliberately reviewable step.)

---

## 7. Config schema — `.milestone-config/feeder.json`

Thin and consumer-driven, same discipline as the driver: new keys only when a real consumer needs them.

| Key | Type | Default | Purpose |
|---|---|---|---|
| `substrateDir` | string | `.project/` | Where the project-constitution docs live. |
| `selfCheck` | `"milestone-driver" \| "internal" \| false` | `"milestone-driver"` | Which reviewer backs the self-check gate. |
| `decomposerAgent` | string | `milestone-feeder:decomposer` | Override the breakdown agent (default-filled). |
| `issueAuthorAgent` | string | `milestone-feeder:issue-author` | Override the authoring agent (default-filled). |
| `issueSizeGuidance` | string | *(none)* | Optional natural-language sizing rule (e.g. "≤1 PR, ≤1 new screen"). |

Shared keys (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`) are **read from the driver config, not duplicated.**

### `.milestone-config/` migration note

Adopting `.milestone-config/` suite-wide means the driver should resolve its profile from `.milestone-config/driver.json` first, falling back to the current root `milestone-driver.json` (backward-compatible — existing repos keep working). This is a small, separate change to `milestone-driver`; track it so the shared-config-dir decision is actually realized.

---

## 8. Modes & autonomy

| Mode | Trigger | Behavior |
|---|---|---|
| Decompose (preview) | `/milestone-feeder:decompose <brief>` | Full procedure, stops at a reviewable plan file. |
| Decompose (apply) | `… --apply` | Same, then creates the milestone + issues + labels. |
| Refine | `/milestone-feeder:refine <milestone>` | Re-triage an existing milestone, patch gapped issues, fill missing edges. Idempotent. |

Authoring autonomy boundary: makes design/implementation calls grounded in the substrate; parks product calls to the "needs product input" report. Authors no code, opens no PRs, never touches branches.

---

## 9. Suggested build order (dogfood it)

Build the feeder as its own milestone the driver can run, once a minimal slice exists:

1. `setup` skill + config schema + `no-source-edit` hook (the safety/profile spine).
2. `decomposer` agent + `decompose` skill, preview-only (no GitHub writes) — produces the plan file.
3. `issue-author` agent + the §4 output contract.
4. Self-check gate (§5) wired to the driver's reviewers.
5. `--apply` (GitHub milestone + issue + label creation).
6. `refine` mode.

Steps 1–3 are the "larger defined chunk" with no irreversible side effects — the safe first build target.

---

## 10. Open questions (settle during build)

- Brief format: freeform vs a light template (a feeder "brief skill" could itself emit a structured brief). Lean: accept freeform, normalize internally first.
- Does the feeder own milestone creation, or adopt an existing milestone and only populate issues? Lean: create-or-adopt (mirror the driver's Trello adopt-or-create pattern).
- Where the "needs product input" report lives: a local file vs a comment on the epic issue. Lean: both — file in preview, epic comment on apply.
