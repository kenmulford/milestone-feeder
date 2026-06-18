---
name: decompose
description: This skill should be used when the user invokes "/milestone-feeder:decompose <brief>", or asks to "decompose a brief into a milestone", "break a feature into issues". Turns a feature brief into a GitHub milestone + small, well-formed issues. PREVIEW ONLY in this version — writes a reviewable plan file; creates nothing on GitHub. Authors no code; opens no PRs.
---

# decompose — brief → milestone + issues

Read config + substrate, ingest a brief, separate product gaps from design decisions, dispatch the decomposer once and the issue-author per candidate, assemble the dependency graph, render the milestone description, and write a reviewable plan file. The driver's predecessor: it specifies what the driver then builds.

This skill is the orchestrator of the feeder's preview pipeline (`SPEC.md` §6, Steps 0–5; emit at Step 6). It makes *design and implementation* calls when the substrate or a stated repo convention supplies the answer, and it parks *product* calls — decisions about what to build or user-facing behavior with no conventional default — to a report instead of guessing them (`SPEC.md` §2 park boundary). It runs every dispatched agent read-only, against provided text, and lands its entire output in local files. **Authors no code, opens no PRs, never touches branches, never invents product scope — product gaps are parked to a report, never guessed. Preview only: no GitHub writes.**

## Announce first

Say this to the user before doing any work:

> Standing by while I decompose the brief into a milestone + issues. This is a preview — I'll write a reviewable plan file and create nothing on GitHub.

## Modes

Flags are **recognized by token match, not argument-parsed.** Claude Code does no argument parsing — `$ARGUMENTS` is string-substituted — so this skill is not a CLI parser. A flag is **recognized** when its token appears anywhere in the invocation text, exactly as the rest of the suite treats flags (mirrors `milestone-driver/skills/solve-milestone/SKILL.md:13`). The bare brief is `$ARGUMENTS` with any `--<token>` stripped.

| Trigger | Mode | Behavior |
|---|---|---|
| `/milestone-feeder:decompose <brief>` | **Preview** (default) | Full procedure, Steps 0–5, stops at a reviewable plan file. **No GitHub writes.** |
| `… --apply` | **Apply** *(deferred → v0.2.0)* | Recognized as a token, but **not implemented in this version.** When `--apply` is present, run the preview pipeline unchanged and note in the plan file that apply is deferred to v0.2.0 (issue #10). This version performs **no GitHub writes on any path** — `--apply` does not change that. |

The self-check gate (`SPEC.md` §5, Step 6 of the procedure) and the `--apply` GitHub-write path (`SPEC.md` §6, Step 7) are intentionally **out of scope** in this version — they ship in milestone **v0.2.0** (issues #9 and #10). This is a forward reference, not a gap: the preview pipeline is complete and self-contained, and emits a plan file whose self-check status line records that the gate is deferred.

## Procedure

### Step 0 — Read config + substrate (best-effort)

Read `.milestone-config/feeder.json`. **Absent → invoke `milestone-feeder:setup`** (it bootstraps the profile, aligns the label taxonomy, and returns control), then continue — the user does not re-run the command (`skills/setup/SKILL.md` Phase 5).

Extract the feeder's own keys with their bundled defaults (`docs/profile-schema.md`, absent-means-default):

| Key | Default | Use |
|---|---|---|
| `substrateDir` | `.project/` | Where the project-constitution docs live (grounds authoring). |
| `selfCheck` | `"milestone-driver"` | Reviewer backing the self-check gate — **read but unused this version** (Step 6 deferred to v0.2.0). |
| `decomposerAgent` | `milestone-feeder:decomposer` | The breakdown agent dispatched once at Step 3. |
| `issueAuthorAgent` | `milestone-feeder:issue-author` | The authoring agent dispatched per candidate at Step 4. |
| `issueSizeGuidance` | *(none)* | Optional sizing rule passed into the decomposer brief; absent → no constraint beyond the defaults. |

Read the substrate under `substrateDir` **best-effort** (`SPEC.md` §6 Step 0). Honor the `.project/` contract: a section that is absent or marked `[TBD]` is treated as **not present** — it is **skipped, never grounded on**. Degrade gracefully: a missing substrate directory is not an error; the run proceeds on whatever sections exist and on stated repo conventions. Cite a substrate-grounded decision as `.project/<doc>.md#<section>` when carrying it forward.

Resolve the **shared keys** the decomposer and issue-author need for grounding, from the driver config (`docs/profile-schema.md` shared-keys chain):

1. `.milestone-config/driver.json` (primary).
2. Root `milestone-driver.json` (legacy fallback).
3. **Absent-default** — an unset key uses its documented default; the feeder does not invent a value.

The shared keys are `sourceGlobs`, `uiSurfaceGlobs`, and `integrationBranch`. **Degradation:** when `uiSurfaceGlobs` is absent (neither driver file carries it), treat every candidate as **logic** (no UI surface can be matched, so no design-lens distinction is drawn) and **state the degradation** in the plan file's grounding section. The pipeline still runs.

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

If a product gap is severe enough that the candidate set **cannot even be formed** without it (the brief's core scope is undecided), **STOP**: emit the "needs product input" report (Step 6 format) and end the run — do not dispatch the decomposer against an undecided scope. Otherwise carry `productGaps[]` forward: the pipeline proceeds with the decidable work, and the gaps surface in the plan + report at Step 6.

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

### Step 6 — Emit (preview)

> **Self-check gate deferred.** `SPEC.md` §6 Step 6 (the self-check against the driver's `triage-reviewer` / `design-reviewer`, §5) and Step 7 (`--apply` GitHub creation) are **out of scope in this version** — they ship in v0.2.0 (issues #9 and #10). This version emits the preview directly; the plan file's self-check status line records that the gate is **deferred**, so a reader knows it was not run (not that it passed).

Write a reviewable **plan file** to a gitignored per-run scratch path: `.milestone-feeder/plan-<slug>.md`, where `<slug>` is a short kebab-case slug of the milestone goal. `.milestone-feeder*` **should be gitignored** (per-clone runtime scratch, like the driver's `.milestone-driver-*`); if the repo's `.gitignore` does not yet carry that pattern, the skill writes the file there **regardless** — the path is per-run scratch the user reviews and discards, never committed by this skill.

**Plan-file format:**

```markdown
# Milestone plan (PREVIEW) — <milestone goal, one line>

Self-check: DEFERRED — the §5 self-check gate ships in v0.2.0 (#9); not run this version.
Source brief: <inline | file:<path> | epic #<n>>

## Milestone description (preview)
<the Step 5 Wave-ordered description, verbatim — the §4 template with local slugs>

## Issues
### #A — <title>   [<ui|logic>, <risk:*>]
<the full §4 ISSUE_BODY for #A>

### #B — <title>   [parked — needs product input]
<marker only; no fabricated body — see the needs-product-input report>

### … (one block per candidate, in Wave order)

## Substrate grounding
- <each design call carried forward> — grounded in <.project/<doc>.md#<section> | sibling file:line>
- Degradations: <e.g. "uiSurfaceGlobs absent → all candidates treated as logic"; "none" otherwise>

## Needs product input
<pointer: "see .milestone-feeder/needs-product-input-<slug>.md" when productGaps is non-empty; "none" otherwise>

---
To create these on GitHub, re-run with `--apply` (deferred to v0.2.0 — #10). This preview wrote no GitHub state.
```

If `productGaps[]` is **non-empty**, also write a **"needs product input" report** to `.milestone-feeder/needs-product-input-<slug>.md`:

```markdown
🔴 Needs product input — <milestone goal, one line>

These decisions have no conventional default and were NOT guessed. Decide each, record it, then re-run decompose.

| # | Undecided | Why no default | Blocks |
|---|---|---|---|
| 1 | <the product decision> | <why the substrate / a convention cannot answer it> | <which candidate(s) / the whole scope> |
| 2 | … | … | … |
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
