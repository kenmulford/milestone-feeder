---
name: decompose
description: This skill should be used when the user invokes "/milestone-feeder:decompose <brief>", or asks to "decompose a brief into a milestone", "break a feature into issues". Turns a feature brief into a GitHub milestone + small, well-formed issues, vetting every generated issue through the driver's reviewers (self-check gate) before emit. PREVIEW ONLY in this version — writes a reviewable plan file; creates nothing on GitHub. Authors no code; opens no PRs.
---

# decompose — brief → milestone + issues

Read config + substrate, ingest a brief, separate product gaps from design decisions, dispatch the decomposer once and the issue-author per candidate, assemble the dependency graph, render the milestone description, run the self-check gate against the generated issues, and write a reviewable plan file. The driver's predecessor: it specifies what the driver then builds.

This skill is the orchestrator of the feeder's preview pipeline (`SPEC.md` §6, Steps 0–6; emit at Step 7). It makes *design and implementation* calls when the substrate or a stated repo convention supplies the answer, and it parks *product* calls — decisions about what to build or user-facing behavior with no conventional default — to a report instead of guessing them (`SPEC.md` §2 park boundary). Before emitting, it runs the **self-check gate** (Step 6, `SPEC.md` §5): it dispatches the driver's own reviewers against each generated issue and gates on the returned `GAPS` block — making the feeder's quality bar identical to the driver's entry gate. It runs every dispatched agent read-only, against provided text, and lands its entire output in local files. **Authors no code, opens no PRs, never touches branches, never invents product scope — product gaps are parked to a report, never guessed. Preview only: no GitHub writes (the `--apply` GitHub-write path remains deferred to v0.2.0, #10).**

## Announce first

Say this to the user before doing any work:

> Standing by while I decompose the brief into a milestone + issues. This is a preview — I'll write a reviewable plan file and create nothing on GitHub.

## Modes

Flags are **recognized by token match, not argument-parsed.** Claude Code does no argument parsing — `$ARGUMENTS` is string-substituted — so this skill is not a CLI parser. A flag is **recognized** when its token appears anywhere in the invocation text, exactly as the rest of the suite treats flags (mirrors `milestone-driver/skills/solve-milestone/SKILL.md:13`). The bare brief is `$ARGUMENTS` with any `--<token>` stripped.

| Trigger | Mode | Behavior |
|---|---|---|
| `/milestone-feeder:decompose <brief>` | **Preview** (default) | Full procedure, Steps 0–7, including the self-check gate (Step 6); stops at a reviewable plan file. **No GitHub writes.** |
| `… --apply` | **Apply** *(deferred → v0.2.0)* | Recognized as a token, but **not implemented in this version.** When `--apply` is present, run the preview pipeline unchanged — self-check gate and all — and note in the plan file that apply is deferred to v0.2.0 (issue #10). This version performs **no GitHub writes on any path** — `--apply` does not change that. |

The self-check gate (`SPEC.md` §5, Step 6 of the procedure) is **in scope and active** in this version — it gates every generated issue before emit (it performs no GitHub writes itself, so it runs in preview too). Only the `--apply` GitHub-write path (`SPEC.md` §6, Step 7) remains **out of scope** in this version — it ships in milestone **v0.2.0** (issue #10). That is a forward reference, not a gap: the preview pipeline is complete and self-contained, gates its output through the self-check, and emits a plan file whose self-check status line records the actual gate outcome.

## Procedure

### Step 0 — Read config + substrate (best-effort)

Read `.milestone-config/feeder.json`. **Absent → invoke `milestone-feeder:setup`** (it bootstraps the profile, aligns the label taxonomy, and returns control), then continue — the user does not re-run the command (`skills/setup/SKILL.md` Phase 5).

Extract the feeder's own keys with their bundled defaults (`docs/profile-schema.md`, absent-means-default):

| Key | Default | Use |
|---|---|---|
| `substrateDir` | `.project/` | Where the project-constitution docs live (grounds authoring). |
| `selfCheck` | `"milestone-driver"` | Which backend runs the self-check gate (Step 6). `"milestone-driver"` → dispatch the driver's `triage-reviewer` / `design-reviewer` per generated issue (degrades to `"internal"` at runtime if they don't resolve); `"internal"` → run the built-in checklist that mirrors the five triage criteria; `false` → **skip the gate with a visible warning** (resolved in full at Step 6). |
| `decomposerAgent` | `milestone-feeder:decomposer` | The breakdown agent dispatched once at Step 3. |
| `issueAuthorAgent` | `milestone-feeder:issue-author` | The authoring agent dispatched per candidate at Step 4. |
| `issueSizeGuidance` | *(none)* | Optional sizing rule passed into the decomposer brief; absent → no constraint beyond the defaults. |

Read the substrate under `substrateDir` **best-effort** (`SPEC.md` §6 Step 0). Honor the `.project/` contract: a section that is absent or marked `[TBD]` is treated as **not present** — it is **skipped, never grounded on**. Degrade gracefully: a missing substrate directory is not an error; the run proceeds on whatever sections exist and on stated repo conventions. Cite a substrate-grounded decision as `.project/<doc>.md#<section>` when carrying it forward.

Resolve the **shared keys** the decomposer and issue-author need for grounding, from the driver config (`docs/profile-schema.md` shared-keys chain):

1. `.milestone-config/driver.json` (primary).
2. Root `milestone-driver.json` (legacy fallback).
3. **Absent-default** — an unset key uses its documented default; the feeder does not invent a value.

The shared keys are exactly three: `sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch` (the canonical consumer-facing set — `SPEC.md` §7, `docs/profile-schema.md` §2). Each resolves down the chain above.

Resolve `nonNegotiables` **separately**, down the **same chain** (`.milestone-config/driver.json` → root `milestone-driver.json` → absent → **OMITTED**, never invented): it is **not** a fourth shared key but an **additional reviewer-profile input the self-check gate (Step 6) passes through** — the framework/platform/version constraints the driver's triage-reviewer expects on the profile and gates against (§6.2). An absent `nonNegotiables` is OMITTED (the reviewer simply has no version/platform constraints to check). **Degradation:** when `uiSurfaceGlobs` is absent (neither driver file carries it), treat every candidate as **logic** (no UI surface can be matched, so no design-lens distinction is drawn) and **state the degradation** in the plan file's grounding section. The pipeline still runs.

### Step 1 — Ingest the brief

The brief arrives in one of three forms. **Detect** which:

| Form | Detection | Read |
|---|---|---|
| **GitHub epic issue** | The bare brief is `#<n>`, or a bare integer | `gh issue view <n> --json number,title,body,comments` |
| **File path** | The bare brief is a path to an existing file | Read the file |
| **Inline text** | Otherwise | Use the text as-is |

§10 lean (`SPEC.md` §10): accept the brief **freeform**, normalize internally **first** into this shape before anything downstream consumes it:

```
{
  goal:            <one paragraph: what to build and why, in product terms>,
  in-scope:        [<bullets>],
  out-of-scope:    [<bullets>],
  surfaces:        [<the screens / modules / surfaces the brief touches>],
  epicIssueNumber: <n>   # present only when the brief was a GitHub epic issue; else omitted
}
```

Record `epicIssueNumber` when the brief was an epic issue — it is carried forward for the **deferred** apply report (`SPEC.md` §10 lean: epic comment on apply, v0.2.0). In preview it is recorded only; **no comment is posted** on the epic issue.

### Step 2 — Product-gap check (the park boundary)

Separate the two classes of decision the brief implies (`SPEC.md` §2, §6 Step 2):

| Class | Test | Action |
|---|---|---|
| **Product decision** | No conventional default — what to build, or user-facing behavior the substrate / a stated convention does not answer | Record to `productGaps[]`. **Never guessed.** |
| **Design / implementation decision** | The substrate or a stated repo convention supplies the answer | Resolved — proceed; cite the grounding (`.project/<doc>.md#<section>` or a sibling `file:line`). |

If a product gap is severe enough that the candidate set **cannot even be formed** without it (the brief's core scope is undecided), **STOP**: emit the "needs product input" report (Step 7 format) and end the run — do not dispatch the decomposer against an undecided scope. Otherwise carry `productGaps[]` forward: the pipeline proceeds with the decidable work, and the gaps surface in the plan + report at Step 7.

### Step 3 — Dispatch the decomposer (once)

Dispatch the agent named in `decomposerAgent` (default `milestone-feeder:decomposer`) **exactly once** (`SPEC.md` §6 Step 3 — one heavy reasoning step).

**Brief it with** (matches `agents/decomposer.md` → "What you receive"):

- The **normalized brief** from Step 1 (`{ goal, in-scope, out-of-scope, surfaces }`).
- The **filled substrate sections** from Step 0 — only the sections that exist (absent / `[TBD]` skipped).
- The **resolved shared keys** — the *values* for `sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`.
- `issueSizeGuidance` when set; else the default (~1 PR each, independently buildable).
- The `productGaps[]` carried from Step 2.

**It returns** (verbatim from `agents/decomposer.md` → "Structured return block"):

```
CANDIDATES:
  - tag: #A
    title: <imperative one-line issue title>
    surface: ui | logic
    risk: light | heavy
    sketch: <what this issue does + the substrate ref / sibling file:line grounding its design>
  - … (one per candidate)
EDGES:
  - "#B depends_on #A — <reason / the exact artifact reference>"
  - …                       # [] when no candidate depends on another
WAVES:
  - "Wave 1 (parallel): #A, #C"
  - "Wave 2: #B (depends on #A)"
  - …                       # topological sort of EDGES; Wave 1 = no unmet deps
PRODUCT_GAPS:
  - gap: <the product decision with no conventional default>
    why_blocked: <why it cannot be grounded in the substrate or a convention>
    brief_ref: <the brief line / phrase that asks for it>
  - …                       # "none" when the brief is fully resolvable
```

`EDGES` is the literal `[]` when no candidate depends on another; `PRODUCT_GAPS` is the literal `none` when the brief is fully resolvable. **Merge** any decomposer `PRODUCT_GAPS` into `productGaps[]` — they join the gaps found at Step 2.

### Step 4 — Dispatch issue-author per candidate (parallelizable)

For **EACH** candidate returned at Step 3, dispatch the agent named in `issueAuthorAgent` (default `milestone-feeder:issue-author`). Dispatches are **parallelizable** — run them concurrently when the tool environment supports it (`SPEC.md` §6 Step 4).

**Brief each with** (matches `agents/issue-author.md` → "What you receive"):

- The **candidate** — its tag, title, surface/risk hint, and sketch (from Step 3).
- The **brief + substrate** — the grounding sources from Steps 0–1.
- The **resolved shared keys** — `sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`.
- The **edges naming this candidate** — the decomposer edges that touch this tag, to record verbatim (the author transcribes; it does not invent edges or reorder Waves).
- Any `productGaps[]` **scoped to this candidate**.

**Each returns** (verbatim from `agents/issue-author.md` → "Output format"):

```
STATUS: AUTHORED | PRODUCT_GAP
ISSUE_TAG: #A
TITLE: <final imperative title>
ISSUE_BODY: |
  <the §4 issue-body template, verbatim — Summary / Acceptance criteria /
   Design (recorded, consistent) / Dependencies / Classification>
LABELS: [<ui|logic>, <risk:light|risk:heavy if confident>]
PRODUCT_GAP (only when STATUS: PRODUCT_GAP): { what: <the product decision with no conventional default>, why: <why it cannot be grounded> }
```

When a candidate returns `STATUS: PRODUCT_GAP`, **route it to `productGaps[]`** — do **not** author a half-invented issue from a fabricated body. The candidate is recorded as parked, not authored; the milestone preview still renders the candidate's tag/title with a "parked — needs product input" marker.

### Step 5 — Assemble graph + render the milestone description

Build the **dependency graph** from the decomposer's `EDGES`: each candidate's direct dependencies, and the Wave-ordered topological sort the decomposer returned in `WAVES`. The graph uses the candidates' **local tags / slugs** — no GitHub issue numbers exist in preview (`agents/decomposer.md` clause 6: local tags, not GitHub numbers).

Render the **milestone description** to the `SPEC.md` §4 Wave template, substituting the local slugs/tags for the `#<n>` placeholders:

```markdown
<one-paragraph milestone goal>

## Waves
- Wave 1 (parallel): #A, #B, #C
- Wave 2: #D (depends on #A, #B)
- Wave 3: #E (depends on #D)
```

This is the human-readable description and the exact ordering source the driver's `solve-milestone` and `triage` consume (`SPEC.md` §4). In preview the identifiers are local slugs; `--apply` (v0.2.0) is what rewrites them to real GitHub numbers — not this version.

### Step 6 — Self-check gate (the keystone)

Before emitting, vet **every generated issue** with the same gate that fronts the driver's build loop, so what the feeder emits passes the driver's triage clean (`SPEC.md` §5; success criterion `SPEC.md` §1). This step runs in **preview too** — it performs **no GitHub writes**; it gates what the plan file (Step 7) reports. Dispatch every reviewer **read-only, against the generated text** (their contracts take provided issue text and make no `gh` call of their own — confirmed against `milestone-driver/agents/triage-reviewer.md:96-101` and `design-reviewer.md:94-99`; no agent modification is needed).

#### 6.1 — Resolve the `selfCheck` backend

The `selfCheck` value read at Step 0 selects the backend. Resolve it as follows:

| `selfCheck` | Backend |
|---|---|
| `"milestone-driver"` (default) | Dispatch `milestone-driver:triage-reviewer` per generated issue, and `milestone-driver:design-reviewer` for issues whose triage returns `NEEDS_DESIGN_REVIEW: yes`. **If the reviewers do not resolve at dispatch time, degrade to `"internal"` (see the runtime trigger below) — a notice, never a failure.** |
| `"internal"` | Run the **internal checklist** (§6.4) — the feeder's own check mirroring the five triage criteria. Same pass/Blocker verdict shape, so the gate logic downstream is backend-agnostic. |
| `false` | **Skip the gate.** Print a **visible 🔴 warning** to the user — `🔴 Self-check DISABLED (selfCheck:false) — generated issues were NOT vetted against the driver's entry gate; they may not pass triage.` — and record `SKIPPED (selfCheck:false)` in the plan-file status line (Step 7). Proceed straight to emit; run no reviewer and no checklist. |

**Runtime degrade-to-internal trigger (`"milestone-driver"` → `"internal"`).** The degrade is decided at **dispatch time, not config time** (mirrors the *config*-time reviewer-resolve probe in `skills/setup/SKILL.md:29`, but applied live here because availability can differ between setup and this run). On the **first** issue's `triage-reviewer` dispatch: attempt the dispatch; if the agent **does not resolve** (no such agent in the session — `milestone-driver` not installed) **or the dispatch returns no usable block** (the return does not contain a parseable `ISSUE:` / `GAPS:` block), then:

1. Emit a visible notice: `Self-check: milestone-driver reviewers did not resolve — degrading to the internal checklist for this run.`
2. Switch the backend to `"internal"` for the **remainder of the run** (do not retry `milestone-driver` per issue — decide once, on the first dispatch).
3. Record the outcome under the `INTERNAL` status line at Step 7.

This gives the `"milestone-driver"` → `"internal"` branch a single, defined trigger: a non-resolving agent or an unparseable return on the first dispatch. A reviewer that resolves and returns a valid block — even one full of Blockers — is **not** a degrade; that is a normal gate result handled by §6.3.

**Per-issue fallback for a later non-resolution.** The first-dispatch trigger above decides the backend for the run, but a **later** issue's `milestone-driver` dispatch can still come back unusable (no resolvable agent that call, or a return with no parseable `ISSUE:` / `GAPS:` block) even after the run committed to `"milestone-driver"`. Such a return matches neither §6.3 verdict (it is not `GAPS: none`, and it carries no parseable Blocker), so it must not fall through — an issue is **NEVER** emitted unvetted. When it happens, run **that one issue** through the §6.4 internal checklist as a per-issue fallback, take its verdict from there, and record `internal-fallback` against that issue in the Step 7 status line. The run's backend stays `"milestone-driver"` for the remaining issues (this is a single-issue fallback, not the run-wide degrade).

#### 6.2 — Compose each reviewer brief (from GENERATED content)

Brief each reviewer from the **generated** artifacts (matches `triage-reviewer.md` → "What you receive" and `design-reviewer.md` → "What you receive"), using **local slug identifiers** throughout (`#A`/`#B`) — no GitHub numbers exist in preview:

- **The issue** — the generated title, the generated `ISSUE_BODY` (Summary / Acceptance criteria / Design / Dependencies / Classification), and the acceptance criteria within it, from Step 4.
- **Recorded design decisions** — **empty** (no GitHub issue exists yet, so there are no comments / `design-cleared` notes). State this explicitly in the brief so the reviewer does not treat the empty set as a gap in itself.
- **Milestone description** — the Step 5 Wave-ordered description (with local slugs) as the **cross-issue dependency context** — this is the reviewer's ordering source for the Dependencies criterion.
- **The profile** — the resolved **real target-repo** shared keys `sourceGlobs`, `uiSurfaceGlobs` (for source grounding), **plus `nonNegotiables`** (the additional reviewer-profile input — not a shared key). All are already resolved at Step 0 (that is the single resolution authority — same chain, same absent-default rule); `nonNegotiables` absent → omitted (the reviewer simply has no version/platform constraints to check against).

For `design-reviewer`, brief the **pointers to existing UI surfaces** via the resolved `uiSurfaceGlobs` (matches `design-reviewer.md:38`).

#### 6.3 — Consume the returned blocks (the gate logic)

Each `triage-reviewer` returns an `ISSUE / DEPENDS_ON / NEEDS_DESIGN_REVIEW / GAPS` block; each `design-reviewer` returns an `ISSUE / GAPS` block (verbatim shapes at `triage-reviewer.md:59-70` and `design-reviewer.md:58-67`). For each generated issue, **aggregate** the `GAPS` entries from its triage block and (when dispatched) its design block, keyed on **lens / severity / description**:

| Aggregated result | Verdict |
|---|---|
| Every dispatched block returns `GAPS: none` | **PASS** — the issue clears the gate. |
| Any `GAPS` entry carries `severity: Blocker` | **FAIL** — the issue is gated; route it through the retry/park fork (§6.5). |

`severity: Advisory` entries do **not** fail the gate (they mirror the driver's own Advisory-is-not-blocking rule, `triage-reviewer.md:81-82`); record them in the plan file's grounding section as notes, but do not retry on them. `GAPS: none` passes; any `Blocker` fails — there is no third state.

The internal-checklist backend (§6.4) produces the **same verdict shape** — a per-issue PASS, or a FAIL carrying findings with the reviewers' five fields (`lens` / `severity` / `type` / `description` / `to_clear`) — so §6.5 reads `lens` and `severity` (and §6.6 reads `type`) identically regardless of backend.

#### 6.4 — The internal checklist (the `"internal"` backend)

When the backend is `"internal"` (configured, or degraded-to at §6.1, or the per-issue fallback at §6.1), apply this checklist to **each generated issue's text** — it mirrors, criterion-for-criterion, what the driver's reviewers check (`triage-reviewer.md:43-53`, `design-reviewer.md:42-52`) and this repo's five-criteria contract (`SPEC.md` §4 table). Emit each finding in the **same five-field shape the reviewers return** — `lens` / `severity` / `type` / `description` / `to_clear` — so §6.5 reads `lens` and `severity`, and §6.6 reads `type`, identically regardless of backend. An issue with no Blocker finding is PASS.

| # | Criterion (mirrors `SPEC.md` §4) | Internal check on the generated issue text | Blocker when |
|---|---|---|---|
| 1 | **Consistency** | Re-read the Design section: do any two recorded statements contradict (cannot both be true)? | Two recorded statements contradict (`triage-reviewer.md:45`). |
| 2 | **Buildability** | Does every decision the acceptance criteria require have a recorded value or a `Convention followed:` line citing the substrate / a sibling `file:line`? | A required decision is neither recorded nor resolvable by a stated convention (`triage-reviewer.md:47`). A choice an established convention answers is **Advisory**, not Blocker. |
| 3 | **Completeness** | Do the acceptance criteria enumerate happy + empty + error/failure + disabled/edge states — not just the happy path? | A required state is silently missing and that makes the issue un-deliverable (`triage-reviewer.md:49`). |
| 4 | **Dependencies** | Does the issue reference a type/file/contract/screen another generated issue introduces, and is that edge declared in the Dependencies section + reflected in the Wave order? | An undeclared hard dependency exists (`triage-reviewer.md:51`). |
| 5 | **UI flag** *(+ design sub-criteria for UI issues)* | Is the issue classified UI vs logic against `uiSurfaceGlobs`? For a **UI** issue: does the Design section name the existing pattern to mirror (`file:line`), the required states (empty/loading/error/disabled), the affordances (confirm dialog for any destructive op), and accessibility labels? | A UI issue is missing a required state, a required affordance (e.g. confirm dialog on a destructive op), or names no pattern to mirror (`design-reviewer.md:44,50,52`). |

For each finding, set the five fields: **`lens`** = `architect` for criteria 1–4, `design` for criterion 5's UI sub-criteria (mirroring which driver reviewer owns the criterion); **`severity`** = `Blocker` per each row's "Blocker when" rule, else `Advisory` — a choice an established convention answers is **Advisory, not Blocker** (criterion 2's rule, applied to every criterion); **`type`** = the driver reviewers' own `type` vocabulary, mapped from the failing criterion (table below) so §6.6 can key on it exactly as it does for a `milestone-driver` block; **`description`** = the failing statement on the generated text; **`to_clear`** = what the issue must record to clear it. This is the same shape §6.3 aggregates and §6.5 classifies.

| Failing criterion | `type` (driver vocabulary) | Lens it maps to |
|---|---|---|
| 1 — Consistency | `contradiction` | architect (`triage-reviewer`) |
| 2 — Buildability | `not-buildable` — or `missing-criteria` when a required decision is simply *unrecorded* (no contradiction, just absent); pick the closest | architect (`triage-reviewer`) |
| 3 — Completeness | `missing-criteria` | architect (`triage-reviewer`) |
| 4 — Dependencies | `undeclared-dependency` ← **§6.6 keys on this; it MUST be present** | architect (`triage-reviewer`) |
| 5 — UI / design sub-criteria | the design-lens type matching the failing sub-criterion: `missing-state` (a required state absent), `missing-affordance` (a required affordance absent, e.g. no confirm dialog on a destructive op), `pattern-inconsistency` (the design diverges from the named existing pattern), `spec-insufficiency` (the design is under-specified to build), or `accessibility` (missing labels / a11y) | design (`design-reviewer`) |

When `uiSurfaceGlobs` is absent (the degradation noted at Step 0), treat every issue as **logic** — criterion 5's UI sub-criteria do not apply (no UI surface can be matched), exactly as the driver's reviewers emit `NEEDS_DESIGN_REVIEW: no` when `uiSurfaceGlobs` is absent (`triage-reviewer.md:53`).

#### 6.5 — Retry / park fork (per FAILed issue)

For each issue that FAILed §6.3, classify each Blocker and act — bounded to **at most 2** `issue-author` re-dispatches, the same cap the driver applies on every gate (`milestone-driver/skills/solve-issue/SKILL.md:119`):

| Blocker class | Test | Action |
|---|---|---|
| **Design / implementation-resolvable** | A Blocker in the issue **body** the substrate or a stated repo convention can answer — a recordable design/impl decision (e.g. a missing state, an unnamed pattern to mirror). *(An `undeclared-dependency` Blocker is **not** here — §6.6 handles it; see precedence below.)* | **Re-dispatch `issue-author`** for that candidate (§Step 4 brief) with the Blocker's `description` + `to_clear` and the existing `ISSUE_BODY` to fix. Re-run §6.3 on the revised issue. **≤2 retries.** |
| **Genuine product gap** | No conventional default — what to build / user-facing behavior the substrate and a stated convention do not answer (the Buildability "no conventional default" case). | **Park to `productGaps[]`** / the needs-product-input report — do **not** re-author (re-dispatching cannot resolve a product gap; only a human can). Record as `needs-product-input`. |
| **Still-Blocker after 2 retries** | A design/impl Blocker that has not cleared after the 2nd `issue-author` re-dispatch. | **Park as needs-human-direction** in the report (the issue is non-converging — usually the candidate's design is wrong). Do not re-author further. |

**Retry-budget shape.** The **≤2** cap counts `issue-author` **re-dispatches per issue** (not Blockers, not gate passes). Each re-dispatch's brief carries **all of that issue's currently-outstanding Blockers** at once — a re-dispatch addresses every open Blocker in a single authoring pass, not one Blocker per retry — so two re-dispatches give the candidate two full attempts to clear the whole gate.

**Precedence — `undeclared-dependency` is §6.6, not §6.5.** An `undeclared-dependency` Blocker is handled entirely by §6.6 (absorb the edge into the graph + re-render the milestone description); it does **not** consume a §6.5 `issue-author` re-dispatch. §6.5's re-author path is reserved for design/impl Blockers in the issue **body** (missing state, unnamed pattern to mirror, etc.). The two never both act on the same Blocker.

A parked issue is **not emitted** in the milestone (§6.6 handles it and its dependents). The needs-product-input report (Step 7 format) gains a row per parked issue, marking product-gap vs needs-human-direction.

#### 6.6 — Absorb undeclared edges; drop parked issues

- **Undeclared `DEPENDS_ON` edges.** When a returned block surfaces a `DEPENDS_ON` edge (a `triage-reviewer` block) **or** a `severity: Blocker` of `type: undeclared-dependency` (from either backend — a `milestone-driver` block or an internal-checklist Criterion-4 finding; both now carry `type`, so this resolves identically) the decomposer did not declare, **add it to the dependency graph** and **re-render the milestone description** (re-run Step 5's render) so the Wave order reflects the new edge **before** any §6.5 re-dispatch — the re-dispatched `issue-author` and any subsequent reviewer pass see the corrected ordering context. This absorb-and-re-render cycle participates in the **same ≤2 per-issue re-dispatch bound** as §6.5: an issue still carrying a Blocker after its 2nd re-dispatch **parks as needs-human-direction** regardless of how the edge was re-rendered, so the re-render/re-dispatch loop always terminates at the cap.
- **Drop parked issues and their dependents.** A parked issue (product-gap or needs-human-direction) is removed from the emitted milestone, **and so is every issue that transitively depends on it** (a dependent of a dropped issue cannot build). Drop them from the rendered milestone description and mark them in the plan file as dropped-because-dependency. Re-render the milestone description once more after dropping, so the emitted Wave order (Step 7) contains only the issues that actually ship.

After §6.6, the surviving issue set has either all-PASS (or all-Advisory-only) verdicts, or the run is `SKIPPED` (`selfCheck:false`). Carry the gate outcome forward to the Step 7 status line.

### Step 7 — Emit (preview)

> **`--apply` GitHub creation deferred.** The self-check gate (Step 6 above) is active and has already gated the candidate set by the time this step runs. Only the `--apply` GitHub-write path (`SPEC.md` §6 step 7 — milestone + issue + label creation) remains **out of scope in this version**; it ships in v0.2.0 (issue #10). This version emits the preview directly; the plan file's self-check status line records the **actual gate outcome** (PASS / PARKED / INTERNAL / SKIPPED), so a reader knows the gate ran and what it found.

Write a reviewable **plan file** to a gitignored per-run scratch path: `.milestone-feeder/plan-<slug>.md`, where `<slug>` is a short kebab-case slug of the milestone goal. `.milestone-feeder*` **should be gitignored** (per-clone runtime scratch, like the driver's `.milestone-driver-*`); if the repo's `.gitignore` does not yet carry that pattern, the skill writes the file there **regardless** — the path is per-run scratch the user reviews and discards, never committed by this skill.

**Plan-file format:**

```markdown
# Milestone plan (PREVIEW) — <milestone goal, one line>

Self-check: <the Step 6 outcome — one of:
  PASS — all <N> issues GAPS: none (milestone-driver reviewers)
  INTERNAL — all <N> issues GAPS: none (internal checklist; milestone-driver reviewers did not resolve)
  PARKED — <M> issue(s) → needs product input; <K> issue(s) → needs human direction (still-Blocker after 2 retries)
  SKIPPED (selfCheck:false) — 🔴 gate disabled; generated issues were NOT vetted>
Source brief: <inline | file:<path> | epic #<n>>

## Milestone description (preview)
<the Step 5 Wave-ordered description, verbatim — the §4 template with local slugs>

## Issues
### #A — <title>   [<ui|logic>, <risk:*>]   [self-check: PASS]
<the full §4 ISSUE_BODY for #A>

### #B — <title>   [parked — needs product input]
<marker only; no fabricated body — see the needs-product-input report>

### #C — <title>   [parked — needs human direction (self-check Blocker, non-converging after 2 retries)]
<marker only; the issue did not clear the self-check gate — see the report>

### #D — <title>   [dropped — depends on parked #B]
<marker only; a dependent of a parked issue cannot build, so it is not emitted (Step 6 §6.6)>

### … (one block per surviving candidate, in Wave order; only PASS / Advisory-only issues carry a full body)

## Substrate grounding
- <each design call carried forward> — grounded in <.project/<doc>.md#<section> | sibling file:line>
- Degradations: <e.g. "uiSurfaceGlobs absent → all candidates treated as logic"; "none" otherwise>

## Needs human input
<pointer: "see .milestone-feeder/needs-product-input-<slug>.md" when productGaps is non-empty OR the self-check parked any issue as needs-human-direction; "none" otherwise>

---
To create these on GitHub, re-run with `--apply` (deferred to v0.2.0 — #10). This preview wrote no GitHub state.
```

If `productGaps[]` is **non-empty** OR the self-check parked any issue as **needs-human-direction** (§6.5), also write a **"needs product input" report** to `.milestone-feeder/needs-product-input-<slug>.md`. The report carries a **Kind** column so the human can tell a product decision (no conventional default — decide and record it) from a non-converging self-check Blocker (the candidate's design is likely wrong — redirect it):

```markdown
🔴 Needs human input — <milestone goal, one line>

These items blocked the milestone and were NOT guessed. Resolve each, then re-run decompose.

| # | Kind | Item | Why blocked | Blocks |
|---|---|---|---|---|
| 1 | product-gap | <the product decision with no conventional default> | <why the substrate / a convention cannot answer it> | <which candidate(s) / the whole scope> |
| 2 | needs-human-direction | <the self-check Blocker that did not clear in 2 retries> | <the reviewer's `description` / `to_clear`> | <which candidate(s) + any dropped dependents> |
| … | … | … | … | … |
```

**No GitHub writes occur on any path.** The plan file and the report are local scratch; nothing is posted to an issue, no milestone is created, no labels are applied, no comment is added to the epic. Apply (v0.2.0) is the only path that writes GitHub state, and it is not implemented here.

## Output style

Be concise — report status and outcomes flatly, no wall-of-text. Present steps, gates, lists, and options as **tables**, not inline prose. Mark anything that needs a human with 🔴. (Mirrors the agents' communication-style contract.)

## Non-negotiables

- **Preview only — performs NO GitHub writes; `--apply` is deferred to v0.2.0.** No milestone is created, no issue is opened, no label is applied, no comment is posted on any path. The entire output lands in local scratch files (the plan + the needs-product-input report). The `--apply` token is recognized but not implemented this version (issue #10).
- **Authors no code, opens no PRs, never touches branches.** The feeder reads code to ground decisions; it never edits a source file, creates a branch, or opens a PR. Every dispatched agent is read-only and runs against provided text.
- **Parks product gaps — never invents scope.** A decision with no conventional default is recorded to `productGaps[]` and surfaced in the needs-product-input report — never guessed to make an issue buildable. Design / implementation calls the substrate or a stated convention answers are resolved and cited; calls with no conventional default are parked.
- **Substrate is read best-effort, never fabricated.** Absent or `[TBD]` sections are skipped, never grounded on. A design call cites its real grounding (`.project/<doc>.md#<section>` or a verified sibling `file:line`) or it is parked as a product gap.
- **The decomposer is dispatched exactly once; the issue-author once per candidate.** The pipeline owns the dispatch count; the agents return text and the orchestrator consumes it — no agent opens a GitHub artifact of its own.
- **Self-check gate is mandatory.** Every generated issue is vetted (§5 / §6 Step 6) before emit; a failing issue is retried (≤2) or parked — never silently emitted. The gate is only skipped on an explicit `selfCheck:false`, and only with a visible 🔴 warning recorded in the plan-file status line.
