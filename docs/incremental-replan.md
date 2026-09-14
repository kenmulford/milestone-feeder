# Incremental re-plan: growth after the architect dispatch

`plan` dispatches the architect once per brief (`skills/plan/SKILL.md` Step 3). A
re-plan whose brief gained items after that dispatch returned gets **one
incremental dispatch per batch of added items** instead of a second full
dispatch, so the architect never rewrites a candidate a human may already be
reviewing or that `create` may already have deployed. This file states the
detection rule and the incremental contract once; `skills/plan/SKILL.md` and
`agents/architect.md` point here rather than restating it.

## 1. Where the brief can grow after Step 3

The only growth point in the `plan` / `update` flow: a **re-plan**, the user
re-running `/milestone-feeder:plan` on a brief that has grown since a prior run
already wrote a plan file at the same deterministic slug. `update` never
dispatches the architect itself (`skills/update/SKILL.md`); its sole path back
here is the existing "no plan file found → run `plan` first" fallback, already
covered by this file.

## 2. Detecting an incremental re-plan (Step 1)

Compute this run's slug early, by Step 7's own derivation, and check for a
prior plan file at `.milestone-feeder/plan-<slug>.md`. Read its persisted
`## Original brief` … `## End original brief` text and classify:

| Case | Path |
|---|---|
| No prior file | Full dispatch (today, unchanged). |
| Prior brief text identical to this run's | Full dispatch (a plain re-plan). |
| This run's brief is a strict superset: the prior text intact, with material appended | **Incremental dispatch.** |
| Any other change (edited, reordered, or removed prior text) | Full dispatch (safe default: a changed existing scope cannot honor "never rewrites an existing candidate"). |

## 3. The incremental architect dispatch (Step 3)

Input and output are `agents/architect.md` → "Incremental mode". `plan`
reconstructs the prior `CANDIDATES` / `EDGES` / `WAVES` from the prior plan
file rather than a second contract field (`docs/plan-file-contract.md`
unchanged): each `### #<tag> - <title> [<surface>, <risk>] […]` heading plus
its `Depends on #<n>` lines and the `## Waves` block already carry them.

## 4. The orchestrator merge (Step 3, after return)

- **Merge candidates and edges**: prior ∪ new, unchanged and unreordered.
- **Recompute `WAVES`** over the merged edges, the same topological sort
  `agents/architect.md` clause 4 defines; the incremental return carries no
  `WAVES` of its own.
- **Step 4 dispatches `issue-author` only for the new candidates.** A prior
  candidate's issue body is carried forward from the prior plan file verbatim,
  never re-authored.
- **Step 5.1 ADOPTS the prior plan's title + provenance**: `plan` sets
  `preResolvedVersion` to the prior plan file's `Milestone title (exact)` and
  `Version provenance` values, so the ADOPT branch (`docs/version-ladder.md`)
  runs instead of the ladder and the milestone identity `create` may already
  have deployed stays fixed.
- **Step 7 carries the prior deploy receipt forward** under its existing rule;
  nothing about that rule changes.
