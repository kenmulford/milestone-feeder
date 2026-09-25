# Brief: build pointers (milestone-feeder)

**Goal.** Each issue names where its change lands, what it calls, and which test it mirrors, as `path (anchor)` pointers the driver's planner resolves at build time. Issues never carry code. Each issue delivers one behavior, and a change too small to stand alone rides with the issue that edits the same file.

Verified against `develop` at `c8c655a` on 2026-09-23.

**Constraints to hold across all items:**
- CI stays green: `scripts/check-contract-strings.sh`, `scripts/check-vocabulary.sh`, `scripts/validate-plugin-structure.py`.
- `FILE_WORD_CEILINGS` for `agents/issue-author.md` and `agents/architect.md` rises only by measured growth: post-edit words times 1.05, rounded up to the next 50, recorded in the table comment with the issue number. This is the rule the `agents/issue-author.md` row already records.
- The driver reads the new lines as optional input (milestone-driver `docs/briefs/2026-09-23-build-packet.md`). `Edits:` stays a bare path list, because architect clause 11 orders shared files by it.
- No em dash in new text.

---

## 1. Pointer lines in the Design block

**Evidence:** the `agents/issue-author.md § Output format` Design block carries `Convention followed:`, `Layer:`, `Edits:`, `Config pointers:` and `Sites searched:`. None of them names the symbol a change lands at, the existing code it calls, or the test it mirrors.

**Work:** in `agents/issue-author.md`, add three optional lines to the Design block, directly after `Edits:`:
- `Edit points:` each existing symbol the change modifies, as `path (anchor)` with its declaration text as the anchor. A file the issue creates is listed as `path (new)`.
- `Calls:` each existing symbol the new code calls or conforms to, as `path (anchor)` at its declaration.
- `Tests:` the test file the issue's tests go in, and the sibling test they mirror, each as `path (anchor)`.

Rigor gate additions:
- Each pointer is grep-verified against the live repo, the same bar as `Convention followed:`.
- An anchor is declaration or heading text, never a line number and never a code excerpt.
- A line with nothing to name is omitted.
- A resolved consumer template with no Design section carries the lines in the section that covers design, per `## Authoring to a resolved consumer template` ("Content never disappears").

**Acceptance:** the output-format template and the Rigor gate carry all three lines. A dogfood `plan` run on this repo emits `Edit points:` on every candidate that edits an existing file, and every emitted pointer resolves through milestone-driver `scripts/resolve-citation.sh`.

## 2. One behavior per candidate, and folding

**Evidence:** `agents/architect.md` clause 1 splits the brief into "the smallest set of issues each roughly one PR and independently buildable" and prefers "more small issues over fewer large ones." Its sizing input defaults to "~1 PR each, independently buildable." Nothing sets a behavior count, and nothing sets a floor.

**Work:** in `agents/architect.md` clause 1:
- A candidate delivers one behavior: one outcome a user can observe, whose happy, empty, error and disabled criteria fit in 6 acceptance criteria. A sketch that needs more is two candidates.
- A candidate that changes one existing site and introduces no type, file, screen or behavior of its own folds into the candidate whose `edits` lists that site's file. Its sketch line joins the absorbing candidate's sketch. When no candidate edits that file, it stays a candidate.
- Folding runs before clause 3, 9 and 11 edges are derived.
- A set `issueSize` overrides both rules.

Update the sizing default in `agents/architect.md` (`Sizing guidance`) and `skills/plan/SKILL.md` (the `issueSize` bullet in the architect brief) to name clause 1 in place of restating "~1 PR each".

**Acceptance:** clause 1 carries both rules. `grep -rn "1 PR each" agents skills` prints nothing. `python3 scripts/validate-plugin-structure.py` exits 0.
