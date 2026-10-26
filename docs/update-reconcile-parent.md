# update's roadmap parent-reconcile pass

This is the `update`-scoped reference holding the full mechanics of `update`'s Step 1R, the pass that keeps the roadmap's `md-epic` parent issue in sync on a re-plan (issue #247). `skills/update/SKILL.md` keeps a lean orchestration skeleton for this pass and points here on demand, the same progressive-disclosure split `create` already uses for its own heavy steps (`docs/create-deploy-sequence.md`). The numbered steps below (1 through 7) match `skills/update/SKILL.md` Step 1R's own numbered list one for one.

This pass reuses five of `create`'s already-built mechanics **by reference**, each an entry point of the `md-epic-parent` twin pair (`scripts/md-epic-parent.sh` / `.ps1`): the number gather, the body render, the parent resolve-or-create, and the manifest-receipt write (`docs/create-deploy-sequence.md` "Step 1R" -> "The md-epic parent-issue pass"), plus the whole sub-issue-linking pass (same file, "The sub-issue-linking pass"). None of those five mechanics is re-authored here. The three this pass owns (the preliminary receipt read, the diff-gated body PATCH, and the removed-milestone detection) are entry points of its own twin pair, `scripts/update-reconcile-parent.sh` / `.ps1`. What stays in this file is the judgment: the roadmap-manifest gate, which branch a run takes, the failure semantics, and the report formats.

## The gate

Derive `<slug>` exactly as `update`'s Step 1 does (`skills/update/SKILL.md` Step 1, the same slug-derivation rule `plan` and `create` use). Check for a roadmap manifest at `.milestone-feeder/roadmap-<slug>.md`.

| Resolution | Action |
|---|---|
| **Absent** | Single-plan path. Fall through to `update`'s Step 1 and run Steps 1 through 5; nothing below this table runs. |
| **Found** | This run reconciles the parent. Read the manifest (never regenerate it). Run steps 1 through 7 below, then report. |

## Invocation

One separately invokable entry point per owned mechanic, each with its exit statuses recorded in the twin's header. Resolve either twin pair at the plugin root, this repo's convention for bundled assets (`docs/step-0-grounding.md` "the plugin-root convention this repo uses for bundled assets"; `hooks/hooks.json`):

```
# bash
"${CLAUDE_PLUGIN_ROOT}/scripts/update-reconcile-parent.sh" <entry-point> [args]
# PowerShell 7+, when nothing is captured or redirected (see the note below)
& "$env:CLAUDE_PLUGIN_ROOT/scripts/update-reconcile-parent.ps1" <entry-point> [args]
```

**On PowerShell, an entry point whose output you capture or redirect runs as a child process, not through the call operator.** The twin writes its rows through `[Console]::Out`, which an in-session `&` call sends to the console, so the capture returns nothing: `read-receipt` would read empty and this pass would treat an already-deployed parent as brand new, skipping the diff-gate that keeps a re-run at zero writes. Same rule, same reason, as the sibling twin's (`docs/create-deploy-sequence.md` "Step 1R" -> "The md-epic parent-issue pass", its Invocation block):

```
# PowerShell 7+, whenever the output is captured or redirected
$parentBefore = pwsh -NoProfile -File "$env:CLAUDE_PLUGIN_ROOT/scripts/update-reconcile-parent.ps1" read-receipt "<manifest>"
```

| Step | Entry point | Arguments | Capture |
|---|---|---|---|
| **Preliminary** | `read-receipt` | `<manifest>` | the parent's prior number; nothing when the manifest carries no well-formed receipt |
| **4** | `diff-gate` | `<parent> <body-file> <live-body-file>` | `compare`TAB`same`\|`differ`, then `patch`TAB`skipped`\|`patched` |
| **5** | `detect-removed` | `<live-body-file> <number> [<number> ...]` | one `dropped`TAB`<number>` row per milestone the re-plan dropped; nothing when none was |

## Preliminary: read the manifest's own prior receipt

Before step 1 begins, read whatever the manifest already carries at its `Parent issue (GitHub): #<n>` header line (`docs/roadmap-manifest-format.md`): `read-receipt "<manifest>"`, captured as `$parent_before` (bash) / `$parentBefore` (PowerShell). A plain, side-effect-free read, and the sole gate on steps 3, 4, and 5: it says only whether a live parent body already exists to compare against. Step 3's `resolve-or-create` re-examines this same line as its own first branch, so this never substitutes for that resolution.

The capture is empty when there is no receipt yet (a brand-new roadmap, or one `create` has not deployed the parent for) and when the value is malformed (a hand-edited manifest), the same absent-means-absent guard `update`'s Step 3.0 milestone-receipt read uses (`skills/update/SKILL.md` Step 3.0).

## Step 1: gather every milestone's number

Reuse the twin pair's `gather-numbers` entry point, `create`'s own step 2, "Gather every deployed milestone's number, in build order", exactly as written (`docs/create-deploy-sequence.md` "Step 1R" -> "The md-epic parent-issue pass" step 2): for each manifest entry it reads that milestone's own `Milestone number (GitHub): <n>` receipt from its recorded `Plan file:` path, falling back to the exact-title lookup when the receipt is absent. Its output is the `numbers` array.

**Failure semantics.** If both the receipt and the title lookup fail to resolve a number for some milestone (it was added to the roadmap re-plan but has not itself been independently deployed yet, via a separate `create`/`update` run against its own plan file), stop this pass right here: report which milestone could not be resolved, and do not touch the parent issue at all. A milestone dropped from the current manifest is simply not iterated here at all (it no longer has an entry), so it never blocks this step; see step 5 for how its removal is detected and flagged instead.

## Step 2: render the body

Reuse the twin pair's `render-body` entry point, `create`'s own step 3, "Render the body", exactly as written (same file, same section): the manifest's reviewed `Parent intro:` line, then the ```` ```md-epic-order ```` fenced block with one `number: <n>` line per milestone gathered in step 1 above, in build order. Redirect its output into a temp file to dodge the backtick hazards documented there, through that section's Invocation block (on PowerShell the capture form is a child process, or the file lands empty), and call that file `$bodyfile` (bash) / `$bodyFile` (PowerShell).

## Step 3: resolve or create the parent

Reuse the twin pair's `resolve-or-create` entry point, `create`'s own step 4, "Resolve the parent (create-or-adopt), then create it or REPLACE-PATCH it", exactly as written (same file, same section): receipt present, adopt directly; absent, an open `md-epic`-labeled issue with the exact `Parent title:` text, adopt that; no match, create. Capture the resolved/created number as `$parent`, with the `created`/`adopted` field step 7 gates on.

**Gated on the preliminary read, because that entry point writes when it adopts.** `resolve-or-create` REPLACE-PATCHes the body on adopt, `create`'s contract for a first-time deploy but a double-write on a reconcile. So with `$parent_before` present, adopt that number directly as `$parent` and call nothing here: step 4's diff-gate owns the body write, keeping an unchanged roadmap at zero parent-reconcile writes. Invoke it only when `$parent_before` is absent, where its title-match adopt and its create branch each write the correct body.

**The one exception to "`update` never creates."** `update`'s own Non-negotiables say it never creates a *milestone* (Step 3b: milestone-not-found is a terminal error). The parent issue is not a milestone; `create`'s own contract for it is create-or-adopt, and `update` reuses that contract whole. This is the one object `update` gains the ability to originate; it still never creates a milestone.

## Step 4: diff-gate the body write

`create`'s own pass PATCHes the body unconditionally on every adopt (`docs/create-deploy-sequence.md` "Step 1R" -> "The md-epic parent-issue pass" step 4), correct for a first-time deploy but wrong for a reconcile: an unconditional PATCH would fire on every single `update` run even when nothing about the roadmap changed, which breaks the rule that an unchanged roadmap makes zero parent writes. `update` therefore wraps the same REPLACE-form rewrite in a diff-gate:

| `$parent_before` (preliminary read, above) | Action |
|---|---|
| **Present** (the parent already existed before this run) | Fetch its live body, compare to step 2's freshly rendered body. Identical: write nothing, no PATCH, no diff shown, this run performed zero parent-body writes. Differ: PATCH with that same REPLACE-form `gh issue edit --body-file` rewrite, then report that the body changed. |
| **Absent** (this run created the parent, or adopted it by title with no prior receipt) | Nothing to diff against; step 3's create/adopt already wrote the correct body. No separate PATCH follows. |

`diff-gate <parent> <body-file> <live-body-file>`, on the Present row only. `<body-file>` is step 2's rendered file; `<live-body-file>` is where the entry point saves the fetched live body, so step 5 reads the same bytes and this pass spends exactly one fetch. Its `compare` row prints before the PATCH is attempted, so a failed write still leaves the report the decision it has to name.

Both sides of the comparison, and the saved live body, have their carriage returns stripped and their trailing newlines removed, so the two twins compare and save identical bytes. A body differing from the render only in line endings therefore counts as unchanged and costs zero writes.

## Step 5: detect a removed milestone

Reuse the same live body step 4 fetched, through the file it saved (only meaningful when `$parent_before` was present; a brand-new parent has no prior state, so nothing can have been "removed" from it). `detect-removed <live-body-file> <number> [<number> ...]` parses that body's old `number: <n>` lines (the block as it stood before this run) and diffs them against step 1's freshly gathered numbers, passed in build order.

It prints one `dropped`TAB`<n>` row per number the old block carried that the current set no longer does, in the order the old block listed them, and nothing at all when none was dropped. Turning each row into the flagged line the report carries is the Report section below, never the twin's.

A removed milestone needs no other action: its entry is already absent from the freshly rendered block (step 2 renders from the current manifest only), and `update` issues no unlink call, no close call, and no delete call for it or its issues, ever. This mirrors `update`'s existing "On GitHub, not in plan" convention for a live object no longer in the plan (`skills/update/SKILL.md` Step 4's reconcile table, and its Non-negotiables' "never closes, never deletes" line): flag it in the report (below) and take no other action.

## Step 6: link the current milestones' issues as sub-issues of the parent

Reuse the twin pair's `link-sub-issues` entry point, the entire linking pass, exactly as written (`docs/create-deploy-sequence.md` "Step 1R" -> "The sub-issue-linking pass"): the once-per-parent already-linked fetch, the per-milestone Wave-ordered children, the nested-epic refusal, the per-child link plus re-assert, the 100-sub-issue cap warning, and the end-of-pass linked/failed/skipped report. Run it over the current manifest's milestones (step 1's gathered set), in build order, on every `update` run against this roadmap, not only when a milestone was added. It prints rows and decides nothing: that pass's row table maps them to notices and the report.

Singling out "the newly added milestone" takes no extra step: that pass's own once-per-parent fetch and its already-linked skip make every already-linked milestone's issues a no-op automatically. A milestone genuinely new to the roadmap is the only one whose issues this actually links.

## Step 7: write the manifest receipt

Only on a genuinely new parent (step 3's create branch, `$parent_before` was absent and no title match was found either). Reuse the twin pair's `write-receipt` entry point, `create`'s own step 5, the idempotent read-modify-write onto the roadmap manifest's `Parent issue (GitHub): #<n>` line, exactly as written (same file, same section).

## Report

Route through `update`'s existing Step 5 report mechanism (`skills/update/SKILL.md` Step 5), sourcing the "Source brief reference" from the roadmap manifest's own `Source brief:` header line (the same `inline` / `file:<path>` / `epic #<n>` shape a per-milestone plan file carries, `docs/roadmap-manifest-format.md`) instead of a plan file's. Summarize: the parent's number and whether it was created / adopted / left unchanged; whether the body PATCHed (step 4) or was already in sync; which milestones' issues were newly linked (step 6); and which milestones (if any) were flagged as removed (step 5), each marked with the same 🔴 flagged-for-your-decision convention `update` already uses.

## Failure semantics

No new failure handling is added: a `gh` error in the gather (step 1), the resolve-or-create (step 3), or the diff-gate's live-body read or PATCH (step 4) exits non-zero naming that call on stderr, and any per-child link failure (step 6) surfaces as a row; each stops that step, reports what already completed and what remains, and deletes nothing. A re-run resumes safely: the gather retries receipt-then-title per milestone, the parent resolve retries receipt-then-title-then-create, the diff-gate re-reads the receipt and re-compares fresh, and the linking pass's already-linked check means nothing already linked is re-attempted.

**Honest bound.** The removed-milestone detection (step 5) trusts the parent's live body to still carry the `md-epic-order` block this pass itself last wrote. If a human hand-edits the parent issue's body directly on GitHub between runs (deleting a `number:` line by hand, for instance), the next run reads that edited state as "removed" even though the roadmap manifest itself never dropped that milestone, and the diff-gate (step 4) would PATCH over the hand edit on the very next run that changes anything else. This is the same class of stated limitation `update`'s existing stable-title assumption already carries (`skills/update/SKILL.md` "## idempotency" -> "Honest bound"): edit the brief/plan (here, the roadmap), not the GitHub object directly.
