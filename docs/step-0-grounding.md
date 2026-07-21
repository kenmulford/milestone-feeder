# Step-0 grounding inputs — resolve once, hand into the routine, degrade like the digest

`plan`'s Step 0 (`skills/plan/SKILL.md` Step 0 — the once-per-run OUTER boundary) assembles **four grounding inputs** the inner routine consumes: the **grounding digest**, the **global implied-surfaces reference**, the **project-local implied-surfaces overlay** merged into it, and the **consumer issue-template**. All four share one resolution contract; this file states that shared contract **once**, then records each input's own specifics. It is reference content relocated out of `skills/plan/SKILL.md` to keep that always-loaded file within the repo's own size standard; nothing about what Step 0 does changes, only where its mechanics are recorded — mirrors the existing `docs/one-time-notices.md` and `docs/version-ladder.md` relocations. (The candidate-scoped **file-map** is **not** a Step-0 input — it is built **per candidate** at the Step-4 issue-author dispatch, scoped to that candidate's own grounding, and its mechanics are recorded in `docs/file-map.md`.) `skills/plan/SKILL.md` Step 0 keeps only the short in-place stubs that name the inputs and this file; resolve each exactly as recorded here.

## Contents

1. [The shared contract — resolve-once / hand-in / degrade / supplement](#1-the-shared-contract--resolve-once--hand-in--degrade--supplement)
2. [The grounding digest](#2-the-grounding-digest)
3. [The global implied-surfaces reference](#3-the-global-implied-surfaces-reference)
4. [The project-local overlay — additive merge](#4-the-project-local-overlay--additive-merge)
5. [The consumer issue-template](#5-the-consumer-issue-template)

## 1. The shared contract — resolve-once / hand-in / degrade / supplement

Every input in this file obeys the **same four-part contract**. Each input's own section below records only what is *specific* to it; the four properties here are not restated per input.

- **Resolve ONCE, here.** Each input is resolved a single time, at the Step-0 OUTER boundary, alongside the shared-keys resolution — **never** re-resolved per candidate or per inner-routine invocation. Step 0 **produces** each input; the Step-3 architect brief and the Step-4 issue-author brief that **consume** them are wired at Steps 3 / 4.
- **Hand into the inner routine.** Each resolved input is carried in the `resolved` callable-contract bundle (`skills/plan/SKILL.md` — the inner-routine `resolved` parameter) and handed **unchanged** into the routine; the routine re-assembles / re-resolves **nothing**.
- **Degrade best-effort, never abort** (`.project/design-philosophy.md#Error & failure philosophy`). An absent / unreadable / malformed source resolves to an **empty / minimal pass-through — no error, no abort**; the run proceeds best-effort on stated repo conventions, and whatever downstream consult depended on it becomes a clean no-op.
- **Supplement, never replacement.** Each input **adds to**, and does not close, the agents' own on-demand Read/grep path. Every agent's rigor gate stays mandatory — the architect cites its grounding / verifies a sibling `file:line` before recording it, and the issue-author "greps before it cites." No input is an allowlist; an agent may Read/grep anything not present in it.

## 2. The grounding digest

A compact, **ordered** set of `.project/<doc>.md#<section>` *slices* — each slice = the section anchor (in that citation form) paired with that section's body text — assembled while reading the project docs.

- **Selection filter (no new rule).** Select slices with the **same filter already in force** at Step 0 — exactly the sections that exist, with absent / `[TBD]` sections skipped (Step 0's "skipped, never grounded on", and Step 3's "only the sections that exist"). Introduce **no new** selection or skip rule.
- **Superset.** The digest carries *every* implicated existing section, so handing it downstream in place of the directory never drops grounding.
- **Specific degrade.** A missing `projectDocs` directory, all-absent / `[TBD]` sections, or a read/parse failure → an **empty / minimal digest** (per §1's degrade rule).

## 3. The global implied-surfaces reference

The **plugin-bundled GLOBAL** implied-surfaces reference: read `${CLAUDE_PLUGIN_ROOT}/docs/implied-surfaces.md` (the plugin-root convention this repo uses for bundled assets — `hooks/hooks.json`) into the resolved content this run hands downstream. It is the reasoning prompt the architect's implied-surfaces clause consults (`agents/architect.md` → "What you receive" → *the resolved implied-surfaces reference*; clause 8).

- **Scope of this resolution: the GLOBAL reference only.** The project-local overlay (§4) is merged into it in the very next step, producing the single **merged** reference the run hands downstream.
- **Specific degrade.** An absent / unreadable / malformed reference resolves to an **empty / minimal pass-through** (per §1); the architect's clause-8 consult then becomes a **no-op**.

## 4. The project-local overlay — additive merge

Immediately after resolving the global reference (§3), read the **optional project-local** overlay at the fixed **consumer-repo** path `.milestone-config/implied-surfaces.md` — the suite config directory, **NOT** plugin-bundled (contrast the global reference, which is the plugin-root `${CLAUDE_PLUGIN_ROOT}/docs/implied-surfaces.md`). The overlay is discovered by that **fixed path** — there is no `feeder.json` key that points at it (`docs/implied-surfaces.md` → "Project-local overlay" → *Where it lives*). Its shape **mirrors the global reference** (`docs/implied-surfaces.md` → "Project-local overlay" → *Its shape*): one capability per `##` heading, its implied surfaces listed beneath. Parse it into that same `##`-section structure and **operate on the parsed structure — do not redefine the shape**.

**Merge it ADDITIVELY into the global reference, producing the ONE merged reference this run hands downstream** (`docs/implied-surfaces.md` → "Project-local overlay" → *How it merges — additive only*). Merge precedence:

- A capability **only in the global** → carried **unchanged**.
- A capability **only in the overlay** → **ADDED**.
- A capability in **both** → the **UNION** of their surface lists, **deduped**, **global surfaces first, then overlay-added surfaces, in stable order**.

The global reference is the **FLOOR — never reduced**; the merge is **purely additive with NO removal path**. A deletion attempt is therefore a **no-op by construction** (there is simply no delete operation), and an **empty / add-nothing** overlay yields **merged == global**. Per-run trimming of a surface a given milestone does not want stays the **plan REVIEW's job** (Step 7's implied-surfaces review prompt; `docs/implied-surfaces.md` → "Project-local overlay" → *How it merges* — "the plan review's job"), **not** a config-level delete.

**Specific degrade.** An **absent** overlay → the global reference is used **UNCHANGED**, which is **NOT an error and carries NO notice** (most projects ship no overlay — the common case). An **unreadable / malformed / wrong-shape** overlay → **fall back to the global reference unchanged, best-effort skip, NEVER aborting the run** (the overlay's own "Malformed input is skipped, never grounded on" contract). A **non-blocking notice MAY** surface the skip, but it **must NOT gate**. The overlay's discovery path — how existing users learn the overlay exists (the `setup` mention and the one-time `plan` / `update` notice) — is owned elsewhere (already on develop), **NOT** this step; Step 0 only **resolves + merges** the overlay.

## 5. The consumer issue-template

**Source: the consumer repo's `.github/ISSUE_TEMPLATE/` directory** — the issue convention that repo already keeps for its human filers. Resolving it lets the issue-author write to *that* structure instead of the plugin's built-in default (`agents/issue-author.md` → "Output format"), so agent-filed and human-filed issues in the same repo read and triage the same way.

**Selection — four rungs, deterministic and classification-free.** This is the **single authoritative statement** of the selection rule; `SPEC.md` §4, `skills/plan/SKILL.md` Step 0, `agents/issue-author.md`, and the §7 notice in `docs/one-time-notices.md` all defer here rather than restate it. Take the **first** rung that holds:

| Rung | Condition | Result |
|---|---|---|
| **1** | `agentIssueTemplate` set in the driver config and the file it names is readable | Resolve **that** template and hand it in. |
| **2** | Exactly one **selectable** template in the directory | Resolve that template and hand it in — **today's rule, unchanged**. |
| **3** | Zero, or two-plus with no usable key | Hand in nothing — the author uses its built-in default. |
| **4** | — | Absence **never blocks issue creation**. |

**Rung 1 — the recorded choice.** `agentIssueTemplate` is a repo-relative path to the `.github/ISSUE_TEMPLATE/` template that **`milestone-bootstrapper` records into `.milestone-config/driver.json` at provision time** ([milestone-bootstrapper#156](https://github.com/kenmulford/milestone-bootstrapper/issues/156)) as the one agents author to. The rung exists because `#156` provisions **two** stock templates (`change_request.yml` + `bug_report.yml`): without it a bootstrapped repo would land on rung 3 forever — the count is two — and the stock set this input exists to serve would be ignored **permanently**, not temporarily. Rung 1 moves the decision to **provision time, where it is a recorded human choice rather than an inference**.

**Resolve the key down the EXISTING driver-config chain**, the one `skills/plan/SKILL.md` Step 0 already documents for the shared keys: **`.milestone-config/driver.json` (primary) → root `milestone-driver.json` (legacy fallback) → absent-default**. Reuse that chain — there is no second resolution path and no new file to discover.

🔴 **`agentIssueTemplate` is NOT a fourth shared key — do not promote it.** The canonical consumer-facing shared set is **exactly three**: `sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch` (`SPEC.md` §7, `docs/profile-schema.md` §2, restated at `skills/plan/SKILL.md` Step 0). That triple is a documented contract and **stays three**. Rung 1 is a **targeted read inside this section's own resolution** — nothing else in the feeder consumes it and it is never carried downstream in the `resolved` bundle as a shared key. A later reader "tidying" this by adding it to the shared triple would break that contract; the correct shape is the one recorded here.

**Rung 1 degrades INTO rung 2, never into an error.** The key **absent**, **unreadable**, or naming a file that **does not exist** → fall straight through to rung 2, which is **exactly today's behavior**. So the rung is **inert until `#156` lands**: a repo carrying no `agentIssueTemplate` resolves byte-for-byte as it does today. No error, no park, no gate (rung 4).

**Rung 1 preserves every non-goal.** It adds **no** classification, **no** bug-vs-change distinction, **no** new architect enum, and **no** plan-file change — it names a template repo-wide; it does not choose one per issue.

**Rung 2 — the count.** Count the **selectable** templates in the directory — `*.yml`, `*.yaml`, `*.md` — **excluding the reserved `.github/ISSUE_TEMPLATE/config.yml`**, which is GitHub's template-chooser config (`blank_issues_enabled`, `contact_links`), not a selectable template. So `bug.yml` + `config.yml` counts as **ONE** and resolves `bug.yml`. The exclusion is load-bearing because that layout is very common: counting `config.yml` would read it as "two or more" and fall to rung 3, defeating the single-template case this input exists to serve. Choosing intelligently **among** several templates at rung 3 remains a deferred non-goal — **no** heuristic, **no** new architect field, **no** change to the plan-file format; rung 1 answers that case with a recorded choice instead of an inference.

**A `.md` template** is handed in as the body skeleton **directly** — no translation.

**A `.yml` / `.yaml` Issue Form** is translated: each `body:` entry becomes a `## <label>` section, emitted **in `body:` order**. All five field types the [GitHub Issue Forms schema](https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/syntax-for-githubs-form-schema) defines are covered — no type is left unhandled:

| `type` | Translation |
|---|---|
| `markdown` | Display-only instructions — **never emitted** as a section. |
| `input` | Plain content, the same as `textarea`. |
| `textarea` | Plain content. `attributes.value` is a **prefill to REPLACE, not content to echo**; a `render:` key wraps that section's body in a fenced code block of that language. |
| `dropdown` | The selected option. |
| `checkboxes` | Each applicable option's label, the same way `dropdown` renders its selection. |

Carry the form's **`labels:`** and its **`title:` prefix** when present, so the author can apply them. Carry each field's **`validations.required`** flag through — the author needs it to decide when an ungroundable required field returns `STATUS: PRODUCT_GAP` (`agents/issue-author.md` → "Authoring to a resolved consumer template").

**Specific degrade.** An unusable `agentIssueTemplate` falls through to rung 2 (above). Below that: an absent `.github/ISSUE_TEMPLATE/`, an unreadable template, or unparseable YAML → **rung 3, resolves to nothing**; the author uses the built-in default. **No error, no park — it never blocks issue creation** (`.project/design-philosophy.md#Error & failure philosophy`: best-effort, read-only, non-blocking — "they never stop `plan`"). The changed default output shape carries its own existing-user discovery path — the one-time issue-template notice (`docs/one-time-notices.md` → "Consumer issue-template notice") — per `.project/design-philosophy.md#One-way doors` ("non-breaking is necessary but not sufficient").
