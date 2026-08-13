# Milestone plan: Add a paginated activity-log list to the account area

Milestone title (exact): 🔴 UNRESOLVED. The version ladder reached rung 4 (prompt) and this run is non-interactive, so no title was resolved and none was invented. Type the exact title here, with its semver inside the string, before running `create`.
Version provenance: 🔴 UNRESOLVED (rung 4 prompt, which cannot run in a non-interactive session)
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
A paginated activity-log list in the account area over the account events the system already records, newest first at 30 rows per page. Scope stops at that list: no new event type, no export, no filtering.

## Waves
- Wave 1 (parallel): #A

## Issues
### #A - Add the paginated activity-log list to the account area   [ui, risk:heavy]
## Summary

Members can review their own recent account activity from the account area. The list shows the login, profile-edit, and email-change events the system already records, newest first, paginated at 30 rows per page.

## Acceptance criteria

- [ ] A member with more than 30 recorded events sees the newest 30 on the first page and reaches older events through the pagination controls.
- [ ] A member with no recorded events sees the existing list pattern's empty-state copy and no rows.
- [ ] A failed load renders the existing list pattern's load-error handling in place of rows.
- [ ] A member whose events fit on one page sees the pagination controls disabled.
- [ ] The list returns only the signed-in member's events, enforced server-side.

## Non-goals

- No new event type: the list surfaces only events the system already records.
- No export and no filtering.

## Design (recorded, consistent)

- Page size: 30 rows per page (`project/conventions.md#Lists`).
- Row order: newest first (`project/conventions.md#Lists`).
- Pattern to mirror: the existing list pattern named at `project/conventions.md#Lists`, which supplies the page-size constant, empty-state copy, load-error handling, and the single-page disabled-control behavior.
- States: populated, empty, load-error, and single-page disabled pagination (`project/conventions.md#Test patterns`), plus the loading state taken from the mirrored pattern (`project/conventions.md#Lists`).
- Affordances: the row list, a previous-page control, and a next-page control; the list is read-only and carries no destructive action, so no confirm affordance.
- Accessibility: the previous-page and next-page controls take their accessible names from the mirrored pattern's controls (`project/conventions.md#Lists`).
- Events shown: logins, profile edits, and email changes (`brief.md:3-4`).
- Scope: the read returns only the signed-in member's events (`brief.md:3-4`).
- Convention followed: `project/conventions.md#Lists`.

## Dependencies

- None.

## Project-docs grounding
- Page size, 30 rows per page: grounded in `project/conventions.md#Lists`
- Row order, newest first: grounded in `project/conventions.md#Lists`
- Pattern to mirror (page-size constant, empty-state copy, load-error handling, single-page disabled-control behavior): grounded in `project/conventions.md#Lists`
- The four observable states (populated, empty, load-error, single-page disabled pagination): grounded in `project/conventions.md#Test patterns`
- Events shown, and the server-side scoping of the read to the signed-in member: grounded in `brief.md:3-4`
- Degradations: `uiSurfaceGlobs` absent → `plan` draws no UI-vs-logic design-lens distinction, and the issue-author classified #A on the issue's own facts under its own clause 5; `.milestone-config/feeder.json` absent → the feeder own-keys took their bundled defaults and `setup` could not be auto-invoked in a non-interactive run; no driver config on disk → the shared keys came from the run environment's declared values; no `.github/ISSUE_TEMPLATE/` and no `agentIssueTemplate` → the issue-author authored to the built-in §4 body template; no `src/` on disk → the sibling `src/lists/ActivityListService.ts` that `project/conventions.md#Lists` names could not be grep-verified, so the pattern to mirror is cited through the convention section that names it; version-ladder rungs 1 to 3 yielded nothing (no `Milestone:` line in the brief, no `versioning` key, `gh api` has no repo context, and the repo is not a git repo so there are no tags), and rung 4 prompts, so the milestone title and its version provenance are unresolved above.

## Needs human input
none

---
This plan file is the build artifact. Run `/milestone-feeder:create` to deploy it to GitHub (it ensures the labels, creates-or-adopts the milestone by the exact title above, opens each surviving issue, rewrites the slug references to real issue numbers, and patches the milestone description with the Wave order). `plan` wrote no GitHub state.
