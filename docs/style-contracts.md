# Style contracts — shared reference

This file is the single source of truth for the three style contracts this
plugin's skills and agents follow. Each governs a **different surface**, which
is why they can mandate opposite things and both be right: one governs what a
skill prints to your terminal, one governs the human-facing prose an agent
authors, one governs the shape of the block an agent returns to its caller.

Both the contract text and its consumers exist in exactly this one file plus
pointers — each skill and agent cites the section below rather than restating
its text inline. This is a prompt-only plugin with no include capability, so
consolidation means **one definition plus pointers**, never a build step (the
same mechanism `docs/one-time-notices.md:14-17` and
`docs/plan-file-contract.md:3` already use).

## Surface boundary

| Contract | Governs which surface | Definition lives |
|---|---|---|
| [`## Output style`](#output-style) | What a **skill prints to the terminal** — status, gates, step lists, options. Tables are mandated here. | This file, [below](#output-style). |
| [`## GitHub prose style`](#github-prose-style) | The **human-facing prose an agent authors** — issue bodies, milestone descriptions, parent-issue narrative, and the roadmap change-rationale a human reads at the split confirmation. Checkbox bullets and `- Key: value` one-liners; zero tables. | `agents/issue-author.md` `## Prose style` — the single definition. |
| [`## Communication style`](#communication-style) | The **wrapper an agent returns to its caller** — which block it emits and the enum/tag structure inside it. | This file, [below](#communication-style). |

The first two read as contradictory only because neither used to say which
surface it governs. `## Output style` mandates tables because a terminal
report is scanned; the GitHub prose contract forbids them because an issue
body is parsed by the driver's triage and read in a browser
(`agents/issue-author.md:49-80`). Both are right for their own surface.

## Output style

Be concise — report status and outcomes flatly, no wall-of-text. Present steps, gates, lists, and options as **tables**, not inline prose. Mark anything that needs a human with 🔴. (Mirrors [`## Communication style`](#communication-style) below — the agents' twin of this contract.)

**Who this binds:** `skills/build-roadmap/SKILL.md`, `skills/plan/SKILL.md`,
`skills/setup/SKILL.md`, `skills/create/SKILL.md`, `skills/update/SKILL.md` —
each carries a pointer line citing this section.

## Communication style

Return the structured block only. No preamble, no summary, no congratulatory notes. Terse, evidence-grounded, flat.

**Per-agent clauses are appended locally.** The skeleton above is the shared
part. Each agent appends the clause that carries its own meaning — which block
it returns, and the identifier convention inside it — directly under its
pointer to this section. Those local clauses are load-bearing, not
boilerplate: `agents/architect.md` binds local tags (`#A`, `#B`) and never
GitHub numbers; `agents/roadmap-splitter.md` binds names, brief slices, and
1-based build-order positions.

## GitHub prose style

**The single definition is `agents/issue-author.md` `## Prose style`.** It is
not copied here — this section is the index that names it, states which
surface it governs, and records who is bound to it. Restating those rules in a
second place is exactly the drift this file exists to remove.

**Surface governed:** agent-authored prose a human reads — an issue body, a
milestone description, an `md-epic` parent issue's narrative, and the
roadmap-splitter's change-rationale (rendered in the split-confirmation review
and written to the local roadmap manifest, `skills/build-roadmap/SKILL.md:86`,
`docs/roadmap-manifest-format.md:34`). Most of that surface lands on GitHub,
which is what the section is named for; the rationale is the one bound field
that stays local, and it is bound because it is prose a human reads, not
because of where it is posted. Not terminal output (that is
[`## Output style`](#output-style)), and not the return wrapper's block or
enum structure (that is [`## Communication style`](#communication-style)).

| Agent | Fields bound | Not bound |
|---|---|---|
| `agents/issue-author.md` | The whole `ISSUE_BODY`. | The return wrapper (`STATUS` / `ISSUE_TAG` / `TITLE` / `LABELS` / `PRODUCT_GAP`). |
| `agents/architect.md` | `sketch` (`:70`), the `EDGES` `<reason>` slot (`:82`). | `title`, `surface`, `risk`, `layer` — one-liners and enums. |
| `agents/roadmap-splitter.md` | `parent_title`, `parent_intro`, `rationale` (clause 4, `:31`). | `milestone`, `position` — an identifier and an integer; `brief_slice` (`:46`) — the author's own brief text, quoted or closely paraphrased. |

Each agent cites the definition from its own `## Prose style` section rather
than carrying a copy of the rules.
