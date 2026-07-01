# Roadmap manifest format

`build-roadmap` writes the roadmap manifest to `.milestone-feeder/roadmap-<slug>.md` on confirmation — the authoritative cross-milestone build artifact that records WHICH milestones to plan and in WHAT order, plus the full original brief. This reference is its exact shape: `build-roadmap` Step 4 reads it on demand to write the manifest, and the downstream consumers read the manifest this shape produces (`skills/plan/SKILL.md` Step 3.7; `skills/create/SKILL.md` Step 1R).

Write the manifest in this shape. It carries the source-brief reference, the **full** original brief (a durable record of the whole-app brief this roadmap was built from), the cross-milestone build order, and one entry per confirmed milestone. It does **NOT** carry the per-milestone §4 issue bodies or Wave order — those live in each milestone's own `plan-<slug>.md` (`.project/design-philosophy.md#Layering & boundaries`):

```markdown
# Milestone roadmap — <whole-app brief one-line goal>

Source brief: <inline | file:<path> | epic #<n>>
Confirmed: yes — this roadmap is the USER-CONFIRMED split. Any merge / split / reorder the user asked for at the confirmation checkpoint is already applied here; this is NOT the raw splitter proposal.
Build order: <milestone 1 name> → <milestone 2 name> → … → <milestone N name>

## Original brief
<The FULL original whole-app brief text, persisted verbatim and multi-line — every
 section the author wrote, in full. This is a MULTI-LINE section, NOT a single
 header line: a durable record of the whole-app brief this roadmap was built from.
 Persisting it here is the manifest owner's contract. The brief is delimited by the paired
 `## Original brief` … `## End original brief` markers (the literal closing line below),
 so a brief that contains its OWN `## ` headings is captured intact — a consumer reads
 strictly between the two markers and is NOT truncated at the brief's first internal
 `## ` heading.>
## End original brief

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
