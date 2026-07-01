# Expected contract — 06 cross-cutting-consistency  (FLAGSHIP · GRADER ONLY)

The standing table directive lives ONLY in `project/design-system.md`; the brief does not
restate it. The feeder must pull it from your project's standing docs and propagate it into EVERY
table-bearing page-issue, consistently, citing it — drafting each issue to the driver's triage
bar so nothing drops it.

## MUST — consistency
- All ~10 page-issues are classified **UI** (uiSurfaceGlobs is set) and each carries the FULL directive in its acceptance criteria:
  - columns sortable AND filterable EXCEPT the Actions column,
  - pagination at **30 rows per page** (the literal "30" must survive — not weakened to "paginated" or "a sensible page size"),
  - empty state (`EmptyState` illustration + CTA),
  - loading skeleton,
  - reuse `DataTable`.
- Each issue cites `project/design-system.md` (`Convention followed:`) rather than re-inventing.
- **NO drift across the 10:** the directive must not be present on some issues and missing or weakened on others. Check the later issues (7–10) as hard as the first.

## MUST — consistency at scale
- Every one of the ~10 page-issues carries the COMPLETE, unweakened directive (sortable + filterable EXCEPT the Actions column, pagination literally "30" per page) — drafted consistently across all 10, with the later issues (7–10) checked as hard as the first.
- There is no in-feeder gate: the feeder DRAFTS each issue to the driver's triage bar rather than auditing the not-yet-created issues itself. A milestone where an issue silently drops or weakens the directive is a FAILURE of the consistency claim.

## METRIC for this scenario
Fraction of the 10 issues carrying the **complete, unweakened** directive as drafted
(target: **10/10**). Record the actual fraction and any drift found (which issues, what drifted).

## FAIL if
- The directive drifts or weakens across issues; or "30/page" is silently weakened; or issues classify as `logic` (uiSurfaceGlobs ignored) so the design spec is never authored.
