---
name: refine
description: This skill should be used when the user invokes "/milestone-feeder:refine <milestone>", or asks to "refine a milestone", "re-triage and patch an existing milestone", or "fill missing dependency edges". Runs an IDEMPOTENT re-run against an EXISTING milestone — re-triages its live issues through the driver's reviewers (the #9 self-check gate), patches gapped issue bodies, fills missing dependency edges, and re-renders the Wave order. Idempotent: a clean milestone → NO-OP (writes nothing); an issue already `GAPS: none` is left byte-unchanged. Preview is the DEFAULT — writes a diff-style patch-plan file and changes nothing on GitHub; `--apply` edits the live issues. Creates and deletes NO issues. Authors no code; opens no PRs.
---

# refine — idempotent re-run against an existing milestone

Load a live GitHub milestone (its description, open issues, and **each issue's recorded design comments**), re-triage every issue through the driver's reviewers (the #9 self-check gate), patch the gapped issue bodies, fill the missing dependency edges, re-render the Wave order, and emit a diff-style patch plan. The maintenance counterpart of `decompose`: where decompose *creates* a milestone, refine *re-vets and repairs* one that already exists — **creating and deleting no issues.**

This skill REUSES decompose's machinery by reference, never by duplication: the self-check gate (`skills/decompose/SKILL.md` Step 6, §6.1–§6.6) and the `--apply` GitHub-write primitives (`skills/decompose/SKILL.md` §7-apply — the `gh label create --force` block, the `env.t` quote-safe milestone resolve, the `gh api PATCH` description form, the report routing). The single behavioral difference at the gate is the **input**: decompose vets *generated* issues with *empty* recorded-design and *local slugs*; refine vets *live* issues with their **real GitHub comments**, the **live milestone description** as cross-issue context, and **real GitHub issue numbers**. Every dispatched agent stays read-only and runs against provided text; the GitHub writes are performed by the skill itself via `gh`. **Preview is the default and writes NO GitHub state; `--apply` edits live issue bodies / labels and the milestone description — it CREATES and DELETES no issues. Authors no code, opens no PRs, never touches branches, never invents product scope — product gaps are parked to a report, never guessed.**

## Announce first

Say this to the user before doing any work — pick the line that matches the recognized mode (Modes table):

> **Preview (default):** Standing by while I refine the milestone — load its live issues + comments, re-run the self-check gate, and write a diff-style patch plan. This is a preview; I'll change nothing on GitHub.

> **Apply (`--apply`):** Standing by while I refine the milestone, run the self-check gate, then edit the gapped live issues + add missing edges + re-render the milestone description on GitHub. I'll write the patch-plan file as a local record first. If the milestone is already clean, this is a no-op — I'll say so and write nothing.

## Modes

Flags are **recognized by token match, not argument-parsed** — identical to decompose's flag-recognition convention (`skills/decompose/SKILL.md:22`, mirroring `milestone-driver/skills/solve-milestone/SKILL.md:13`). A flag is **recognized** when its token appears anywhere in the invocation text; `$ARGUMENTS` is string-substituted, not parsed. The bare milestone title is `$ARGUMENTS` with any `--<token>` stripped.

| Trigger | Mode | Behavior |
|---|---|---|
| `/milestone-feeder:refine <milestone>` | **Preview** (default) | Full procedure, Steps 0–5, including the self-check gate (Step 2); stops at a diff-style patch-plan file. **No GitHub writes.** |
| `… --apply` | **Apply** | Runs the full procedure (Steps 0–5, including the gate at Step 2) **then** applies the patches to LIVE issues at Step 5 — `gh issue edit --body` per patched issue, label adds, and `gh api PATCH` the milestone description. **Recognized by token match** (`--apply` appears in the invocation) **or the natural-language equivalent** ("apply it", "edit them on GitHub") — both route to the apply path (Step 5 §5-apply); absent either signal, preview runs (the locked default). |

Both paths run the #9 self-check gate (`skills/decompose/SKILL.md` Step 6) against the live issues; it performs no GitHub writes itself, so it runs in preview too. **Idempotency holds on both paths:** an issue whose gate verdict is `GAPS: none` is left byte-unchanged, and a fully-clean milestone yields a no-op (preview reports "nothing to patch"; `--apply` writes nothing — Step 5 IDEMPOTENCY contract).

## Procedure

### Step 0 — Read config + substrate (best-effort)

Identical to decompose Step 0 (`skills/decompose/SKILL.md` Step 0) — do not restate it; it is reused verbatim:

- Read `.milestone-config/feeder.json`. **Absent → invoke `milestone-feeder:setup`** (bootstraps the profile, aligns the label taxonomy, returns control), then continue — the user does not re-run the command.
- Extract the feeder's own keys with their bundled defaults (`substrateDir`, `selfCheck`, `decomposerAgent`, `issueAuthorAgent`, `issueSizeGuidance` — decompose's Step 0 table). `decompose` dispatches the decomposer; refine **does not** (it adds no candidates), so `decomposerAgent` is unused here — only `issueAuthorAgent` (Step 3) and `selfCheck` (Step 2) are consumed.
- Read the substrate under `substrateDir` **best-effort** (absent / `[TBD]` sections skipped, never grounded on).
- Resolve the **shared keys** (`sourceGlobs`, `uiSurfaceGlobs`, `integrationBranch`) and `nonNegotiables` from the driver config down the documented chain (`.milestone-config/driver.json` → root `milestone-driver.json` → absent-default). `nonNegotiables` is the additional reviewer-profile input the gate (Step 2) passes through; absent → OMITTED. `uiSurfaceGlobs` absent → treat every issue as **logic** and state the degradation in the patch plan.

### Step 1 — Load the live milestone

Resolve the milestone **BY EXACT TITLE** using the **same quote-safe `env.t` resolve idiom + multiple-match adopt-first-and-log** from `skills/decompose/SKILL.md` §7-apply.b — do not re-derive or reprint it; reuse the cited form (the title is read from the environment via `env.t`, never string-interpolated into the jq filter; bash and PowerShell 7+ forms are both given there). **One intentional delta:** refine's `--jq` `select` also returns `description` (it needs the live milestone description for the gate's cross-issue context and as the Step 4 render target) — i.e. `--jq '.[] | select(.title==env.t) | {number, state, description}'`, otherwise identical to decompose §7-apply.b. There is one canonical resolve idiom (decompose §7-apply.b) plus this single stated delta — not a second copy.

| Result | Action |
|---|---|
| **No title match** | 🔴 **ERROR-AND-STOP.** Refine creates nothing — there is no milestone to refine. Print `🔴 refine: no milestone titled "<title>" — refine re-vets an EXISTING milestone and creates none. Run /milestone-feeder:decompose to create it first.` and **end the run.** This is a terminal stop, distinct from decompose §7-apply.b's "no match → create" branch — refine never creates. |
| **Exactly one title match** (open or closed) | **Adopt** its `.number` and `.description`. Refine edits an existing milestone; it does not reopen or delete it. |
| **Multiple title matches** (GitHub permits same-title milestones) | **Adopt the FIRST returned**, log a notice — `refine: multiple milestones titled "<title>" — adopted first returned (#<n>)` — mirroring decompose §7-apply.b's recorded-ambiguity rule. Never touch the others. |

Then read the milestone's substance — the **recorded design refine feeds the reviewers**:

| Read | Command | Why |
|---|---|---|
| Milestone description | the `.description` captured in the resolve above | The current Wave order — the cross-issue dependency context the gate passes to the reviewers (the §6.2 "Milestone description" slot), and the render target for Step 4. |
| Open issues | `gh issue list --milestone "<title>" --state open --json number,title,body,labels` | The live issue set to re-vet — including each issue's **`body`** (decompose §7-apply.c list-and-match idiom). |
| **Each issue's comments** | `gh issue view <n> --json comments` **per issue** | **`gh issue list` omits comment bodies, so a per-issue `view` is required.** These REAL comments are the recorded design decompose's gate passes as *empty* — refine passes them through (the §6.2 "Recorded design decisions" slot, which the driver's `triage-reviewer.md:37` defines as "the issue's comments and any `design-cleared` notes"). This is refine's defining input delta. |

**Body+comments join.** The two reads above are complementary, not redundant: `gh issue list` carries each issue's **live `body`** but no comments; `gh issue view <n>` carries that issue's **comments** but is fetched only for comments. For each issue #n, pass its **body (from the `gh issue list` result)** AND its **comments (from the per-issue `gh issue view`)** together into the §6.2 gate brief, **joined on the issue number** — so the gate sees the real-comments + live-body delta in full (the body fills §6.2's "The issue" slot; the comments fill its "Recorded design decisions" slot).

**Degradation (open-issues-only scope).** Refine re-vets the milestone's **OPEN** issues; a dependency edge onto a closed/already-built issue is out of scope (closed work is done, so it does not affect the buildable Wave order). An undeclared dependency from an open issue onto a CLOSED sibling is therefore not surfaced — state the bound; refine does not load closed issues.

### Step 2 — Self-check via the #9 gate

Run the self-check gate from `skills/decompose/SKILL.md` Step 6 (§6.1–§6.6) **as the shared gate — do not duplicate its text.** Backend resolution (§6.1), verdict/aggregate logic (§6.3), the internal-checklist fallback (§6.4), and the five-field `GAPS` shape are all identical. Only the **brief composition (§6.2)** changes; the refine DELTAS:

| §6.2 slot | decompose passes | **refine passes** |
|---|---|---|
| The issue | the *generated* title + `ISSUE_BODY` | the **live** issue's `title` + `body` from Step 1 |
| Recorded design decisions | **empty** (no GitHub issue exists yet) | the issue's **REAL comments** from `gh issue view <n> --json comments` (Step 1) — `triage-reviewer.md:37` |
| Milestone description (cross-issue context) | the Step 5 render with **local slugs** | the **LIVE milestone description** from Step 1 (real `#n` numbers) |
| The profile | resolved `sourceGlobs` / `uiSurfaceGlobs` / `nonNegotiables` | identical (Step 0) |
| Identifiers throughout | **local slugs** (`#A`/`#B`) | **real GitHub issue numbers** (`#n`) |

Everything else is the cited gate, unchanged: dispatch `triage-reviewer` per issue (and `design-reviewer` when its `NEEDS_DESIGN_REVIEW: yes`), aggregate per-issue on lens/severity/description (§6.3 — `GAPS: none` → PASS; any `severity: Blocker` → FAIL; Advisory does not fail), with the `selfCheck` backend resolution and degrade-to-internal trigger of §6.1. Every reviewer is dispatched **read-only against the provided text** — same agent-read-only invariant.

Identify, per issue: (a) **Blocker gaps** in the body (§6.3 FAIL), and (b) **missing dependency edges** — the gate's `undeclared-dependency` findings (a `triage-reviewer` `DEPENDS_ON` edge or a `severity: Blocker` of `type: undeclared-dependency`, §6.6) the live milestone description does not already encode.

### Step 3 — Patch gapped issues; add missing edges

For each FAILed issue, follow the gate's own retry/park fork (`skills/decompose/SKILL.md` §6.5–§6.6) — reused, not redefined — with refine's patch-brief composition stated explicitly below. **At most 2** `issue-author` re-dispatches per issue (the same cap; `skills/decompose/SKILL.md` §6.5).

| Blocker class | Action |
|---|---|
| **Design / implementation-resolvable** (a body Blocker the substrate or a stated convention can answer — a missing state, an unnamed pattern to mirror) | **Re-dispatch `issue-author` to PATCH the body** (composition below). Then **re-dispatch the reviewer** (§6.2 brief carrying the revised body) and **re-aggregate its returned block** (§6.3) — a real fresh review, not a self-assessment or a re-aggregation of stale blocks. ≤2 retries. |
| **Missing dependency edge** (`undeclared-dependency`) | **Absorb into the graph** and re-render the description (§6.6 / Step 4) — does NOT consume an `issue-author` re-dispatch (§6.5 precedence). |
| **Genuine product gap** (no conventional default — what to build / user-facing behavior) | **Park to the report — NOT patched.** Re-dispatching cannot resolve a product gap; only a human can. Record as `needs-product-input`. |
| **Still-Blocker after 2 retries** | 🔴 **Retry-exhaustion terminal** — park as **needs-human-direction**, body left UNPATCHED (adopting #9 AC5). The issue is non-converging (usually the recorded design is wrong). Do not re-author further. |

**Issue-author patch-brief composition (the load-bearing delta — state it; do not assume the agent has a patch mode).** The `issue-author` contract (`agents/issue-author.md` → "What you receive" / "Output format") authors a **FRESH** body — it has **no documented "patch an existing body" input mode**. So the **ORCHESTRATOR composes the patch brief**: it carries the **EXISTING issue body** (from Step 1) **plus the specific gap to fix** — the Blocker's `description` + `to_clear` from §6.3 — and asks for a **revised body** that clears that gap while preserving everything already correct. The agent stays **read-only / text-in / text-out**: it reads the existing body + the gap + the same grounding (brief/substrate/shared keys per the §6.5 re-dispatch brief), and **returns a revised `ISSUE_BODY`** in its normal `STATUS / ISSUE_TAG / TITLE / ISSUE_BODY / LABELS` wrapper. It writes nothing to GitHub — refine owns every write (Step 5). A re-dispatch's brief carries **all of that issue's outstanding Blockers at once** (the §6.5 retry-budget shape), so two re-dispatches give two full clearing attempts.

**Add missing edges.** Each `undeclared-dependency` finding (Step 2) is **absorbed into the dependency graph** and re-rendered at Step 4 — the same §6.6 absorb-and-re-render cycle, bounded by the same ≤2 per-issue cap so the loop always terminates. Refine adds edges; it never removes a declared edge a human recorded.

A parked issue's body is left as-is on GitHub (refine deletes / drops nothing — there is nothing to "not emit," unlike decompose §6.6, because the issues already exist). Its gap goes to the report.

### Step 4 — Re-render the milestone description

Re-render the milestone description with any **added** edges using decompose's render (`skills/decompose/SKILL.md` Step 5) against the `SPEC.md` §4 Wave template — reused, not redefined. The identifiers are the milestone's **real `#n` numbers** (the issues already exist; no slug→`#n` rewrite is needed — that decompose pass is for freshly-created issues only). The re-rendered Wave order reflects the added edges; existing edges and their ordering are preserved.

**No-edge case (idempotency):** if Step 2 found **no** missing edge, the description is **not re-rendered** — the live description is already correct and is left byte-unchanged (no PATCH at Step 5).

### Step 5 — Emit: preview (default) or apply (`--apply`)

| Signal | Path |
|---|---|
| `--apply` token **absent** (and no NL "apply" / "edit on GitHub" equivalent) | **Preview (default)** — §5-preview. Writes the patch-plan file (+ report). **No GitHub writes.** |
| `--apply` token present, **or** the NL equivalent | **Apply** — §5-apply. Writes the patch-plan file first (the local audit record), **then** edits the live issues. |

#### §5-preview — Preview (default): write the diff-style patch plan

Write a **diff-style patch-plan file** to the gitignored per-run scratch path `.milestone-feeder/refine-plan-<slug>.md`, where `<slug>` is a short kebab-case slug of the milestone title. `.milestone-feeder*` is gitignored per-clone runtime scratch (the same convention as decompose's plan file, `skills/decompose/SKILL.md:282`); the skill writes there regardless of whether `.gitignore` carries the pattern — per-run scratch the user reviews and discards.

**Patch-plan format.** Per issue, show the proposed body **diff** (not the full body — only what changes), the added labels, and the added edges, plus the re-rendered milestone description and a needs-human-input section. The header tag is conditional on the path (`PREVIEW` vs `APPLIED`), mirroring decompose's plan-file convention (`skills/decompose/SKILL.md:284`):

```markdown
# Refine plan (<PREVIEW | APPLIED>) — <milestone title> (#<milestone-number>)

Self-check: <the Step 2 outcome — one of:
  CLEAN — all <N> issues GAPS: none; no missing edges → NO-OP (nothing to patch)
  PATCHED — <P> issue(s) body-patched; <E> edge(s) added; <N-P> issue(s) already clean (byte-unchanged)
  PARKED — <M> issue(s) → needs product input; <K> issue(s) → needs human direction (still-Blocker after 2 retries)
  INTERNAL — gate ran on the internal checklist (milestone-driver reviewers did not resolve)
  INTERNAL-FALLBACK — <F> issue(s) ran the internal checklist as a per-issue fallback (their milestone-driver dispatch returned unusable mid-run; the run stayed milestone-driver for the rest) — mirrors decompose §6.1's per-issue `internal-fallback` marker; record the issue number(s)
  SKIPPED (selfCheck:false) — 🔴 gate disabled; live issues were NOT re-vetted>
Milestone: #<n> "<title>"  (open issues: <N>)

## Per-issue patches
### #<n> — <title>   [patched | already clean (byte-unchanged) | parked: needs-product-input | parked: needs-human-direction]
<for a patched issue: a unified-style diff of the body — only the changed hunks (the Design/Acceptance lines the gap added), e.g.
  ## Design (recorded, consistent)
  + - Empty state: render the no-results placeholder, mirroring ContactsListPage:88 (cleared Blocker: missing empty state)
added labels: <[ui|logic, risk:*] or "none">
added edges:  <"Depends on #<m> — <reason>" or "none">>
<for an already-clean issue: the literal line "GAPS: none — left byte-unchanged (no edit)"  — NO diff, NO body shown>
<for a parked issue: marker + pointer to the report; body left as-is>

## Milestone description
<if edges were added: the re-rendered §4 Wave description (real #n), with added edges marked>
<if no edge was added: "unchanged — no missing edges (byte-unchanged, no PATCH)">

## Needs human input
<pointer: "see .milestone-feeder/needs-product-input-<slug>.md" when any issue parked; "none" otherwise>

---
<footer, conditional on the path:
  PREVIEW → "To apply these to GitHub, re-run with `--apply` — it edits each patched issue's body, adds the labels, and PATCHes the milestone description. This preview wrote no GitHub state. Already-clean issues are skipped (byte-unchanged)."
  APPLY   → "Applied to GitHub: <P> issue body edit(s), <L> label add(s), milestone-description PATCH <yes|skipped (no edge added)>. Already-clean issues were skipped (byte-unchanged). Needs-human-input report routed to <local file .milestone-feeder/needs-product-input-<slug>.md | none>.">
```

If any issue was parked (product-gap or needs-human-direction), also write the **"needs human input" report** to `.milestone-feeder/needs-product-input-<slug>.md` — the same Kind-column format decompose uses (`skills/decompose/SKILL.md:329-339`): a `product-gap` row (decide and record it) vs a `needs-human-direction` row (the recorded design is likely wrong — redirect it). Reuse that format; do not redefine it.

**On the preview path, no GitHub writes occur.** The patch plan and report are local scratch.

#### §5-apply — Apply (`--apply`): edit the live issues

After §5-preview has written the patch plan (the local audit record), apply the patches to LIVE issues in **this fixed order**, reusing decompose's §7-apply write-primitives by reference. All `gh` invocations are run **by the skill itself**, not by any dispatched agent. Commands are shell-neutral; the read-modify-write notes both a bash and a PowerShell 7+ form (decompose §7-apply.d).

**No-op short-circuit (BEFORE pass (a) — gates ALL writes).** If the Step 2 gate found **no gapped/patched issue AND no missing edge was added**, then the milestone is already clean: print the no-op line (`Refine: milestone already clean — no changes`) and **RETURN, performing ZERO `gh` writes** — **no** label ensure (pass a), **no** issue edit (pass b/c), **no** milestone PATCH (pass d). Pass (a)'s `gh label create --force` is a GitHub write that must NOT fire on a clean milestone; this guard sits above it so the AC6 no-op contract ("a clean milestone writes NOTHING") holds. **Only when there is at least one patched issue OR at least one added edge** does control fall through to the passes below.

| # | Write | Primitive (reused) |
|---|---|---|
| a | **Ensure labels** (BEFORE any add) — the four-label `gh label create … --force` block | `skills/decompose/SKILL.md` §7-apply.a (which itself chains to `skills/setup`) — verbatim, not re-invented. |
| b | **Edit each PATCHED issue's body** — `gh issue edit <n> --body "<patched body>"` | The bare `gh issue edit <n> --body` invocation only, from `skills/decompose/SKILL.md` §7-apply.d. One edit per patched issue. **Note:** refine reuses only the invocation form — it does **NO** slug→`#n` rewrite (the live issues already carry real numbers; the §7-apply.d rewrite is decompose's slug→#n pass on freshly-CREATED issues, which is semantically the opposite of refine's edit-an-existing-patched-body). |
| c | **Add labels — PATCHED issues ONLY** (the labels the patch itself implies) — `gh issue edit <n> --add-label <ui\|logic>` / `--add-label <risk:*>` | The `gh issue edit --add-label` helper, `skills/decompose/SKILL.md` §7-apply.a. **Scope:** label-adds are tied to the gate verdict — they apply ONLY to issues this run PATCHED (pass b), adding the classification/risk label the patch implies. A **clean (`GAPS: none`) issue is NEVER touched** — no label add, no body edit — even if it happens to be missing a `risk:*` label; that is not label churn refine performs (AC6 byte-unchanged). |
| d | **PATCH the milestone description** (ONLY if an edge was added at Step 4) — `gh api --method PATCH "repos/{owner}/{repo}/milestones/<milestone-number>" -f description="<re-rendered Wave order>"` | The `gh api PATCH` description form from `skills/decompose/SKILL.md` §7-apply.d (the REPLACE form — both bash and PowerShell 7+). |

The needs-human-input report routes to the **local file** (refine takes a milestone title, not an epic issue — there is no `epicIssueNumber`, so decompose §7-apply.e's epic-comment branch never applies). Print a notice that the report is local.

**Partial-failure path.** A failed `gh issue edit` (pass b/c) or the milestone PATCH (pass d) is reported, not silent; re-running `--apply` is safe — an already-clean issue is skipped (byte-unchanged), an already-patched body re-PATCHes to the same content (the gate finds `GAPS: none` on the now-patched body → no re-edit), and the description PATCH overwrites (idempotent). This reuses decompose §7-apply's partial-failure discipline (`skills/decompose/SKILL.md` §7-apply, "Partial-failure path") — refine adds no resume mechanic of its own beyond re-running the gate.

### IDEMPOTENCY (AC6) — the explicit contract

This is the keystone behavior that distinguishes refine from decompose. It holds on **both** paths:

| Condition | Behavior |
|---|---|
| An issue whose gate verdict is `GAPS: none` (Step 2) | **Left BYTE-UNCHANGED** — no `gh issue edit`, no label churn, no diff in the patch plan (only the "GAPS: none — left byte-unchanged" line). The gate decides this per issue, independently. |
| NO issue is gapped AND NO edge is missing (a fully-clean milestone) | **NO-OP.** On `--apply`, refine writes **NOTHING** — no issue edit, no label, no milestone PATCH — and says so (`refine: milestone "<title>" is already clean — nothing to patch (no-op)`). On preview, the patch plan records `CLEAN — NO-OP`. |
| Re-running refine on a milestone it just patched | A **no-op** — the previously-patched issues now return `GAPS: none`, so they are left byte-unchanged; the description (already re-rendered) has no new edge to add, so no PATCH. Idempotent by construction. |

**Caveat (stable-gate assumption).** The no-op / byte-unchanged guarantee assumes the gate returns a **stable verdict** across runs; an LLM-backed reviewer may rarely re-flag a previously-cleared issue, in which case refine re-patches it (bounded by the same ≤2 re-dispatch cap). This is an honest bound on idempotency, not a redesign.

Refine **CREATES and DELETES no issues** — it only edits existing ones (body, labels) and PATCHes the milestone description. Issue creation/deletion is decompose's job, never refine's.

## Output style

Be concise — report status and outcomes flatly, no wall-of-text. Present steps, gates, lists, and options as **tables**, not inline prose. Mark anything that needs a human with 🔴. (Mirrors the agents' communication-style contract and decompose's output style.)

## Non-negotiables

- **Idempotent — clean → no write, byte-unchanged.** An issue at `GAPS: none` is left byte-unchanged (no `gh issue edit`); a fully-clean milestone yields a true no-op (`--apply` writes nothing) and refine says so. Re-running on an already-patched milestone is a no-op.
- **Creates and deletes NO issues.** Refine edits existing issue bodies / labels and the milestone description only — issue creation and deletion are decompose's job. **Milestone-not-found → ERROR-AND-STOP** (refine never creates the milestone).
- **Authors no code, opens no PRs, never touches branches.** Editing issue bodies / labels / a milestone description is NOT code, a PR, or a branch. Refine reads code to ground decisions; it never edits a source file, creates a branch, or opens a PR. The `--apply` GitHub writes are performed by the skill itself via `gh`, not by any dispatched agent — the agent-read-only invariant holds.
- **Reuses the #9 self-check gate + #10 write-primitives — no second definition.** The gate is `skills/decompose/SKILL.md` Step 6 (§6.1–§6.6); the write-primitives are `skills/decompose/SKILL.md` §7-apply (the `--force` label block, the `env.t` resolve, the `gh issue edit --body`, the `gh api PATCH` description). Refine references them; it does not re-derive a drifting copy. The only delta is the gate's input — real comments, live description, real `#n`.
- **Parks product gaps — never invents scope.** A decision with no conventional default is parked to the needs-human-input report — never guessed to clear a Blocker. A still-Blocker after 2 `issue-author` re-dispatches is parked as needs-human-direction with the body left UNPATCHED (retry-exhaustion terminal).
- **Every dispatched agent is read-only / text-in.** The reviewers (Step 2) and the `issue-author` (Step 3 — briefed with the existing body + the gap, returning a revised body) read provided text and write nothing to GitHub. Refine owns every write.
