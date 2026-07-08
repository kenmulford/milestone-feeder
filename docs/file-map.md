# File-map — resolve a candidate-scoped `{ path, anchors }` index once at Step 0

`plan`'s Step 0 (`skills/plan/SKILL.md` Step 0) resolves, once per run and alongside the grounding digest, a compact **file-map** — an ordered, `sourceGlobs`-bounded index of `{ path, anchors }` pointers at where cited code and sibling patterns live — carried in the `resolved` callable-contract bundle and handed into every Step-4 issue-author brief beside the prose digest. This file is the canonical source for the file-map's mechanics: its shape, the ordering rule, anchor extraction, the degrade matrix, and its supplement-not-allowlist contract. It is reference content relocated out of `skills/plan/SKILL.md` to keep that always-loaded file within the repo's own size standard; nothing about what the file-map does changes, only where its mechanics are recorded — mirrors the existing `docs/one-time-notices.md` relocation. `skills/plan/SKILL.md` Step 0 keeps only the short in-place stub that names this file; resolve the file-map exactly as recorded here.

## Contents

1. What the file-map is — shape and purpose
2. Ordering rule (deterministic enumeration)
3. Anchor extraction (Markdown-only) and non-Markdown files
4. Degrade matrix
5. Supplement, not an allowlist — and never persisted

## 1. What the file-map is — shape and purpose

The file-map is an **ordered list** of entries, one entry per file matching the resolved `sourceGlobs` (`skills/plan/SKILL.md` Step 0 resolves `sourceGlobs` as a shared key in the same boundary). Each entry has exactly two fields:

- **`path`** — repo-relative path to the matched file.
- **`anchors`** — the file's top-level `##` / `###` heading-text list (for Markdown files), or the empty list `[]` (for non-Markdown files — see §3).

Its job is **discovery / location** — pointing the issue-author at *where* a sibling pattern or cited artifact lives — not grounding text. **Pointers only, never content:** an entry never carries section bodies or file contents, only the path and the heading-text list. The author still Reads/greps the located file to verify and cite it (§5).

The file-map mirrors the grounding digest's own resolve-once-hand-to-all pattern (`skills/plan/SKILL.md` Step 0, the digest paragraph): resolved **once** at the Step-0 outer boundary, carried in the `resolved` bundle, and handed **unchanged** into every candidate's Step-4 brief — never re-assembled or re-resolved per candidate/invocation.

## 2. Ordering rule (deterministic enumeration)

The `ordered` guarantee is the **enumeration's own natural order, held stable for the run** — not a separately imposed sort. Resolve entries in this order:

1. The globs in their resolved `sourceGlobs` **array order**.
2. Within each glob, files in **glob-match / filesystem enumeration order**.
3. **First-match-wins dedup:** a file matching more than one glob appears **ONCE**, at its **first-matching glob's** position.

Do **not** invent a new sort key (no alphabetical, no mtime, no separate sort step layered on top of the enumeration). The map is resolved once and handed identically to every brief, so the load-bearing guarantee is within-run identity — every author brief receives the same ordered map.

## 3. Anchor extraction (Markdown-only) and non-Markdown files

- **Markdown files** — `anchors` is the file's top-level `##` / `###` heading-text list, extracted from the file.
- **Non-Markdown files** (e.g. a `hooks/**` script) — included as `{ path, anchors: [] }`. **No read and no anchor extraction is attempted** for a non-Markdown file, so anchor extraction can never fail for it; it is never excluded on account of its type.

## 4. Degrade matrix

Degrade exactly as the grounding digest does (`skills/plan/SKILL.md` Step 0; `.project/design-philosophy.md#Error & failure philosophy`) — best-effort, never abort the run:

| Condition | Behavior |
|---|---|
| `sourceGlobs` absent/empty, or matching no files | Resolve to an **empty list** — **not** an error; the run proceeds exactly as it does for an empty digest. |
| A **matched file** that is unreadable, or whose anchor extraction fails | **Skip that single file** and continue over the rest — the run is **never aborted**. (A non-Markdown file has no read attempted, so this skip fires for it only on an enumeration-level failure such as a broken symlink.) |

## 5. Supplement, not an allowlist — and never persisted

The file-map **supplements, never replaces**, and is **not an allowlist**. It adds to, and does not close, the issue-author's on-demand Read/grep path: the author's rigor gate (`agents/issue-author.md` Rigor gate — "grep before you cite") is unchanged and still mandatory, so the author still greps/Reads the live repo to verify every citation before recording it, and may grep/Read anything **not** present in the file-map.

It is held **entirely in the in-run `resolved` bundle and is never persisted to disk** — no new file appears under `.milestone-feeder/` or `.milestone-config/` (`.project/environment.md#Data stores`), and there is **no rescan/daemon** (`.project/environment.md#Async & messaging`).
