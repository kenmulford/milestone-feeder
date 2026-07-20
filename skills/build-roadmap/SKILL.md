---
name: build-roadmap
description: >-
  This skill is INTERNAL — it is invoked by the `plan` skill when it detects an oversized whole-app brief that spans several releases, never by a user command. It turns that oversized brief into a confirmed, sequenced roadmap of milestones: it dispatches the `milestone-feeder:roadmap-splitter` agent once to propose a strict, build-ordered partition, surfaces the proposed split for the user to confirm / merge / split / reorder / reject, and on confirmation writes a roadmap manifest to `.milestone-feeder/roadmap-<slug>.md`, then returns control plus the manifest path to `plan`. Read-only on GitHub: writes a single local scratch manifest and creates nothing on GitHub. Authors no code; opens no PRs.
---

# build-roadmap — oversized brief → confirmed milestone roadmap

Turn one oversized whole-app brief into a confirmed, sequenced roadmap of milestones — without yet planning or deploying any of them. This is an **internal** skill: the user never invokes it directly; `plan` invokes it (wired in #154) when it detects a brief that spans several releases. It dispatches the `milestone-feeder:roadmap-splitter` agent (#151) **once** to propose a strict, build-ordered partition of the brief, surfaces that proposal for the user to confirm / merge / split / reorder / reject **before writing anything**, and on confirmation writes a roadmap manifest to local scratch and returns control (plus the manifest path) to `plan`.

The roadmap manifest is the **cross-milestone build artifact**: it records *which* milestones to plan and in *what* order, plus the full original brief. It does **not** carry each milestone's §4 issue bodies or Wave order — those live in each milestone's own `plan-<slug>.md`, produced when `plan` runs its single-milestone pipeline per milestone downstream (`.project/design-philosophy.md#Layering & boundaries` — the plan file / manifest is the build artifact; skills orchestrate). This skill performs **no GitHub writes** and **authors no code**: its entire output is one local scratch manifest under `.milestone-feeder/`. It dispatches the splitter read-only, against provided text, and consumes its structured `ROADMAP` block.

## Announce first

Say this to the user before doing any work:

> Standing by while I turn this oversized brief into a proposed, sequenced roadmap of milestones and surface it for your confirmation. This is read-only — I'll dispatch the roadmap-splitter once, show you the proposed split, and write nothing until you confirm. No GitHub state.

## Procedure

### Step 0 — Receive the inputs from `plan` (no re-resolution)

`plan` hands this skill everything it needs — already resolved once at `plan`'s own Step 0. **This skill re-reads no config and re-resolves nothing** (the resolve-once boundary; `skills/plan/SKILL.md` Step 0 — the once-per-run OUTER boundary). It receives:

| Input | What it is |
|---|---|
| **The oversized whole-app brief** | The normalized brief (`{ goal, in-scope, out-of-scope, surfaces, … }`, `plan` Step 1) for the whole app — the scope `plan` judged to span several releases. |
| **The source-brief reference** | The `inline` \| `file:<path>` \| `epic #<n>` form `plan` detected when it ingested the brief (`plan` Step 1). Recorded verbatim in the manifest header; this skill posts nothing to any epic. |
| **The resolved feeder profile + shared keys** | The feeder keys and the resolved shared keys (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`) `plan` resolved at its Step 0. Passed through; never re-resolved. |
| **The resolved project-docs grounding digest** | The `.project/<doc>.md#<section>` slices `plan` assembled at its Step 0. Passed through to the splitter as its grounding; an **empty digest** (no `.project/`, or all sections absent / `[TBD]`) is passed through unchanged and is **not an error** (`.project/design-philosophy.md#Error & failure philosophy`). |

### Step 1 — Dispatch the roadmap-splitter (exactly once)

Dispatch `milestone-feeder:roadmap-splitter` (#151) **exactly once** — it does not itself fan out per-milestone planning (`.project/design-philosophy.md#Layering & boundaries`; the once-per-run dispatch discipline `plan` applies to the architect, `skills/plan/SKILL.md` Step 3 — "Dispatch the architect (once)").

**Brief it with** (matches `agents/roadmap-splitter.md` → "What you receive"):

- **The brief** — the normalized whole-app scope from Step 0.
- **The resolved project-docs digest** from Step 0 — the splitter's grounding. Handed in as-is; an empty digest is passed through unchanged (degrade exactly as Step 0 does).
- **The resolved shared profile key** — the *value* for `sourceGlobs` (the source paths that back the splitter's on-demand repo reads in its Rigor gate).

**It returns** (verbatim from `agents/roadmap-splitter.md` → "Structured return block"):

```
ROADMAP:
  - milestone: <name of proposed milestone>
    position: 1
    brief_slice: <the portion of the brief this milestone owns>
    rationale: <merged | split | reordered | unchanged vs the author's headings, and why>
  - milestone: <name of proposed milestone>
    position: 2
    brief_slice: <…>
    rationale: <…>
  - …                       # one entry per proposed milestone, IN BUILD ORDER
parent_title: <the roadmap's one-line goal, reused from the whole-app brief's
              own one-line goal>   # top-level field, alongside ROADMAP
parent_intro: <the intro for the future md-epic parent issue's
              body: what the roadmap covers and the build order it spans>
```

`parent_title` and `parent_intro` are whole-roadmap fields, not per-milestone entries: the roadmap's one-line goal (the future `md-epic` parent issue's title) and the intro for that issue's body (`agents/roadmap-splitter.md` clause 7). Both ride alongside the `ROADMAP` list only when the split is multi-milestone (two or more entries); the single-milestone return (Step 2's single-milestone row) omits them entirely, not blank.

### Step 2 — Validate the returned ROADMAP (partition / single-milestone / error)

Read the returned block and route to exactly one of three outcomes. **Nothing is written under `.milestone-feeder/` until Step 4**, so a wrong return at this step leaves the working tree clean.

| Outcome | Detection | Action |
|---|---|---|
| **Multi-milestone partition** | The block parses; **two or more** entries; `position` values run `1..N` with no gaps or repeats; the `brief_slice` set is a **strict partition** of the brief's in-scope — every part of the brief assigned to exactly one milestone, none dropped, none duplicated. | Proceed to **Step 3** (surface for confirm). |
| **Single-milestone (does not split)** | The block parses but carries **fewer than two** milestones (a single entry at `position: 1` — the analog of the architect's literal `none`, `agents/roadmap-splitter.md` clause 5). | **Write no manifest.** Tell the user it is a single milestone after all, and **return control** so `plan` proceeds with its existing single-milestone pipeline on the whole brief **unchanged**. **This is NOT an error.** |
| **Error / malformed / non-partition** | The dispatch failed (no usable block returned), **or** the block is unparseable, **or** it is **not a strict partition** (a brief slice unassigned, a slice double-assigned, or `position` values with a gap or a repeat), **or** it is a multi-milestone (two or more entries) return that omits `parent_title` and/or `parent_intro` (the fields `agents/roadmap-splitter.md` clause 7 requires whenever the split is multi-milestone): a well-formed but incomplete parent-field return is malformed under this row too. | **Surface the failure** to the user (state what was wrong). **Write no partial or corrupt manifest.** **Return control without advancing** (`plan` does not proceed on a failed split). |

A partition check that the splitter's own contract guarantees is **re-verified here, not assumed** — the skill owns the manifest, so it gates what lands in it.

### Step 3 — Surface the proposed roadmap for confirm / merge / split / reorder / reject

Step 2's multi-milestone route guarantees `parent_title`/`parent_intro` are present at this point (a return missing either field never reaches Step 3, per Step 2's error row). Surface them first, in a small key/value table:

| Field | Value |
|---|---|
| Parent title | <parent_title> |
| Parent intro | <parent_intro> |

**Surface the proposed roadmap for the user to confirm BEFORE writing anything** — mirror `plan`'s surface-for-confirm (`skills/plan/SKILL.md` Step 7 — "Surface the resolved identity for confirm/override"; `.project/design-philosophy.md#One-way doors` — a one-way door is surfaced for sign-off, never silently finalized). Present the proposal as a table, one row per milestone:

| # | Milestone | Brief slice | Build-order position | Change-rationale |
|---|---|---|---|---|
| 1 | <name> | <slice> | 1 | <merged / split / reordered / unchanged, and why> |
| 2 | <name> | <slice> | 2 | <…> |
| … | … | … | … | … |

The user may:

| Choice | Effect |
|---|---|
| **Confirm** | Record the proposal as-is. Proceed to Step 4. |
| **Merge / split / reorder** | Apply the user's edits to the roadmap, then **re-verify the partition** (Step 2's partition rule) — a user edit that drops or duplicates a brief slice, or that breaks the `1..N` positions, is **re-surfaced for correction, never silently written**. This correction loop is **bounded: at most 2 re-prompts total per correction attempt** — not per visit to Step 3 (a plain **Confirm** with no edit never touches the cap) and not per violation type. Each of the 1st and 2nd re-prompts **names exactly which slice or position broke the partition** — a brief_slice left unassigned, a brief_slice assigned to two or more milestones, or a `position` value that creates a gap or repeat in the `1..N` sequence (e.g. "milestone slice X was not assigned", "milestone slice Y was assigned to both #A and #B", "position 3 is missing / duplicated") — **never** a generic "invalid edit" message. On the **3rd invalid edit** (cap exhausted), 🔴 produce the escape hatch verbatim — "edit the brief directly and re-run plan" — treated **exactly as the existing Reject outcome**: write no manifest, return control to `plan` with no manifest path; **never** a 3rd re-prompt. Once the edited roadmap is a valid partition and the user confirms it, proceed to Step 4 recording the **user-confirmed** roadmap (edits applied) — **not** the raw proposal. |
| **Reject** | **Write no manifest.** Return control to `plan` (the user declined the split). |

The same three choices govern `parent_title`/`parent_intro` too: Confirm records them as-is, an edit to either persists the edited value (never the raw proposal), and Reject discards them along with the rest of the rejected proposal, no manifest written.

### Step 4 — Write the roadmap manifest (on confirmation) and return control

**Make the scratch git-invisible from the first write (zero user setup).** `.milestone-feeder/` is pure per-run scratch with no tracked config of its own. **Before writing any file under `.milestone-feeder/`, FIRST ensure the directory self-ignores:** create `.milestone-feeder/` if absent, and ensure `.milestone-feeder/.gitignore` exists containing a single `*` line — which makes the whole folder (and the `.gitignore` itself) invisible to `git status` in **any** consumer repo, without touching the consumer's root `.gitignore` (`.project/environment.md#Data stores` — scratch under `.milestone-feeder/`, gitignored via a `*` drop on first write). This is the same first-write self-ignore `plan` uses (`skills/plan/SKILL.md` Step 7 — "Make the scratch git-invisible from the first write"):

```bash
# bash — ensure the scratch dir self-ignores BEFORE the first write under it.
mkdir -p .milestone-feeder
[ -f .milestone-feeder/.gitignore ] || printf '*\n' > .milestone-feeder/.gitignore
```

```powershell
# PowerShell 7+ — same ensure-self-ignore before the first write.
New-Item -ItemType Directory -Force -Path .milestone-feeder | Out-Null
if (-not (Test-Path .milestone-feeder/.gitignore)) { Set-Content -LiteralPath .milestone-feeder/.gitignore -Value '*' -Encoding utf8NoBOM }
```

**Derive the manifest slug deterministically.** Write the manifest to `.milestone-feeder/roadmap-<slug>.md`, where `<slug>` is derived from the **whole-app brief's one-line goal / title** by the **same deterministic rule the plan file uses** (`.project/conventions.md#Naming`; `skills/plan/SKILL.md` Step 7): take the one-line goal, lowercase it, replace every run of non-alphanumeric characters with a single hyphen, strip any leading/trailing hyphens, and cap the length at a reasonable bound (trimming a trailing hyphen if the cut lands on one). A roadmap has no single milestone goal, so the slug derives from the whole-app brief's one-line goal/title; the manifest header carries the source-brief reference for the brief↔manifest match.

**Write the manifest** (format in `docs/roadmap-manifest-format.md` — read it on demand). **A failed scratch-write is surfaced, not swallowed** — if the write fails, tell the user and **do not advance control** as if a manifest existed (`.project/design-philosophy.md#Error & failure philosophy` — surfaced, never silently dropped). Never leave a partial or corrupt manifest: on any write failure, the manifest must be absent, not half-written.

The header block now also carries the user-confirmed `Parent title:` and `Parent intro:` fields immediately after `Build order:`, persisting the values confirmed at Step 3, never the raw splitter proposal.

**Return control + the manifest path to `plan`.** On a successful write, return the manifest path so `plan` resumes and runs its single-milestone pipeline once per milestone the roadmap names, in build order. On the single-milestone (Step 2) or reject (Step 3) paths, return with **no** manifest path — signalling `plan` to proceed with its existing single-milestone pipeline on the whole brief, unchanged.

## Manifest format

The roadmap manifest is the **authoritative cross-milestone build artifact** — its exact shape (every field, the paired `## Original brief` … `## End original brief` markers, the `## Milestones (in build order)` entries, and the two-stage `Plan file:` handle) is defined in `docs/roadmap-manifest-format.md`. Step 4 reads that reference on demand to write the manifest; consumers cite this contract by section name as `skills/build-roadmap/SKILL.md "Manifest format"` (`skills/plan/SKILL.md` Step 3.7; `skills/create/SKILL.md` Step 1R).

## Output style

Defined once at `docs/style-contracts.md#output-style` — read it there; it is not restated here.

## Non-negotiables

- **Internal only.** Invoked by `plan` (#154) when it detects an oversized brief — never a user command. Introduces **no new `feeder.json` key**; the user-facing discovery / migration path is owned by #154 (`.project/design-philosophy.md#One-way doors` — a new profile key is added only when a real consumer needs it).
- **The roadmap-splitter is dispatched exactly once.** It returns the `ROADMAP` block and this skill consumes it; the splitter opens no GitHub artifact of its own.
- **Surface for confirm — never silently finalize.** The proposed roadmap is always surfaced for the user to confirm / merge / split / reorder / reject before any write. On edits, the manifest records the **user-confirmed** roadmap (edits applied), re-verified as a strict partition; on reject, no manifest is written.
- **Fewer than two milestones is the single-milestone state, NOT an error.** Write no manifest, tell the user, and return so `plan` proceeds with its existing single-milestone pipeline unchanged.
- **A failed dispatch, a malformed return, or a non-partition split writes NO partial or corrupt manifest.** The failure is surfaced, not swallowed; control does not advance on a failed split or a failed scratch-write.
- **The manifest persists the FULL original brief** delimited by the paired `## Original brief` … `## End original brief` markers — a multi-line section robust to briefs containing their own `## ` headings (a consumer reads strictly between the markers) — a durable record of the whole-app brief this roadmap was built from. The manifest is the cross-milestone build artifact, and this skill is its owner.
- **Each milestone entry reserves a `Plan file:` field, written PENDING.** `build-roadmap` plans no milestone, so it cannot know the disambiguated `assignedSlug` that names each plan file — it leaves the field empty. The roadmap planning fan-out (`plan` Step 3.7) populates it with `.milestone-feeder/plan-<assignedSlug>.md` after it plans that milestone; that recorded path is the handle `create`'s deploy-loop reads (`skills/create/SKILL.md` Step 1R), never a name-derived slug. (Producer↔consumer contract shared with #155 / #157.)
- **Scratch is git-invisible from the first write** — `.milestone-feeder/.gitignore` is ensured to contain a single `*` before the first write under `.milestone-feeder/`, as bash + PowerShell 7+ twins.
- **`build-roadmap` writes NO GitHub state and authors no code.** Its entire output is one local scratch manifest. No milestone is created, no issue is opened, no label is applied, no PR is opened, no branch is touched. The downstream `plan` → `create` pipeline is the only thing that writes GitHub state.
