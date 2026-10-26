---
name: update
description: This skill should be used when the user invokes "/milestone-feeder:update <brief>", or asks to "update the milestone", "my plan changed, sync it", or "reconcile my refreshed plan to the milestone". Reconciles your refreshed plan onto the existing milestone, creating any missing issue, patching any drifted body, and re-rendering the build order.
---

# update: reconcile a refreshed plan onto the existing milestone

Refresh the plan file `plan` wrote for this brief (by the same deterministic slug), resolve the existing milestone **by the deploy-receipt number `create` recorded, falling back to the exact title** when there is no receipt, then reconcile the plan onto that live milestone: create the issues the plan has and GitHub doesn't, patch the issues whose bodies drifted (showing the diff first), add any new dependency edge and re-render the build-order description, and flag any live issue the plan no longer carries. When the milestone was resolved by its recorded number and the plan's title has changed, `update` renames the milestone in place to the new title before reconciling (the single, bounded way `update` mutates a milestone's identity, Step 3). This is the "my plan changed" verb: where `create` *deploys* a plan onto a fresh milestone, `update` *re-deploys* a refreshed plan onto one that already exists. It absorbs the old re-vet-in-place job for free: the plan going in was drafted to pass the driver's triage clean, so reconciling it repairs whatever drifted from spec (`docs/specs/v0.3.0-humanize-the-surface.md` §5).

`update` reconciles onto an existing milestone and **never creates the milestone**: milestone-not-found is a 🔴 error-and-stop directing the user to `create` (the opposite of `create`'s "absent → create" branch; `docs/specs/v0.3.0-humanize-the-surface.md` §5). A live issue absent from the plan is flagged for the user's decision. The plan file is the source of truth: a live body is patched only when it differs, and the diff is shown before applying, never a silent clobber; to change an issue, change the brief/plan, not GitHub. No flags: `update` *is* a verb; there is nothing to argument-parse, and there is no `update`-specific preview mode (`plan` is the preview for the whole family, `docs/specs/v0.3.0-humanize-the-surface.md` §2: zero flags anywhere). It reuses `create`'s write primitives by reference, no second definition (the label-ensure block, the `env.t` quote-safe milestone resolve, `gh issue create --body-file`, `gh issue edit --body-file`, the `gh api PATCH` description form, and the slug→`#n` rewrite for newly-created issues); the logic `update` adds is the reconcile / diff / flag step plus the bounded title rename (Step 3a), itself no new primitive, just create's PATCH-milestone form composed with its `-f title=` field idiom. Authors no code, opens no PRs, never touches branches; every dispatched agent (only on the run-`plan`-first fallback) stays read-only against provided text, and the `gh` writes are performed by the skill itself, so the agent-read-only invariant holds.

## Announce first

Say this to the user before doing any work:

> Standing by while I update the milestone. I'll refresh the plan file for your brief (running `plan` first if there isn't one yet), find the milestone (by the milestone number `create` recorded in your plan file, or by its exact title if there's no recorded number) and, when I found it by that number and your plan's title has changed, rename the milestone in place to the new title. Then I'll reconcile your plan onto the live milestone: creating any missing issue, patching any drifted body (I'll show you the diff before I write), adding any new dependency edge and re-rendering the build order, and flagging any live issue your plan no longer carries. If the milestone is already in sync with the plan, this is a no-op: I'll say so and write nothing.

> **Roadmap re-plan found:** I found a roadmap manifest for this brief, so I'll also keep its shared parent issue in sync: re-render its build-order block, resolve or create it by its recorded receipt, link any newly added milestone's issues to it as sub-issues, and flag any milestone the re-plan dropped. If nothing about the parent changed since the last run, this is a no-op too.

## Procedure

### Step 0: Read config (best-effort)

Read `.milestone-config/feeder.json`. **Absent → invoke `milestone-feeder:setup`** (it bootstraps the profile, aligns the label taxonomy, and returns control), then continue: the user does not re-run the command (`skills/setup/SKILL.md` Phase 5). `update` reads the same own-keys as `plan` (`skills/plan/SKILL.md` Step 0: `projectDocs`, `architectAgent`, `issueAuthorAgent`, `issueSize`). On the found path `update` regenerates nothing (it reconciles the recorded plan against the live milestone), so it consumes none of these generation keys; the only path that consumes them is the run-`plan`-first fallback (Step 1), where `plan` itself reads them. The only configuration `update` itself needs is GitHub write access (the `gh` surface in Step 3 / Step 4).

**Run `update`'s one-time Step-0 notices.** From the repo root, run the notice emitter once: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/emit-notice.sh" update` on a host with bash, `pwsh -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/emit-notice.ps1" update` on a Windows host without one. It walks `scripts/emit-notice.json` in file order, selects every unit whose `skills` list names `update`, and for each performs the marker gate, the trigger check, the print, and the marker write in one step. Never re-type a notice as free-form agent text. What each unit says, when it fires, and why is recorded at `docs/one-time-notices.md (How each skill runs this file)`. Three units currently name `update`: the Implied-surfaces notice (marker shared with `plan`'s Step 0), the md-epic parent notice (marker shared with `create`'s Step 0), and the Remediate-verb notice (marker shared with `plan`'s Step 0). Each shows at most once per clone across its shared verbs. Every unit is best-effort and never aborts the `update` run; read-only except the `.runtime/` dir + marker (the Implied-surfaces unit never writes the overlay). A bash host without `jq` emits nothing; a missing script, an unusable data file, or a malformed unit is skipped for that entry only.

### Step 1R: Reconcile the roadmap's md-epic parent (roadmap re-plan only)

**One brief, or a roadmap re-plan.** Most runs reconcile one plan file against one milestone (Step 1 below). When the brief resolves to a roadmap (the same whole-app brief `build-roadmap` split into N milestones, `skills/build-roadmap/SKILL.md` "Manifest format"), `update` also keeps the roadmap's `md-epic` parent issue in sync with a re-plan. Each milestone in the roadmap is reconciled independently: run `update` against that milestone's own recorded `Plan file:`/brief, and Step 1 through Step 5 apply per milestone. The shared parent issue `create` produces on the roadmap path (`docs/create-deploy-sequence.md` "Step 1R") has its own reconcile pass, this step.

**Gate (mirrors `create`'s Step 1R).** Derive `<slug>` exactly as Step 1 does, then check for a roadmap manifest at `.milestone-feeder/roadmap-<slug>.md`. Absent: single-plan path, unchanged. Fall through to Step 1 and run Steps 1 through 5 as documented below. Found: this run reconciles the parent. Read the manifest (never regenerate it, `update` re-dispatches no agent here either) and run the pass below, then report (Step 5's routing, sourced from the manifest's own `Source brief:` line instead of a plan file's). This pass never also attempts a Step 1 through 5 reconcile of any one milestone's own issues in the same run; that stays a separate `update` invocation per milestone, unaffected.

**The pass, in order** (full mechanics, every `gh` form, both shells, live in `docs/update-reconcile-parent.md`). The five reused steps run through the `md-epic-parent` twin pair; the three this pass owns run through its own, `${CLAUDE_PLUGIN_ROOT}/scripts/update-reconcile-parent.{sh,ps1}`, resolved and selected exactly as `create`'s Step 1R resolves its twins (`skills/create/SKILL.md` Step 1R; on PowerShell, an entry point whose output is captured runs as a child process).

**Preliminary.** Read the manifest's own prior `Parent issue (GitHub): #<n>` receipt through the `update-reconcile-parent` twin pair's `read-receipt` entry point. It prints the number, or nothing when the manifest carries no well-formed receipt yet, and that presence or absence is what gates steps 3, 4, and 5 below.

1. Gather every manifest milestone's number, in build order. Reuses the `gather-numbers` entry point of the `md-epic-parent` twin pair by reference, unchanged (`docs/create-deploy-sequence.md` "Step 1R" → "The md-epic parent-issue pass" step 2). A milestone whose number cannot be resolved (never independently deployed yet) stops this pass right here: the same failure semantics that pass already documents, reused as-is. A milestone dropped from the current manifest simply has no entry to iterate, so it never blocks this step.
2. Render the parent's body fresh from the manifest's `Parent title:` / `Parent intro:` plus the gathered numbers. Reuses that twin pair's `render-body` entry point by reference, unchanged (same md-epic-order fence, same file-based assembly).
3. Resolve or create the parent by the manifest's `Parent issue (GitHub): #<n>` receipt (then a title match, then create). Reuses that twin pair's `resolve-or-create` entry point by reference, unchanged, and gated on the preliminary read: when it returned a number, adopt that number directly and call nothing here, leaving the body write to step 4's diff-gate (that entry point REPLACE-PATCHes on its adopt branch, which is right for a first-time deploy and would double-write on a reconcile); invoke it only when the preliminary read came back empty. Unlike a milestone, which `update` never creates (Step 3b), the parent issue is create-or-adopt, matching `create`'s own contract for it; this is the one write `update` newly gains the ability to originate.
4. Diff-gate the body write. When the preliminary read returned a number, invoke the `update-reconcile-parent` twin pair's `diff-gate` entry point over the parent, step 2's rendered body file, and a path for it to save the live body to: it fetches and saves that live body, compares, and PATCHes only when the two differ, printing the `compare` and `patch` rows this step reports from. `create`'s own pass PATCHes unconditionally every run; see the explicit `## IDEMPOTENCY` contract below. On a genuinely new parent (the preliminary read came back empty), do not invoke it: there is nothing to diff against, and the create/adopt in step 3 already wrote the correct body (`docs/update-reconcile-parent.md` "Step 4: diff-gate the body write").
5. Detect a removed milestone. When the preliminary read returned a number, invoke that twin pair's `detect-removed` entry point over the live body step 4 saved plus step 1's freshly gathered numbers: it prints one row per number the re-plan dropped. Each dropped milestone's `md-epic-order` entry is simply not re-emitted (step 2 already renders from the current manifest only), its sub-issue links to the parent are left in place, and it is flagged in this run's report, mirroring `update`'s existing "On GitHub, not in plan" convention (Step 4's reconcile table) for a live object no longer in the plan. On a brand-new parent, do not invoke it: there is no prior state, so nothing can have been removed (`docs/update-reconcile-parent.md` "Step 5: detect a removed milestone").
6. Link the current milestones' issues as sub-issues of the parent. Reuses the `md-epic-parent` pair's `link-sub-issues` entry point, the entire linking pass (the once-per-parent already-linked fetch, the per-milestone Wave-ordered children, the nested-epic refusal, the per-child link plus re-assert, the cap warning, the end-of-pass report), by reference, unchanged, run over the current manifest's milestones every time. Its own already-linked check makes this a no-op for every milestone whose issues were linked on a prior run; a newly added milestone's issues are the only ones this actually links. The rows it prints are turned into notices and the report by the same row table `create` follows.
7. Write the manifest receipt, only on a genuinely new parent (step 3's create branch). Reuses that same pair's `write-receipt` entry point by reference, unchanged.

**Failure semantics.** A `gh` error at any step stops that step, reports what completed and what remains, and deletes nothing; a re-run resumes via the same receipt / adopt-by-title / already-linked-check resolve (`docs/update-reconcile-parent.md` "Failure semantics"). No new resume machinery.

### Step 1: Resolve / refresh the plan file for the brief

Derive `<slug>` **deterministically** from the one-line milestone goal of the brief, using the same derivation `plan` uses (`skills/plan/SKILL.md` Step 7, the slug-derivation rule) and the same Step 1 resolution `create` uses (`skills/create/SKILL.md` Step 1): lowercase the goal, replace every run of non-alphanumeric characters with a single hyphen, strip any leading/trailing hyphen, and cap the length at the same bound (trimming a trailing hyphen if the cut lands on one). The same brief always resolves to the same path:

```
.milestone-feeder/plan-<slug>.md
```

Resolve the plan file at that path:

| Resolution | Action |
|---|---|
| **Found** | Read it; reconcile exactly it (the §3 plan-file contract, Step 2) against the live milestone (Step 3–4). No pipeline re-run, no re-vet: trust the recorded plan (no re-check). It is the plan you approved. Proceed to Step 2. |
| **Absent** | Run `plan` first against the brief: the full pipeline, which writes the plan file at this same path (`skills/plan/SKILL.md` Step 7). Then read the freshly-written plan file and reconcile it (Step 2). |

**Staleness (a changed brief earns a fresh plan), identical to create.** The slug is a function of the brief's goal, so a changed brief derives a different slug → no match at the path above → the Absent row fires and `update` re-plans (faithful: you changed the brief, so you get a fresh plan). When the slug matches an older plan file (the brief is unchanged since `plan` ran), `update` uses that file and prints a one-line notice:

> using existing plan file from <when>: re-run `plan` to refresh

This is the same staleness behavior `create` carries (`skills/create/SKILL.md` Step 1); there is no flag and no prompt.

### Step 2: Read the plan-file contract

The plan file is the load-bearing build artifact: `update` reads it and reconciles GitHub against it, regenerating nothing (`docs/specs/v0.3.0-humanize-the-surface.md` §3). `update` parses the **same plan-file contract `create` parses**, the same fields, by name: see the shared plan-file contract at `docs/plan-file-contract.md` for the full per-field table and output templates (`create` parses the same contract, `skills/create/SKILL.md` Step 2; the field-requirement grounding is `docs/specs/v0.3.0-humanize-the-surface.md` §3). In brief, the fields `update` consumes are exactly create's:

- Milestone title (exact): the load-bearing identity field `update` resolves the milestone by **on the title-fallback path, and compares against the live title on the receipt path** (Step 3); distinct from the descriptive one-line goal.
- Milestone description (Wave order): the build-order description with local slugs (`#A`/`#B`), the render target the reconcile re-renders + PATCHes when an edge is added (Step 4).
- Per surviving issue (slug, title, the full §4 `ISSUE_BODY` verbatim, labels (`ui`|`logic` + `risk:*`), surface/risk): the issues to reconcile against the live milestone (Step 4), read verbatim, **no regeneration**.
- Parked / dropped issues (read from the bracketed marker on the `### #X - <title>` heading; `skills/create/SKILL.md` Step 2): marked, **never created**, routed to the needs-input report (Step 5).
- **Source brief reference** (`inline` | `file:<path>` | `epic #<n>`): drives the report routing (Step 5); an `epic #<n>` reference is the `epicIssueNumber` for the epic-comment branch.

`update` does **not** re-derive any of these: it does not re-dispatch the architect or the issue-author. It reads the recorded values and reconciles them onto the live milestone.

### Step 3: Resolve the existing milestone (receipt-first, title fallback)

`update` resolves the milestone **by the deploy-receipt number first**, falling back to the exact-title resolve only when there is no receipt. The receipt is the `Milestone number (GitHub): <n>` line `create` writes into the plan file post-deploy (the write block and its field shape: `docs/create-deploy-sequence.md (Write the deploy receipt (the concluding action of pass b))`); `update` only reads it here: it never writes it (the write is `create`'s job, the carry-forward on re-plan is `plan`'s, Step 7).

#### 3.0: Read the deploy receipt from the plan file

Read the single labeled receipt line from the plan file Step 1 resolved (`.milestone-feeder/plan-<slug>.md`). Parse the one `Milestone number (GitHub): <n>` line (same field shape `create` writes, `docs/create-deploy-sequence.md (Write the deploy receipt (the concluding action of pass b))`); the line is optional: a v0.3.0 plan file, or one never deployed, lacks it and still parses (`docs/specs/v0.3.1-driver-handoff.md` §6: *"A v0.3.0 plan file lacking them still parses (the consumers degrade gracefully)"*). Extract `<n>` if present; absence is normal, not an error. The receipt counts as **present for branching only when `<n>` is a non-empty positive integer**; an empty or non-numeric value (e.g. a hand-edited `Milestone number (GitHub): abc`) is treated as absent and falls through to 3b (the title-fallback path), never routed to 3a, where `gh api .../milestones/abc` would error.

```bash
# bash: extract the receipt number if present; n is empty when absent (no error).
plan=".milestone-feeder/plan-<slug>.md"
n="$(grep -m1 '^Milestone number (GitHub):' "$plan" 2>/dev/null | sed 's/^Milestone number (GitHub): *//')"
```

```powershell
# PowerShell 7+: same read; $n is $null/empty when the line is absent (no error).
$plan = ".milestone-feeder/plan-<slug>.md"
$n = (Get-Content -LiteralPath $plan -ErrorAction SilentlyContinue |
      Select-String -Pattern '^Milestone number \(GitHub\): *(.+)$' |
      Select-Object -First 1).Matches.Groups[1].Value
```

**Branch on a valid receipt number** (present and a non-empty positive integer per the rule above: an empty or non-numeric `<n>` is treated as absent and falls through to 3b):

#### 3a: RECEIPT PRESENT → resolve by NUMBER (then a bounded rename if the title changed)

GET the milestone object directly by its number (`gh api "repos/{owner}/{repo}/milestones/<n>"`) and read `{number, state, description, title}` from it (the live `.title` is read here so it can be compared against the plan's title below). Adopt it read-only: like the title-resolve fallback (3b), `update` does **not** reopen a closed milestone (reopening is a `gh` write outside update's reconcile write-set: create / patch / edge / description only), so the zero-write no-op contract holds even when the milestone is closed. Resolving by the stable number hardens every receipt-present run (a non-rename run included) against a milestone whose title has since drifted.

```
# bash and PowerShell 7+ are identical: gh api is cross-platform; no variable interpolated into a jq filter.
gh api "repos/{owner}/{repo}/milestones/<n>"
```

Then **compare** the plan file's `Milestone title (exact)` line (the Milestone title (exact) row of `docs/plan-file-contract.md (## Plan-file field table)`) against the live `.title` from the GET:

| Receipt-present case | Action |
|---|---|
| **Titles differ → rename (the single identity write)** | PATCH the new title onto the milestone before the reconcile. The suite has no ready-made `PATCH .../milestones/<n> -f title=` form: compose it from `docs/create-deploy-sequence.md (b. Create-or-adopt the milestone)`, its Adopt + reopen PATCH form and its Create row's `-f title=` idiom. It must be quote-safe: hold the new title in a shell variable `t` quoted inside the `-f` value (titles may contain `"`), mirroring that section's quote-safe rationale. This is distinct from create's jq `env.t` *resolve* (the body at Step 3a spells out the difference). Never string-interpolate the title into the `-f` value. ANNOUNCE-THEN-WRITE: state the rename `old "<live title>" → new "<plan title>"` *before* applying it (the rename forms are below). This is the only way `update` mutates a milestone's identity, and it fires only here (resolved-by-number and titles differ), before Step 4's reconcile. |
| **Titles same → no title PATCH** | Write no identity PATCH. A same-title resolved-by-number run preserves the zero-write no-op contract for identity: there is nothing to rename, so the rename never fires. Proceed straight to Step 4 with the adopted `.number` and `.description`. |

The bounded rename forms (titles-differ case above), both shells. The new title is held in a shell variable `t` (set on its own line so the current shell, which has `$t`, expands it) and quoted inside the `-f` value, **never inlined as a literal** into the `-f` value. (This is a `-f "title=$t"` PATCH with no jq filter, distinct from the create-side `env.t` mechanism, which is jq syntax for the `--jq 'select(.title==env.t)'` *resolve*, not a PATCH.)

```bash
# bash: new title in a shell variable on its OWN line, so the shell (which has $t) expands it; the quoted -f value is space-safe (a title with an embedded double-quote must be escaped, same caveat as create's env.t idiom)
t="<plan title>"
gh api --method PATCH "repos/{owner}/{repo}/milestones/<n>" -f "title=$t"
```

```powershell
# PowerShell 7+: same form: set $env:t first, then PATCH (title never inlined into -f)
$env:t = "<plan title>"
gh api --method PATCH "repos/{owner}/{repo}/milestones/<n>" -f "title=$env:t"
```

Adopt the GET's `.number` and `.description` (after any rename above) and proceed to Step 4.

#### 3b: RECEIPT ABSENT → fall back to resolve by EXACT title (no rename)

When the plan file carries no receipt line, resolve by title, with **no rename on this path**. Resolve the milestone by the exact `Milestone title (exact)` line from the plan file (Step 2), against all existing milestones, using the same `env.t` quote-safe resolve idiom `docs/create-deploy-sequence.md (b. Create-or-adopt the milestone)` records, entry point `scripts/deploy-write-sequence.sh (find-milestone <title>)`: do not re-derive or reprint it; reuse the cited form (the title is read from the environment via `env.t`, never string-interpolated into the jq filter: `gh api` has no `--arg`). One intentional delta: `update`'s `--jq` `select` also returns `description` (it needs the live milestone description as the cross-issue context and as the Step 4 re-render target), i.e. `--jq '.[] | select(.title==env.t) | {number, state, description}'`, otherwise identical to create pass (b).

The not-found branch is the **opposite of create** (`update` never creates the milestone):

| Result | Action |
|---|---|
| **No title match** | 🔴 ERROR-and-STOP. `update` creates nothing: there is no milestone to update. Print `🔴 update: no milestone titled "<title>": update re-deploys onto an EXISTING milestone and creates none. Run /milestone-feeder:create to create it first.` and, since a missing receipt means `update` cannot rename in place, add the rename pointer for the case the user meant to rename an existing milestone rather than create a new one. Two bash commands, the title set in a shell variable on its own line first so `$t` is expanded by the shell that has it set (the quoted `-f` value is space-safe; an embedded double-quote must be escaped, same caveat as create's `env.t` idiom): `If you meant to RENAME an existing milestone, run: t="<plan title>" then gh api --method PATCH "repos/{owner}/{repo}/milestones/<the existing milestone number>" -f "title=$t"`. Look up `<the existing milestone number>` with the suite's paginated, all-state resolve idiom `gh api "repos/{owner}/{repo}/milestones?state=all&per_page=100" --paginate` (`docs/create-deploy-sequence.md (b. Create-or-adopt the milestone)`, entry point `scripts/deploy-write-sequence.sh (find-milestone <title>)`; a CLOSED or page-2+ milestone is found, which a bare default-`state=open` first-page list would miss), or on GitHub, since `update` resolved none here (same composed title-PATCH as 3a; PowerShell 7+: set `$env:t` first, then the same gh api call with `-f "title=$env:t"`). Then end the run: `update` still creates nothing. This is a terminal stop, the inverse of create pass (b)'s "no match → create" branch (`docs/specs/v0.3.0-humanize-the-surface.md` §5 not-found line). |
| **Exactly one title match** (open or closed) | Adopt its `.number` and `.description`: re-use it, never delete it or its issues. `update` adopts the milestone read-only: unlike create pass (b), it does not reopen a closed milestone (reopening is a `gh` write outside update's reconcile write-set: create / patch / edge / description only), so the zero-write no-op contract holds even when the milestone is closed. `update` never creates or reopens the milestone: adoption is the only path that proceeds. No rename on this path: renaming is the receipt-present (3a) path only. |
| **Multiple title matches** (GitHub permits same-title milestones) | Adopt the first returned (read-only, never reopened, even if closed), and log a notice (`update: multiple milestones titled "<title>", adopted first returned (#<n>)`), mirroring create pass (b)'s recorded-ambiguity rule. Never touch the others. |

### Step 4: Reconcile the plan file against the live milestone

This is `update`'s defining step. List the milestone's live OPEN issues and match each plan issue ↔ live issue **by exact title**, reusing create pass (c)'s list-and-match-by-title idiom by reference (`skills/create/SKILL.md` Step 3 pass (c)), with one delta: `update` adds the `body` field to the `--json` list (create pass (c) lists `number,title` only, since create never patches an adopted body; `update` needs the live `body` to diff it against the plan body):

```
gh issue list --milestone "<milestone-title>" --state open --json number,title,body
```

Then apply the reconcile, **announce-then-write each action**. Exactly these five branches:

| Reconcile case | Action |
|---|---|
| **In plan, not on GitHub** (a plan issue whose title matches no live issue) | Create it through `scripts/deploy-write-sequence.sh (create-issues <job-file>)`, which runs the `--body-file` create of `docs/create-deploy-sequence.md (or this is the create path)` (pass (c)). The job file holds `milestoneTitle` (the milestone's exact title), `"adopt": false` (Step 4 already matched the live issues by title, so `create-issues` lists nothing), and `issues`: only the plan issues missing from GitHub, each with `slug`, `title`, `bodyFile` (a `.milestone-feeder/` file holding the plan's full §4 ISSUE_BODY, verbatim) and `labels`. Build the map file as one `<slug><TAB><n><TAB>reused` row per matched live issue from Step 4, then append the `create-issues` output rows. Then run `scripts/deploy-write-sequence.sh (apply-bodies <job-file> <map-file>)`: it rewrites each `created` row's body from its `bodyFile` with the substring-safe slug→`#n` rule (`docs/create-deploy-sequence.md (d. Second pass: rewrite slug)`) and skips every `reused` row. Apply the plan's labels exactly as recorded, appending the `risk:*` label only when the plan records one (`docs/create-deploy-sequence.md` Absent-risk branch). Announce the create. |
| **In both, body differs** (title matches a live issue, but the live `body` ≠ the plan body after the slug rewrite) | PATCH to match the plan. The plan's `ISSUE_BODY` holds local slugs (`#A`) while a live body holds real `#n` after create pass (d), so compare and write the rewritten body, never the raw one. First complete the map: one `<slug><TAB><n><TAB>reused` row per matched live issue from Step 4, plus the `create-issues` output rows once the create row has run (the map the create row builds; it is needed even when nothing is created). Only with the map complete, for each matched issue write the plan body to one `.milestone-feeder/` file, rewrite it with `scripts/deploy-write-sequence.sh (rewrite-slugs <map-file> <text-file>)` into a second `.milestone-feeder/` file, and run `scripts/deploy-write-sequence.sh (apply-body <number> <body-file>)` on that rewritten file. It prints the unified diff of the live body → the rewritten body, then runs `gh issue edit <n> --body-file`, so the write is announce-then-write and never a silent clobber. `update` applies it to a drifted existing body, which create itself never patches (create preserves adopted bodies as-is, pass (c) body policy). This is the one reconcile action with no create analogue. A body equal to the rewritten plan body after normalizing line endings and trailing newlines is left untouched (`apply-body` prints `unchanged` and makes no edit: this feeds the no-op). |
| **New dependency edge** (the plan's Wave order encodes an edge the live milestone description does not) | Add it: absorb the edge into the graph, re-render the build-order / Wave description (reuse create pass (d)'s Wave-description render + its slug→`#n` substring-safe rewrite (descending slug-length order, token-boundary match); `skills/create/SKILL.md` Step 3 pass (d)), then PATCH the milestone description: reuse create pass (d)'s `gh api --method PATCH "repos/{owner}/{repo}/milestones/<number>" -f description=…` REPLACE form by reference (both bash and PowerShell 7+ given there). If no edge is new, the description is left byte-identical (no PATCH). |
| **On GitHub, not in plan** (a live OPEN issue whose title matches no plan issue) | 🔴 Flag for the user's decision in the report (Step 5); closing it is the user's call (park, don't guess). |
| **Nothing differs** | NO-OP: perform zero `gh` writes (no label ensure, no issue create/edit, no milestone PATCH) and say so: `update: milestone "<title>" already matches the plan: nothing to reconcile (no-op)`. |

**Ensure labels is gated behind "at least one issue will be created or patched."** The four-label `gh label create … --force` block (create pass (a), `skills/create/SKILL.md` Step 3 pass (a)) is a GitHub write (reuse it by reference, do not redefine the four label lines), but it must not fire on a clean milestone. Gate it: run it only when the reconcile will create at least one issue or patch at least one body. On a pure no-op (or a run whose only action is the flag of an extra live issue, which is report-only), no label is ensured: that is the no-op short-circuit, the same discipline the write sequence has always carried.

**Order the writes safely (the fixed order, mirroring create's pass sequence):**

1. Ensure labels: create pass (a), **only if** the reconcile will write at least one issue (create or patch).
2. **Create missing issues** + the slug→`#n` rewrite for each newly-created body: create pass (c) + (d).
3. **Patch differing bodies**: diff-then-write, one `scripts/deploy-write-sequence.sh (apply-body <number> <body-file>)` per drifted issue.
4. PATCH the milestone description: create pass (d), **only if** an edge was added at this step.

### Step 5: Report (flag-list + summary)

Write a reconcile summary. The **on-GitHub-not-in-plan** flags go to a report the user reviews. Route it exactly as create pass (e) routes its needs-input report (`skills/create/SKILL.md` Step 3 pass (e)), by the recorded Source brief reference (Step 2):

| Brief form (from the plan file's Source brief reference) | Where the report goes |
|---|---|
| **GitHub epic issue** (`epic #<n>` recorded) | Post the report as a comment on the epic issue: `gh issue comment <epicIssueNumber> --body-file <tmp>`, with `<tmp>` holding the report. |
| **File path / inline text** (no epic) | Write the local file `.milestone-feeder/update-report-<slug>.md` and print a notice that the report is local (no epic issue to comment on). |

Before writing the local report, ensure the scratch dir self-ignores (it normally already does: Step 1 resolved or wrote the plan file under `.milestone-feeder/`, and `plan` ensured `.milestone-feeder/.gitignore` contains `*`; `skills/plan/SKILL.md` Step 7): create `.milestone-feeder/` if absent and ensure `.milestone-feeder/.gitignore` contains a single `*` line, so the report is git-invisible in the consumer repo with zero user setup.

The report carries the create pass (e) needs-input pointer (any parked / dropped issues recorded in the plan, routed as create routes them) **plus** `update`'s reconcile flags: the live OPEN issues the plan no longer carries, each marked 🔴 *flagged for your decision: `update` will not close it; closing is your call.*

**Summarize the run** (concise, table form): N created, M body-patched (with the diffs shown at Step 4), E edges added (description PATCHed yes/no), F flagged-for-your-decision. When nothing differed, print the single no-op line instead.

## IDEMPOTENCY: the explicit contract

This is the keystone behavior. It holds by construction. It follows from the plan-file-is-source-of-truth layering (`.project/design-philosophy.md#Layering & boundaries`):

| Condition | Behavior |
|---|---|
| A live issue body equal to the rewritten plan body after normalizing line endings and trailing newlines | Left untouched: no `gh issue edit`, no diff in the report. The per-issue compare (Step 4) decides this independently. |
| **Resolved by receipt number, title unchanged** (the plan's `Milestone title (exact)` equals the live `.title`) | No identity PATCH: the rename never fires; the receipt-present same-title run is a no-op for identity (Step 3a). |
| **Resolved by receipt number, title changed** | The title PATCH is the single new identity write: it fires exactly once, before the reconcile (Step 3a), then the rest of the run reconciles as usual. A re-run after the rename resolves the same number and now finds the titles equal, so the rename does not fire again. |
| **Nothing differs**: every plan issue exists with a body equal to the rewritten plan body (line endings and trailing newlines normalized), the description encodes no new edge, no live issue is unaccounted for, and (when resolved by number) the title is unchanged | NO-OP. `update` writes nothing (no identity PATCH, no label ensure, no issue create/edit, no milestone-description PATCH) and says so (`update: milestone "<title>" already matches the plan: nothing to reconcile (no-op)`). |
| Re-running `update` on a milestone it just synced | A **no-op** by construction: the issues it created/patched now match the plan byte-for-byte, so they are left untouched; the description (already re-rendered) has no new edge, so no PATCH; and (receipt path) the title already equals the plan's, so no rename. |
| **Roadmap parent, live body byte-identical to the freshly rendered body** (Step 1R, step 4 of `docs/update-reconcile-parent.md`) | Left untouched: no `gh issue edit`, no PATCH. The diff-gate decides this independently of the per-issue body compare above; it is the same rule applied to the parent issue instead of a milestone issue. |
| **Roadmap parent, every current milestone's issues already linked as sub-issues** (Step 1R, step 6) | NO-OP for linking: the linking pass's own already-linked check (reused by reference, `docs/update-reconcile-parent.md` "Step 6: link the current milestones' issues as sub-issues of the parent") skips every child; nothing double-links. |
| Re-running `update` on a roadmap it just reconciled | A **no-op** by construction: the gathered milestone numbers are unchanged, so the freshly rendered body matches the live one (no PATCH); every milestone's issues are already linked (no re-link); and the manifest already carries the parent receipt (no re-create). |

Honest bound (stable-title assumption). The title↔title match (Step 4) relies on **stable, exact, OPEN titles** (the same constraint `create`'s adopt-match carries, `skills/create/SKILL.md` Step 3 pass (c)). If a plan issue's title was edited on GitHub between runs, the match misses and `update` would create a (duplicate-looking) new issue and flag the renamed live one (the stated cost of editing a title on GitHub instead of in the brief/plan). Titles must stay stable for an idempotent re-run.

**Honest bound (roadmap parent, hand-edited body).** The removed-milestone detection (`docs/update-reconcile-parent.md` step 5) trusts the parent's live body to still carry the `md-epic-order` block this pass itself last wrote. A human hand-edit of the parent issue's body on GitHub between runs is read as drift the same way a hand-edited milestone issue title is: the next run may flag a milestone as "removed" that the roadmap manifest never actually dropped, and the diff-gate would PATCH over the hand edit on the next run that changes anything else. Edit the roadmap (the brief/plan), not the GitHub object directly.

## Output style

Defined once at `docs/style-contracts.md#output-style`: read it there; it is not restated here.

**Plain English.** Write every response, document, and GitHub issue, milestone, comment, and PR body in plain, concise English. Never include hypothesis, conjecture, or defensive text.

## Non-negotiables

- **Reconciles a refreshed plan onto an existing milestone: milestone-not-found → ERROR-and-STOP.** `update` resolves the milestone by the deploy-receipt number `create` recorded (Step 3a), falling back to the exact title when there is no receipt (Step 3b), and never creates it; a missing milestone is a 🔴 terminal stop directing the user to `/milestone-feeder:create` (and, since a missing receipt means no in-place rename, carrying a one-line `gh` rename pointer for the rename-not-create case). Creating the milestone is `create`'s job, not `update`'s.
- **Bounded rename-in-place is the only way `update` mutates identity.** A title PATCH fires only on the receipt-present path when the plan's `Milestone title (exact)` differs from the live title (Step 3a); it is announced before it writes and applied before the reconcile. A same-title receipt-present run writes no identity PATCH (the no-op-for-identity contract holds), and the title-fallback path (3b) never renames.
- **never closes, never deletes.** A live issue absent from the plan is flagged for the user's decision in the report, never auto-closed or deleted (park, don't guess). `update` only creates missing issues, patches drifted bodies, adds edges, and PATCHes the description.
- **Plan file is the source of truth; announce-then-write.** A live body is patched only when it differs, and the diff is shown before applying, never a silent clobber. To change an issue, change the brief/plan, not GitHub. The plan going in was drafted to pass the driver's triage clean, so reconciling it inherently repairs drift.
- **Idempotent: nothing differs → zero writes, and `update` says so.** See the explicit `## IDEMPOTENCY` contract above.
- **Reuses `create`'s write primitives: no second definition.** The label-ensure block (`skills/create/SKILL.md` Step 3 pass (a)), the `env.t` quote-safe milestone resolve (`docs/create-deploy-sequence.md (b. Create-or-adopt the milestone)`), `gh issue create` (pass (c)) + the slug→`#n` rewrite (pass (d)), `scripts/deploy-write-sequence.sh (apply-body <number> <body-file>)` (the same entry point `skills/remediate/SKILL.md` Step 5 uses), the `gh api PATCH` description form (pass (d)), and the report routing (pass (e)) are all reused by reference. The one new write `update` adds beyond the reconcile / diff / flag step is the bounded title PATCH (Step 3a), and even that introduces no new primitive: it is composed from create's PATCH-milestone form (the Adopt + reopen row of `docs/create-deploy-sequence.md (b. Create-or-adopt the milestone)`) and its `-f title=` field idiom (the Create row of `docs/create-deploy-sequence.md (b. Create-or-adopt the milestone)`), with the new title held quote-safe in a shell variable `t` (quoted inside the `-f` value), mirroring create's quote-safe rationale (`docs/create-deploy-sequence.md (b. Create-or-adopt the milestone)`). That is distinct from create's jq `env.t` *resolve*.
- **No flags, no aliases.** `update` is a verb; nothing is argument-parsed. There is no `update`-specific preview mode: `plan` is the preview for the whole family (`create` / `update` announce what they will write, then write).
- **The roadmap's md-epic parent is reconciled on a re-plan, gated on a roadmap manifest (Step 1R).** When `.milestone-feeder/roadmap-<slug>.md` exists for the brief, `update` also reconciles the shared parent issue `create` produces on the roadmap path: it re-renders the `md-epic-order` block to the current build order, resolves or creates the parent by the manifest's `Parent issue (GitHub): #<n>` receipt (the one object `update` newly gains the ability to create; a milestone itself is still never created, Step 3b), links each milestone's issues to it as sub-issues, and flags any milestone the re-plan dropped. The parent-body PATCH is diff-gated against the live body: unchanged means zero writes (see the explicit `## IDEMPOTENCY` contract above). Absent manifest: this step never runs, and the single-plan path runs as documented above. Reuses `docs/update-reconcile-parent.md`'s mechanics by reference; authors no second definition of the block-render, the parent create-or-adopt, or the sub-issue-linking logic.
- **Authors no code, opens no PRs, never touches branches.** Editing issues / a milestone description / labels / one epic comment is not code, a PR, or a branch. `update` reads code to ground decisions; it never edits a source file, creates a branch, or opens a PR. All `gh` writes are performed by the skill itself, not by any dispatched agent: the agent-read-only invariant holds (the only agent dispatch is on the run-`plan`-first fallback, where `plan`'s agents are read-only against provided text).
