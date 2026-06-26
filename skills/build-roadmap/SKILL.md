---
name: build-roadmap
description: This skill is INTERNAL — it is invoked by the `plan` skill when it detects an oversized whole-app brief that spans several releases, never by a user command. It turns that oversized brief into a confirmed, sequenced roadmap of milestones: it dispatches the `milestone-feeder:roadmap-splitter` agent once to propose a strict, build-ordered partition, surfaces the proposed split for the user to confirm / merge / split / reorder / reject, and on confirmation writes a roadmap manifest to `.milestone-feeder/roadmap-<slug>.md`, then returns control plus the manifest path to `plan`. Read-only on GitHub: writes a single local scratch manifest and creates nothing on GitHub. Authors no code; opens no PRs.
---

# build-roadmap — oversized brief → confirmed milestone roadmap

Turn one oversized whole-app brief into a confirmed, sequenced roadmap of milestones — without yet planning or deploying any of them. This is an **internal** skill: the user never invokes it directly; `plan` invokes it (wired in #154) when it detects a brief that spans several releases. It dispatches the `milestone-feeder:roadmap-splitter` agent (#151) **once** to propose a strict, build-ordered partition of the brief, surfaces that proposal for the user to confirm / merge / split / reorder / reject **before writing anything**, and on confirmation writes a roadmap manifest to local scratch and returns control (plus the manifest path) to `plan`.

The roadmap manifest is the **cross-milestone build artifact**: it records *which* milestones to plan and in *what* order, plus the full original brief. It does **not** carry each milestone's §4 issue bodies or Wave order — those live in each milestone's own `plan-<slug>.md`, produced when `plan` runs its single-milestone pipeline per milestone downstream (`.project/design-philosophy.md#Layering & boundaries` — the plan file / manifest is the build artifact; skills orchestrate). This skill performs **no GitHub writes** and **authors no code**: its entire output is one local scratch manifest under `.milestone-feeder/`. It dispatches the splitter read-only, against provided text, and consumes its structured `ROADMAP` block.

## Announce first

Say this to the user before doing any work:

> Standing by while I turn this oversized brief into a proposed, sequenced roadmap of milestones and surface it for your confirmation. This is read-only — I'll dispatch the roadmap-splitter once, show you the proposed split, and write nothing until you confirm. No GitHub state.

## Procedure

### Step 0 — Receive the inputs from `plan` (no re-resolution)

`plan` hands this skill everything it needs — already resolved once at `plan`'s own Step 0. **This skill re-reads no config and re-resolves nothing** (the resolve-once boundary; `skills/plan/SKILL.md:22`). It receives:

| Input | What it is |
|---|---|
| **The oversized whole-app brief** | The normalized brief (`{ goal, in-scope, out-of-scope, surfaces, … }`, `plan` Step 1) for the whole app — the scope `plan` judged to span several releases. |
| **The source-brief reference** | The `inline` \| `file:<path>` \| `epic #<n>` form `plan` detected when it ingested the brief (`plan` Step 1). Recorded verbatim in the manifest header; this skill posts nothing to any epic. |
| **The resolved feeder profile + shared keys** | The feeder keys and the resolved shared keys (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`) `plan` resolved at its Step 0. Passed through; never re-resolved. |
| **The resolved project-docs grounding digest** | The `.project/<doc>.md#<section>` slices `plan` assembled at its Step 0. Passed through to the splitter as its grounding; an **empty digest** (no `.project/`, or all sections absent / `[TBD]`) is passed through unchanged and is **not an error** (`.project/design-philosophy.md#Error & failure philosophy`). |

### Step 1 — Dispatch the roadmap-splitter (exactly once)

Dispatch `milestone-feeder:roadmap-splitter` (#151) **exactly once** — it does not itself fan out per-milestone planning (`.project/design-philosophy.md#Layering & boundaries`; the once-per-run dispatch discipline `plan` applies to the architect, `skills/plan/SKILL.md:331`).

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
```

### Step 2 — Validate the returned ROADMAP (partition / single-milestone / error)

Read the returned block and route to exactly one of three outcomes. **Nothing is written under `.milestone-feeder/` until Step 4**, so a wrong return at this step leaves the working tree clean.

| Outcome | Detection | Action |
|---|---|---|
| **Multi-milestone partition** | The block parses; **two or more** entries; `position` values run `1..N` with no gaps or repeats; the `brief_slice` set is a **strict partition** of the brief's in-scope — every part of the brief assigned to exactly one milestone, none dropped, none duplicated. | Proceed to **Step 3** (surface for confirm). |
| **Single-milestone (does not split)** | The block parses but carries **fewer than two** milestones (a single entry at `position: 1` — the analog of the architect's literal `none`, `agents/roadmap-splitter.md` clause 5). | **Write no manifest.** Tell the user it is a single milestone after all, and **return control** so `plan` proceeds with its existing single-milestone pipeline on the whole brief **unchanged**. **This is NOT an error.** |
| **Error / malformed / non-partition** | The dispatch failed (no usable block returned), **or** the block is unparseable, **or** it is **not a strict partition** — a brief slice unassigned, a slice double-assigned, or `position` values with a gap or a repeat. | **Surface the failure** to the user (state what was wrong). **Write no partial or corrupt manifest.** **Return control without advancing** — `plan` does not proceed on a failed split. |

A partition check that the splitter's own contract guarantees is **re-verified here, not assumed** — the skill owns the manifest, so it gates what lands in it.

### Step 3 — Surface the proposed roadmap for confirm / merge / split / reorder / reject

**Surface the proposed roadmap for the user to confirm BEFORE writing anything** — mirror `plan`'s surface-for-confirm (`skills/plan/SKILL.md:608`, `:610`; `.project/design-philosophy.md#One-way doors` — a one-way door is surfaced for sign-off, never silently finalized). Present the proposal as a table, one row per milestone:

| # | Milestone | Brief slice | Build-order position | Change-rationale |
|---|---|---|---|---|
| 1 | <name> | <slice> | 1 | <merged / split / reordered / unchanged, and why> |
| 2 | <name> | <slice> | 2 | <…> |
| … | … | … | … | … |

The user may:

| Choice | Effect |
|---|---|
| **Confirm** | Record the proposal as-is. Proceed to Step 4. |
| **Merge / split / reorder** | Apply the user's edits to the roadmap, then **re-verify the partition** (Step 2's partition rule) — a user edit that drops or duplicates a brief slice, or that breaks the `1..N` positions, is **re-surfaced for correction, never silently written**. Once the edited roadmap is a valid partition and the user confirms it, proceed to Step 4 recording the **user-confirmed** roadmap (edits applied) — **not** the raw proposal. |
| **Reject** | **Write no manifest.** Return control to `plan` (the user declined the split). |

### Step 4 — Write the roadmap manifest (on confirmation) and return control

**Make the scratch git-invisible from the first write (zero user setup).** `.milestone-feeder/` is pure per-run scratch with no tracked config of its own. **Before writing any file under `.milestone-feeder/`, FIRST ensure the directory self-ignores:** create `.milestone-feeder/` if absent, and ensure `.milestone-feeder/.gitignore` exists containing a single `*` line — which makes the whole folder (and the `.gitignore` itself) invisible to `git status` in **any** consumer repo, without touching the consumer's root `.gitignore` (`.project/environment.md#Data stores` — scratch under `.milestone-feeder/`, gitignored via a `*` drop on first write). This is the same first-write self-ignore `plan` uses (`skills/plan/SKILL.md:579-591`):

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

**Write the manifest** (format below). **A failed scratch-write is surfaced, not swallowed** — if the write fails, tell the user and **do not advance control** as if a manifest existed (`.project/design-philosophy.md#Error & failure philosophy` — surfaced, never silently dropped). Never leave a partial or corrupt manifest: on any write failure, the manifest must be absent, not half-written.

**Return control + the manifest path to `plan`.** On a successful write, return the manifest path so `plan` resumes and runs its single-milestone pipeline once per milestone the roadmap names, in build order. On the single-milestone (Step 2) or reject (Step 3) paths, return with **no** manifest path — signalling `plan` to proceed with its existing single-milestone pipeline on the whole brief, unchanged.

## Manifest format

Write the manifest in this shape. It carries the source-brief reference, the **full** original brief (persisted in full — required downstream by the brief-coverage verification, #158), the cross-milestone build order, and one entry per confirmed milestone. It does **NOT** carry the per-milestone §4 issue bodies or Wave order — those live in each milestone's own `plan-<slug>.md` (`.project/design-philosophy.md#Layering & boundaries`):

```markdown
# Milestone roadmap — <whole-app brief one-line goal>

Source brief: <inline | file:<path> | epic #<n>>
Confirmed: yes — this roadmap is the USER-CONFIRMED split. Any merge / split / reorder the user asked for at the confirmation checkpoint is already applied here; this is NOT the raw splitter proposal.
Build order: <milestone 1 name> → <milestone 2 name> → … → <milestone N name>

## Original brief
<The FULL original whole-app brief text, persisted verbatim and multi-line — every
 section the author wrote, in full. This is a MULTI-LINE section, NOT a single
 header line: the downstream brief-coverage verification (#158) reads it to confirm
 the roadmap covers everything the brief asked for. Persisting it here is the manifest
 owner's contract, shared with #158 / #157.>

## Milestones (in build order)

### 1. <milestone name>
- Brief slice: <the portion of the brief this milestone owns — the author sections / scope it covers, verbatim or closely paraphrased>
- Build-order position: 1
- Plan file: <pending — `build-roadmap` leaves this EMPTY; the roadmap planning fan-out (`plan` Step 3.7) populates it with `.milestone-feeder/plan-<assignedSlug>.md` after it plans this milestone>
- Change-rationale: <merged | split | reordered | unchanged vs the author's headings, and why — the sections involved and the dependency, if any>

### 2. <milestone name>
- Brief slice: <…>
- Build-order position: 2
- Plan file: <pending — populated by the fan-out (`plan` Step 3.7) after it plans this milestone>
- Change-rationale: <…>

### … (one block per confirmed milestone, in build order; positions run 1..N)

---
This roadmap manifest is the cross-milestone build artifact. It records WHICH milestones to plan and in WHAT order, plus the full original brief — NOT each milestone's §4 issue bodies or Wave order, which `plan` produces into that milestone's own `.milestone-feeder/plan-<slug>.md` when it runs the single-milestone pipeline per milestone above. `build-roadmap` wrote no GitHub state.
```

**The `Plan file:` field — the deterministic per-milestone handle, written in two stages.** Each milestone entry carries a `Plan file:` field, but `build-roadmap` writes it **PENDING (empty)**: at manifest-write time it has confirmed only the milestone *names* and *build order* — it has planned **no** milestone, so it does **not** yet know the disambiguated `assignedSlug` that names the plan file (that slug is goal-derived with an `-m<index>` collision tiebreaker the milestone *name* does not encode; `plan` Step 3.7.d owns it). The **roadmap planning fan-out** (`plan` Step 3.7) **populates** each entry's `Plan file:` with that milestone's real path — `.milestone-feeder/plan-<assignedSlug>.md` — **after** it plans that milestone (`plan` Step 3.7.g). Once the fan-out finishes, every planned milestone's entry carries its real plan-file path, and that path is the **deterministic handle `create`'s deploy-loop resolves each milestone's plan file by** (`skills/create/SKILL.md` Step 1R) — **never** a slug re-derived from the milestone name. `build-roadmap` itself reserves the field and plans nothing; populating it is the fan-out's job.

## Output style

Be concise — report status and outcomes flatly, no wall-of-text. Present steps, gates, lists, and options as **tables**, not inline prose. Mark anything that needs a human with 🔴. (Mirrors the agents' communication-style contract.)

## Non-negotiables

- **Internal only.** Invoked by `plan` (#154) when it detects an oversized brief — never a user command. Introduces **no new `feeder.json` key**; the user-facing discovery / migration path is owned by #154 (`.project/design-philosophy.md#One-way doors` — a new profile key is added only when a real consumer needs it).
- **The roadmap-splitter is dispatched exactly once.** It returns the `ROADMAP` block and this skill consumes it; the splitter opens no GitHub artifact of its own.
- **Surface for confirm — never silently finalize.** The proposed roadmap is always surfaced for the user to confirm / merge / split / reorder / reject before any write. On edits, the manifest records the **user-confirmed** roadmap (edits applied), re-verified as a strict partition; on reject, no manifest is written.
- **Fewer than two milestones is the single-milestone state, NOT an error.** Write no manifest, tell the user, and return so `plan` proceeds with its existing single-milestone pipeline unchanged.
- **A failed dispatch, a malformed return, or a non-partition split writes NO partial or corrupt manifest.** The failure is surfaced, not swallowed; control does not advance on a failed split or a failed scratch-write.
- **The manifest persists the FULL original brief** in a multi-line `## Original brief` section — the manifest is the cross-milestone build artifact, and this skill is its owner (the persisted-brief decision is shared with #158 / #157).
- **Each milestone entry reserves a `Plan file:` field, written PENDING.** `build-roadmap` plans no milestone, so it cannot know the disambiguated `assignedSlug` that names each plan file — it leaves the field empty. The roadmap planning fan-out (`plan` Step 3.7) populates it with `.milestone-feeder/plan-<assignedSlug>.md` after it plans that milestone; that recorded path is the handle `create`'s deploy-loop reads (`skills/create/SKILL.md` Step 1R), never a name-derived slug. (Producer↔consumer contract shared with #155 / #157.)
- **Scratch is git-invisible from the first write** — `.milestone-feeder/.gitignore` is ensured to contain a single `*` before the first write under `.milestone-feeder/`, as bash + PowerShell 7+ twins.
- **`build-roadmap` writes NO GitHub state and authors no code.** Its entire output is one local scratch manifest. No milestone is created, no issue is opened, no label is applied, no PR is opened, no branch is touched. The downstream `plan` → `create` pipeline is the only thing that writes GitHub state.
