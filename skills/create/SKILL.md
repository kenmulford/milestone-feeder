---
name: create
description: This skill should be used when the user invokes "/milestone-feeder:create <brief>", or asks to "create the milestone", "deploy the approved plan", or "build the milestone and issues". Deploys the plan you approved to GitHub — labels, the milestone, every issue, and the build order — trusting the review the plan file already recorded; it does NOT re-check or re-plan. If you have no plan file yet for this brief, it runs `plan` first to make one, then deploys. No flags. Authors no code; opens no PRs.
---

# create — deploy the approved plan to GitHub (read-the-plan, faithful)

Resolve the plan file `plan` wrote for this brief (by the same deterministic slug), then deploy **exactly it** to GitHub: ensure the labels, create-or-adopt the milestone by its exact title, open each surviving issue, rewrite the local slug references to real issue numbers, PATCH the build-order description onto the milestone, file the needs-input report, and — as its **closing action** — verify the deployed milestone(s) and issues cover the original brief (Step 3V). The deploy step of the feeder pipeline: where `plan` *compiles* the plan file, `create` *deploys* it.

`create` is **faithful** — it builds what you approved. On the found path it does **NOT** re-dispatch the architect or the issue-author, and does **NOT** re-run the self-check gate (the reviewer). The plan file already recorded the gate-surviving issue set and its verdict; `create` trusts that verdict and writes the recorded issues — it regenerates nothing (`docs/specs/v0.3.0-humanize-the-surface.md` §4: *"on the found path, `create` does not re-dispatch the architect / issue-author, and does not re-run the self-check gate"*). The only path that runs the gate from `create` is the run-`plan`-first fallback (the plan file was absent, so there is nothing yet to deploy). **No flags** — `create` *is* the write verb of the plan/create pair; there is nothing to argument-parse (`docs/specs/v0.3.0-humanize-the-surface.md` §2: zero flags anywhere). Authors no code, opens no PRs, never touches branches; every dispatched agent — only on the run-`plan`-first fallback — stays read-only against provided text. The GitHub writes are performed by the skill itself via `gh`, so the agent-read-only invariant holds.

**One brief, or a roadmap of N milestones.** Most runs deploy **one** plan file to **one** milestone (the single-plan path). When `plan`'s roadmap flow produced a **roadmap manifest** for this brief — the ordered list of N milestone plan files in build order (`skills/build-roadmap/SKILL.md` "Manifest format") — `create` deploys **all N** in one run by **looping this same per-plan deploy** over the manifest's milestones in build order, recording each milestone's cross-milestone position in its description. The per-plan deploy is reused **by reference, not re-derived as a drifting copy** (`.project/design-philosophy.md#What we optimize for` — composability). The single-plan path is the **N=1** case and is unchanged; the multi-milestone loop is purely additive and is gated on a manifest only `plan`'s roadmap flow produces (Step 1R below).

## Announce first

Say this to the user before doing any work — pick the line that matches the resolution outcome (the plan file was found, or it was absent):

> **Plan file found:** Standing by while I deploy the approved plan to GitHub — I'll ensure the labels, create-or-adopt the milestone, open each issue, rewrite the slug references to real numbers, and PATCH the build order. I'm deploying **exactly the plan you approved** — I trust the review it already recorded and re-check nothing.

> **No plan file yet:** I don't have a plan file for this brief, so I'll run `plan` first to make one (it reads your project docs, breaks the idea into issues, and checks each against your conventions), then deploy that plan to GitHub.

> **Roadmap of milestones found:** I have a roadmap of N milestones for this brief, so I'll deploy **all N** in build order — for each one I'll ensure the labels, create-or-adopt the milestone, open its issues, rewrite the slug references to real numbers, and PATCH its build order, then record where it sits in the overall build order (`build order: milestone X of N`). I deploy **exactly the plan you approved** for each milestone and re-check nothing. If one fails I'll stop and report what deployed and what's left to do — I delete nothing, and re-running picks up where it stopped.

## Procedure

### Step 0 — Read config (best-effort)

Read `.milestone-config/feeder.json`. **Absent → invoke `milestone-feeder:setup`** (it bootstraps the profile, aligns the label taxonomy, and returns control), then continue — the user does not re-run the command (`skills/setup/SKILL.md` Phase 5). `create` reads the same own-keys as `plan` (`projectDocs`, `reviewer`, `architectAgent`, `issueAuthorAgent`, `issueSize` — `skills/plan/SKILL.md` Step 0); on the found path it consumes **none** of them (it deploys the recorded plan and regenerates nothing), and on the run-`plan`-first fallback `plan` itself consumes them. The only configuration `create` itself needs is GitHub write access (the `gh` surface in the passes below).

**`create` additionally reads its own `autoHandoff` key** (Step 4 — the driver handoff). This is the one own-key `create` consumes on **both** paths (it is not a `plan` key). Extract it with its bundled default, same absent-means-default discipline as the `plan` key-extraction table (`skills/plan/SKILL.md` Step 0; `docs/profile-schema.md`):

| Key | Default | Use |
|---|---|---|
| `autoHandoff` | `"prompt"` | After the deploy, whether `create` offers to hand the milestone to `milestone-driver` to start building (Step 4). `"prompt"` → ask (default); `"auto"` → kick off immediately, no prompt; `"off"` → never offer. An **unrecognized value** (anything that is not exactly `"prompt"`, `"auto"`, or `"off"`) is treated as the default `"prompt"` — mirrors how `versioning` treats an invalid value as absent (`docs/profile-schema.md` `versioning` per-key note); never error on the key. |

### Step 1R — Resolve the deploy target: a single plan, or a roadmap of N milestones

Check for a **roadmap manifest** at `.milestone-feeder/roadmap-<slug>.md` (slug derived as in Step 1). **Absent → single-plan path, UNCHANGED:** fall through to Step 1 and run Steps 1 → 4 once (the **N=1** case). **Found → roadmap deploy:** read the manifest (**never** regenerate it) and loop the per-plan deploy (Step 2 → Step 3 passes a–e) over its milestones in build order, resolving each by its recorded `Plan file:` path and recording its `build order: milestone X of N` line **inside** pass (d)'s description PATCH (idempotent), then run Step 3V over the whole-app brief. A mid-loop failure stops, deletes nothing, and re-runs resume.

Full mechanics — the resolution table, the outer-loop per-milestone steps, and the build-order-line assembly twins — live in **`docs/create-deploy-sequence.md` → "Step 1R — Resolve the deploy target"**.

### Step 1 — Resolve the plan file for the brief

Derive `<slug>` **deterministically** from the one-line milestone goal of the brief, using the **same derivation `plan` uses** (`skills/plan/SKILL.md` Step 7 — the slug-derivation rule): lowercase the goal, replace every run of non-alphanumeric characters with a single hyphen, strip any leading/trailing hyphen, and cap the length at the same bound (trimming a trailing hyphen if the cut lands on one). The same brief always resolves to the same path:

```
.milestone-feeder/plan-<slug>.md
```

Resolve the plan file at that path:

| Resolution | Action |
|---|---|
| **Found** | Read it; deploy **exactly it** (the §3 plan-file contract below) — no pipeline re-run, no re-vet. Trust the recorded gate verdict. Proceed to Step 2. |
| **Absent** | Run `plan` **first** against the brief — the full pipeline + the self-check gate, which **writes** the plan file at this same path (`skills/plan/SKILL.md` Step 7). Then read the freshly-written plan file and deploy it (Step 2). |

**Staleness (a changed brief earns a fresh plan).** The slug is a function of the brief's goal, so a **changed** brief derives a **different** slug → no match at the path above → the **Absent** row fires and `create` re-plans (faithful: you changed the brief, so you get a fresh plan). When the slug **matches an OLDER** plan file (the brief is unchanged since `plan` ran), `create` uses **that** file — you approved THAT — and prints a one-line notice:

> using existing plan file from <when> — re-run `plan` to refresh

This is the only staleness behavior; there is no flag and no prompt — a matching slug means the recorded plan is what you approved (`docs/specs/v0.3.0-humanize-the-surface.md` §4).

### Step 2 — Read the plan-file contract

The plan file is the **load-bearing build artifact** — `create` reads it and writes GitHub from it, regenerating nothing (`docs/specs/v0.3.0-humanize-the-surface.md` §3). Parse every field below by name (the format is `skills/plan/SKILL.md` Step 7; the field requirements are the `docs/plan-file-contract.md` Plan-file field table and `docs/specs/v0.3.0-humanize-the-surface.md` §3):

| Plan-file field | What `create` reads it for |
|---|---|
| **Milestone title (exact)** | The load-bearing identity field — `create` resolves the milestone by THIS exact string (pass b). Distinct from the one-line goal (descriptive only). |
| **Milestone description (Wave order)** | The Step-5 build-order description, verbatim, with **local slugs** (`#A`/`#B`). `create` rewrites the slugs to real `#n` and PATCHes it onto the milestone (pass d). |
| **Per surviving issue** — slug, title, the FULL §4 `ISSUE_BODY` verbatim, labels (`ui`\|`logic` + `risk:*`), surface/risk | The issues to create — read verbatim, **no regeneration** (pass c). Only the **surviving** (gate-clean / Advisory-only) issues in the plan file's `## Issues` section are created. |
| **Parked issues** — read from the **bracketed marker on the `### #X — <title>` heading** (`[parked — needs product input]` or `[parked — needs human direction …]`, `docs/plan-file-contract.md` Plan-file output template), not a discrete `kind:` field | Marked in the plan file, **NEVER created**. Routed to the needs-input report (pass e). |
| **Dropped issues** — read from the **bracketed marker on the `### #X — <title>` heading** (`[dropped — depends on parked #X]`, `docs/plan-file-contract.md` Plan-file output template) | Marked in the plan file, **NEVER created** (a dependent of a parked issue can't build). |
| **Self-check verdict** — the plan file's `Self-check:` line (the literal label `plan` writes, `docs/plan-file-contract.md` Plan-file field table) | `create` reports its recorded token (PASS / INTERNAL / PARKED / SKIPPED(reviewer:false)) and **trusts it — no re-vet** (`docs/specs/v0.3.0-humanize-the-surface.md` §4). |
| **Source brief reference** — `inline` \| `file:<path>` \| `epic #<n>` | Drives the report routing (pass e). An `epic #<n>` reference is the `epicIssueNumber` for the epic-comment branch. |

`create` does **not** re-derive any of these — it does not re-dispatch the architect for the candidates, the issue-author for the bodies/labels, or the reviewer for the verdict. It reads the recorded values and deploys them.

### Step 3 — Deploy (the write sequence, in this fixed order)

Deploy the plan file's recorded issue set to GitHub in this **fixed pass order** — every `gh` write performed **by the skill itself**, never a dispatched agent (the v0.2.0 apply write-sequence, preserved verbatim; only the *source* of the bodies / labels / waves / title / verdict changed — `create` reads them from the plan file, regenerating nothing; `docs/specs/v0.3.0-humanize-the-surface.md` §3, §4). Full mechanics for passes **a–d** — each `gh` form with its bash + PowerShell 7+ twin, the create-or-adopt table, the deploy-receipt back-write, the slug→`#n` map, and the substring-safe rewrite rule — live in **`docs/create-deploy-sequence.md` → "Step 3 — deploy write-sequence (passes a-d)"**:

| Pass | What it does |
|---|---|
| **a. Ensure labels** | Upsert the four canonical labels (`gh label create … --force`) **FIRST**, so every later `--label` resolves; re-runs never duplicate. |
| **b. Create-or-adopt the milestone (by EXACT title)** | Resolve by the exact title — create / adopt (reopen if closed) / **never delete** — then write the deploy receipt (`Milestone number (GitHub): <n>`) back to the plan file (quote-safe `env.t` resolve; the back-write **reports, never blocks**). |
| **c. Create each surviving issue; build the slug→`#n` map** | Create **only** the non-parked / non-dropped issues; on adopt, reuse by exact title (no duplicates), adopted bodies left as-is; apply each issue's recorded labels. |
| **d. Second pass — rewrite slug→`#n`** | With the **complete** map, rewrite every slug occurrence (newly-created issue bodies + the milestone description) **substring-safe** — descending slug-length order, token-boundary match — then PATCH the description (REPLACE form; idempotent). |
| **e. File the needs-input report** | Retained inline below — routes only when the `## Needs human input` pointer is not "none". |

#### e. File the needs-input report

The plan file records the **Source brief reference** (`inline` \| `file:<path>` \| `epic #<n>`) and its `## Needs human input` pointer (Step 2). Route the report whenever the plan file's `## Needs human input` section points to a report (its pointer is NOT "none") — equivalently, whenever the plan recorded **any product gap OR any parked issue** (`skills/plan/SKILL.md` Step 7 writes that pointer under the broader condition: `productGaps[]` non-empty OR the self-check parked any issue; a carried-forward product gap can set it with zero parked issues). Route by the recorded brief form. The report **body already exists** in the `plan` run's output (`.milestone-feeder/needs-product-input-<slug>.md`, `docs/plan-file-contract.md` Needs-product-input report template); `create` **routes** it — it does not regenerate the gaps:

| Brief form (from the plan file's Source brief reference) | Where the report goes |
|---|---|
| **GitHub epic issue** (`epic #<n>` recorded) | Post the report as a **comment on the epic issue:** `gh issue comment <epicIssueNumber> --body "<report>"`. |
| **File path / inline text** (no epic) | Write / keep the **local file** `.milestone-feeder/needs-product-input-<slug>.md` and **PRINT a notice** that the report is local (no epic issue to comment on). |

Before writing the local report, ensure the scratch dir self-ignores (it normally already does — `plan` wrote the plan file under `.milestone-feeder/` and ensured `.milestone-feeder/.gitignore` contains `*`; `skills/plan/SKILL.md` Step 7): create `.milestone-feeder/` if absent and ensure `.milestone-feeder/.gitignore` contains a single `*` line, so the report is git-invisible in the consumer repo with zero user setup.

If the plan file's `## Needs human input` pointer is "none" (no product gap and nothing parked), there is no report to route — say so and skip this pass.

### Step 3V — Verify the deploy covers the original brief (create's closing action)

After the deploy loop (single-plan Step 3 passes a–e; roadmap Step 1R's loop over all N milestones), `create` runs an **always-on, best-effort, non-blocking** closing verification: resolve the **original** brief (in-session, else the persisted copy read **strictly between** the paired `## Original brief` … `## End original brief` markers, else a non-blocking `original brief unavailable` notice — **never** fabricated), read **every** deployed milestone + issue back via `gh` (content or a `read-error` marker), dispatch the brief-coverage verifier (`milestone-feeder:brief-coverage-verifier`, #156) **once** with that payload, and route the returned punch-list exactly like pass (e) (epic → comment; file / inline → local git-invisible file + notice; clean → "nothing missed", route nothing). It **never** blocks completion / the handoff / any merge and **never** auto-fixes; it skips with a notice when nothing was deployed to read back or #156 is not installed.

Full mechanics — the skip-condition table, the brief-resolution ladder, the paired-delimiter extractor twins, the read-back twins, and the routing table — live in **`docs/create-deploy-sequence.md` → "Step 3V — Verify the deploy covers the original brief"**.

### Step 4 — Offer the driver handoff (clean-run only)

After the deploy, `create` can hand the milestone to `milestone-driver` to start building — **build-kickoff only**, governed by `autoHandoff` (Step 0) and **three gates that must ALL hold**:

- **Gate 1 — clean run only:** the `## Needs human input` pointer is **"none"** **AND** the self-check actually ran — a real PASS / INTERNAL verdict, **not** `SKIPPED(reviewer:false)` (its issues were never vetted → Gate 1 fail).
- **Gate 2 — driver installed (else silently skip):** if `/milestone-driver:solve-milestone` does **not** resolve in this session, skip silently — no prompt, no error.
- **Gate 3 — never crosses the release boundary:** the handoff merges **only** to the integration branch; `develop → main`, closing the milestone, and deploy stay manual and human-only.

`autoHandoff` (default `"prompt"`) selects prompt / auto / off (an unrecognized value → `"prompt"`); the invocation passes the **exact** `Milestone title (exact)` line. On a **roadmap** run the single-plan handoff is **not** auto-fired across the roadmap.

Full mechanics — the gate write-ups, the `autoHandoff` behavior table, and the numeric-title caveat — live in **`docs/create-deploy-sequence.md` → "Step 4 — Offer the driver handoff"**.

### Partial-failure path (resume on re-run)

A `create` run is **not "done"** until the milestone description AND every created-issue body carry real `#n` numbers. A failure can land in pass (c) (an issue create) or pass (d) (a body edit or the milestone-description PATCH); the table below maps each to its action. **Pass (d) is IDEMPOTENT** — re-applying the slug→`#n` rewrite to an already-numeric body or description is a no-op (the substring-safe rule finds no slug to rewrite), and the PATCH overwrites — so a re-run can always safely re-execute pass (d) against the captured (or re-derivable, from the now-complete title→`#n` map) slug→`#n` map, **even when pass (c) created nothing** because every issue was already adopted by title.

| Failure point | Immediate action | Resume on re-run |
|---|---|---|
| **Pass (c)** — a `gh issue create` fails mid-loop | **Abort pass (d)** — the slug→`#n` map is incomplete; rewriting against it would write dangling references. **Report** what was created + the captured partial map + which candidate failed. | The adopt + match-by-title path (b → c) reuses the already-created issues by title (no duplicates), creates the remaining surviving issues, then runs pass (d) against the now-complete map. |
| **Pass (d), milestone-description PATCH** fails — after all issues were created | **Report** that the issues exist but the milestone description still shows local slugs; the description is unresolved. | Re-run re-executes pass (d): it rebuilds the slug→`#n` map from the adopted issues (match-by-title) and re-PATCHes the description (PATCH overwrites — idempotent). |
| **Pass (d), a `gh issue edit` (body rewrite)** fails — after all issues were created | **Report** which created issue still carries local slugs in its body. | Re-run re-executes pass (d): re-applying the rewrite to already-numeric bodies is a no-op, and the still-slugged body is rewritten and edited. Adopted (pre-existing) issue bodies are left as-is per the pass-(c) body policy. |

In all cases the failure path is **defined, not silent**, and re-running `create` always re-attempts pass (d) until the milestone description and all created-issue bodies carry real numbers — the resume re-uses the match-by-title de-dup (least-code).

**Multi-milestone roadmap (the outer loop, Step 1R).** When a roadmap manifest drove the deploy, the same partial-failure discipline applies **per milestone**, with a cross-milestone dimension on top. If a milestone's deploy fails mid-loop — a missing plan file at per-milestone step **i**, or any pass (c)/(d) failure inside its Step 3 — **STOP the loop** and report the partial state: which milestones **fully deployed** (with their `#`), which one **failed and at which pass**, and which remain **pending**. **Delete nothing.** A **re-run resumes**: the outer loop re-iterates the whole manifest in build order — each already-deployed milestone is **adopted by exact title** (create-or-adopt, reopened if closed; its open issues reused by title; its pass (d), including the `build order: milestone X of N` line, re-PATCHed idempotently), and the failed + remaining milestones deploy. Resumption is the existing per-plan path applied per milestone — no new resume machinery.

## Output style

Be concise — report status and outcomes flatly, no wall-of-text. Present steps, gates, lists, and options as **tables**, not inline prose. Mark anything that needs a human with 🔴. (Mirrors the agents' communication-style contract and `plan`'s output style.)

## Non-negotiables

- **`create` is the ONLY write verb of the plan/create pair, and it writes GitHub state.** `plan` writes only local scratch (the plan file + the needs-input report); `create` deploys that plan file to GitHub — ensures the labels, creates-or-adopts the milestone by exact title, opens each surviving issue, rewrites the slugs to real `#n`, PATCHes the Wave description, and routes the needs-input report. There is **no flag** — `create` *is* the write verb; nothing is argument-parsed.
- **Trusts the plan file's recorded verdict — no re-vet.** On the found path `create` does NOT re-dispatch the architect or the issue-author, and does NOT re-run the self-check gate (the reviewer). It deploys the recorded gate-surviving issue set and reports the recorded verdict line. The only path that runs the gate from `create` is the run-`plan`-first fallback (the plan file was absent).
- **NEVER creates parked or dropped issues.** Only the surviving (gate-clean / Advisory-only) issues recorded in the plan file are created. Parked issues (product-gap / needs-human-direction) are routed to the needs-input report; dropped dependents are omitted. Neither is ever opened on GitHub.
- **Create-or-adopt NEVER deletes.** The milestone is resolved by exact title — created if absent, adopted (and reopened if closed) if present. `create` never deletes a milestone or any of its issues, and never duplicates an existing same-title open issue (it reuses it by title).
- **Authors no code, opens no PRs, never touches branches.** Creating issues / a milestone / labels / one epic comment is NOT code, a PR, or a branch. The feeder reads code to ground decisions; it never edits a source file, creates a branch, or opens a PR. The GitHub writes are performed by the skill itself via `gh`, not by any dispatched agent.
- **Every dispatched agent stays read-only — only on the run-`plan`-first fallback.** On the found path `create` dispatches no agent at all (it deploys the recorded plan). On the absent path it runs `plan`, whose architect / issue-author / reviewer dispatches are all read-only against provided text (`skills/plan/SKILL.md` Non-negotiables). The agent-read-only invariant holds on both paths.
- **The driver handoff is build-kickoff only, gated three ways, and never crosses the release boundary (Step 4).** `create` offers the handoff **only** on a clean run (the `## Needs human input` pointer is "none" **AND** the self-check actually ran — a `SKIPPED(reviewer:false)` verdict is a Gate 1 fail, since its issues were never vetted) **and** only when `/milestone-driver:solve-milestone` resolves in this session (absent → silently skip, no prompt, no error). It invokes `/milestone-driver:solve-milestone "<exact milestone title>"` — which merges only to the integration branch; `develop → main` stays a manual human call. The handoff **never** auto-merges to a protected branch and never removes the release gate. `autoHandoff` (default `"prompt"`) governs prompt / auto / off; an unrecognized value is treated as the default `"prompt"`.
- **`create` closes by verifying the deploy covers the original brief (Step 3V) — always-on, non-blocking, never auto-fixing.** After the deploy loop (single-plan Step 3 / roadmap Step 1R) and before the optional Step-4 handoff, `create` reads back every deployed milestone + issue via `gh` (bash + PowerShell 7+ twins), dispatches the brief-coverage verifier (#156, `milestone-feeder:brief-coverage-verifier`) against the **original** brief — resolved in-session, else from the persisted copy bounded by the paired `## Original brief` … `## End original brief` markers (the roadmap manifest on a roadmap run, the plan file on a single-milestone run), which Step 3V reads **strictly between** the markers (graceful fallback to the next `## ` heading when no closing delimiter is present) so a brief carrying its own `## ` headings is read intact, else a non-blocking `original brief unavailable` notice (**never a fabricated brief**) — passing each target's content-or-`read-error` marker so #156 runs no `gh` read of its own. It routes the returned punch-list exactly like the needs-input report (epic → comment; file/inline → local git-invisible file + notice; empty → "nothing missed", route nothing). It is **best-effort**: it never blocks `create`'s completion, the Step-4 handoff, or any merge, never auto-fixes / edits / reopens / comments-to-fix any deployed issue or milestone, and skips with a non-blocking notice when nothing was deployed to read back or #156 is not installed.
- **A roadmap of N milestones deploys by LOOPING the unchanged per-plan deploy (Step 1R).** When `plan`'s roadmap flow left a roadmap manifest for this brief (`.milestone-feeder/roadmap-<slug>.md`), `create` deploys all N milestones in build order by running **Step 3 passes a–e unchanged** per milestone and recording each one's cross-milestone position as a single canonical `build order: milestone X of N` line in its description (idempotent — pass (d)'s REPLACE-form PATCH overwrites it, so the count never grows). The single-plan path is the **N=1** case and is byte-for-byte unchanged. Create-or-adopt is inherited per iteration: a mid-loop failure **stops and reports**, deletes nothing, and a re-run resumes (already-deployed milestones adopted by exact title, the rest deployed).
