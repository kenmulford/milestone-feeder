# Step-0 grounding inputs — resolve once, hand into the routine, degrade like the digest

`plan`'s Step 0 (`skills/plan/SKILL.md` Step 0 — the once-per-run OUTER boundary) assembles **four grounding inputs** the inner routine consumes: the **grounding digest**, the **file-map**, the **global implied-surfaces reference**, and the **project-local implied-surfaces overlay** merged into it. All four share one resolution contract; this file states that shared contract **once**, then records each input's own specifics. It is reference content relocated out of `skills/plan/SKILL.md` to keep that always-loaded file within the repo's own size standard; nothing about what Step 0 does changes, only where its mechanics are recorded — mirrors the existing `docs/one-time-notices.md` and `docs/version-ladder.md` relocations, and folds in the former `docs/file-map.md` (now consolidated here so every Step-0 grounding input is one level deep from `skills/plan/SKILL.md`). `skills/plan/SKILL.md` Step 0 keeps only the short in-place stubs that name the inputs and this file; resolve each exactly as recorded here.

## Contents

1. [The shared contract — resolve-once / hand-in / degrade / supplement](#1-the-shared-contract--resolve-once--hand-in--degrade--supplement)
2. [The grounding digest](#2-the-grounding-digest)
3. [The file-map](#3-the-file-map)
4. [The global implied-surfaces reference](#4-the-global-implied-surfaces-reference)
5. [The project-local overlay — additive merge](#5-the-project-local-overlay--additive-merge)

## 1. The shared contract — resolve-once / hand-in / degrade / supplement

Every input in this file obeys the **same four-part contract**. Each input's own section below records only what is *specific* to it; the four properties here are not restated per input.

- **Resolve ONCE, here.** Each input is resolved a single time, at the Step-0 OUTER boundary, alongside the shared-keys resolution — **never** re-resolved per candidate or per inner-routine invocation. Step 0 **produces** each input; the Step-3 architect brief and the Step-4 issue-author brief that **consume** them are wired at Steps 3 / 4.
- **Hand into the inner routine.** Each resolved input is carried in the `resolved` callable-contract bundle (`skills/plan/SKILL.md` — the inner-routine `resolved` parameter) and handed **unchanged** into the routine; the routine re-assembles / re-resolves **nothing**.
- **Degrade best-effort, never abort** (`.project/design-philosophy.md#Error & failure philosophy`). An absent / unreadable / malformed source resolves to an **empty / minimal pass-through — no error, no abort**; the run proceeds best-effort on stated repo conventions, and whatever downstream consult depended on it becomes a clean no-op.
- **Supplement, never replacement.** Each input **adds to**, and does not close, the agents' own on-demand Read/grep path. Every agent's rigor gate stays mandatory — the architect cites its grounding / verifies a sibling `file:line` before recording it, and the issue-author "greps before it cites." No input is an allowlist; an agent may Read/grep anything not present in it.

## 2. The grounding digest

A compact, **ordered** set of `.project/<doc>.md#<section>` *slices* — each slice = the section anchor (in that citation form) paired with that section's body text — assembled while reading the project docs.

- **Selection filter (no new rule).** Select slices with the **same filter already in force** at Step 0 — exactly the sections that exist, with absent / `[TBD]` sections skipped (Step 0's "skipped, never grounded on", and Step 3's "only the sections that exist"). Introduce **no new** selection or skip rule.
- **Superset.** The digest carries *every* implicated existing section, so handing it downstream in place of the directory never drops grounding.
- **Specific degrade.** A missing `projectDocs` directory, all-absent / `[TBD]` sections, or a read/parse failure → an **empty / minimal digest** (per §1's degrade rule).

## 3. The file-map

An **ordered**, `sourceGlobs`-bounded index of `{ path, anchors }` pointers at **where** cited code and sibling patterns live — resolved once at Step 0 alongside the digest and handed into every Step-4 issue-author brief beside the prose digest. (`sourceGlobs` is resolved as a shared key in the same Step-0 boundary.)

### 3.1 Shape and purpose

An **ordered list**, one entry per file matching the resolved `sourceGlobs`. Each entry has exactly two fields:

- **`path`** — repo-relative path to the matched file.
- **`anchors`** — the file's top-level `##` / `###` heading-text list (for Markdown files), or the empty list `[]` (for non-Markdown files — see §3.3).

Its job is **discovery / location** — pointing the issue-author at *where* a sibling pattern or cited artifact lives — not grounding text. **Pointers only, never content:** an entry never carries section bodies or file contents, only the path and the heading-text list. The author still Reads/greps the located file to verify and cite it (§1's supplement rule; §3.5).

### 3.2 Ordering rule (deterministic enumeration)

The `ordered` guarantee is the **enumeration's own natural order, held stable for the run** — not a separately imposed sort. Resolve entries in this order:

1. The globs in their resolved `sourceGlobs` **array order**.
2. Within each glob, files in **glob-match / filesystem enumeration order**.
3. **First-match-wins dedup:** a file matching more than one glob appears **ONCE**, at its **first-matching glob's** position.

Do **not** invent a new sort key (no alphabetical, no mtime, no separate sort step layered on top of the enumeration). The map is resolved once and handed identically to every brief, so the load-bearing guarantee is within-run identity — every author brief receives the same ordered map.

### 3.3 Anchor extraction (Markdown-only) and non-Markdown files

- **Markdown files** — `anchors` is the file's top-level `##` / `###` heading-text list, extracted from the file.
- **Non-Markdown files** (e.g. a `hooks/**` script) — included as `{ path, anchors: [] }`. **No read and no anchor extraction is attempted** for a non-Markdown file, so anchor extraction can never fail for it; it is never excluded on account of its type.

### 3.4 Specific degrade

| Condition | Behavior |
|---|---|
| `sourceGlobs` absent/empty, or matching no files | Resolve to an **empty list** — **not** an error; the run proceeds exactly as it does for an empty digest. |
| A **matched file** that is unreadable, or whose anchor extraction fails | **Skip that single file** and continue over the rest — the run is **never aborted**. (A non-Markdown file has no read attempted, so this skip fires for it only on an enumeration-level failure such as a broken symlink.) |

### 3.5 Never persisted

Beyond §1's supplement-not-allowlist rule, the file-map is held **entirely in the in-run `resolved` bundle and is never persisted to disk** — no new file appears under `.milestone-feeder/` or `.milestone-config/` (`.project/environment.md#Data stores`), and there is **no rescan/daemon** (`.project/environment.md#Async & messaging`).

## 4. The global implied-surfaces reference

The **plugin-bundled GLOBAL** implied-surfaces reference: read `${CLAUDE_PLUGIN_ROOT}/docs/implied-surfaces.md` (the plugin-root convention this repo uses for bundled assets — `hooks/hooks.json`) into the resolved content this run hands downstream. It is the reasoning prompt the architect's implied-surfaces clause consults (`agents/architect.md` → "What you receive" → *the resolved implied-surfaces reference*; clause 8).

- **Scope of this resolution: the GLOBAL reference only.** The project-local overlay (§5) is merged into it in the very next step, producing the single **merged** reference the run hands downstream.
- **Specific degrade.** An absent / unreadable / malformed reference resolves to an **empty / minimal pass-through** (per §1); the architect's clause-8 consult then becomes a **no-op**.

## 5. The project-local overlay — additive merge

Immediately after resolving the global reference (§4), read the **optional project-local** overlay at the fixed **consumer-repo** path `.milestone-config/implied-surfaces.md` — the suite config directory, **NOT** plugin-bundled (contrast the global reference, which is the plugin-root `${CLAUDE_PLUGIN_ROOT}/docs/implied-surfaces.md`). The overlay is discovered by that **fixed path** — there is no `feeder.json` key that points at it (`docs/implied-surfaces.md` → "Project-local overlay" → *Where it lives*). Its shape **mirrors the global reference** (`docs/implied-surfaces.md` → "Project-local overlay" → *Its shape*): one capability per `##` heading, its implied surfaces listed beneath. Parse it into that same `##`-section structure and **operate on the parsed structure — do not redefine the shape**.

**Merge it ADDITIVELY into the global reference, producing the ONE merged reference this run hands downstream** (`docs/implied-surfaces.md` → "Project-local overlay" → *How it merges — additive only*). Merge precedence:

- A capability **only in the global** → carried **unchanged**.
- A capability **only in the overlay** → **ADDED**.
- A capability in **both** → the **UNION** of their surface lists, **deduped**, **global surfaces first, then overlay-added surfaces, in stable order**.

The global reference is the **FLOOR — never reduced**; the merge is **purely additive with NO removal path**. A deletion attempt is therefore a **no-op by construction** (there is simply no delete operation), and an **empty / add-nothing** overlay yields **merged == global**. Per-run trimming of a surface a given milestone does not want stays the **plan REVIEW's job** (Step 7's implied-surfaces review prompt; `docs/implied-surfaces.md` → "Project-local overlay" → *How it merges* — "the plan review's job"), **not** a config-level delete.

**Specific degrade.** An **absent** overlay → the global reference is used **UNCHANGED**, which is **NOT an error and carries NO notice** (most projects ship no overlay — the common case). An **unreadable / malformed / wrong-shape** overlay → **fall back to the global reference unchanged, best-effort skip, NEVER aborting the run** (the overlay's own "Malformed input is skipped, never grounded on" contract). A **non-blocking notice MAY** surface the skip, but it **must NOT gate**. The overlay's discovery path — how existing users learn the overlay exists (the `setup` mention and the one-time `plan` / `update` notice) — is owned elsewhere (already on develop), **NOT** this step; Step 0 only **resolves + merges** the overlay.
