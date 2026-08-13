# Milestone plan: Add a paginated activity-log list to the account area

Milestone title (exact): 🔴 UNRESOLVED - the Step 5.1 ladder ran to rung 4 (prompt) and no human is available in this non-interactive run. Rung 1 found no `Milestone:` line and no inline statement; rung 2 found no `versioning` declaration (`.milestone-config/feeder.json` is absent); rung 3 inferred nothing (the `gh api` milestones read is unavailable offline, and the repo carries no `.git`, so no `vX.Y.Z` tag exists to read). No title was fabricated. Resolve this line before running `create`.
Version provenance: 🔴 UNRESOLVED - no ladder rung resolved, and the rung-4 prompt could not run non-interactively. Not one of `explicit` | `declaration` | `inferred from <tag/milestone>` | `prompted`, because none of those rungs produced a value.
Source brief: file:brief.md

## Original brief
# Brief: Paginated activity log

Add a paginated activity-log list to the account area, showing the member's recent
account events (logins, profile edits, email changes), newest first. Paginate at 30
rows per page. Mirror the existing list pattern.

In scope:
- The activity-log list, newest first, paginated at 30 rows per page.

Out of scope:
- Any new event type: the list only surfaces events the system already records.
- Export or filtering.
## End original brief

## Milestone description (Wave order)
Adds the account area's paginated activity-log list over the account events the system already records, newest first at 30 rows per page. It surfaces no new event type and adds no export or filtering.

## Waves
- Wave 1 (parallel): #A

## Issues
### #A - Add the paginated activity-log list to the account area   [logic, risk:heavy]
## Summary

Add a paginated activity-log list to the account area, showing the member's recorded account events (logins, profile edits, email changes) newest first. The list paginates at 30 rows per page.

## Acceptance criteria

- [ ] The account area's activity-log list shows the member's recorded account events (logins, profile edits, email changes), newest first, 30 rows per page.
- [ ] When no account events exist, the list shows the empty-state copy the existing list pattern defines.
- [ ] When the event list fails to load, the list shows the load-error handling the existing list pattern defines.
- [ ] When the result fits on a single page, the pagination controls render in their disabled state, per the existing list pattern.

## Non-goals

- New account-event types: the list surfaces only events the system already records.
- Export or filtering of the activity-log list.

## Design (recorded, consistent)

- Paginate at 30 rows per page, newest first. `project/conventions.md#Lists`
- Empty-state copy, load-error handling, and the single-page disabled-control behavior mirror the list pattern this convention names. `project/conventions.md#Lists`
- The four states (populated, empty, load-error, single-page disabled-pagination) are each an observable acceptance criterion. `project/conventions.md#Test patterns`
- Convention followed: `project/conventions.md#Lists`

## Dependencies

- None.

## Project-docs grounding
- Page size 30 rows per page, newest first: grounded in `project/conventions.md#Lists`
- Empty-state copy, load-error handling, and the single-page disabled-control behavior: grounded in `project/conventions.md#Lists`
- The four states carried as observable acceptance criteria: grounded in `project/conventions.md#Test patterns`
- No sibling-pattern citation recorded: `src/lists/ActivityListService.ts`, the pattern `project/conventions.md#Lists` names, does not exist in this repo (no file exists under `src/`), so those behaviors ground on the convention section itself
- No `layer` field and no layer edge: the project docs state no layering convention (no `design-philosophy.md#Layering & boundaries`, no `conventions.md#File & folder layout`, no `library-manifest.md`), so the architect's clause-9 pass was a no-op
- Degradations: `uiSurfaceGlobs` absent → all candidates treated as logic; no driver config resolved (`.milestone-config/driver.json` and root `milestone-driver.json` both absent) → the shared keys came from the run's declared preview config; `.milestone-config/feeder.json` absent and `milestone-feeder:setup` not invocable non-interactively → `projectDocs` resolved to `project/` from the run's declared preview config, not from a file on disk; consumer issue-template resolution landed on rung 3 (no `.github/ISSUE_TEMPLATE/`, no `agentIssueTemplate`) → the issue-author authored to the built-in §4 default structure; implied-surfaces overlay absent → the merged reference equals the global bundled reference; candidate #A's file-map resolved empty (its sketch cites no `path:line` and no `path (anchor)` seed that exists on disk, and no keyword-fallback folder matched under `sourceGlobs`); Step 5.1 reached rung 4 with no human available → the milestone title and version provenance above are unresolved, not fabricated

## Needs human input
none

---
This plan file is the build artifact. Run `/milestone-feeder:create` to deploy it to GitHub (it ensures the labels, creates-or-adopts the milestone by the exact title above, opens each surviving issue, rewrites the slug references to real issue numbers, and patches the milestone description with the Wave order). `plan` wrote no GitHub state.
