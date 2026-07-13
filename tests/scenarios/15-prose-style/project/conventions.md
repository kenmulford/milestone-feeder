# Conventions

<!--
Project doc (.project/-style fixture for scenario 15). Cite as
`project/conventions.md#<section>`. Keep ## headings stable — they are citation anchors.
-->

## Lists
Where list surfaces live and how they behave.
Lists paginate at **30 rows per page** and order newest first. Mirror the existing list
pattern at `src/lists/ActivityListService.ts` — page-size constant, empty-state copy,
load-error handling, and the disabled-control behavior on a single-page result all come
from there. A list issue records the page size verbatim and cites this convention; it
does not re-derive a page size.

## Test patterns
Where tests live and what a good one looks like.
Each list surface carries the four states — populated (happy), empty, load-error, and the
single-page disabled-pagination edge — as observable acceptance criteria, mirroring the
existing list pattern's own coverage.
