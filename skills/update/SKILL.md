---
name: update
description: This skill should be used when the user invokes "/milestone-feeder:update <brief>", or asks to "update the milestone", "my plan changed — sync it", or "reconcile my refreshed plan to the milestone". Refreshes the plan file for your brief (runs `plan` first if there isn't one yet), resolves the milestone by its exact title — and STOPS with a 🔴 error if no such milestone exists, because `update` re-deploys onto an existing milestone and never creates one (run `create` for that). Then it reconciles your plan onto the live milestone: creates any issue that's in the plan but missing on GitHub, patches any issue whose body has drifted (showing you the diff before it writes), adds any new dependency edge and re-renders the build order, and FLAGS — never closes — any live issue that's no longer in your plan. If nothing differs it's a no-op and says so. No flags. Authors no code; opens no PRs.
---

# update — reconcile a refreshed plan onto the existing milestone

Refresh the plan file `plan` wrote for this brief (by the same deterministic slug), resolve the existing milestone by its exact title, then **reconcile the plan onto that live milestone**: create the issues the plan has and GitHub doesn't, patch the issues whose bodies drifted (showing the diff first), add any new dependency edge and re-render the build-order description, and **flag** — never close — any live issue the plan no longer carries. This is the "my plan changed" verb: where `create` *deploys* a plan onto a fresh milestone, `update` *re-deploys* a refreshed plan onto one that already exists. It absorbs the old re-vet-in-place job **for free** — the plan going in is gate-clean (it came through `plan`'s self-check), so reconciling it repairs whatever drifted from spec (`docs/specs/v0.3.0-humanize-the-surface.md` §5).

`update` reconciles onto an **existing** milestone and **NEVER creates the milestone** — milestone-not-found is a 🔴 error-and-stop directing the user to `create` (the opposite of `create`'s "absent → create" branch; `docs/specs/v0.3.0-humanize-the-surface.md` §5). It **NEVER closes and NEVER deletes** — a live issue absent from the plan is flagged for the user's decision, never auto-closed (park, don't guess). The **plan file is the source of truth**: a live body is patched only when it differs, and the diff is shown before applying — never a silent clobber; to change an issue, change the brief/plan, not GitHub. **No flags** — `update` *is* a verb; there is nothing to argument-parse, and there is no `update`-specific preview mode (`plan` is the preview for the whole family — `docs/specs/v0.3.0-humanize-the-surface.md` §2: zero flags anywhere). It **reuses `create`'s write primitives by reference — no second definition** (the label-ensure block, the `env.t` quote-safe milestone resolve, `gh issue create`, `gh issue edit --body`, the `gh api PATCH` description form, and the slug→`#n` rewrite for newly-created issues); the only logic `update` adds is the reconcile / diff / flag step. Authors no code, opens no PRs, never touches branches; every dispatched agent — only on the run-`plan`-first fallback — stays read-only against provided text, and the `gh` writes are performed by the skill itself, so the agent-read-only invariant holds.

## Announce first

Say this to the user before doing any work:

> Standing by while I update the milestone. I'll refresh the plan file for your brief (running `plan` first if there isn't one yet), resolve the milestone by its exact title, then reconcile your plan onto the live milestone — creating any missing issue, patching any drifted body (I'll show you the diff before I write), adding any new dependency edge and re-rendering the build order, and flagging — never closing — any live issue your plan no longer carries. If the milestone is already in sync with the plan, this is a no-op — I'll say so and write nothing.

## Procedure

### Step 0 — Read config (best-effort)

Read `.milestone-config/feeder.json`. **Absent → invoke `milestone-feeder:setup`** (it bootstraps the profile, aligns the label taxonomy, and returns control), then continue — the user does not re-run the command (`skills/setup/SKILL.md` Phase 5). `update` reads the same own-keys as `plan` (`projectDocs`, `reviewer`, `architectAgent`, `issueAuthorAgent`, `issueSize` — `skills/plan/SKILL.md` Step 0). On the **found** path `update` regenerates nothing (it reconciles the recorded plan against the live milestone), so it consumes **none** of these generation keys; the only path that consumes them is the run-`plan`-first fallback (Step 1), where `plan` itself reads them. The only configuration `update` itself needs is GitHub write access (the `gh` surface in Step 3 / Step 4).

### Step 1 — Resolve / refresh the plan file for the brief

Derive `<slug>` **deterministically** from the one-line milestone goal of the brief, using the **same derivation `plan` uses** (`skills/plan/SKILL.md:262`) and **the same Step 1 resolution `create` uses** (`skills/create/SKILL.md` Step 1): lowercase the goal, replace every run of non-alphanumeric characters with a single hyphen, strip any leading/trailing hyphen, and cap the length at the same bound (trimming a trailing hyphen if the cut lands on one). The same brief always resolves to the same path:

```
.milestone-feeder/plan-<slug>.md
```

Resolve the plan file at that path:

| Resolution | Action |
|---|---|
| **Found** | Read it; reconcile **exactly it** (the §3 plan-file contract, Step 2) against the live milestone (Step 3–4). No pipeline re-run, no re-vet — trust the recorded gate verdict. Proceed to Step 2. |
| **Absent** | Run `plan` **first** against the brief — the full pipeline + the self-check gate, which **writes** the plan file at this same path (`skills/plan/SKILL.md` Step 7). Then read the freshly-written plan file and reconcile it (Step 2). |

**Staleness (a changed brief earns a fresh plan) — identical to create.** The slug is a function of the brief's goal, so a **changed** brief derives a **different** slug → no match at the path above → the **Absent** row fires and `update` re-plans (faithful: you changed the brief, so you get a fresh plan). When the slug **matches an OLDER** plan file (the brief is unchanged since `plan` ran), `update` uses **that** file and prints a one-line notice:

> using existing plan file from <when> — re-run `plan` to refresh

This is the same staleness behavior `create` carries (`skills/create/SKILL.md` Step 1); there is no flag and no prompt.

### Step 2 — Read the plan-file contract

The plan file is the **load-bearing build artifact** — `update` reads it and reconciles GitHub against it, regenerating nothing (`docs/specs/v0.3.0-humanize-the-surface.md` §3). `update` parses the **SAME plan-file contract `create` parses** — the same fields, by name: see `skills/create/SKILL.md` Step 2 for the full per-field table (the format is `skills/plan/SKILL.md` Step 7; the field requirements are its plan-file-contract table and `docs/specs/v0.3.0-humanize-the-surface.md` §3). In brief, the fields `update` consumes are exactly create's:

- **Milestone title (exact)** — the load-bearing identity field `update` resolves the milestone by (Step 3); distinct from the descriptive one-line goal.
- **Milestone description (Wave order)** — the build-order description with **local slugs** (`#A`/`#B`), the render target the reconcile re-renders + PATCHes when an edge is added (Step 4).
- **Per surviving issue** — slug, title, the FULL §4 `ISSUE_BODY` verbatim, labels (`ui`|`logic` + `risk:*`), surface/risk: the issues to reconcile against the live milestone (Step 4), read verbatim — **no regeneration**.
- **Parked / dropped issues** — read from the bracketed marker on the `### #X — <title>` heading (`skills/create/SKILL.md` Step 2): marked, **NEVER created**, routed to the needs-input report (Step 5).
- **Self-check verdict** — the plan file's `Self-check:` line: `update` reports its recorded token and **trusts it — no re-vet** (`docs/specs/v0.3.0-humanize-the-surface.md` §5: the plan going in is gate-clean).
- **Source brief reference** — `inline` | `file:<path>` | `epic #<n>`: drives the report routing (Step 5); an `epic #<n>` reference is the `epicIssueNumber` for the epic-comment branch.

`update` does **not** re-derive any of these — it does not re-dispatch the architect, the issue-author, or the reviewer. It reads the recorded values and reconciles them onto the live milestone.

### Step 3 — Resolve the existing milestone by EXACT title

Resolve the milestone by the **exact** `Milestone title (exact)` line from the plan file (Step 2), against all existing milestones, using the **same `env.t` quote-safe resolve idiom from `skills/create/SKILL.md` Step 3 pass (b)** — do not re-derive or reprint it; reuse the cited form (the title is read from the environment via `env.t`, **never** string-interpolated into the jq filter — `gh api` has no `--arg`; bash and PowerShell 7+ forms are both given there). **One intentional delta:** `update`'s `--jq` `select` also returns `description` (it needs the live milestone description as the cross-issue context and as the Step 4 re-render target) — i.e. `--jq '.[] | select(.title==env.t) | {number, state, description}'`, otherwise identical to create pass (b).

The not-found branch is the **OPPOSITE of create** — `update` never creates the milestone:

| Result | Action |
|---|---|
| **No title match** | 🔴 **ERROR-AND-STOP.** `update` creates nothing — there is no milestone to update. Print `🔴 update: no milestone titled "<title>" — update re-deploys onto an EXISTING milestone and creates none. Run /milestone-feeder:create to create it first.` and **END the run.** This is a terminal stop, the inverse of create pass (b)'s "no match → create" branch (`docs/specs/v0.3.0-humanize-the-surface.md` §5 not-found line). |
| **Exactly one title match** (open or closed) | **Adopt** its `.number` and `.description` — re-use it, never delete it or its issues. `update` adopts the milestone **read-only**: unlike create pass (b), it does **NOT** reopen a closed milestone (reopening is a `gh` write outside update's reconcile write-set — create / patch / edge / description only), so the zero-write no-op contract holds even when the milestone is closed. `update` never CREATES or REOPENS the milestone — adoption is the only path that proceeds. |
| **Multiple title matches** (GitHub permits same-title milestones) | **Adopt the FIRST returned** (read-only — never reopened, even if closed), and log a notice — `update: multiple milestones titled "<title>" — adopted first returned (#<n>)` — mirroring create pass (b)'s recorded-ambiguity rule. Never touch the others. |

### Step 4 — Reconcile the plan file against the live milestone

This is `update`'s **defining step**. List the milestone's live OPEN issues and match each plan issue ↔ live issue **BY EXACT TITLE**, reusing create pass (c)'s list-and-match-by-title idiom by reference (`skills/create/SKILL.md` Step 3 pass (c)), with **one delta: `update` adds the `body` field** to the `--json` list (create pass (c) lists `number,title` only, since create never patches an adopted body — `update` needs the live `body` to diff it against the plan body):

```
gh issue list --milestone "<milestone-title>" --state open --json number,title,body
```

Then apply the reconcile, **announce-then-write each action** — exactly these five branches:

| Reconcile case | Action |
|---|---|
| **In plan, NOT on GitHub** (a plan issue whose title matches no live issue) | **CREATE it** — reuse create pass (c) `gh issue create --title "<title>" --body "<the plan's full §4 ISSUE_BODY, verbatim>" --milestone "<milestone-title>" --label <ui\|logic> --label <risk:*>` by reference, then the create pass (d) **slug→`#n` rewrite for the NEWLY-created issue's body** by reference (the substring-safe rule: descending slug-length order, token-boundary match — `skills/create/SKILL.md` Step 3 pass (d)). Apply the plan's labels exactly as recorded. **Announce the create.** |
| **In BOTH, body DIFFERS** (title matches a live issue, but the live `body` ≠ the plan body) | **PATCH to match the plan** — reuse the bare `gh issue edit <n> --body "<the plan body>"` invocation form from create pass (d) (`skills/create/SKILL.md` Step 3 pass (d)) — only the shell command is shared; `update` applies it to a **drifted existing body**, which create itself never patches (create preserves adopted bodies as-is, pass (c) body policy). This is the one reconcile action with no create analogue. **SHOW THE DIFF FIRST** (announce-then-write): print a unified-style diff of the live body → the plan body — only the changed hunks — **THEN** apply. **NEVER a silent clobber.** A body that is **byte-identical** to the plan is left **untouched** (no edit — this feeds the no-op). |
| **New dependency edge** (the plan's Wave order encodes an edge the live milestone description does not) | **ADD it** — absorb the edge into the graph, **re-render the build-order / Wave description** (reuse create pass (d)'s Wave-description render + its slug→`#n` substring-safe rewrite — descending slug-length order, token-boundary match — `skills/create/SKILL.md` Step 3 pass (d)), then **PATCH** the milestone description: reuse create pass (d)'s `gh api --method PATCH "repos/{owner}/{repo}/milestones/<number>" -f description=…` REPLACE form by reference (both bash and PowerShell 7+ given there). If **NO** edge is new, the description is left **byte-unchanged** (no PATCH). |
| **On GitHub, NOT in plan** (a live OPEN issue whose title matches no plan issue) | **🔴 FLAG for the user's decision** in the report (Step 5) — **NEVER close, NEVER delete.** Closing it is the user's call (park, don't guess) — state plainly that `update` will not auto-close it. |
| **Nothing differs** | **NO-OP** — perform **ZERO** `gh` writes (no label ensure, no issue create/edit, no milestone PATCH) and **SAY SO**: `update: milestone "<title>" already matches the plan — nothing to reconcile (no-op)`. |

**Ensure labels is GATED behind "at least one issue will be created or patched."** The four-label `gh label create … --force` block (create pass (a), `skills/create/SKILL.md` Step 3 pass (a)) is a GitHub write — reuse it by reference, do **not** redefine the four label lines — but it must **NOT** fire on a clean milestone. Gate it: run it only when the reconcile will create at least one issue OR patch at least one body. On a pure no-op (or a run whose only action is the flag of an extra live issue, which is report-only), no label is ensured — that is the no-op short-circuit, the same discipline the write sequence has always carried.

**Order the writes safely (the fixed order, mirroring create's pass sequence):**

1. **Ensure labels** — create pass (a), **only if** the reconcile will write at least one issue (create or patch).
2. **Create missing issues** + the slug→`#n` rewrite for each newly-created body — create pass (c) + (d).
3. **Patch differing bodies** — diff-then-write, one `gh issue edit --body` per drifted issue.
4. **PATCH the milestone description** — create pass (d), **only if** an edge was added at this step.

### Step 5 — Report (flag-list + summary)

Write a reconcile summary. The **on-GitHub-not-in-plan** flags go to a report the user reviews — route it exactly as create pass (e) routes its needs-input report (`skills/create/SKILL.md` Step 3 pass (e)), by the recorded **Source brief reference** (Step 2):

| Brief form (from the plan file's Source brief reference) | Where the report goes |
|---|---|
| **GitHub epic issue** (`epic #<n>` recorded) | Post the report as a **comment on the epic issue:** `gh issue comment <epicIssueNumber> --body "<report>"`. |
| **File path / inline text** (no epic) | Write the **local file** `.milestone-feeder/update-report-<slug>.md` and **PRINT a notice** that the report is local (no epic issue to comment on). |

The report carries the create pass (e) needs-input pointer (any parked / dropped issues recorded in the plan, routed as create routes them) **plus** `update`'s reconcile flags — the live OPEN issues the plan no longer carries, each marked 🔴 *flagged for your decision — `update` will not close it; closing is your call.*

**Summarize the run** (concise, table form): N created, M body-patched (with the diffs shown at Step 4), E edges added (description PATCHed yes/no), F flagged-for-your-decision — or, when nothing differed, the single no-op line.

## IDEMPOTENCY — the explicit contract

This is the keystone behavior. It holds by construction:

| Condition | Behavior |
|---|---|
| A live issue body **byte-identical** to the plan body | **Left UNTOUCHED** — no `gh issue edit`, no diff in the report. The per-issue compare (Step 4) decides this independently. |
| **Nothing differs** — every plan issue exists with a byte-identical body, the description encodes no new edge, and no live issue is unaccounted for | **NO-OP.** `update` writes **NOTHING** — no label ensure, no issue create/edit, no milestone PATCH — and **says so** (`update: milestone "<title>" already matches the plan — nothing to reconcile (no-op)`). |
| Re-running `update` on a milestone it just synced | A **no-op** by construction — the issues it created/patched now match the plan byte-for-byte, so they are left untouched; the description (already re-rendered) has no new edge, so no PATCH. |

**Honest bound (stable-title assumption).** The title↔title match (Step 4) relies on **stable, exact, OPEN titles** — the same constraint `create`'s adopt-match carries (`skills/create/SKILL.md` Step 3 pass (c)). If a plan issue's title was edited on GitHub between runs, the match misses and `update` would CREATE a (duplicate-looking) new issue and FLAG the renamed live one — the stated cost of editing a title on GitHub instead of in the brief/plan. Titles must stay stable for an idempotent re-run.

## Output style

Be concise — report status and outcomes flatly, no wall-of-text. Present steps, gates, lists, and options as **tables**, not inline prose. Mark anything that needs a human with 🔴. (Mirrors the agents' communication-style contract and `create`'s / `plan`'s output style.)

## Non-negotiables

- **Reconciles a refreshed plan onto an EXISTING milestone — milestone-not-found → ERROR-AND-STOP.** `update` resolves the milestone by exact title and **NEVER creates it**; a missing milestone is a 🔴 terminal stop directing the user to `/milestone-feeder:create` (creating the milestone is `create`'s job, not `update`'s).
- **NEVER closes, NEVER deletes.** A live issue absent from the plan is **flagged for the user's decision** in the report, never auto-closed or deleted (park, don't guess). `update` only creates missing issues, patches drifted bodies, adds edges, and PATCHes the description.
- **Plan file is the source of truth; announce-then-write.** A live body is patched **only when it differs**, and the **diff is shown before applying** — never a silent clobber. To change an issue, change the brief/plan, not GitHub. The plan going in is gate-clean (it came through `plan`'s self-check), so reconciling it inherently repairs drift.
- **Idempotent — nothing differs → zero writes, and `update` says so.** A byte-identical body is left untouched; a fully-synced milestone yields a true no-op (zero `gh` writes); re-running on an already-synced milestone is a no-op by construction.
- **Reuses `create`'s write primitives — no second definition.** The label-ensure block (`skills/create/SKILL.md` Step 3 pass (a)), the `env.t` quote-safe milestone resolve (pass (b)), `gh issue create` + the slug→`#n` rewrite (passes (c)/(d)), `gh issue edit --body` (pass (d)), the `gh api PATCH` description form (pass (d)), and the report routing (pass (e)) are all reused **by reference**. The only logic `update` adds is the reconcile / diff / flag step.
- **No flags, no aliases.** `update` is a verb; nothing is argument-parsed. There is no `update`-specific preview mode — `plan` is the preview for the whole family (`create` / `update` announce what they will write, then write).
- **Authors no code, opens no PRs, never touches branches.** Editing issues / a milestone description / labels / one epic comment is NOT code, a PR, or a branch. `update` reads code to ground decisions; it never edits a source file, creates a branch, or opens a PR. All `gh` writes are performed by the skill itself, not by any dispatched agent — the agent-read-only invariant holds (the only agent dispatch is on the run-`plan`-first fallback, where `plan`'s agents are read-only against provided text).
