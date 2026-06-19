---
name: update
description: This skill should be used when the user invokes "/milestone-feeder:update <brief>", or asks to "update the milestone", "my plan changed — sync it", or "reconcile my refreshed plan to the milestone". Refreshes the plan file for your brief (runs `plan` first if there isn't one yet), then finds the milestone to update: it uses the milestone number `create` recorded in your plan file if that's there, and otherwise falls back to matching by the exact title — and STOPS with a 🔴 error if neither finds one, because `update` re-deploys onto an existing milestone and never creates one (run `create` for that). When it found the milestone by its recorded number and your plan's title has changed, it renames the milestone in place to the new title (the one way `update` changes a milestone's identity). Then it reconciles your plan onto the live milestone: creates any issue that's in the plan but missing on GitHub, patches any issue whose body has drifted (showing you the diff before it writes), adds any new dependency edge and re-renders the build order, and FLAGS — never closes — any live issue that's no longer in your plan. If nothing differs it's a no-op and says so. No flags. Authors no code; opens no PRs.
---

# update — reconcile a refreshed plan onto the existing milestone

Refresh the plan file `plan` wrote for this brief (by the same deterministic slug), resolve the existing milestone **by the deploy-receipt number `create` recorded — falling back to the exact title** when there is no receipt, then **reconcile the plan onto that live milestone**: create the issues the plan has and GitHub doesn't, patch the issues whose bodies drifted (showing the diff first), add any new dependency edge and re-render the build-order description, and **flag** — never close — any live issue the plan no longer carries. When the milestone was resolved by its recorded number and the plan's title has changed, `update` **renames the milestone in place to the new title** before reconciling — the single, bounded way `update` mutates a milestone's identity (Step 3). This is the "my plan changed" verb: where `create` *deploys* a plan onto a fresh milestone, `update` *re-deploys* a refreshed plan onto one that already exists. It absorbs the old re-vet-in-place job **for free** — the plan going in is gate-clean (it came through `plan`'s self-check), so reconciling it repairs whatever drifted from spec (`docs/specs/v0.3.0-humanize-the-surface.md` §5).

`update` reconciles onto an **existing** milestone and **NEVER creates the milestone** — milestone-not-found is a 🔴 error-and-stop directing the user to `create` (the opposite of `create`'s "absent → create" branch; `docs/specs/v0.3.0-humanize-the-surface.md` §5). It **NEVER closes and NEVER deletes** — a live issue absent from the plan is flagged for the user's decision, never auto-closed (park, don't guess). The **plan file is the source of truth**: a live body is patched only when it differs, and the diff is shown before applying — never a silent clobber; to change an issue, change the brief/plan, not GitHub. **No flags** — `update` *is* a verb; there is nothing to argument-parse, and there is no `update`-specific preview mode (`plan` is the preview for the whole family — `docs/specs/v0.3.0-humanize-the-surface.md` §2: zero flags anywhere). It **reuses `create`'s write primitives by reference — no second definition** (the label-ensure block, the `env.t` quote-safe milestone resolve, `gh issue create`, `gh issue edit --body`, the `gh api PATCH` description form, and the slug→`#n` rewrite for newly-created issues); the logic `update` adds is the reconcile / diff / flag step **plus the bounded title rename** (Step 3a) — itself no new primitive, just create's PATCH-milestone form composed with its `-f title=` field idiom. Authors no code, opens no PRs, never touches branches; every dispatched agent — only on the run-`plan`-first fallback — stays read-only against provided text, and the `gh` writes are performed by the skill itself, so the agent-read-only invariant holds.

## Announce first

Say this to the user before doing any work:

> Standing by while I update the milestone. I'll refresh the plan file for your brief (running `plan` first if there isn't one yet), find the milestone — by the milestone number `create` recorded in your plan file, or by its exact title if there's no recorded number — and, when I found it by that number and your plan's title has changed, rename the milestone in place to the new title. Then I'll reconcile your plan onto the live milestone — creating any missing issue, patching any drifted body (I'll show you the diff before I write), adding any new dependency edge and re-rendering the build order, and flagging — never closing — any live issue your plan no longer carries. If the milestone is already in sync with the plan, this is a no-op — I'll say so and write nothing.

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

- **Milestone title (exact)** — the load-bearing identity field `update` resolves the milestone by **on the title-fallback path, and compares against the live title on the receipt path** (Step 3); distinct from the descriptive one-line goal.
- **Milestone description (Wave order)** — the build-order description with **local slugs** (`#A`/`#B`), the render target the reconcile re-renders + PATCHes when an edge is added (Step 4).
- **Per surviving issue** — slug, title, the FULL §4 `ISSUE_BODY` verbatim, labels (`ui`|`logic` + `risk:*`), surface/risk: the issues to reconcile against the live milestone (Step 4), read verbatim — **no regeneration**.
- **Parked / dropped issues** — read from the bracketed marker on the `### #X — <title>` heading (`skills/create/SKILL.md` Step 2): marked, **NEVER created**, routed to the needs-input report (Step 5).
- **Self-check verdict** — the plan file's `Self-check:` line: `update` reports its recorded token and **trusts it — no re-vet** (`docs/specs/v0.3.0-humanize-the-surface.md` §5: the plan going in is gate-clean).
- **Source brief reference** — `inline` | `file:<path>` | `epic #<n>`: drives the report routing (Step 5); an `epic #<n>` reference is the `epicIssueNumber` for the epic-comment branch.

`update` does **not** re-derive any of these — it does not re-dispatch the architect, the issue-author, or the reviewer. It reads the recorded values and reconciles them onto the live milestone.

### Step 3 — Resolve the existing milestone (receipt-first, title fallback)

`update` resolves the milestone **by the deploy-receipt NUMBER first**, falling back to the exact-title resolve only when there is no receipt. The receipt is the `Milestone number (GitHub): <n>` line `create` writes into the plan file post-deploy (the create-side write block at `skills/create/SKILL.md:99-135`; the exact field shape at `skills/create/SKILL.md:104`); `#59` only **READS** it here — it never writes it (the write is `create`'s job, the carry-forward on re-plan is `plan`'s, Step 7).

#### 3.0 — Read the deploy receipt from the plan file

Read the single labeled receipt line from the **plan file Step 1 resolved** (`.milestone-feeder/plan-<slug>.md`). Parse the one `Milestone number (GitHub): <n>` line (same field shape `create` writes — `skills/create/SKILL.md:104`); the line is **optional** — a v0.3.0 plan file, or one never deployed, lacks it and still parses (`docs/specs/v0.3.1-driver-handoff.md` §6: *"A v0.3.0 plan file lacking them still parses (the consumers degrade gracefully)"*). Extract `<n>` if present; absence is normal, not an error. The receipt counts as **PRESENT for branching ONLY when `<n>` is a non-empty positive integer**; an empty or non-numeric value (e.g. a hand-edited `Milestone number (GitHub): abc`) is treated as **ABSENT** and falls through to 3b (the title-fallback path) — never routed to 3a, where `gh api .../milestones/abc` would error.

```bash
# bash — extract the receipt number if present; n is empty when absent (no error).
plan=".milestone-feeder/plan-<slug>.md"
n="$(grep -m1 '^Milestone number (GitHub):' "$plan" 2>/dev/null | sed 's/^Milestone number (GitHub): *//')"
```

```powershell
# PowerShell 7+ — same read; $n is $null/empty when the line is absent (no error).
$plan = ".milestone-feeder/plan-<slug>.md"
$n = (Get-Content -LiteralPath $plan -ErrorAction SilentlyContinue |
      Select-String -Pattern '^Milestone number \(GitHub\): *(.+)$' |
      Select-Object -First 1).Matches.Groups[1].Value
```

**BRANCH on a valid receipt number** (present AND a non-empty positive integer per the rule above — an empty or non-numeric `<n>` is treated as absent and falls through to 3b):

#### 3a — RECEIPT PRESENT → resolve by NUMBER (then a bounded rename if the title changed)

GET the milestone object directly by its number — `gh api "repos/{owner}/{repo}/milestones/<n>"` — and read `{number, state, description, title}` from it (the live `.title` is read here so it can be compared against the plan's title below). Adopt it **read-only**: like the title-resolve fallback (3b), `update` does **NOT** reopen a closed milestone (reopening is a `gh` write outside update's reconcile write-set — create / patch / edge / description only), so the zero-write no-op contract holds even when the milestone is closed. Resolving by the stable number hardens every receipt-present run — a non-rename run included (criterion a) — against a milestone whose title has since drifted.

```
# bash and PowerShell 7+ are identical — gh api is cross-platform; no variable interpolated into a jq filter.
gh api "repos/{owner}/{repo}/milestones/<n>"
```

Then **compare** the plan file's `Milestone title (exact)` line (`skills/plan/SKILL.md:331`; defined by the plan-file-contract row at `skills/plan/SKILL.md:295`) against the live `.title` from the GET:

| Receipt-present case | Action |
|---|---|
| **Titles DIFFER → RENAME (the single identity write)** | **PATCH the new title onto the milestone BEFORE the reconcile** (criterion b). Compose the PATCH from create's two cited idioms — there is **no** pre-existing `PATCH .../milestones/<n> -f title=` form in the suite; it is **composed** from the PATCH-milestone form (`skills/create/SKILL.md:96`) joined with the `-f title=` field idiom (`skills/create/SKILL.md:94`). It **MUST** be quote-safe: hold the new title in a **shell variable `t`** quoted inside the `-f` value (titles may contain `"`), mirroring create's quote-safe rationale (`skills/create/SKILL.md:82,86,90`) — distinct from create's jq `env.t` *resolve* (the body at Step 3a spells out the difference) — never string-interpolate the title into the `-f` value. **ANNOUNCE-THEN-WRITE:** state the rename `old "<live title>" → new "<plan title>"` *before* applying it (the rename forms are below). This is the **ONLY** way `update` mutates a milestone's identity, and it fires **only** here (resolved-by-number AND titles differ), **before** Step 4's reconcile. |
| **Titles SAME → NO title PATCH** | Write **no** identity PATCH (criterion c). A same-title resolved-by-number run **preserves the zero-write no-op contract for identity** — there is nothing to rename, so the rename never fires. Proceed straight to Step 4 with the adopted `.number` and `.description`. |

The bounded rename forms (titles-differ case above) — both shells. The new title is held in a **shell variable `t`** (set on its own line so the current shell, which has `$t`, expands it) and quoted inside the `-f` value — **never inlined as a literal** into the `-f` value. (This is a `-f "title=$t"` PATCH with no jq filter — distinct from the create-side `env.t` mechanism, which is jq syntax for the `--jq 'select(.title==env.t)'` *resolve*, not a PATCH.)

```bash
# bash — new title in a shell variable on its OWN line, so the shell (which has $t) expands it; the quoted -f value is space-safe (a title with an embedded double-quote must be escaped, same caveat as create's env.t idiom)
t="<plan title>"
gh api --method PATCH "repos/{owner}/{repo}/milestones/<n>" -f "title=$t"
```

```powershell
# PowerShell 7+ — same form: set $env:t first, then PATCH (title never inlined into -f)
$env:t = "<plan title>"
gh api --method PATCH "repos/{owner}/{repo}/milestones/<n>" -f "title=$env:t"
```

Adopt the GET's `.number` and `.description` (after any rename above) and proceed to Step 4.

#### 3b — RECEIPT ABSENT → fall back to resolve by EXACT title (the v0.3.0 path, byte-for-byte — no rename)

When the plan file carries **no** receipt line, resolve the milestone exactly as v0.3.0 did — **no rename on this path** (criterion d). Resolve the milestone by the **exact** `Milestone title (exact)` line from the plan file (Step 2), against all existing milestones, using the **same `env.t` quote-safe resolve idiom from `skills/create/SKILL.md` Step 3 pass (b)** — do not re-derive or reprint it; reuse the cited form (the title is read from the environment via `env.t`, **never** string-interpolated into the jq filter — `gh api` has no `--arg`; bash and PowerShell 7+ forms are both given there). **One intentional delta:** `update`'s `--jq` `select` also returns `description` (it needs the live milestone description as the cross-issue context and as the Step 4 re-render target) — i.e. `--jq '.[] | select(.title==env.t) | {number, state, description}'`, otherwise identical to create pass (b).

The not-found branch is the **OPPOSITE of create** — `update` never creates the milestone:

| Result | Action |
|---|---|
| **No title match** | 🔴 **ERROR-AND-STOP.** `update` creates nothing — there is no milestone to update. Print `🔴 update: no milestone titled "<title>" — update re-deploys onto an EXISTING milestone and creates none. Run /milestone-feeder:create to create it first.` **and**, since a missing receipt means `update` cannot rename in place, add the rename pointer for the case the user meant to rename an existing milestone rather than create a new one (criterion e) — two bash commands, the title set in a shell variable on its own line first so `$t` is expanded by the shell that has it set (the quoted `-f` value is space-safe; an embedded double-quote must be escaped, same caveat as create's `env.t` idiom): `If you meant to RENAME an existing milestone, run: t="<plan title>" then gh api --method PATCH "repos/{owner}/{repo}/milestones/<the existing milestone number>" -f "title=$t"` — look up `<the existing milestone number>` with the suite's paginated, all-state resolve idiom `gh api "repos/{owner}/{repo}/milestones?state=all&per_page=100" --paginate` (`skills/create/SKILL.md:86`) — so a CLOSED or page-2+ milestone is found, which a bare default-`state=open` first-page list would miss — or on GitHub, since `update` resolved none here (same composed title-PATCH as 3a; PowerShell 7+: set `$env:t` first, then the same gh api call with `-f "title=$env:t"`). Then **END the run** — `update` still creates nothing. This is a terminal stop, the inverse of create pass (b)'s "no match → create" branch (`docs/specs/v0.3.0-humanize-the-surface.md` §5 not-found line). |
| **Exactly one title match** (open or closed) | **Adopt** its `.number` and `.description` — re-use it, never delete it or its issues. `update` adopts the milestone **read-only**: unlike create pass (b), it does **NOT** reopen a closed milestone (reopening is a `gh` write outside update's reconcile write-set — create / patch / edge / description only), so the zero-write no-op contract holds even when the milestone is closed. `update` never CREATES or REOPENS the milestone — adoption is the only path that proceeds. **No rename on this path** — renaming is the receipt-present (3a) path only. |
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
| **Resolved by receipt number, title UNCHANGED** (the plan's `Milestone title (exact)` equals the live `.title`) | **NO identity PATCH** — the rename never fires; the receipt-present same-title run is a no-op for identity (Step 3a, criterion c). |
| **Resolved by receipt number, title CHANGED** | The title PATCH is the **single** new identity write — it fires exactly once, **before** the reconcile (Step 3a, criterion b), then the rest of the run reconciles as usual. A re-run after the rename resolves the same number and now finds the titles equal, so the rename does not fire again. |
| **Nothing differs** — every plan issue exists with a byte-identical body, the description encodes no new edge, no live issue is unaccounted for, and (when resolved by number) the title is unchanged | **NO-OP.** `update` writes **NOTHING** — no identity PATCH, no label ensure, no issue create/edit, no milestone-description PATCH — and **says so** (`update: milestone "<title>" already matches the plan — nothing to reconcile (no-op)`). |
| Re-running `update` on a milestone it just synced | A **no-op** by construction — the issues it created/patched now match the plan byte-for-byte, so they are left untouched; the description (already re-rendered) has no new edge, so no PATCH; and (receipt path) the title already equals the plan's, so no rename. |

**Honest bound (stable-title assumption).** The title↔title match (Step 4) relies on **stable, exact, OPEN titles** — the same constraint `create`'s adopt-match carries (`skills/create/SKILL.md` Step 3 pass (c)). If a plan issue's title was edited on GitHub between runs, the match misses and `update` would CREATE a (duplicate-looking) new issue and FLAG the renamed live one — the stated cost of editing a title on GitHub instead of in the brief/plan. Titles must stay stable for an idempotent re-run.

## Output style

Be concise — report status and outcomes flatly, no wall-of-text. Present steps, gates, lists, and options as **tables**, not inline prose. Mark anything that needs a human with 🔴. (Mirrors the agents' communication-style contract and `create`'s / `plan`'s output style.)

## Non-negotiables

- **Reconciles a refreshed plan onto an EXISTING milestone — milestone-not-found → ERROR-AND-STOP.** `update` resolves the milestone **by the deploy-receipt number `create` recorded (Step 3a), falling back to the exact title when there is no receipt (Step 3b)**, and **NEVER creates it**; a missing milestone is a 🔴 terminal stop directing the user to `/milestone-feeder:create` (and, since a missing receipt means no in-place rename, carrying a one-line `gh` rename pointer for the rename-not-create case) — creating the milestone is `create`'s job, not `update`'s.
- **Bounded rename-in-place is the ONLY way `update` mutates identity.** A title PATCH fires **only** on the receipt-present path when the plan's `Milestone title (exact)` differs from the live title (Step 3a); it is announced before it writes and applied **before** the reconcile. A same-title receipt-present run writes no identity PATCH (the no-op-for-identity contract holds), and the title-fallback path (3b) never renames.
- **NEVER closes, NEVER deletes.** A live issue absent from the plan is **flagged for the user's decision** in the report, never auto-closed or deleted (park, don't guess). `update` only creates missing issues, patches drifted bodies, adds edges, and PATCHes the description.
- **Plan file is the source of truth; announce-then-write.** A live body is patched **only when it differs**, and the **diff is shown before applying** — never a silent clobber. To change an issue, change the brief/plan, not GitHub. The plan going in is gate-clean (it came through `plan`'s self-check), so reconciling it inherently repairs drift.
- **Idempotent — nothing differs → zero writes, and `update` says so.** A byte-identical body is left untouched; a fully-synced milestone yields a true no-op (zero `gh` writes); re-running on an already-synced milestone is a no-op by construction.
- **Reuses `create`'s write primitives — no second definition.** The label-ensure block (`skills/create/SKILL.md` Step 3 pass (a)), the `env.t` quote-safe milestone resolve (pass (b)), `gh issue create` + the slug→`#n` rewrite (passes (c)/(d)), `gh issue edit --body` (pass (d)), the `gh api PATCH` description form (pass (d)), and the report routing (pass (e)) are all reused **by reference**. The one new write `update` adds beyond the reconcile / diff / flag step is the **bounded title PATCH (Step 3a)** — and even that introduces no new primitive: it is **composed** from create's PATCH-milestone form (`skills/create/SKILL.md:96`) and its `-f title=` field idiom (`skills/create/SKILL.md:94`), with the new title held quote-safe in a **shell variable `t`** (quoted inside the `-f` value) — mirroring create's quote-safe rationale (`skills/create/SKILL.md:82,86,90`), distinct from create's jq `env.t` *resolve*.
- **No flags, no aliases.** `update` is a verb; nothing is argument-parsed. There is no `update`-specific preview mode — `plan` is the preview for the whole family (`create` / `update` announce what they will write, then write).
- **Authors no code, opens no PRs, never touches branches.** Editing issues / a milestone description / labels / one epic comment is NOT code, a PR, or a branch. `update` reads code to ground decisions; it never edits a source file, creates a branch, or opens a PR. All `gh` writes are performed by the skill itself, not by any dispatched agent — the agent-read-only invariant holds (the only agent dispatch is on the run-`plan`-first fallback, where `plan`'s agents are read-only against provided text).
