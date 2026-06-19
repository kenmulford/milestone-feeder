# Expected contract — 06 cross-cutting-consistency  (FLAGSHIP · GRADER ONLY)

The standing table directive lives ONLY in `project/design-system.md`; the brief does not
restate it. The feeder must pull it from your project's standing docs and propagate it into EVERY
table-bearing page-issue, consistently, citing it — and the `design-reviewer` must catch any
issue that drops it.

## MUST — consistency
- All ~10 page-issues are classified **UI** (uiSurfaceGlobs is set) and each carries the FULL directive in its acceptance criteria:
  - columns sortable AND filterable EXCEPT the Actions column,
  - pagination at **30 rows per page** (the literal "30" must survive — not weakened to "paginated" or "a sensible page size"),
  - empty state (`EmptyState` illustration + CTA),
  - loading skeleton,
  - reuse `DataTable`.
- Each issue cites `project/design-system.md` (`Convention followed:`) rather than re-inventing.
- **NO drift across the 10:** the directive must not be present on some issues and missing or weakened on others. Check the later issues (7–10) as hard as the first.

## MUST — gate enforcement
- The self-check gate dispatches the REAL `design-reviewer` per UI issue.
- If any issue OMITS or weakens the directive, the `design-reviewer` flags it (`pattern-inconsistency` / `missing-affordance` / `missing-state`) and the issue is re-authored to clear it (≤2). A milestone where an issue silently shipped without the directive **and the gate PASSED it** is a FAILURE of the consistency claim.

## METRIC for this scenario
Fraction of the 10 issues carrying the **complete, unweakened** directive after the gate
(target: **10/10**). Record the actual fraction and any drift found (which issues, what drifted).

## FAIL if
- The directive drifts across issues and the gate passes the drift; or "30/page" is silently weakened; or issues classify as `logic` (uiSurfaceGlobs ignored) so the design lens never runs.
