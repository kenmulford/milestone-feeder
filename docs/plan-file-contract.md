# Plan-file contract

This is the shared reference for the plan file's fields and output templates — the structures `create` and `update` parse. Its three artifacts are copied verbatim from `skills/plan/SKILL.md` Step 7, so downstream skills can cite one definition instead of each repeating the contract.

- [Plan-file field table](#plan-file-field-table)
- [Plan-file output template](#plan-file-output-template)
- [Needs-product-input report template](#needs-product-input-report-template)

## Plan-file field table

| Field | Requirement |
|---|---|
| **Milestone title (exact)** | The exact milestone title, on its own labeled line — **distinct** from the one-line goal. Now **user-owned** and carrying the resolved **semver inside the string** (no separate version field), resolved at Step 5.1 by the version ladder and **surfaced for the user to confirm or override BEFORE `create`** (`docs/specs/v0.3.1-driver-handoff.md` §3, §6). `create` / `update` still resolve the milestone by this exact title (creating it if absent, adopting it if it already exists), and the driver parses the version from it — this remains the load-bearing identity field; the one-line goal is descriptive only. |
| **Version provenance** | One line, one of `explicit` \| `declaration` \| `inferred from <tag/milestone>` \| `prompted` (the Step 5.1 ladder rung that resolved the title — `docs/specs/v0.3.1-driver-handoff.md` §6 "Version provenance" row). It makes the surfaced default **legible** so the user can trust or correct it. |
| **Multi-milestone advisory** | **ADDITIVE and OPTIONAL** — present **ONLY** on the **retained** path: the architect raised `SCOPE_SPANS_MULTIPLE_MILESTONES` (Step 3) **AND** the front-door (Step 3.6) did **NOT** route this brief into `build-roadmap` (`roadmapRouteTaken` false — the signal was raised but the route degraded, was declined, or resolved to a single milestone). On that path it carries the flag + the proposed split (milestone names + their candidate tags) **VERBATIM** from the architect — `plan` does not re-partition. **OMITTED entirely** when the signal is `none` (single-milestone plan byte-for-byte unchanged) **OR** when the front-door **took the route** (`roadmapRouteTaken` true — the confirmed roadmap was surfaced in its place, so this passive advisory is **SUPERSEDED**; on the route path the single-milestone Steps 4–7 do not run for the whole brief anyway). **Non-blocking** — it does not change what gets deployed; the plan stays a deployable single-milestone plan. Sourced from the architect's structural read of `CANDIDATES`, so on the retained path it is written even if every candidate is parked/dropped (Step 6). Grounding: `docs/specs/v0.3.1-driver-handoff.md` §6 (the additive plan-file field) and §5. |
| **One-line goal** | The milestone goal in one line — the header. |
| **Milestone description (Wave order)** | The Step 5 build-order / Wave description, verbatim, with local slugs (`#A`/`#B`). This is what `create` PATCHes onto the milestone after issue numbers exist. |
| **Per surviving issue** | For each surviving (gate-clean / Advisory-only) issue: its slug, title, the FULL §4 `ISSUE_BODY` verbatim, its labels, and its surface/risk. `create` reads these — no regeneration. An `implied` candidate (architect `disposition: implied`) additionally carries the `[implied — review / trim / augment]` marker on its issue heading (the `## Issues` template below); a grounded candidate renders without it. |
| **Parked issues** | Each parked issue: slug, title, and kind (`product-gap` \| `needs-human-direction`). Marked, never created. |
| **Dropped issues** | Each dropped issue: slug, title, and the parked dependency that dropped it. Marked, never created. |
| **Self-check verdict line** | The Step 6 outcome (PASS / INTERNAL / PARKED / SKIPPED(reviewer:false)). `create` trusts it; no re-vet. |
| **Source brief reference** | `inline` \| `file:<path>` \| `epic #<n>` — drives the downstream report routing and the brief↔plan match. Record `epicIssueNumber` here when the brief was an epic. |
| **Original brief (full text)** | The **full** brief text this plan run received — persisted verbatim and multi-line as the `## Original brief` … `## End original brief` delimited section below (a brief is multi-line, so a SECTION, not a `Label: value` header line; `Source brief reference` records only the form token; the paired end-delimiter keeps a brief that contains its own `## ` headings intact for the consumer, never truncated at its first internal heading). It is the durable single-milestone fallback `create`'s closing brief-coverage verification reads to audit the deploy against the original brief (`skills/create/SKILL.md` Step 3V — the brief-resolution ladder). Mirrors the roadmap manifest's `## Original brief`, which persists the whole-app brief for a roadmap run (`skills/build-roadmap/SKILL.md` "Manifest format"). |

## Plan-file output template

```markdown
# Milestone plan — <milestone goal, one line>

Milestone title (exact): <the exact milestone title — carries the resolved semver INSIDE the string; create/update resolve the milestone by THIS string. SURFACED for the user to confirm/override before `create`; on an infer rung it carries the reference version verbatim — adjust the patch/minor/major bump on this line>
Version provenance: <explicit | declaration | inferred from <tag/milestone> | prompted>
Self-check: <the Step 6 outcome — one of:
  PASS — all <N> issues GAPS: none (milestone-driver reviewers)
  INTERNAL — all <N> issues GAPS: none (internal checklist; milestone-driver reviewers did not resolve)
  PARKED — <M> issue(s) → needs product input; <K> issue(s) → needs human direction (still-Blocker after 2 retries)
  SKIPPED (reviewer:false) — 🔴 gate disabled; generated issues were NOT vetted>
Source brief: <inline | file:<path> | epic #<n>>
Milestone number (GitHub): <n>   # OPTIONAL sibling header line — carried forward verbatim from a prior plan file if present; omitted on first plan (create writes it post-deploy, skills/create/SKILL.md Step 3 pass (b))

## Original brief
<The full brief text this plan run received, persisted verbatim and multi-line — every
 section the author wrote, in full. A brief is multi-line, so this is a SECTION, not a
 `Label: value` header line. `create`'s closing brief-coverage verification reads it to
 audit the deploy against the original brief (the durable single-milestone fallback —
 `skills/create/SKILL.md` Step 3V brief-resolution ladder). Mirrors the roadmap manifest's
 `## Original brief` (`skills/build-roadmap/SKILL.md` "Manifest format"). On a roadmap run
 this persists the per-milestone brief-slice; the whole-app brief lives in the manifest.
 The brief is delimited by the paired `## Original brief` … `## End original brief` markers
 (the literal closing line below), so a brief that contains its OWN `## ` headings is
 captured intact — the consumer reads strictly between the markers and is NOT truncated at
 the first internal `## ` heading.>
## End original brief

## Milestone description (Wave order)
<the Step 5 Wave-ordered description, verbatim — the §4 template with local slugs>

## Issues
### #A — <title>   [<ui|logic>, <risk:*>]   [self-check: PASS]
<the full §4 ISSUE_BODY for #A>

### #F — <title>   [<ui|logic>, <risk:*>]   [self-check: PASS]   [implied — review / trim / augment]
<the full §4 ISSUE_BODY for #F — a `disposition: implied` candidate (architect clause 8) renders DISTINCTLY, carrying the `[implied — review / trim / augment]` marker (the verbatim words `implied — review / trim / augment` inside the brackets) alongside the [ui|logic, risk:*] / self-check tags; a grounded candidate (#A above) omits the marker and renders exactly as today>

### #B — <title>   [parked — needs product input]
<marker only; no fabricated body — see the needs-product-input report>

### #C — <title>   [parked — needs human direction (self-check Blocker, non-converging after 2 retries)]
<marker only; the issue did not clear the self-check gate — see the report>

### #D — <title>   [dropped — depends on parked #B]
<marker only; a dependent of a parked issue cannot build, so it is not carried (Step 6 §6.6)>

### … (one block per surviving candidate, in Wave order; only PASS / Advisory-only issues carry a full body; a `disposition: implied` candidate additionally carries the `[implied — review / trim / augment]` marker on its heading, as #F above)

## Multi-milestone advisory   <!-- OPTIONAL section — written ONLY on the retained path: the architect raised SCOPE_SPANS_MULTIPLE_MILESTONES (Step 3) AND the front-door did NOT route into build-roadmap (Step 3.6, roadmapRouteTaken false). OMITTED ENTIRELY when the signal is `none` (file byte-for-byte the pre-#61 shape) OR when the front-door took the route (roadmapRouteTaken true — superseded by the confirmed roadmap). Advisory only — does not change what gets deployed; the plan stays a deployable single-milestone plan. -->
🔴 This brief looks like ~<N> milestones. Deploy the one big milestone below, or split the brief and re-run. Proposed split (carried verbatim from the architect):
- <proposed milestone 1 name>: #A, #C
- <proposed milestone 2 name>: #B

## Project-docs grounding
- <each design call carried forward> — grounded in <.project/<doc>.md#<section> | sibling file:line>
- Degradations: <e.g. "uiSurfaceGlobs absent → all candidates treated as logic"; "none" otherwise>

## Needs human input
<pointer: "see .milestone-feeder/needs-product-input-<slug>.md" when productGaps is non-empty OR the self-check parked any issue as needs-human-direction; "none" otherwise>

---
This plan file is the build artifact — run `/milestone-feeder:create` to deploy it to GitHub (it ensures the labels, creates-or-adopts the milestone by the exact title above, opens each surviving issue, rewrites the slug references to real issue numbers, and patches the milestone description with the Wave order). `plan` wrote no GitHub state.
```

## Needs-product-input report template

```markdown
🔴 Needs human input — <milestone goal, one line>

These items blocked the milestone and were NOT guessed. Resolve each, then re-run plan.

| # | Kind | Item | Why blocked | Blocks |
|---|---|---|---|---|
| 1 | product-gap | <the product decision with no conventional default> | <why the project docs / a convention cannot answer it> | <which candidate(s) / the whole scope> |
| 2 | needs-human-direction | <the self-check Blocker that did not clear in 2 retries> | <the reviewer's `description` / `to_clear`> | <which candidate(s) + any dropped dependents> |
| … | … | … | … | … |
```
