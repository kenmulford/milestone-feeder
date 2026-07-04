# update's roadmap parent-reconcile pass, the relocated mechanics

This is the `update`-scoped reference holding the full mechanics of `update`'s Step 1R, the pass that keeps the roadmap's `md-epic` parent issue in sync on a re-plan (issue #247). `skills/update/SKILL.md` keeps a lean orchestration skeleton for this pass and points here on demand, the same progressive-disclosure split `create` already uses for its own heavy steps (`docs/create-deploy-sequence.md`). The numbered steps below (1 through 7) match `skills/update/SKILL.md` Step 1R's own numbered list one for one.

This pass reuses three of `create`'s already-built mechanics **by reference, unchanged**: the gather-every-milestone's-number step, the render-the-body step, and the resolve-or-create-the-parent step (all from #245, `docs/create-deploy-sequence.md` "Step 1R" -> "The md-epic parent-issue pass"), plus the whole sub-issue-linking pass (#246, same file, "The sub-issue-linking pass"). None of those four mechanics is re-authored here; each step below either points at one of them or documents the genuinely new logic this issue adds: the roadmap-manifest gate, the diff-gated body PATCH, and the removed-milestone detection.

## The gate

Derive `<slug>` exactly as `update`'s Step 1 does (`skills/update/SKILL.md` Step 1, the same slug-derivation rule `plan` and `create` use). Check for a roadmap manifest at `.milestone-feeder/roadmap-<slug>.md`.

| Resolution | Action |
|---|---|
| **Absent** | Single-plan path, UNCHANGED. Fall through to `update`'s Step 1 and run Steps 1 through 5 exactly as documented, byte-unchanged from today. Nothing below this table runs. |
| **Found** | This run reconciles the parent. Read the manifest (never regenerate it). Run steps 1 through 7 below, then report. |

## Preliminary: read the manifest's own prior receipt (new twin)

Before step 1 begins, read whatever the manifest already carries at its `Parent issue (GitHub): #<n>` header line (`docs/roadmap-manifest-format.md`). This is a plain, side-effect-free read, used only by step 4's diff-gate and step 5's removed-milestone detection below to decide whether a live parent body already exists to compare against. The actual resolve-or-create in step 3 independently re-examines this same line as its own first branch (#245's mechanic, reused whole in step 3), so this preliminary read never substitutes for that resolution; it only gates whether steps 4 and 5 apply.

```bash
# bash. parent_before is empty when the manifest carries no receipt yet (a brand-new roadmap,
# or one create hasn't deployed the parent for). #? strips an optional leading "#".
manifest=".milestone-feeder/roadmap-<slug>.md"
parent_before="$(grep -m1 '^Parent issue (GitHub):' "$manifest" 2>/dev/null | sed -E 's/^Parent issue \(GitHub\): *#?([0-9]+).*/\1/')"
```

```powershell
# PowerShell 7+. Same read; $parent_before is $null/empty when the line is absent.
$manifest = ".milestone-feeder/roadmap-<slug>.md"
$parent_before = (Get-Content -LiteralPath $manifest -ErrorAction SilentlyContinue |
      Select-String -Pattern '^Parent issue \(GitHub\): *#?(\d+)' |
      Select-Object -First 1).Matches.Groups[1].Value
```

A malformed or non-numeric value (a hand-edited manifest) simply fails to match, so `$parent_before` comes back empty, the same absent-means-absent guard `update`'s own Step 3.0 milestone-receipt read already uses (`skills/update/SKILL.md` Step 3.0).

## Step 1: gather every milestone's number (reused by reference, unchanged)

Reuse #245's step 2, "Gather every deployed milestone's number, in build order", exactly as written (`docs/create-deploy-sequence.md` "Step 1R" -> "The md-epic parent-issue pass" step 2): for each of the manifest's `## Milestones (in build order)` entries, read its own `Milestone number (GitHub): <n>` receipt from its recorded `Plan file:` path, falling back to the exact-title lookup when the receipt is absent. Accumulate the `numbers` array in build order.

**Failure semantics, inherited unchanged.** If both the receipt and the title lookup fail to resolve a number for some milestone (it was added to the roadmap re-plan but has not itself been independently deployed yet, via a separate `create`/`update` run against its own plan file), STOP this pass right here: report which milestone could not be resolved, and do not touch the parent issue at all. A milestone dropped from the CURRENT manifest is simply not iterated here at all (it no longer has an entry), so it never blocks this step; see step 5 for how its removal is detected and flagged instead.

## Step 2: render the body (reused by reference, unchanged)

Reuse #245's step 3, "Render the body", exactly as written (same file, same section): the manifest's reviewed `Parent intro:` line, then the ```` ```md-epic-order ```` fenced block with one `number: <n>` line per milestone gathered in step 1 above, in build order, built into a temp file to dodge the backtick hazards documented there. Call the resulting file `$bodyfile` (bash) / `$bodyFile` (PowerShell).

## Step 3: resolve or create the parent (reused by reference, unchanged)

Reuse #245's step 4, "Resolve the parent (create-or-adopt), then create it or REPLACE-PATCH it", exactly as written (same file, same section): receipt present, adopt directly; absent, an open `md-epic`-labeled issue with the exact `Parent title:` text, adopt that; no match, create. Capture the resolved/created number as `$parent`.

**The one exception to "`update` never creates."** `update`'s own Non-negotiables say it never creates a *milestone* (Step 3b: milestone-not-found is a terminal error). The parent issue is not a milestone; #245's own contract for it is create-or-adopt, and `update` reuses that contract whole. This is the one object `update` gains the ability to originate; it still never creates a milestone.

## Step 4: diff-gate the body write (new logic, the fix this issue's advisory called for)

`create`'s own pass (the "re-run rewrite" in #245's step 4) PATCHes the body unconditionally on every adopt, correct for a first-time deploy but wrong for a reconcile: an unconditional PATCH would fire on every single `update` run even when nothing about the roadmap changed, which contradicts the "idempotent re-run performs zero additional parent-reconcile writes" acceptance criterion. `update` therefore wraps the SAME REPLACE-form rewrite in a diff-gate:

| `$parent_before` (preliminary read, above) | Action |
|---|---|
| **Present** (the parent already existed before this run) | Fetch its live body, compare to step 2's freshly rendered body. Identical: write nothing, no PATCH, no diff shown, this run performed zero parent-body writes. Differ: PATCH with #245's same REPLACE-form `gh issue edit $parent --body-file $bodyfile` (reused by reference), then report that the body changed. |
| **Absent** (this run created the parent, or adopted it by title with no prior receipt) | Nothing to diff against; step 3's create/adopt already wrote the correct body. No separate PATCH follows. |

```bash
# bash. Only runs when $parent_before was present (preliminary read). $bodyfile is step 2's rendered file.
if [ -n "$parent_before" ]; then
  live_body="$(gh issue view "$parent" --json body --jq '.body')"
  rendered_body="$(cat "$bodyfile")"
  if [ "$live_body" = "$rendered_body" ]; then
    echo "update: parent #$parent already matches the current roadmap - no PATCH (diff-gated)"
  else
    gh issue edit "$parent" --body-file "$bodyfile"
    echo "update: parent #$parent's body PATCHed to the current build order"
  fi
fi
```

```powershell
# PowerShell 7+. Same diff-gate.
if ($parent_before) {
  $liveBody = (gh issue view $parent --json body --jq '.body') -join "`n"
  $renderedBody = (Get-Content -LiteralPath $bodyFile -Raw)
  if ($liveBody.TrimEnd() -eq $renderedBody.TrimEnd()) {
    Write-Output "update: parent #$parent already matches the current roadmap - no PATCH (diff-gated)"
  } else {
    gh issue edit $parent --body-file $bodyFile
    Write-Output "update: parent #$parent's body PATCHed to the current build order"
  }
}
```

Bash's `$(...)` command substitution already strips trailing newlines from both captures, so the comparison above is not tripped up by a trailing-newline difference between `gh`'s returned body and the locally rendered file; the PowerShell twin normalizes the same way with an explicit `.TrimEnd()` on both sides, since `Get-Content -Raw` preserves them.

## Step 5: detect a removed milestone (new logic)

Reuse the SAME `$live_body` / `$liveBody` fetched in step 4 (only meaningful when `$parent_before` was present; a brand-new parent has no prior state, so nothing can have been "removed" from it). Parse its OLD `number: <n>` lines (the block as it stood before this run) and diff them against step 1's freshly gathered `numbers` array.

```bash
# bash. old_numbers is this parent's PRIOR md-epic-order block; numbers is step 1's current set.
if [ -n "$parent_before" ]; then
  old_numbers=()
  while IFS= read -r n; do old_numbers+=("$n"); done < <(printf '%s\n' "$live_body" | grep -oE '^number: [0-9]+$' | grep -oE '[0-9]+')
  for n in "${old_numbers[@]}"; do
    found=0
    for m in "${numbers[@]}"; do [ "$n" = "$m" ] && found=1 && break; done
    if [ "$found" = "0" ]; then
      echo "update: milestone #$n was removed from the roadmap re-plan - its md-epic-order entry is dropped, its sub-issue links to #$parent are left in place (never unlinked), and it is never closed or deleted; flagged for your decision"
    fi
  done
fi
```

```powershell
# PowerShell 7+. Same diff.
if ($parent_before) {
  $oldNumbers = [regex]::Matches($liveBody, '(?m)^number: (\d+)$') | ForEach-Object { $_.Groups[1].Value }
  foreach ($n in $oldNumbers) {
    if ($numbers -notcontains $n) {
      Write-Output "update: milestone #$n was removed from the roadmap re-plan - its md-epic-order entry is dropped, its sub-issue links to #$parent are left in place (never unlinked), and it is never closed or deleted; flagged for your decision"
    }
  }
}
```

A removed milestone needs no other action: its entry is already absent from the freshly rendered block (step 2 renders from the current manifest only), and `update` issues no unlink call, no close call, and no delete call for it or its issues, ever. This mirrors `update`'s existing "On GitHub, NOT in plan" convention for a live object no longer in the plan (`skills/update/SKILL.md` Step 4's reconcile table, and its Non-negotiables' "NEVER closes, NEVER deletes" line): flag it in the report (below) and take no other action.

## Step 6: link the current milestones' issues as sub-issues of the parent (reused by reference, unchanged)

Reuse #246's ENTIRE linking pass, steps 1 through 5, exactly as written (`docs/create-deploy-sequence.md` "Step 1R" -> "The sub-issue-linking pass"): the once-per-parent already-linked fetch, the per-milestone Wave-ordered children, the nested-epic refusal, the per-child link plus re-assert, the 100-sub-issue cap warning, and the end-of-pass linked/failed/skipped report. Run it over the CURRENT manifest's milestones (step 1's gathered set), in build order, on every `update` run against this roadmap, not only when a milestone was added.

No new logic is needed to single out "the newly added milestone": #246's own step 1 (fetch the parent's already-linked sub-issues) and step 4a (skip a child already linked) make every already-linked milestone's issues a no-op automatically. A milestone genuinely new to the roadmap is the only one whose issues this actually links.

## Step 7: write the manifest receipt (reused by reference, unchanged)

Only on a genuinely new parent (step 3's create branch, `$parent_before` was absent AND no title match was found either). Reuse #245's step 5, the idempotent read-modify-write onto the roadmap manifest's `Parent issue (GitHub): #<n>` line, exactly as written (same file, same section).

## Report

Route through `update`'s existing Step 5 report mechanism (`skills/update/SKILL.md` Step 5), sourcing the "Source brief reference" from the roadmap manifest's own `Source brief:` header line (the same `inline` / `file:<path>` / `epic #<n>` shape a per-milestone plan file carries, `docs/roadmap-manifest-format.md`) instead of a plan file's. Summarize: the parent's number and whether it was created / adopted / left unchanged; whether the body PATCHed (step 4) or was already in sync; which milestones' issues were newly linked (step 6); and which milestones (if any) were flagged as removed (step 5), each marked with the same 🔴 flagged-for-your-decision convention `update` already uses.

## Failure semantics

Inherited unchanged from #245 and #246, no new failure handling is added: a `gh` error in the gather (step 1), the resolve-or-create (step 3), the diff-gated PATCH (step 4), or any per-child link (step 6) stops that step, reports what already completed and what remains, and deletes nothing. A re-run resumes safely: the gather retries receipt-then-title per milestone, the parent resolve retries receipt-then-title-then-create, the diff-gate re-compares fresh, and the linking pass's already-linked check means nothing already linked is re-attempted.

## How each acceptance criterion is met

| Criterion | Where it is satisfied |
|---|---|
| Reorder: block rewritten in place | Steps 1 to 4: the render (step 2) always reflects the manifest's CURRENT order; the diff-gate (step 4) PATCHes when the live body differs. |
| Added milestone: linked (reuses #246) | Step 6, run over the current milestone set every time; #246's own already-linked check does the rest. |
| Removed milestone: entry removed, links left, flagged, never deleted | Step 5 (detection and flag) plus step 2's render (the entry is simply not re-emitted). No unlink/close/delete call exists anywhere in this pass. |
| Single-milestone update byte-unchanged | "The gate" above: absent manifest, this whole pass never runs. |
| Idempotent re-run, zero additional parent-reconcile writes | Step 1 is read-only; step 4's diff-gate no-ops when the body matches; step 6's already-linked check no-ops per child; step 7 only fires on a genuinely new parent. |
| Failure path stops, reports, deletes nothing | "Failure semantics" above, inherited from #245/#246 unchanged. |
| No second definition | Steps 1, 2, 3, 6, and 7 all point at #245's/#246's existing mechanics by reference; only the gate, the preliminary receipt read, the diff-gate (step 4), and the removed-milestone detection (step 5) are new, and none of them re-authors a block-render, a parent create-or-adopt, or a sub-issue-linking mechanic. |
| bash + PowerShell 7+ twins | Every new form above (the preliminary read, steps 4 and 5) ships both. |

**Honest bound.** The removed-milestone detection (step 5) trusts the parent's live body to still carry the `md-epic-order` block this pass itself last wrote. If a human hand-edits the parent issue's body directly on GitHub between runs (deleting a `number:` line by hand, for instance), the next run reads that edited state as "removed" even though the roadmap manifest itself never dropped that milestone, and the diff-gate (step 4) would PATCH over the hand edit on the very next run that changes anything else. This is the same class of stated limitation `update`'s existing stable-title assumption already carries (`skills/update/SKILL.md` "## IDEMPOTENCY" -> "Honest bound"): edit the brief/plan (here, the roadmap), not the GitHub object directly.
