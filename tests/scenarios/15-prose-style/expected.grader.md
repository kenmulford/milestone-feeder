# Expected contract — 15 prose style  (GRADER ONLY)

A small list brief (add a paginated activity-log list) is authored against a project whose
`project/conventions.md#Lists` states that lists paginate at **30 rows per page** and
mirror the existing list pattern at `src/lists/ActivityListService.ts`. The brief restates
the "30 rows per page" figure; it is the literal directive the prose-style guardrail must
protect.

The claim under test: **the issue-author's authored `ISSUE_BODY` obeys the prose-style
ruleset added to `agents/issue-author.md` (`## Prose style — confidence lives in the
citation`) — a Summary of 2–3 plain sentences, no banned filler vocabulary or hedges, one
declarative line per acceptance criterion and per recorded design decision (the citation is
the rationale, with no appended explanatory sentence), and no template narration — while the
content-preservation guardrail keeps every completeness state, the literal "30 rows per page"
directive, and the grounded `Convention followed:` citation present verbatim. A deliberately
padded rewrite of the same body FAILS the prose assertions, and a rewrite that trims prose by
dropping a state or weakening the directive FAILS the guardrail.**

This is a **plan-side, preview-only** scenario (zero GitHub writes), mirroring the
plan-side portion of scenarios 11–14.

The expected candidate set (local tags; exact titles may vary):

| Tag | Candidate | Surface | Touches |
|---|---|---|---|
| #A | Add a paginated activity-log list | `logic` | list / pagination (30 rows per page) |

---

## MUST — (a) the authored body reads concise and direct  (AC1)

- **Summary is 2–3 plain sentences.** The `#A` §4 `## Summary` is at most three sentences
  that state what changes and why. It does NOT scene-set ("Currently, the application…"),
  benefit-sell ("This will greatly improve…"), or restate the title.
- **No banned filler vocabulary, no hedges.** The `#A` body contains none of
  "comprehensive", "robust", "seamless", "leverage", "ensure that", "in order to",
  "it is important to note", and no hedge ("should ideally", "as appropriate").
- **One decision, one line.** Each `## Acceptance criteria` bullet and each recorded
  `## Design` decision is a single declarative sentence. A decision grounded only by a
  citation renders as exactly one line — the citation — with no appended explanatory
  sentence (the bare `- Convention followed: <ref>` shape).
- **No template narration.** No line explains what a section is for or announces what is
  about to be listed; the section headers carry the structure, the lines carry only facts.

## MUST — (b) CONTROL: a padded rewrite FAILS the same assertions  (AC2 — asserted alternate)

- **Asserted alternate.** The SAME `#A` issue, rewritten with the padding reintroduced —
  a multi-sentence scene-setting Summary, banned filler / hedges, an explanatory sentence
  appended to a citation, and a narrated section — **FAILS** the four (a) checks. This is
  the negative case that proves the assertions have teeth, mirroring the asserted-alternate
  pattern in `tests/scenarios/13-layer-aware-breakdown/expected.grader.md` and
  `tests/scenarios/14-config-pointers/expected.grader.md`.

## MUST — (c) guardrail: concision cuts prose, never content  (AC3)

- Between the compliant body and any concision pass, ALL of the following are present,
  verbatim where the contract requires it:
  - the four completeness states — populated (happy), empty, load-error, single-page
    disabled-pagination — as acceptance criteria (the completeness criterion,
    `agents/issue-author.md` The contract);
  - the literal directive **"30 rows per page"** — NOT silently weakened to "a sensible
    page size" or a vague phrase;
  - the grounded `Convention followed:` citation (mirror `src/lists/ActivityListService.ts`
    per `project/conventions.md#Lists`);
  - every architect edge the candidate carries (here: none — a single independent issue).
- A rewrite that trims prose by DROPPING a state, weakening "30 rows per page", or dropping
  the citation **FAILS** the guardrail — fewer words must not mean less content.

## MUST — (d) additive: existing graders unchanged, README lists it  (AC4)

- No existing `expected.grader.md` (01–06, 10–14) is modified — the addition is purely
  additive, per `.project/conventions.md#Test patterns` ("New scenarios append, and
  `tests/README.md` is updated to list them").
- `tests/README.md`'s scenario set table AND its Layout tree list scenario 15.

## METRIC for this scenario

- The authored Summary is 2–3 plain sentences, no scene-setting / benefit-selling /
  title-restating (yes/no).
- The body carries no banned filler vocabulary and no hedges (yes/no).
- Each acceptance criterion / design decision is one declarative line; a citation-only
  decision has no appended sentence (yes/no).
- No template narration (yes/no).
- CONTROL: the padded rewrite fails the four checks above (yes/no) — the anti-teeth proof.
- Guardrail: the four states + "30 rows per page" + the `Convention followed:` citation +
  any edge survive verbatim, and a content-dropping trim fails (yes/no).

## FAIL if

- The Summary is a padded multi-sentence paragraph that scene-sets, benefit-sells, or
  restates the title.
- The body uses any banned filler word or hedge.
- A recorded design decision appends an explanatory sentence to its citation instead of
  standing as one line.
- A section is narrated — a line explaining what the section is for or announcing a list.
- The CONTROL padded rewrite nonetheless PASSES the prose assertions — the assertions have
  no teeth.
- A concision pass silently drops a completeness state, weakens "30 rows per page" to a
  vague phrase, or drops the `Convention followed:` citation — the guardrail failing to
  protect content.

## Disabled / edge — bash/pwsh parity

- This scenario is **plan-side, preview-only** and **prose-direct** — the prose-style
  authoring / anti-padding / content-survives flow is prose the runner follows; it touches
  no scenario-specific scripted (bash/pwsh) twin. **Cross-platform parity is recorded N/A**
  for this scenario (mirroring scenarios 11–14's plan-side preview portion).
- `expected.grader.md` is **grader-only** (the runner never sees it). Appended at **NN=15**
  (on-disk 01–06, 10–14; 07–09 reserved for the sandbox `create` / `update` scenarios).
