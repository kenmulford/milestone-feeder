# milestone-feeder — as-built spec (v0.3.0)

A Claude Code plugin that turns a feature brief into a **GitHub milestone + small, well-formed issues** that `milestone-driver` can build with no human clarification. The direct predecessor of the driver.

Sibling of `milestone-driver`, same design DNA (see the suite plan: [`../dev-tools/SUITE-PLAN.md`](../dev-tools/SUITE-PLAN.md) §1). Separate plugin, separate config. Status: **as-built spec for v0.3.0** — the live surface (verbs `plan` / `create` / `update` / `setup`, no flags, plan-file-as-contract).

Decisions already locked: name `milestone-feeder`; config at `.milestone-config/feeder.json`; separate plugin in its own repo (suite/marketplace linkage deferred). Decisions taken as sensible defaults below are marked **Decision (default)** — veto any.

---

## 1. Purpose & scope

One job: **turn a brief into a milestone of small, well-formed issues.** Input a brief; output a milestone whose issues each pass the driver's triage clean (`GAPS: none`).

Refuses, on purpose: writing code, opening PRs, touching branches, and **inventing product decisions** (what to build / user-facing behavior with no conventional default). It will make *implementation and design* decisions when the project docs or a repo convention supplies the answer; it will not make *product* calls — a decision with no conventional default it **flags for your decision**, never guesses.

Success criterion is testable: everything it emits passes the same triage that gates the driver. The feeder reuses the driver's actual reviewer agents as its own acceptance gate (§5), so its quality bar *is* the driver's entry gate — no second, drifting definition of "well-formed."

---

## 2. Pipeline position

```
feature brief (file / inline / GitHub epic issue)
        │   reads project docs (.project/) + .milestone-config/driver.json (shared keys)
        ▼
   ┌───────────────┐   milestone + issues    ┌──────────────────┐
   │ milestone-feeder │ ──────────────────────▶ │ milestone-driver │ ──▶ merged PRs
   └───────────────┘  (pass triage clean)     └──────────────────┘
        │
        └── flags PRODUCT gaps for your decision → "needs product input" report (never invents scope)
```

The grounding line: `plan` reads the project's standing docs under `projectDocs` (default `.project/`) and resolves the shared keys (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`) from the driver config — never duplicated in `feeder.json`.

---

## 3. Plugin contents

| Component | Path | Trigger | Purpose |
|---|---|---|---|
| `plan` skill | `skills/plan/SKILL.md` | `/milestone-feeder:plan <brief>` | Compiles a reviewable **plan file** — brief → milestone + small, well-formed candidate issues, vetted through the self-check gate. **Read-only on GitHub** (writes only local scratch). |
| `create` skill | `skills/create/SKILL.md` | `/milestone-feeder:create <brief>` | Deploys the approved plan file to GitHub — labels + milestone + issues + build order. Read-the-plan, **faithful** (trusts the recorded verdict; regenerates nothing). |
| `update` skill | `skills/update/SKILL.md` | `/milestone-feeder:update <brief>` | Reconciles a refreshed plan onto an existing milestone — safe, **never-close**, idempotent. |
| `setup` skill | `skills/setup/SKILL.md` | `/milestone-feeder:setup` (or auto by `plan`) | Bootstraps `.milestone-config/feeder.json`; aligns the issue-label taxonomy with the driver's. Mirrors `milestone-driver:setup`. |
| `architect` agent | `agents/architect.md` (id `milestone-feeder:architect`) | dispatched by `plan`, **once** per run | The architect lens: brief + project docs + repo → candidate issues + dependency graph + build order (Wave order). One heavy reasoning step. |
| `issue-author` agent | `agents/issue-author.md` (id `milestone-feeder:issue-author`) | dispatched by `plan`, once **per candidate** | Per-issue spec authoring to the §4 output contract. Keeps each authoring ask small — the breakdown-for-quality principle applied to writing, not just building. |
| Manifest + registration | `.claude-plugin/plugin.json`, `hooks/hooks.json` | — | Plugin metadata + hook registration. |
| Hook: `no-source-edit` | `hooks/` | PreToolUse (`Write`/`Edit`/`MultiEdit`/`NotebookEdit`) | Deny edits to `sourceGlobs`. The feeder reads code, never writes it. The only mechanical gate it needs (it authors no code and opens no PRs, so the driver's other gates don't apply). |

**Reused, not rebuilt (composability):** `milestone-driver:triage-reviewer` and `:design-reviewer` are dispatched directly as the self-check (§5). They review *provided issue text* (no `gh` call of their own — verified against their agent contracts), so the feeder runs them against generated issues **before any GitHub write**, inside `plan`.

---

## 3.1 The plan-file contract — the load-bearing build artifact

The plan file is the **interface** between `plan` (which writes it) and `create` / `update` (which read it, and regenerate nothing). The mental model: **the plan file is the spec; GitHub is the deployment.** `plan` compiles it; `create` deploys it fresh; `update` re-deploys it onto an existing milestone.

`plan` writes it to a gitignored per-run scratch path, by a **deterministic slug** of the milestone goal, so `create` / `update` resolve the same path from the same brief:

```
.milestone-feeder/plan-<slug>.md
```

Derive `<slug>` deterministically from the one-line milestone goal: lowercase it, replace every run of non-alphanumeric characters with a single hyphen, strip any leading/trailing hyphen, and cap the length at a reasonable bound (trimming a trailing hyphen if the cut lands on one). The same brief always resolves to the same path; a **changed** brief derives a **different** slug — that is the staleness signal (`create` / `update` re-plan when the slug no longer matches).

### Fields a consumer parses (the contract)

The plan file MUST carry, unambiguously, every field below:

| Field | Why `create` / `update` need it |
|---|---|
| **Milestone title (exact)** + one-line goal | The **identity field**: `create` / `update` resolve the milestone by this exact title (create-or-adopt). Distinct from the one-line goal, which is descriptive only. |
| **Milestone description** (Wave / build order, local slugs `#A`/`#B`) | The wave-encoded description to PATCH onto the milestone after issue numbers exist. |
| **Per surviving issue** — slug, title, the FULL §4 body verbatim, labels, surface/risk | The issues to create / patch — verbatim, **no regeneration**. |
| **Parked issues** — slug, title, kind (`product-gap` \| `needs-human-direction`) | Marked, **never created.** Routed to the needs-input report. |
| **Dropped issues** — slug, title, the parked dependency that dropped them | Marked, **never created** (a dependent of a parked issue can't build). |
| **Self-check verdict line** | The Step-6 outcome (`PASS` / `INTERNAL` / `PARKED` / `SKIPPED(reviewer:false)`). `create` reports it and **trusts it — no re-vet**. |
| **Source brief reference** — `inline` \| `file:<path>` \| `epic #<n>` | Drives report routing and the brief↔plan match. An `epic #<n>` reference routes the needs-input report to an epic comment. |

### The slug→`#n` rewrite happens at write time

Issue numbers don't exist until creation, so the plan file carries **local slugs** (`#A`/`#B`) throughout. The load-bearing two-pass slug→`#n` rewrite happens when `create` / `update` write to GitHub — once the issues exist and the slug→`#n` map is complete. `plan` itself does no rewrite.

**What changed from v0.2.0 is ONLY the source** of the issue bodies / labels / waves: they are now **read from the plan file, not regenerated.** The write sequence (label ensure, create-or-adopt, two-pass slug→`#n`, report routing) is unchanged.

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
project docs or a cited sibling pattern. No contradictions.>
- Convention followed: <conventions.md ref or file:line of the sibling pattern>

## Dependencies
- Depends on #<n> — <one-line reason / the exact reference>

## Classification
- Surface: UI | logic
- Risk: light | heavy   (sets the driver's risk:* override; default heavy when unsure)
```

Labels applied by **`create`**: a UI/logic label, and `risk:light` / `risk:heavy` when the feeder is confident — aligned with the driver's existing taxonomy so triage and solve read them natively. The four-label set (`ui`, `logic`, `risk:light`, `risk:heavy`) is provisioned by `setup` and ensured idempotently by `create`.

### Milestone description template (encodes the Wave order)

```markdown
<one-paragraph milestone goal>

## Waves
- Wave 1 (parallel): #A, #B, #C
- Wave 2: #D (depends on #A, #B)
- Wave 3: #E (depends on #D)
```

Human-readable and the exact ordering source `solve-milestone` and triage consume. In the plan file the identifiers are **local slugs**; `create` rewrites them to real GitHub numbers once the issues exist.

---

## 5. The self-check gate (the keystone)

Before writing the plan file, **`plan`** dispatches the driver's own `triage-reviewer` (and `design-reviewer` for UI issues) against each generated issue's text plus the generated milestone description. The gate lives in `plan` — it runs at Step 6, before the plan file is written. `create` trusts the recorded verdict and does **not** re-vet (the only path that runs the gate from `create` is the run-`plan`-first fallback, when no plan file exists).

| Result | Action |
|---|---|
| `GAPS: none` for all issues | Proceed to write the plan file (§6, Step 7). |
| Blocker, design/implementation-resolvable | Re-dispatch `issue-author` to fix, bounded retry (**at most 2**, same cap the driver uses on every gate). |
| Blocker, genuine **product** gap | Flag for your decision in the "needs product input" report; do not invent. |

**Decision (default):** the self-check uses the driver's reviewers when `milestone-driver` is installed; degrades to an internal checklist mirroring the five criteria when it is absent (`reviewer: "milestone-driver" | "internal" | false`). Reusing the real reviewers guarantees parity with the driver's entry gate. `reviewer: false` skips the gate with a visible 🔴 warning recorded in the plan-file verdict line.

---

## 6. Procedure (the `plan` skill)

`plan` runs the full pipeline (Steps 0–6) and stops at a reviewable plan file (Step 7). It is **read-only on GitHub** — its entire output is local scratch files.

| Step | Action |
|---|---|
| 0 | Read `.milestone-config/feeder.json` (absent → `setup`); read the project docs (`projectDocs`, default `.project/`, best-effort); resolve the shared keys (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`) from the driver config. |
| 1 | Ingest the brief (file path, inline text, or a GitHub epic issue); normalize freeform input internally first. |
| 2 | **Product-gap check** (the flag boundary): separate product decisions (no conventional default) from design/implementation decisions (resolvable from project docs/convention). Product gaps are recorded, not guessed. |
| 3 | Dispatch the **`architect`** agent **once**: candidate issue set (small, independently-buildable, ~one PR each) + dependency edges + Wave order. |
| 4 | Dispatch the **`issue-author`** agent **per candidate** (parallelizable) → full spec to §4. |
| 5 | Assemble the dependency graph; render the milestone description (§4) with local slugs. |
| 6 | **Self-check** (§5): iterate to clean (≤2 retries per issue) or flag product gaps. |
| 7 | **Write the plan file** (`.milestone-feeder/plan-<slug>.md`) — the build artifact (§3.1), plus the needs-input report when anything was parked. No GitHub writes. |

**Then `create` deploys the plan file** (faithful — the §6 apply write sequence): ensure labels → create-or-adopt the milestone by exact title → create the surviving issues + build the slug→`#n` map → second-pass slug→`#n` rewrite (issue bodies + the milestone description) → file the needs-input report (epic comment when the brief was an epic; else local file). On the found path it dispatches no agent and re-runs no gate.

**And `update` reconciles it** onto an existing milestone (create-or-patch / add-edge-and-re-render / flag-never-close / no-op): create any plan issue missing on GitHub, patch any drifted body (showing the diff first), add any new dependency edge and re-render the build order, and **flag** — never close — any live issue the plan no longer carries. A fully-synced milestone is a true no-op.

There are **no flags** anywhere: `plan` previews (writes the plan file), `create` / `update` write — each *is* its own verb.

---

## 7. Config schema — `.milestone-config/feeder.json`

Thin and consumer-driven, same discipline as the driver: new keys only when a real consumer needs them. The file name stays `feeder.json` (pairs with `driver.json`, matches the plugin name, avoids hook-script churn). The keys inside — the part a user reads and edits — are humanized.

| Key | Type | Default | Purpose |
|---|---|---|---|
| `projectDocs` | string | `.project/` | Where the project's standing docs live. |
| `reviewer` | `"milestone-driver" \| "internal" \| false` | `"milestone-driver"` | Who checks each issue before it's created; `false` = off. |
| `issueSize` | string | *(none)* | Optional natural-language sizing rule (e.g. "≤1 PR, ≤1 new screen"). |
| `architectAgent` | string | `milestone-feeder:architect` | Override the breakdown (architect) agent. |
| `issueAuthorAgent` | string | `milestone-feeder:issue-author` | Override the authoring agent. |
| `sourceGlobs` | string[] | `["skills/**","agents/**","hooks/**"]` | **Self-protection only** — the paths the feeder's own `no-source-edit` hook guards in the feeder's *own* repo. Distinct from the consumer's shared `sourceGlobs`. |

Consumer-facing shared keys (`uiSurfaceGlobs`, `integrationBranch`, and the *consumer's* `sourceGlobs`) are **read from the driver config, not duplicated** — resolved `.milestone-config/driver.json` → root `milestone-driver.json`.

The `sourceGlobs` key above is **self-protection only**: the `no-source-edit` hook, which guards the feeder's *own* repo, resolves the paths to guard **`feeder.json` first, then falls back to the resolved driver config (`.milestone-config/driver.json` → root `milestone-driver.json`), then fail-open** if neither carries it. This own-repo self-edit guard is semantically distinct from the consumer's shared `sourceGlobs` that the feeder reads from the driver config when planning a target repo.

### `.milestone-config/` migration note

Adopting `.milestone-config/` suite-wide means the driver resolves its profile from `.milestone-config/driver.json` first, falling back to the legacy root `milestone-driver.json` (backward-compatible — existing repos keep working).

---

## 8. Modes & autonomy

Three intent-named verbs, **zero flags**. Each verb *is* the explanation of what it does.

| Verb | Trigger | Behavior |
|---|---|---|
| `plan` | `/milestone-feeder:plan <brief>` | Full procedure, stops at a reviewable plan file (read-only on GitHub). |
| `create` | `/milestone-feeder:create <brief>` | Deploys the approved plan file: labels + milestone + issues + build order. Faithful — trusts the recorded verdict; runs `plan` first if no plan file exists for the brief. |
| `update` | `/milestone-feeder:update <brief>` | Reconciles a refreshed plan onto the existing milestone. Never closes/deletes; idempotent; shows the diff before patching. |

Authoring autonomy boundary: makes design/implementation calls grounded in the project docs; flags product calls (no conventional default) for your decision in the "needs product input" report. Authors no code, opens no PRs, never touches branches.

---

## 9. Build order (dogfood it)

Build the feeder as its own milestone the driver can run — the as-built sequence:

1. **Agent + config rename** — `architect` agent; keys `projectDocs` / `reviewer` / `issueSize` / `architectAgent`; `setup` updated. (The spine — no behavior change.)
2. **`plan` skill** — the plan file becomes the formalized contract (§3.1); drop the apply path.
3. **`create` skill** — read-the-plan deploy + run-`plan`-first fallback; inherits the §6 apply write sequence.
4. **`update` skill** — plan-driven reconcile; never-close, idempotent.
5. **README / docs / metadata** re-vocab to the new surface.
6. **Harness** migrate + re-run (the credibility scenarios, on the new verbs/keys).
7. **Verify** the old vocabulary is gone; bump to v0.3.0.

Steps 1–2 are the spine with no irreversible GitHub side effects — the safe first build target.

---

## 10. Resolved during build (was: open questions)

These were settled by the as-built skills:

- **Brief format.** Accepted **freeform** and normalized internally first into `{ goal, in-scope, out-of-scope, surfaces, epicIssueNumber? }` before anything downstream consumes it (`skills/plan/SKILL.md` Step 1).
- **Milestone ownership.** **Create-or-adopt** by exact title — `create` creates the milestone if no title match, adopts (and reopens if closed) an existing one; never deletes (`skills/create/SKILL.md` pass b). `update` adopts read-only and errors-and-stops if no milestone exists.
- **Where the "needs product input" report lives.** A **local file** (`.milestone-feeder/needs-product-input-<slug>.md`) — or a **comment on the epic issue** when the brief was a GitHub epic. `plan` writes the report body; `create` / `update` route it by the recorded source-brief reference (`skills/create/SKILL.md` pass e).
