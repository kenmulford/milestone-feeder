# File-map — the per-candidate neighborhood map, built at the Step-4 issue-author dispatch

`plan`'s Step 4 (`skills/plan/SKILL.md` Step 4 — the per-candidate issue-author dispatch) builds a **file-map** for each candidate and hands it to that candidate's issue-author beside the grounding digest. This file is the canonical source for the file-map's mechanics: its shape, the NEIGHBORHOOD rule that scopes it, the deterministic enumeration/ordering, the Markdown-only anchor extraction, the degrade matrix, and the never-persisted guarantee. It is reference content relocated out of `skills/plan/SKILL.md` to keep that always-loaded file within the repo's own size standard — mirrors the existing `docs/one-time-notices.md` and `docs/version-ladder.md` relocations. `skills/plan/SKILL.md` Step 4 keeps only the short in-place stub that names this file; build the map exactly as recorded here.

Unlike the three Step-0 grounding inputs — the grounding digest, the global implied-surfaces reference, and the project-local overlay, all resolved **once** at the Step-0 OUTER boundary and recorded in `docs/step-0-grounding.md` — the file-map is **built PER CANDIDATE at the Step-4 dispatch**, scoped to that candidate's own cited grounding rather than the whole `sourceGlobs` set. Everything else — pointers-only, best-effort degrade, supplement-not-allowlist, never-persisted — it shares with those inputs.

## Contents

1. [Shape and purpose](#1-shape-and-purpose)
2. [The NEIGHBORHOOD rule — what a candidate's map contains](#2-the-neighborhood-rule--what-a-candidates-map-contains)
3. [Deterministic enumeration (ordering)](#3-deterministic-enumeration-ordering)
4. [Anchor extraction (Markdown-only) and non-Markdown files](#4-anchor-extraction-markdown-only-and-non-markdown-files)
5. [Specific degrade](#5-specific-degrade)
6. [Never persisted](#6-never-persisted)

## 1. Shape and purpose

An **ordered list** of `{ path, anchors }` pointers at **where** cited code and sibling patterns live — scoped to the candidate's NEIGHBORHOOD (§2), **not** the whole `sourceGlobs` set. Each entry has exactly two fields:

- **`path`** — repo-relative path to a file in the candidate's neighborhood.
- **`anchors`** — the file's top-level `##` / `###` heading-text list (for Markdown files), or the empty list `[]` (for non-Markdown files — see §4).

Its job is **discovery / location** — pointing the issue-author at *where* a sibling pattern or cited artifact lives — not grounding text. **Pointers only, never content:** an entry never carries section bodies or file contents, only the path and the heading-text list. The author still Reads/greps the located file to verify and cite it (the supplement rule below; §6).

**Supplement, never allowlist.** The map **adds to**, and does not close, the issue-author's own on-demand Read/grep path. The author's rigor gate stays mandatory — it "greps before it cites" over the map exactly as elsewhere, and may Read/grep anything **not** present in it (`agents/issue-author.md` → "What you receive" → the file-map bullet).

## 2. The NEIGHBORHOOD rule — what a candidate's map contains

The file-map is scoped to the candidate's **neighborhood** — the folders its own citations reach — never the whole `sourceGlobs` set. The **unit of inclusion is the FOLDER, never a single file**: a coherent group is shown whole or not at all. Build the neighborhood in these steps:

1. **SEED.** The seed files are those named by the candidate's cited `file:line` references in its `sketch` (`agents/architect.md:70`), plus the files referenced by the architect `EDGES` touching that candidate (`agents/architect.md:147`). Each seed pulls in its containing folder (rule 2). A seed's own folder is **never dropped by the cap** — it is the highest-signal input.
2. **WHOLE-FOLDER EXPANSION.** For each seed, include its **ENTIRE folder** as a unit — every `sourceGlobs`-matching file in that folder — **never a partial folder** (the whole folder or none of it).
3. **KEYWORD FALLBACK.** **ONLY when the candidate cites no `file:line` seed:** include whole folders whose path contains a case-insensitive substring match on the candidate's surface (`ui` / `logic`) or a significant word from its title — same whole-folder-unit basis, **never a partial folder, never a whole-repo scan**. For "significant word", apply an ordinary stop-word / longest-word heuristic — drop common stop-words and prefer the longer, meaningful title words.
4. **CAP = 20 FOLDERS (units), NOT individual files — SOFT cap.** Files are never trimmed within an included folder (all-or-nothing per folder). The folders a candidate **genuinely references** — its SEED folders (rules 1–2) — are **ALWAYS included in full even if they number more than 20**: favor completeness; when seed folders alone exceed 20, include them all and log the count (never a silent whole-repo scan — these are only folders the candidate's own citations name). The 20-folder cap therefore bounds **ONLY the keyword-fallback folders** (rule 3). Seed folders (1–2) and keyword-fallback (3) are **mutually exclusive per candidate** — the fallback fires only when there are zero seeds — so there is exactly one folder list per candidate and **no multi-tier truncation to arbitrate**. This is in the spirit of the skill's existing conservative-cap precedent (`skills/plan/SKILL.md:205`, the cap-4 worker window — a "safe, conservative default").

## 3. Deterministic enumeration (ordering)

The `ordered` guarantee is the **enumeration's own natural order, held stable for the candidate's dispatch** — not a separately imposed sort, and **no new sort key** (no alphabetical, no mtime layered on top). Within the neighborhood, resolve entries in this order:

1. **SEED folders first**, in **citation order** — the sketch `file:line` refs first (in their order of mention), then the EDGES artifact refs — with **first-mention-wins dedup**.
2. Then any remaining **keyword-fallback folders**, in `sourceGlobs` **array order**, then **filesystem order**.
3. **Within each included folder**, its files in **glob-match / filesystem enumeration order**.
4. **First-match-wins dedup throughout:** a folder that is both a seed and a keyword match appears **ONCE** (at its seed position); a file matching more than one glob appears once, at its first-matching glob's position.

The map is built once per candidate and handed identically on the one bounded Step-4 retry (`skills/plan/SKILL.md` Step 4 retry brief), so the load-bearing guarantee is within-dispatch identity — the retry receives the same ordered map.

## 4. Anchor extraction (Markdown-only) and non-Markdown files

- **Markdown files** — `anchors` is the file's top-level `##` / `###` heading-text list, extracted from the file.
- **Non-Markdown files** (e.g. a `hooks/**` script) — included as `{ path, anchors: [] }`. **No read and no anchor extraction is attempted** for a non-Markdown file, so anchor extraction can never fail for it; it is never excluded on account of its type.

## 5. Specific degrade

Best-effort, never abort (`.project/design-philosophy.md#Error & failure philosophy`):

| Condition | Behavior |
|---|---|
| The candidate's neighborhood is empty (no seed, and no keyword-fallback folder matches) | Resolve to an **empty map** — **not** an error; the candidate's dispatch proceeds exactly as it does for an empty digest, and the author falls back to its on-demand grep path. |
| A **file in the neighborhood** that is unreadable, or whose anchor extraction fails | **Skip that single file** and continue over the rest — the candidate's dispatch is **never aborted**. (A non-Markdown file has no read attempted, so this skip fires for it only on an enumeration-level failure such as a broken symlink.) |

## 6. Never persisted

Beyond §1's supplement-not-allowlist rule, the file-map is held **entirely in the in-run Step-4 dispatch and is never persisted to disk** — no new file appears under `.milestone-feeder/` or `.milestone-config/` (`.project/environment.md#Data stores`), and there is **no rescan / daemon** (`.project/environment.md#Async & messaging`). It is built synchronously at the Step-4 dispatch and rebuilt / re-handed unchanged on the one bounded retry.
