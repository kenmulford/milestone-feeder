# Expected contract: 20 measured-layout  (GRADER ONLY)

A brief reports a symptom on a SwiftUI budget app: the Transactions table draws wider than its
column. `TransactionsView` writes a measured width into `@State` with `onGeometryChange` and
picks a `Table` or a `List` from it. `AccountsView` does the same. The fixture's
`feeder-env.md` lists a `nonNegotiables` entry that forbids this:
"Never measure a width and feed it back into layout; use size classes or `ViewThatFits`."
`project/conventions.md` carries no layout rule: the rule under test arrives through
`nonNegotiables` alone.

The claim under test (the pass condition of the brief `docs/briefs/2026-11-21-fixed-contract-free-content.md`
item 1): **the issue quotes the non-negotiable verbatim and names a size-class API in place of
the measurement.**

This scenario is **plan-side, preview-only** (zero GitHub writes). It grades
`docs/briefs/2026-11-21-file-a-verified-bug.md` item 2.

## MUST

- The issue quotes the `nonNegotiables` entry verbatim: "Never measure a width and feed it back
  into layout; use size classes or `ViewThatFits`." The quote is accepted with or without the
  backticks around `ViewThatFits`; the words are not paraphrased.
- The issue names a size-class API in place of the measurement: `@Environment(\.horizontalSizeClass)`
  (`UserInterfaceSizeClass?`) or `ViewThatFits`.
- `TransactionsView.swift` is recorded as the site to fix, with the `onGeometryChange` width held
  in `@State` as the code to remove.
- Every `edits:` path names a file `feeder-env.md` declares, and the list is exhaustive.
- The brief states the symptom only; the issue, not the brief, names the fix.

## FAIL if

- The body cites `AccountsView.swift` as `Convention followed:` or as the pattern to mirror, or
  keeps the measured width and only adjusts its threshold.
- The body paraphrases the non-negotiable, or omits it.
- The body names no size-class API (neither `horizontalSizeClass` nor `ViewThatFits`).
- The body fixes the symptom with another measurement (`GeometryReader`, `onGeometryChange`,
  a preference key) fed back into layout.

A body that lists `AccountsView.swift` as a second site with the same breach, to fix or to flag,
passes this check.

## Expected on today's feeder

This scenario fails on today's feeder: it grades
`docs/briefs/2026-11-21-file-a-verified-bug.md` item 2, the issue-author change that quotes a
governing non-negotiable verbatim and names the API it requires, which has not landed. The
baseline run is recorded by #555.

## METRIC for this scenario

- The non-negotiable quoted verbatim (yes/no).
- A size-class API named in place of the measurement (yes/no).
- `AccountsView.swift` not cited as the pattern to mirror (yes/no).

## Disabled / edge: bash/pwsh parity

Plan-side, preview-only, prose-direct: no scripted twin. Cross-platform parity is N/A.
`expected.grader.md` is grader-only (the runner never sees it). Appended at NN=20.
