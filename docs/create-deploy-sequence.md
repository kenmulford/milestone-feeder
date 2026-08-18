# create deploy sequence: the relocated deploy mechanics

This is the create-scoped reference holding the **full mechanics** of `create`'s heavy deploy steps. The skill `skills/create/SKILL.md` keeps a lean orchestration skeleton (the step names, their fixed order, the gates, and one-level pointers) and `create` reads this reference **on demand** when it needs the mechanics. Each section below was relocated **byte-for-byte** from `skills/create/SKILL.md` (its Step 1R, the Step 3 write-sequence passes a–d, and Step 4), so **nothing here changes what `create` deploys**: the relocation is behavior-neutral. Read each section as the verbatim procedure for the step the skill names; `create`'s own pass (e) (the needs-input report) and its invariants stay in the skill.

- [Step 1R: Resolve the deploy target](#step-1r-resolve-the-deploy-target-a-single-plan-or-a-roadmap-of-n-milestones)
- [Step 3: deploy write-sequence (passes a-d)](#step-3-deploy-write-sequence-passes-a-d)
- [Step 3: pass f (mirror the milestone to Trello)](#step-3-pass-f-mirror-the-milestone-to-trello)
- [Step 4: Offer the driver handoff](#step-4-offer-the-driver-handoff-clean-run-only)

### Step 1R: Resolve the deploy target: a single plan, or a roadmap of N milestones

Before resolving a plan file, check whether `plan`'s roadmap flow left a **roadmap manifest** for this brief. Derive `<slug>` **exactly as Step 1 does** (the same deterministic rule, `skills/plan/SKILL.md` Step 7, the slug-derivation rule), then resolve the manifest at the path `build-roadmap` writes, the cross-milestone build artifact `create` deploys (`skills/build-roadmap/SKILL.md` "Manifest format"; `.project/design-philosophy.md#Layering & boundaries`, the plan file / manifest is the build artifact):

```
.milestone-feeder/roadmap-<slug>.md
```

| Resolution | Action |
|---|---|
| **Absent** (no manifest) | **Single-plan path: UNCHANGED.** Fall through to **Step 1** below and run **Steps 1 → 4 once, exactly as today**. This is the **N=1** case; the single-plan path sees zero behavior change. Skip the rest of this section. |
| **Found** (a manifest) | **Multi-milestone roadmap deploy.** Read the manifest and run the **outer loop** below. The manifest is **read, never regenerated**: `create` re-dispatches no agent and re-runs no gate on the found path, exactly as for a plan file (`SPEC.md` §3.1). Do **NOT** also run the single-plan Step 1 resolution for the whole brief: the roadmap replaces it. Each of its milestones has its own `plan-<slug>.md`, and there is no whole-brief plan file. |

**The outer loop (manifest found): loop the per-plan deploy over the manifest's milestones.** The manifest's `## Milestones (in build order)` section lists the milestones, each `### <position>. <milestone name>` with a `Build-order position: <position>` line **and a `Plan file:` path** (the exact plan-file handle the planning fan-out recorded, `skills/build-roadmap/SKILL.md` "Manifest format"; `docs/roadmap-fan-out.md` 3.7.g), in build order. Let **N** be that milestone count. Only the **outer loop** is added: the per-milestone deploy is **Step 3 passes a–e reused unchanged**. **For each milestone, in build order (position 1 → N):**

| Per-milestone step | What runs |
|---|---|
| **0. Consult the deploy checkpoint** | As its OWN first action (before anything else in this row), resolve `$planfile` (this milestone's `Plan file:` path at `position` `$X`) directly from the roadmap manifest; row i then reuses this SAME value (it is read only once, never re-read). Then read this milestone's checkpoint entry (keyed by `$X`) from `.milestone-feeder/deploy-state-<slug>.json`, when present and `jq`-readable. An entry reporting `pass == "d"` and `status == "complete"` earns ONE cheap existence check (a single `gh api .../milestones/<n>` GET, compared against the plan file's exact title and `state == "open"`); on a match, **skip only Step 3 passes (a)-(d)** (row iii's `gh`-heavy re-derivation, and row iv) for this milestone: **row ii (Step 2) and pass (e), the needs-input report routing, ALWAYS still run**, regardless of the checkpoint's verdict, before continuing the outer loop at position `X+1`. On a `gh` error, a title/state mismatch, or the file/entry/`jq` absent or unreadable, the checkpoint entry is untrustworthy: discard it and fall through to the existing, unchanged full per-milestone deploy (rows i-iv in full) for **this milestone only**. See "The deploy checkpoint" below. |
| **i. Resolve this milestone's plan file** | **Reuse the `$planfile` Row 0 already resolved** (it read the recorded `Plan file:` path from this manifest entry as its own first action, above: this row does not re-read it), the exact `.milestone-feeder/plan-<assignedSlug>.md` the planning fan-out populated (`skills/build-roadmap/SKILL.md` "Manifest format"; `docs/roadmap-fan-out.md` 3.7.g). **Do NOT re-derive a slug from the milestone name**: the plan-file slug is goal-derived with an `-m<index>` collision tiebreaker the manifest name does not encode (`docs/roadmap-fan-out.md` 3.7.d), so a name-derived path would miss. Read that plan file and treat it as Step 1's **Found** row, then deploy it. If the entry's `Plan file:` is **pending/empty**, or the file at that path is **absent** (this milestone never finished planning), STOP the loop and report it as a mid-loop failure (🔴, Partial-failure path below). Do **NOT** re-plan from `create`. |
| **ii. Read its plan-file contract** | **Step 2**, unchanged. |
| **iii. Deploy it** | **Step 3 passes a–e**, entirely unchanged: ensure labels (a) / create-or-adopt the milestone by exact title (b) / create-or-reuse each surviving issue by exact title (c) / slug→`#n` rewrite + Wave-description PATCH (d) / route the needs-input report (e). Per-milestone idempotency is the existing **create-or-adopt**, inherited per iteration: never delete a milestone or issue, never duplicate a same-title open issue. |
| **iv. Record the build-order line** | When pass (d) PATCHes this milestone's description, include the canonical `build order: milestone X of N` line in the PATCHed description, alongside the `## Waves` block (see "The build-order line" below). |

**The deploy checkpoint (resume short-circuit, roadmap-only).** Step 3 passes (a)-(d) below stay entirely unchanged and are reused, verbatim, for every milestone this checkpoint does not confirm; pass (e) (the needs-input report routing) always runs regardless of the checkpoint's verdict (see "On a match" below). This subsection adds only row **0** above, plus the read/write mechanics behind it: it does not alter what passes (a)-(e) do, or how the single-plan (N=1, no manifest) path behaves (that path never reaches Step 1R's outer loop, so it never reads or writes this file).

**Purpose: what it short-circuits.** Absent this checkpoint, resuming an N-milestone roadmap re-runs pass (b)'s **create-or-adopt-by-EXACT-title** lookup (below, "Create-or-adopt the milestone (by EXACT title)"), an exact-title `gh api` search against ALL existing milestones, for EVERY milestone, on EVERY run, whether or not that milestone already fully deployed. Pass (b) never reads back its own `Milestone number (GitHub):` receipt to shortcut this: that receipt is "the create-SIDE back-write only … not part of `create`" (below, pass (b)'s receipt-write section). So today, a resumed deploy pays pass (b)'s title lookup, plus passes (a)/(c)/(d)'s own `gh` calls, again for every already-fully-deployed milestone: correct, but pure API overhead on a large roadmap. This checkpoint lets a milestone it confirms is already fully deployed skip straight past Step 3 passes (a)-(d) with one cheap existence check instead; pass (e) (a cheap, local, non-`gh`-heavy step) ALWAYS still runs for every milestone regardless of the checkpoint's verdict, so its own retry-on-resume guarantee is never silently lost.

**File + identity.** `.milestone-feeder/deploy-state-<slug>.json`, `<slug>` derived by the identical rule the plan file and the roadmap manifest use (`skills/plan/SKILL.md` Step 7). Local, per-run scratch, covered by `.milestone-feeder/.gitignore`'s `*` (ensured by `plan`'s roadmap flow before this checkpoint is ever written; this checkpoint never creates that `.gitignore` itself).

**Schema.** One JSON object per file, keyed by `position` (the manifest's `Build-order position`, `$X` below):

```json
{
  "slug": "<slug>",
  "milestones": [
    {
      "position": 1,
      "planFile": ".milestone-feeder/plan-<assignedSlug>.md",
      "milestoneNumber": 42,
      "pass": "d",
      "status": "complete"
    }
  ]
}
```

`pass` is one of `"a"|"b"|"c"|"d"` (deliberately excludes `"e"`): pass (e), the needs-input report, is best-effort and conditional (it routes only when the plan file's `## Needs human input` pointer is not "none"), so it carries no deploy-completeness signal of its own. `pass == "d"` / `status == "complete"` IS the fully-deployed signal this checkpoint tracks (matches the happy-path acceptance criterion verbatim). `milestoneNumber` is `null` until pass (b) resolves it: before that, there is no number to record.

**Write timing (Correction 2, choice (a) picked).** The checkpoint entry is upserted TWICE per pass, for each of passes a-d, inside the SAME per-milestone iteration those passes already run: once at pass-START (`status: "in-progress"`, before that pass's own work begins) and once at pass-END (`status: "complete"`, once that pass's own work succeeds). Chosen over dropping `"in-progress"` from the schema (the alternative, simpler option) because it costs one extra call to the SAME upsert helper per pass (not a second code path) and it gives real crash-diagnosis value: a checkpoint left at, say, `pass: "c", status: "in-progress"` after a crash names exactly where the run died. The read-side check (below) is unchanged either way: it only ever looks for `pass == "d" && status == "complete"`.

**Upsert-by-position helper (never grows a duplicate entry): bash + PowerShell 7+ twins.** Mirrors this file's own idempotent-write idioms: the plan-file receipt's read-modify-write (below, "Write the deploy receipt") and the manifest's per-entry field overwrite keyed by a stable position (`skills/plan/SKILL.md` line ~266). Call this at each pass-start/pass-end site above, with `$pass`/`$status` set to that site's values. `$X` is this milestone's `Build-order position`; `$planfile` is its `Plan file:` path, Row 0 resolves it first (below) and every later row reuses that same value, never re-reading it; `$number` is this milestone's resolved GitHub milestone number (the same VALUE the outer loop's later passes track under their own local name `n`, above, "Gather every deployed milestone's number"; this new mechanism uses its own name, `number`, in its own scope, not a shared variable), empty until pass (b) resolves it:

```bash
# bash. Fail-open. No jq: silent no-op; a write error emits the notice below.
# Either way this returns WITHOUT aborting the deploy in progress.
"${CLAUDE_PLUGIN_ROOT}/scripts/roadmap-deploy.sh" checkpoint-upsert "<slug>" "$X" "$planfile" "$number" "$pass" "$status"
```

```powershell
# PowerShell 7+. Same upsert-by-position, same fail-open contract; native
# ConvertFrom-Json/ConvertTo-Json, no jq dependency.
& "$env:CLAUDE_PLUGIN_ROOT/scripts/roadmap-deploy.ps1" checkpoint-upsert "<slug>" $X $planfile $number $pass $status
```

The script holds the mechanics, once, for both twins: the fresh (re)seed of a 0-byte or absent state file (`-s`, not `-f`, so a corrupted-to-empty file is never silently accepted as valid content), the post-filter guard against overwriting the real file with an unexpectedly empty filter result, the `[int]` casts that keep `position`/`milestoneNumber` JSON numbers on the PowerShell path (a string-typed position would never match the bash reader's `--argjson x` numeric comparison, permanently defeating the short-circuit), and the one notice text, `create: could not persist the deploy checkpoint for milestone $X (pass $pass, $status), continuing without it`. An empty `$number` is recorded as JSON `null`. Exit status is 0 in every case.

**Row 0, the read + short-circuit check (Correction 3's exact shape): bash + PowerShell 7+ twins.** Runs BEFORE row i, for each milestone in build order, and resolves `$planfile` itself as its very first action, by reading this milestone's `Plan file:` line at `position` `$X` straight from the roadmap manifest (row i, row ii, and pass (e) then all reuse this SAME already-resolved value: it is read only once per milestone, never re-read). Once `$planfile` is in hand, read this milestone's checkpoint entry by `position` (`$X`); when it reports `pass == "d" && status == "complete"`, run ONE `gh api` GET against the live milestone and compare it to (a) the plan file's `Milestone title (exact):` line (exact string equality) and (b) `.state == "open"`: a 404/`gh` error, a title mismatch, or `state != "open"` are ALL "does not match" and fall through, consistent with pass (b)'s own title-compare precedent (below). The `gh` call captures **stdout only**: it never merges stderr into the stream being parsed as JSON, so an incidental stderr line on an otherwise-successful call can never masquerade as unparsable JSON and force a false negative. The checkpoint-recorded values read back for the trust test are named `cp_pass`/`cp_status`/`cp_number` (bash) / `$cpPass`/`$cpStatus`/`$cpNumber` (pwsh), deliberately NOT `pass`/`status`/`number`, so they never collide with the upsert helper's caller-supplied parameters of those same names:

```bash
# bash. Row 0: resolve $planfile, consult the checkpoint, then the one cheap
# existence check (Correction 3).
"${CLAUDE_PLUGIN_ROOT}/scripts/roadmap-deploy.sh" checkpoint-read "<slug>" "$X"
```

```powershell
# PowerShell 7+. Same resolve-then-check; native JSON, no jq dependency.
& "$env:CLAUDE_PLUGIN_ROOT/scripts/roadmap-deploy.ps1" checkpoint-read "<slug>" $X
```

Both twins print exactly three `key=value` lines, in this fixed order, and exit 0 in every case (a read that finds nothing is never an abort):

```
planfile=<this milestone's Plan file: path>
short_circuit=<0|1>
number=<the confirmed milestone number, empty whenever short_circuit is 0>
```

Read `planfile` into the caller's `$planfile`, `short_circuit` into `short_circuit` (bash) / `$shortCircuit` (pwsh), and, when it is 1, `number` into `number` (bash) / `$number` (pwsh). The script holds the mechanics, once, for both twins: the manifest scan for this position's `Plan file:` line, the `command -v jq` plus `-s "$state"` (bash) and file-length (pwsh) guards, the `cp_pass`/`cp_status`/`cp_number` trust test, and the `gh` GET captured as stdout only.

**On a match:** this milestone is confirmed fully deployed for Step 3 passes (a)-(d): skip those four passes (and row iv, the build-order line pass (d) produces) for this milestone, print a one-line notice (`create: milestone <X>, checkpoint confirms #<number> already deployed; skipping passes a-d`), then STILL run row ii (Step 2, read the plan-file contract) and pass (e) (the needs-input report routing) exactly as a full deploy would, before continuing the outer loop at position `X+1`. Row ii and pass (e) are cheap and local (no `gh`-heavy re-derivation), so running them for every milestone (checkpoint-confirmed or not) does not reintroduce the O(N) cost this checkpoint eliminates; it only preserves pass (e)'s own retry-on-resume guarantee, which a permanent skip would otherwise silently lose. **On no match** (any of: file/entry/`jq` absent or unreadable, `pass`/`status` not `"d"`/`"complete"`, the `gh` GET erroring, a title mismatch, or `state != "open"`): the checkpoint's claim for THIS milestone only is untrustworthy: discard it and fall through to the existing, unchanged full per-milestone deploy (rows i-iv in full) for this milestone. No other milestone's entry is touched or affected by one milestone's stale/absent entry.

**How each acceptance criterion is met.**

| Criterion | Where it is satisfied |
|---|---|
| Happy path (confirm 1..k with one cheap check: Step 3 passes a-d skipped, row ii + pass e still run for every milestone; full passes a-e only for k+1..N) | Row 0's match branch (above) plus the unchanged rows i-iv for every milestone the check doesn't confirm. |
| Empty/absent state (no `jq`, or file absent/empty → unchanged resume for every milestone) | Row 0's outer `command -v jq` / `[ -s "$state" ]` (bash) and `$stateHasContent` (pwsh) guards: when either is false, no read is attempted at all and every milestone falls straight through to the existing full per-milestone deploy, exactly as today. |
| Error/failure path (a stale-but-present entry never blocks or skips any OTHER milestone) | Row 0's per-milestone scoping: the checkpoint is read and checked once per milestone, inside that milestone's own per-milestone loop iteration; a mismatch discards only that milestone's own `entry`/`short_circuit` (bash) / `$entry`/`$shortCircuit` (pwsh) state. No state carries across milestones. |
| Disabled/edge state (a write failure is a notice, never an abort; N=1 path unaffected) | The upsert helper's fail-open `command -v jq` / try-catch guards (above): a write error is reported and the deploy continues. The single-plan path (Step 1R's Absent row) never reaches the outer loop at all, so it never reads or writes this file. |

**Accepted trade-off (Correction 4).** The cheap existence check verifies only the milestone RECORD (its title and open/closed state): it does not re-verify the milestone's issues. A milestone whose issue was manually deleted or renamed on GitHub between runs is NOT caught by this checkpoint path, unlike today's full pass (c), which re-lists and re-derives every issue's state on every run it actually executes. This is an accepted, deliberate trade-off: the whole point of this checkpoint is O(remaining) instead of O(N), and adding a full issue-level re-check to the checkpoint path would defeat that (it would just be pass (c) again, on every run). A milestone that drifts this way is only caught the next time its own checkpoint entry goes stale (e.g. because the milestone itself was closed or renamed) or on a full non-resumed deploy.

**Two more accepted trade-offs, same O(remaining) trade as Correction 4.** A confirmed milestone also loses two more of passes (b)/(d)'s self-healing retries, both accepted for the same reason: restoring either would mean re-running pass (b) or (d) in full, defeating the point.
- **The build-order-line / Waves self-heal is lost.** Pass (d)'s idempotent REPLACE-form PATCH is what repairs the milestone description (the `build order: milestone X of N` line, the `## Waves` block) on every unconfirmed re-run today. A confirmed milestone skips pass (d) entirely, so if a human or a bug corrupts or reverts that milestone's description on GitHub between runs, it is NOT restored as long as the checkpoint keeps matching (title + open state can both still be correct even with a mangled description): only a full non-resumed deploy, or a fallback triggered by a stale checkpoint entry, re-PATCHes and repairs it.
- **The plan-file receipt's self-healing retry is lost.** Pass (b)'s `Milestone number (GitHub): <n>` receipt write is best-effort/report-don't-block (below, "Write the deploy receipt"). Today, if it fails once, the very next resume re-runs pass (b) in full and its idempotent write retries and usually succeeds. A confirmed milestone never reaches pass (b) again, so a receipt that failed to write on the completing run stays permanently missing, impacting a later `update`'s ability to resolve this milestone after a title change (the receipt's documented purpose, `docs/specs/v0.3.1-driver-handoff.md` §4).

After the loop deploys all N, run **the md-epic parent-issue pass** below exactly once: it ensures the `md-epic` label, creates or adopts the roadmap's single parent issue, renders and PATCHes its `md-epic-order` body block, and writes the manifest's `Parent issue (GitHub): #<n>` receipt. Then report each milestone's deploy receipt (`#`), the recorded build order, and the parent issue's own `#`, and continue to **Step 4** (its multi-milestone note).

**The build-order line (the cross-milestone metadata).** Pin **one** canonical literal, `build order: milestone X of N`, where **X** is this milestone's `Build-order position` (1..N) and **N** is the manifest's milestone count. It extends the Wave-order-in-description convention (`SPEC.md` §4): the description already encodes the *intra*-milestone Wave order (`## Waves`); this single line encodes the *cross*-milestone position the driver reads to build the roadmap in sequence. Place it as a standalone line directly under the milestone goal and above the `## Waves` block, so milestone X's PATCHed description reads:

```markdown
<what this milestone delivers, and its scope boundary: both facts, at whatever length states them>

build order: milestone X of N

## Waves
- Wave 1 (parallel): #A, #B, ...
- ...
```

**Idempotency is INHERITED from pass (d), not re-implemented.** Pass (d) PATCHes the description with the **REPLACE form** (`gh api --method PATCH .../milestones/<number> -f description=...`, Step 3 pass d): it replaces the whole description every run. The build-order line rides **inside that one REPLACE payload**, so a re-run over an already-deployed manifest **overwrites** the line in place; the line count never grows (the same overwrite guarantee pass (d) already makes for the Wave order). **No new read-modify-write of the description is added**: only pass (d)'s payload gains the one canonical line. Assemble the augmented description (bash + PowerShell 7+ twins), then PATCH it with pass (d)'s existing REPLACE-form command:

```bash
# bash. Assemble milestone X's description (goal + the ONE canonical build-order
# line + the slug-rewritten Waves block), then apply pass (d)'s REPLACE-form
# PATCH. X = Build-order position; N = count. $goal and $waves are the two halves
# of the description pass (d) already builds (slugs rewritten to #n).
"${CLAUDE_PLUGIN_ROOT}/scripts/roadmap-deploy.sh" build-order-line "$X" "$N" "<number>" "$goal" "$waves"
```

```powershell
# PowerShell 7+. Same assembly, same REPLACE-form PATCH; the ONE canonical line.
& "$env:CLAUDE_PLUGIN_ROOT/scripts/roadmap-deploy.ps1" build-order-line $X $N "<number>" $goal $waves
```

This operation is the one that is NOT best-effort: it is pass (d)'s load-bearing description write, so it exits with `gh`'s own status and a non-zero takes the mid-loop failure path above.

Re-PATCHing on a re-run overwrites the line, idempotent by construction, so the `build order: milestone X of N` count stays exactly one per milestone, never growing.

**The md-epic parent-issue pass (Step 1R, roadmap-only, runs ONCE after the outer loop).** Once the outer loop above has deployed all N milestones (every milestone's own Step 3 passes a through e complete), `create` runs one more pass, exactly once per roadmap deploy, before continuing to Step 4. This pass produces the driver's cross-milestone parent issue: an ordinary GitHub issue, labeled `md-epic`, whose body carries the ordered list of milestone numbers `milestone-driver` v1.15.0 reads to build the roadmap in sequence (`docs/specs/v0.11.0-md-epic-parent-issue.md`, "The read-contract"). A roadmap manifest existing at all already implies N is at least 2 (above: the `Parent title:`/`Parent intro:` fields, and therefore the manifest itself, are written only for a confirmed multi-milestone split); the single-plan path (this section's Absent row) never reaches this pass, so an N=1 deploy stays byte-unchanged.

**Invocation.** Every `gh` call this pass and the sub-issue-linking pass below make, apart from step 1's one-line label ensure (which stays in this file, identical on both shells), is performed by the script twin **`scripts/md-epic-parent.sh` / `.ps1`**, one separately invokable entry point per step. Resolve the twin at the plugin root, this repo's convention for bundled assets (`docs/step-0-grounding.md` "the plugin-root convention this repo uses for bundled assets"; `hooks/hooks.json`):

```
# bash
"${CLAUDE_PLUGIN_ROOT}/scripts/md-epic-parent.sh" <entry-point> [args]
# PowerShell 7+, when nothing is captured or redirected (see the note below)
& "$env:CLAUDE_PLUGIN_ROOT/scripts/md-epic-parent.ps1" <entry-point> [args]
```

**On PowerShell, an entry point whose output you CAPTURE or REDIRECT runs as a CHILD PROCESS, not through the call operator.** The twin writes its rows through `[Console]::Out`, which an in-session `&` call sends straight to the console: the redirect then writes a ZERO-BYTE file and a `$(...)` capture returns nothing, which would hand `resolve-or-create` an EMPTY body file and REPLACE-PATCH the parent with it at exit 0. Use the child-process form, the same one the twin itself uses for its sibling call (`scripts/md-epic-parent.ps1`, its "Working directory" header note):

```
# PowerShell 7+, whenever the output is captured or redirected
pwsh -NoProfile -File "$env:CLAUDE_PLUGIN_ROOT/scripts/md-epic-parent.ps1" render-body "<intro>" <n> [<n> ...] > $bodyFile
```

This applies to `gather-numbers`, `render-body`, `resolve-or-create`, and `link-sub-issues`, whose captures the steps below consume; `write-receipt` prints only on failure, so either form shows its notice.

| Step | Entry point | Arguments | Capture |
|---|---|---|---|
| **2** | `gather-numbers` | `<manifest>` | one milestone number per line, in build order; NOTHING at all when any one of them could not be resolved |
| **3** | `render-body` | `<intro> <number> [<number> ...]` | the rendered body (redirect it into a file) |
| **4** | `resolve-or-create` | `<manifest> <parent-title> <body-file>` | `<number>`TAB`created`\|`adopted` |
| **5** | `write-receipt` | `<manifest> <number>` | the notice line, when it failed |
| **linking** | `link-sub-issues` | `<manifest> <parent> <number> [<number> ...]` | one row per outcome (the row table below) |

What stays here is the JUDGMENT: which row a run takes, what it logs, and what it reports. The twin carries no notice text, no warning text, and no report format of its own; each entry point's exit statuses are recorded once, in the twin's header.

Run these steps, in this fixed order:

**1. Ensure the `md-epic` label (mirrors pass a's flat upsert form, below).** Run this line before anything else in this pass touches an issue, so the later `--label "md-epic"` always resolves. `--force` upserts (creates if absent, updates color/description if present); re-runs never duplicate. Color and description are non-functional metadata, same as the four canonical labels; the label NAME is the only load-bearing part of the read-contract, exact and case-sensitive:

```
gh label create "md-epic" --color FBCA04 --description "Parent/epic grouping issue" --force
```

This line is identical on bash and PowerShell 7+ (same as pass a's four lines).

**2. Gather every deployed milestone's number, in build order.** The parent's body needs every milestone's real number before it can be rendered, whether the parent is about to be created or re-PATCHed, so gather them BEFORE touching the parent issue at all: this is what keeps a mid-pass failure from ever half-writing a parent body. `gather-numbers "<manifest>"` walks the manifest's `## Milestones (in build order)` entries in the order they appear (position 1..N) and reads each milestone's number:

| Source | Read |
|---|---|
| Primary | This entry's `Plan file:` path (the same path the outer loop's step i resolved), then that plan file's own `Milestone number (GitHub): <n>` receipt line (the receipt pass b writes, below). |
| Fallback (receipt line absent) | Pass b's receipt write is itself best-effort / report-don't-block, so a prior run may have deployed the milestone but failed to write its receipt. The number is re-resolved by an exact-title lookup against that same plan file's `Milestone title (exact):` line, through pass (b)'s OWN primitive in the write-sequence twin (`deploy-write-sequence.sh find-milestone <title>`), taking the first row's number: one definition of the quote-safe resolve, never two. |

If both the receipt and the title lookup fail to resolve a number for some milestone, the entry point prints nothing at all and exits non-zero naming that milestone, so a partial list can never be rendered into a parent body. STOP this pass right here (Failure semantics below): report which milestone could not be resolved, and do not touch the parent issue at all.

**3. Render the body.** `render-body "<parent intro>" <n> [<n> ...]`, with the manifest's reviewed `Parent intro:` line and every number step 2 printed, in build order; redirect the output into a temp file (on PowerShell through the child-process form above, or the file lands empty) and hand that path to step 4. The body is the intro verbatim, then the ordered block: an opening fence that is exactly three backticks immediately followed by `md-epic-order` (no leading or trailing space), one `number: <n>` line per milestone gathered in step 2, in build order, never `#<n>` (per the read-contract, `docs/specs/v0.11.0-md-epic-parent-issue.md`), closed by a line that is exactly a closing fence. The assembly lives in the twin, and never in an inline shell string, because a run of three backticks inside a double-quoted string is hazardous in BOTH shells: bash reads backticks as old-style command substitution (an embedded "command" actually runs), and PowerShell reads a backtick as its escape character, which silently eats two of the three (Microsoft Learn `about_Quoting_Rules`). The twin builds every fence line from a single-quoted string, where a backtick is literal in both shells.

**4. Resolve the parent (create-or-adopt), then create it or REPLACE-PATCH it.** `resolve-or-create "<manifest>" "<parent-title>" "<body-file>"` resolves in this order and captures `<number>`TAB`created`|`adopted`:

| Resolution | Action |
|---|---|
| **(a) The manifest already carries `Parent issue (GitHub): #<n>`** | Adopt `<n>` directly, no further lookup. |
| **(b) Absent, an OPEN issue carrying the `md-epic` label has the exact title of the manifest's `Parent title:`** (mirrors pass c's adopt-by-title de-dup, below) | Adopt that issue's number. This search is the parent pass's OWN, against the issues endpoint, quote-safe through the same `env.t` form pass (b) uses for milestones and for the same reason: a title holding a `"` would break an inlined jq filter and yield a spurious no-match. This safety net keeps the parent from ever duplicating even when a prior run created it but failed to write the receipt (step 5's write is itself best-effort, the identical risk pass b's receipt write carries). |
| **(c) No match** | Create it: `--title "<parent-title>" --body-file "<body-file>" --label "md-epic"`. No `--milestone` flag, no other label. The returned number is captured. |

**On adopt ((a) or (b)), the re-run rewrite (mirrors pass d's REPLACE-form PATCH, below):** the body from step 3 was already recomputed fresh from the current manifest and the current milestone numbers on this same run, so the entry point REPLACES the whole body. This is a full-body replace, never an append, so a re-run never leaves a second `md-epic-order` block. On create ((c) above), the body is already the freshly rendered one from step 3; no separate edit call is made. The captured row is printed BEFORE the replace, so a failed body write still leaves this pass the parent number its report has to name.

**5. Write the manifest receipt.** `write-receipt "<manifest>" "<number>"` writes `Parent issue (GitHub): #<n>` as a sibling header line on the roadmap manifest, using the same idempotent read-modify-write mechanic pass b already implements (below), extended with a two-tier anchor:

- **Present** → rewrite the number in place (exactly one line, never a duplicate).
- **Absent, `Parent intro:` present** → insert immediately after it.
- **Absent, `Parent intro:` also absent, `Build order:` present** → insert immediately after `Build order:` (a hand-edited manifest, or one written before `docs/roadmap-manifest-format.md` reserved `Parent intro:`).
- **Absent, neither anchor present** → degrade visibly: append at EOF (the present branch finds it on the next run).

Every branch acts on the FIRST match only, so a manifest carrying two receipt lines or two anchors still converges on exactly one receipt line and a re-run never grows the line count. On a write error the entry point prints the notice `create: deployed the md-epic parent #<n> but could not write the receipt to <manifest>; re-run to record it` and still exits 0: report it and continue.

**Failure semantics.** The label ensure, the parent resolve-or-create, and the body PATCH are load-bearing writes, not best-effort: a `gh` error in any of them STOPS this pass immediately. Report which step failed and what already succeeded (the label may already be ensured; the parent may already exist under a captured number), then stop; nothing is deleted. A re-run resumes safely: the label upsert is a no-op if it already ran, parent resolution retries receipt-then-title-match before ever creating a second issue, and the body PATCH is REPLACE-form, safe to reapply. Only the closing manifest-receipt write (step 5) is report-don't-block, mirroring pass b: by the time it runs, the parent issue itself already exists with its correct body, so a receipt-write failure is reported as a notice and the run continues; the next `create` re-derives the same number from the title-match fallback (step 4(b)) and rewrites the receipt.

**The sub-issue-linking pass (Step 1R, roadmap-only, runs ONCE immediately after the md-epic parent-issue pass, same run).** Once the parent issue exists (created or adopted at step 4 above, its number captured as `$parent`), `create` runs one further pass, exactly once per roadmap deploy, before continuing to Step 4: it links every deployed milestone's surviving issues to the parent as native GitHub sub-issues, in build order, then re-asserts each freshly linked child's own milestone. This satisfies the driver's read-contract Precondition, "Each milestone's issues are linked to it as native GitHub sub-issues" (`milestone-driver` design spec, "Precondition"), while keeping every child on its OWN milestone, never the parent's (the parent itself carries no milestone at all). The re-assert step is defense-in-depth, not load-bearing: the live probe run for this pass confirmed that linking an already-milestoned child under a milestone-less parent PRESERVES the child's own milestone. See "Re-assert timing" below for exactly when the re-assert call fires.

Order: milestone position 1 to N (the manifest's build order, the same `numbers` array the parent-issue pass's step 2 already gathered, reused here, not re-derived), then, within each milestone, its own Wave order (the same ordering pass (c) and pass (d) already used to deploy that milestone's issues).

**How it runs.** One call, `link-sub-issues "<manifest>" "$parent" <n> [<n> ...]`, passing the SAME numbers step 2 gathered, in build order, one per manifest entry. The entry point fetches the parent's already-linked sub-issues once for the whole pass, walks the milestones in build order and each milestone's children in Wave order, and prints one row per outcome. It decides nothing and prints no notice of its own: this skill turns the rows into the lines below and into the end-of-pass report (step 5).

| Row | When it prints | What `create` prints for it |
|---|---|---|
| `skip-pass`TAB`<error>` | The once-per-parent listing failed. No further row follows. | `create: could not list #$parent's existing sub-issues (<error>); skipping the sub-issue-linking pass this run. The deploy above already succeeded; re-run create/update to retry.` |
| `refused`TAB`<milestone>`TAB`<title>`TAB`<child>` | A child of that milestone already carries `md-epic`. Every child of it follows as `skipped ... nested-epic`. | `create: milestone #<milestone> ("<title>") skipped: sub-issue #<child> already carries md-epic (linking it would create a nested epic); no issue in this milestone was linked` |
| `linked`TAB`<child>` | Linked on this run, its own milestone re-asserted. | `create: linked #<child> as a sub-issue of #$parent and confirmed its milestone` |
| `failed`TAB`<child>`TAB`id-resolve`TAB`<error>` | The child's numeric id would not resolve; nothing was linked. | `create: sub-issue link failed for #<child>: could not resolve its numeric id (<error>)` |
| `failed`TAB`<child>`TAB`link`TAB`<error>` | The link call itself failed. | `create: sub-issue link failed for #<child> (<error>)` |
| `failed`TAB`<child>`TAB`reassert`TAB`<error>` | Linked, but the milestone re-assert failed. | `create: #<child> linked as a sub-issue of #$parent, but re-asserting its own milestone failed (<error>); check #<child>'s milestone by hand` |
| `skipped`TAB`<child>`TAB`already-linked` | The idempotency skip (step 4a below). | Nothing per child; it is recorded under "skipped" in step 5's report. |
| `skipped`TAB`<child>`TAB`cap` | The parent already holds 100 sub-issues (step 4b below). | Nothing per child; the one cap summary line in step 5. |
| `skipped`TAB`<child>`TAB`nested-epic` | Its milestone was refused above. | Nothing per child; the refusal warning already names the milestone. |
| `total`TAB`<count>` | Last row of any pass that ran. | Nothing on its own: it is the parent's resulting sub-issue total, which step 5's cap summary line names. |

**1. The once-per-parent sub-issue listing (fail-open, report-dont-block).** The parent's current sub-issues are listed before any child is touched, so every later idempotency check is a cheap in-memory lookup instead of a call per child, and the read is paginated: a parent can carry up to 100 sub-issues (the cap below, GitHub's documented limit) and the endpoint's default page size is 30, so it mirrors pass (b)'s `per_page=100 --paginate` milestone-list form exactly (confirmed live against `docs.github.com/en/rest/issues/sub-issues`: `per_page`, max 100, default 30). A failure here means `create` cannot safely tell what is already linked, not that nothing is linked; treating a failed fetch as "zero sub-issues" would risk mis-attempted re-links for children a prior run already linked. So a failure here **skips this whole pass, for this run only** (the `skip-pass` row above), goes straight to the end-of-pass report (step 5) naming every candidate child as "not attempted, listing failed", and **never aborts the already-succeeded deploy** (`.project/design-philosophy.md#Error & failure philosophy`, the same fail-open, non-blocking discipline every other best-effort read in this file already follows). Re-running `create`/`update` retries this listing call fresh.

**2. Per milestone: its title and its Wave-ordered surviving issue numbers.** The per-milestone `number` is the one passed in (the outer loop and the parent-issue pass's step 2 already resolved it; it is not re-derived). The milestone's exact title is not always already in hand and this pass always needs the title text itself for the `--milestone` re-assert flag below, so it is read fresh, once per milestone, from that milestone's plan file by the identical extraction step 2's fallback uses. Then this milestone's LIVE, already pass-(d)-PATCHed description is read (the same `gh api .../milestones/<number> --jq '.description'` read pass (f)'s Conv 6 back-link already uses, above) and every `#<n>` token is pulled out of it, in first-appearance order, deduped. A milestone description carries `#<n>` references only inside its `## Waves` block (the goal paragraph and the `build order: milestone X of N` line carry none), so this is exactly that milestone's surviving-issue list in Wave order, with no separate `## Waves` parsing needed.

**Empty milestone (AC2).** When a milestone's description yields no `#<n>` token at all (every candidate for this milestone parked or dropped, or this milestone's own plan produced no surviving issue), this milestone contributes nothing: it prints no row and the walk moves on to the next milestone. This needs no special-case code; an empty list simply drives zero iterations, and is not an error.

**3. Nested-epic refusal, before linking any of this milestone's issues.** If the parent already holds 100 sub-issues before this milestone starts (a prior milestone in this same pass already filled the cap, step 4 below), this check is skipped entirely and every one of this milestone's children goes straight to `skipped ... cap`; there is no reason to spend a `gh` call checking a label on an issue that will not be linked regardless. Otherwise each of this milestone's children is checked for the `md-epic` label, the same label-check form the driver's own parent-detection unit (U1) uses (`milestone-driver` design spec, "The 5 units" → "(U1) Parent detection": `gh issue view <n> --json labels`, exact match against `.labels[].name`). The FIRST child carrying the label refuses the WHOLE milestone: none of its issues are linked (each is recorded "skipped, nested-epic" in step 5's report), the one warning above names the milestone and the offending issue, and the pass continues with the remaining milestones (`milestone-driver` design spec, "Error handling & edge cases": no cycle detection, this refusal is the flag that spec asks the feeder to resolve). A milestone that clears this check (none of its issues carry `md-epic`) proceeds to step 4.

**4. Per child (Wave order), for a milestone that passed step 3.** In this fixed order, per child `$n`:

a. **Already linked?** If `$n` is already among the parent's sub-issues (step 1's fetch, or a number a prior child in this same run added below), it needs nothing further: it is recorded "already linked" in step 5's report and takes no other action, including no re-assert call (see "Re-assert timing" below). This is the pass's re-run no-op: nothing double-links, and an already-correct child is not touched again.

b. **Cap.** Otherwise, if the parent already holds 100 sub-issues, `$n` is not linked this run: it is recorded "skipped, cap" and the walk moves to the next child. The set only grows on a fresh successful link (step c below), so once it reaches 100 this same check keeps every later child, in every remaining milestone, on this same path with no further `gh` calls, in build order, until the pass ends.

c. **Otherwise, link it.** Three steps, each wrapped so a `gh` failure is caught, reported by this child's number and the error, and never silently marked linked; a failure at any of the three stops for THIS child only, and the pass continues with the next child: resolve the child's numeric id, POST it to the parent's `sub_issues` endpoint, then re-assert the child's own milestone. `-F` sends `sub_issue_id` as an integer (gh CLI's typed-field flag: `gh api --help`, "-F/--field has magic type conversion ... integer numbers get converted to appropriate JSON types"), and the endpoint needs the numeric database id, never the issue number (confirmed against `docs.github.com/en/rest/issues/sub-issues`, and live by this pass's own probe run).

**Re-assert timing (states the AC-versus-Design ordering plainly, so both agree).** The re-assert call fires in exactly one case: immediately after THIS run's own fresh link succeeds (step 4c above), the Design section's ordering, chosen because it rides the same per-child pass rather than adding a second, separate top-level sweep over every child on every run (the cheaper of the two readings). A child skipped at step 4a's idempotency check (already linked, whether from this run or an earlier one) gets no re-assert call: it is already correct, and the live probe confirmed that linking an already-milestoned child as a native sub-issue of a milestone-less parent keeps the child on its own milestone. So each surviving issue ends this run confirmed on its own milestone either because THIS run just linked and re-asserted it, or because an earlier run already did and this run correctly left it alone.

**A link that succeeds but whose re-assert fails (a named, known edge).** Reported under "failed" in step 5, never folded into "linked": the sub-issue link itself is real and will be found by a later run's step 1 listing, so a later run's step 4a will treat it as already linked and will not attempt the re-assert again automatically. Given the probe's confirmed-preserved finding this is a low-probability, defense-in-depth-only edge; when it happens, the report names the child so a human can re-assert its milestone by hand.

**5. End-of-pass report.** Whether the pass ran to completion, degraded at the cap, was refused for some milestones, or was skipped entirely (step 1's listing failure), report three lists, by child issue number: **linked** (this run: id resolved, link succeeded, re-assert succeeded), **failed** (with the reason: id-resolve error, link error, or link-succeeded-but-reassert-failed), and **skipped** (with the reason: already linked, cap, or nested-epic, naming the milestone for the nested-epic case). When any child was skipped for the cap, print exactly one summary line naming the parent's resulting sub-issue total (the `total` row) and the remaining issue numbers that were not linked, for example: `create: sub-issue cap reached on #$parent (100 total); not linked this run: #58, #61, #64`. Nothing is ever silently dropped from this report.

**How each acceptance criterion is met.**

| Criterion | Where it is satisfied |
|---|---|
| Every surviving issue linked, confirmed on its own milestone | Step 4c: link then re-assert, in build order (milestone position, then Wave order). |
| Empty milestone contributes nothing | Step 2's no-token case: zero iterations, no row, not an error. |
| Re-run is a no-op (no double-link) | Step 1's once-per-parent fetch plus step 4a's idempotency skip; no re-assert on an idempotent skip (see "Re-assert timing"). |
| Cap warn, never a silent drop | Step 4b's per-child gate plus step 5's single summary line naming the total and the not-linked numbers. |
| Nested-epic refusal | Step 3: whole-milestone skip on the first offending issue, one warning naming the milestone and the issue. |
| Per-child failure reported, never silently linked | Step 4c's catch-and-continue per child; step 5's linked/failed/skipped report. |
| bash + PowerShell 7+ twins | Every `gh` form above runs through the `md-epic-parent` twin pair, which ships both. |

### Step 3: deploy write-sequence (passes a-d)

The full mechanics of the deploy write-sequence passes **a, b, c, d**: the create-or-adopt resolution table, the deploy-receipt back-write, the slug→`#n` map, and the substring-safe rewrite rule. Every `gh` call these four passes make is performed by the script twin **`scripts/deploy-write-sequence.sh` / `.ps1`**, one separately invokable entry point per step (the invocation table below). What stays here is the JUDGMENT: which row a run takes, what it logs, and what it reports. Pass **e** (the needs-input report) stays in `skills/create/SKILL.md` Step 3. (`create`'s Step 3 skeleton names all five passes in fixed order and points here for a–d.)

This is the v0.2.0 apply write-sequence, moved wholesale into `create` and preserved verbatim. Only the **source** of the issue bodies / labels / waves / milestone title / source-brief reference changes: `create` reads them **from the plan file** (Step 2), it regenerates nothing (`docs/specs/v0.3.0-humanize-the-surface.md` §3: *"What changes is only the source of the issue bodies/labels/waves: read from the plan file, not regenerated"*; §4: the write sequence is *"unchanged"*). Every `gh` call below is run **by the skill itself**, through the script twin it invokes, never by a dispatched agent: the agent-read-only invariant holds. The twin ships as a bash and a PowerShell 7+ pair with identical behavior and one shared argv (`.project/library-manifest.md#Approved libraries (by purpose)`).

**Invocation.** Resolve the twin at the plugin root, this repo's convention for bundled assets (`docs/step-0-grounding.md` "the plugin-root convention this repo uses for bundled assets"; `hooks/hooks.json`):

```
# bash
"${CLAUDE_PLUGIN_ROOT}/scripts/deploy-write-sequence.sh" <entry-point> [args]
# PowerShell 7+
& "$env:CLAUDE_PLUGIN_ROOT/scripts/deploy-write-sequence.ps1" <entry-point> [args]
```

| Pass | Entry point | Arguments | Capture |
|---|---|---|---|
| **a** | `labels` | none | nothing |
| **b** | `find-milestone` | `<title>` | every match, one `<number>`TAB`<state>` row, in API order |
| **b** | `create-milestone` | `<title> <description-file>` | the new number |
| **b** | `reopen-milestone` | `<number>` | nothing |
| **b** | `write-receipt` | `<plan-file> <number>` | the notice line, when it failed |
| **c** | `create-issues` | `<job-file>` | the slug map, `<slug>`TAB`<n>`TAB`created`\|`reused` per issue |
| **d** | `rewrite-slugs` | `<map-file> <text-file>` | the rewritten text |
| **d** | `apply-bodies` | `<job-file> <map-file>` | `<slug>`TAB`<n>`TAB`edited`\|`unchanged` per created issue |
| **d** | `patch-description` | `<number> <map-file> <description-file>` | nothing |

**The job file** carries what Step 2 already parsed, so the plan-file contract keeps one reader: `milestoneTitle`, `adopt`, and one `issues` entry per **surviving** issue holding its `slug`, `title`, `bodyFile` (the §4 ISSUE_BODY verbatim, slugs intact) and `labels`. Write it and the body files under `.milestone-feeder/`, which already self-ignores. Every entry point's exit statuses and the job-file schema are recorded once, in the twin's header.

#### a. Ensure labels idempotently (BEFORE creating any issue)

Run `labels` **first**, so the labels exist before any `gh issue create --label` references them. It upserts the canonical four (the same taxonomy `setup` provisions, `skills/setup/SKILL.md`) with `gh label create … --force`, which creates a label if absent and updates its color/description if present: re-runs never duplicate. The four names, colors, and descriptions live in the twin, one list per shell, and the bash and PowerShell lists move together or not at all.

#### b. Create-or-adopt the milestone (by EXACT title)

Resolve the milestone by the **exact** `Milestone title (exact)` line from the plan file (Step 2), against all existing milestones: `find-milestone "<milestone-title>"`. It runs the paginated all-state milestones read and passes the title via an **environment variable** `t` that `gh`'s embedded jq reads as `env.t`, and it **NEVER string-interpolates the title into the jq filter literal**. `gh api` has **no `--arg` flag** (that belongs to standalone `jq`), and a title containing a `"` would break an inlined filter and yield a spurious no-match (→ a duplicate milestone). Reading `env.t` from the process environment is the portable, quote-safe approach, and it is identical on both twins. The entry point prints **every** match and picks none; the table below is what decides:

| Result | Action |
|---|---|
| **No title match** | **Create:** `gh api --method POST "repos/{owner}/{repo}/milestones" -f title="<milestone-title>" -f description="<placeholder>"`. Capture the returned `.number`. The description is a placeholder: it is rewritten with the real Wave order in pass (d), once the slug→`#n` numbers exist. |
| **Exactly one title match, `state: open`** | **Adopt:** record its `.number`. Re-use it; never delete it or its issues. |
| **Exactly one title match, `state: closed`** | **Adopt + reopen:** `gh api --method PATCH "repos/{owner}/{repo}/milestones/<number>" -f state=open`, then record its `.number`. **Never delete** the milestone or any of its issues. |
| **Multiple title matches** (GitHub permits same-title milestones) | **Adopt the FIRST returned**, reopen it if closed, and log a notice: `create: multiple milestones titled "<t>", adopted first returned (#<n>)`. Never delete the others. |

Each row's write is one entry point: **Create** is `create-milestone`, the reopen half of **Adopt + reopen** is `reopen-milestone`, and a plain **Adopt** writes nothing (the search already returned the number). The multiple-match notice is the caller's to log.

**Write the deploy receipt (the concluding action of pass b).** As soon as pass (b) has resolved the milestone `.number` (**any** outcome above: created / adopted-open / adopted-reopened / first-of-multiple), write that number back into the **same plan file Step 1 resolved** (`.milestone-feeder/plan-<slug>.md`, `skills/create/SKILL.md` Step 1) as a single labeled receipt field. This is the stable handle `update` will resolve by after a later title change (`docs/specs/v0.3.1-driver-handoff.md` §4 *"The deploy receipt — a stable handle for rename"*; the plan-file additive-fields row, §6: *"`Milestone number (GitHub):` `<n>` — the deploy receipt … `create` writes it post-deploy"*). The receipt is the create-SIDE back-write only: the `update`-side READ is a separate issue and is **not** part of `create`.

- **Field shape.** Exactly one labeled line, a **sibling to the plan file's existing header lines** (`Milestone title (exact):`, `Version provenance:`, `Source brief:` near the top, the format block at `skills/plan/SKILL.md` Step 7, "Plan-file format"):

  ```
  Milestone number (GitHub): <n>
  ```

- **Guard: write ONLY when a real number was resolved.** If pass (b) resolved **no** `.number` (it neither created nor adopted a milestone), write **nothing**: no receipt line, no placeholder. Prior absence of the line is normal: a first deploy has none, and a plan file that never receives a receipt stays valid and deployable (the field is additive; `docs/specs/v0.3.1-driver-handoff.md` §6: *"A v0.3.0 plan file lacking them still parses (the consumers degrade gracefully)"*).
- **Idempotent read-modify-write.** Read the plan file; if a `Milestone number (GitHub):` line **already exists**, **rewrite its number in place**, exactly one such line, **never** a duplicate; if it is **absent**, **insert** one (as a sibling header line). This is a read-modify-write that **converges to exactly one receipt line carrying the current number**, so it is safe to re-run: a second `create` on an already-adopted milestone rewrites the same line to the same number (no duplicate, no second insert). Unlike pass (d)'s no-op idempotency (where re-applying changes nothing), the receipt actively overwrites, but the line count never grows. (Re-running `create` is safe and produces no duplicates, the same guarantee pass (d) makes for issue bodies, `skills/create/SKILL.md` "Partial-failure path".) `write-receipt <plan-file> <number>` is idempotent by construction: the presence branch rewrites the existing line in place (exactly one), the anchor branch inserts exactly once after `Source brief:`, and a plan file carrying neither degrades VISIBLY by appending the line at EOF, where the presence branch finds it next run.
- **Failure semantics: report, don't block.** A plan-file back-write failure is **REPORTED as a notice but does NOT block**: by this point the GitHub deploy already succeeded (the milestone exists; pass c is about to create the issues), and the plan file is **gitignored per-run scratch** (`docs/specs/v0.3.1-driver-handoff.md` §4: *"The plan file is gitignored per-run scratch, so this back-write is low-stakes"*). The receipt rewrites the **existing** plan file in place, so the scratch dir already self-ignores (`plan` ensured `.milestone-feeder/.gitignore` contains `*` when it first wrote the plan; `skills/plan/SKILL.md` Step 7). The receipt write adds no new visible file. On a write error the entry point prints that notice (`create: deployed milestone #<n> but could not write the receipt to <plan>; re-run to record it`) and still exits 0, alone among the entry points here: surface the line and continue to pass (c). Never abort the deploy over the receipt.

#### c. Create each surviving issue; build the slug→`#n` map

Create **only the SURVIVING** issues recorded in the plan file's `## Issues` section, the **non-parked, non-dropped** issues (Step 2). **Parked and dropped issues recorded in the plan file are NEVER created** (the report still routes the parked ones at pass e; dropped dependents are simply omitted).

`create-issues <job-file>` walks the job file's `issues` in order, which is the plan file's Wave order. On **CREATE** (the milestone had no prior issues; `adopt` false) it creates every surviving issue. On **ADOPT** (`adopt` true) it first lists the milestone's existing OPEN issues, `gh issue list --milestone "<milestone-title>" --state open --json number,title`, so a re-run does not duplicate them, and matches each surviving issue against them **by exact title**. It returns the slug→`#n` map, one row per issue, as each row resolves.

For each surviving issue, **in Wave order** (the plan file's Wave order):

| On adopt, title match? | Action |
|---|---|
| **Yes**: an open issue with the same title already exists | **Reuse** its number, do NOT create a duplicate. Map `slug → #<existing-n>`. Its body is **left as-is** (see body policy below). |
| **No** (or this is the create path) | **Create:** `gh issue create --title "<title>" --body "<the §4 ISSUE_BODY from the plan file, verbatim>" --milestone "<milestone-title>" --label <ui\|logic>`, appending ` --label <risk:light\|risk:heavy>` only when the plan file records a risk label (absent-risk branch below). Capture the returned number. Map `slug → #<new-n>`. |

Apply each issue's **labels exactly as recorded in the plan file** (its `ui`/`logic` label, plus its `risk:*` label when the plan records one, Step 2). Accumulate the full **slug→`#n` map** across every surviving issue (created or reused). The body here still carries the **local slug** references from the plan file; they are rewritten in the second pass (d), once the full map exists. The twin passes it with `--body-file`, which `gh issue create` accepts alongside `--body`: identical bytes on GitHub, and no shell-quoting path for a multi-line body.

**Absent-risk branch.** The `ui`/`logic` `--label` is always emitted. The second `--label` is emitted **only when the issue's plan-file heading carries a `risk:*` tag** (`docs/plan-file-contract.md` Plan-file output template). A heading with no risk tag deploys with the `ui`/`logic` label alone: never a `--label` with no value, and never a re-guessed `risk:heavy`. The missing tag is the issue-author's deliberate deferral to the driver's own risk rubric (`agents/issue-author.md` The contract, clause 5). Every other deploy site cites this branch rather than restating it.

**Adopted-issue body policy.** Adopted (title-matched) issues are **NOT** body-rewritten: their bodies are preserved as-is. A prior `create` run already resolved their slug→`#n` references, and any manual human edits are respected. **ONLY newly-CREATED issues** receive the slug→`#n` body rewrite in pass (d). This non-clobber behavior is intentional, not a gap.

**Re-run title-match constraint (stated limitation).** De-dup on re-run relies on **stable, exact, OPEN titles**: it matches each surviving issue's title against the milestone's open issues. If a title was edited on GitHub between runs, or a prior issue was **closed** (the list is `--state open`), the match misses and a **new** issue may be created. Titles must stay stable for idempotent re-run, a stated constraint, not a silent bug.

#### d. Second pass: rewrite slug→`#n` (the load-bearing two-pass mechanic)

Two passes are required: issue numbers do not exist until (c) creates them, and `gh issue create --milestone` cannot set the Wave-encoded milestone description. With the **complete** slug→`#n` map from (c):

**Substring-safe rewrite rule (load-bearing).** The architect rolls tags `#A`, `#B`, … `#Z`, then doubles to `#AA`, `#AB`, … past 26 (`agents/architect.md`). A naive string replace of `#A`→`#42` would corrupt `#AB` into `#42B`, and could also hit `#A` inside a word. So **every** slug→`#n` rewrite (issue bodies AND the milestone description) MUST:
  1. **Replace in descending slug-length order** (longest slug first: **all double-letter tags before any single-letter tag**), so a longer tag is consumed before a shorter prefix of it can match.
  2. **Match each `#<tag>` only at a token boundary**: the tag must be followed by a non-tag character (whitespace, punctuation, a digit, end-of-string), not by another tag-letter, and never be a substring inside a longer tag or a word. `#A` therefore never matches inside `#AB`, and `#AB2` rewrites to `#<n>2`.

Apply this rule to **every** slug occurrence, wherever it appears (both targets below): it is the mechanic that keeps the rewrite correct. Both twins implement it as one left-to-right maximal-munch scan, which satisfies both clauses at once and is order-independent (the twin's header records why). A map the pass-(c) walk left INCOMPLETE is refused by every pass-(d) entry point, so the abort below is mechanical, not a rule the caller has to remember.

1. **Each newly-CREATED issue** (adopted issues are skipped, see the pass-(c) body policy): rewrite **every slug occurrence in the issue's FULL body** to its mapped `#n`: `## Summary`, `## Design` prose, **and** `## Dependencies` (including the reason text after a dependency, e.g. "Depends on #A - references SyncStatusViewModel, introduced by #A" → **both** `#A` rewritten; `agents/issue-author.md`), using the substring-safe rule, then `gh issue edit <n>` with the rewritten body. `apply-bodies <job-file> <map-file>` does both halves for every `created` row in the map and skips every `reused` row. (A created issue whose full body contains no slug reference needs no edit, and is reported `unchanged`.) Rewriting **only** `## Dependencies` would leave sibling-slug references in Summary/Design/reason text dangling: GitHub would auto-link them to whatever real issue happens to hold that number.
2. **The milestone description:** rewrite **every slug occurrence** in the plan file's Wave-order description from local slugs to real numbers (same substring-safe rule) and PATCH it onto the milestone: `patch-description <number> <map-file> <description-file>`, which sends `gh api --method PATCH "repos/{owner}/{repo}/milestones/<number>" -f description=…`, the REPLACE form. The description is passed to `-f`/`--raw-field`, which always takes its value literally, so a multi-line description is sent as text and never read as an `@file` (that applies only to `-F`).

After (d), every `#n` on GitHub is a real issue number and the milestone description encodes the Wave order in real numbers, exactly the ordering source the driver's `solve-milestone` / `triage` read (`SPEC.md` §4).

### Step 3: pass f (mirror the milestone to Trello)

The **final** deploy pass, added after passes a–d above (pass e, the needs-input report, stays inline in `skills/create/SKILL.md` Step 3). It runs **after passes a–e succeed and the milestone + issues exist** (it needs the milestone number from pass (b), the real `#n` issue numbers from pass (c), and the Wave order from pass (d)) and **before** the Step-4 driver handoff. Its job: make a freshly-planned milestone visible on the PM board immediately, instead of waiting for `milestone-driver` to seed a card on its first build run.

This pass **reuses the driver's existing Trello mechanism by reference**: it does **not** re-author it and adds **no** feeder-side Trello config key. The card shape, target list, auth, and idempotency conventions live in `milestone-driver`'s `skills/solve-milestone/trello-sync.md`, **Conventions 1–7** (point at that file, do not copy the conventions inline):

| Convention | What it governs |
|---|---|
| Conv 1 | Best-effort wrapper: every Trello call logs one line on failure and continues; never a gate. |
| Conv 2 | Availability probe: probe `mcp__trello__get_health` first; MCP tools absent → log once, skip the rest. |
| Conv 3 | Misconfiguration guard: `integrations.trello` present but `boardId` missing → log one line, skip. |
| Conv 4 | Ensure the **queue** list (case-sensitive name match, auto-create if absent). |
| Conv 5 | Card resolution: back-link anchor → name-match → create on the queue list. |
| Conv 6 | `<!-- trello: <card-url> -->` back-link on the milestone description; idempotent (skip when already present). |
| Conv 7 | "Issues" checklist: one `#<n> — <issue title>` item per open milestone issue. |

**Read seam (which profile, and when to skip).** Resolve the **driver** profile via the established feeder resolution chain: `.milestone-config/driver.json` (primary), root `milestone-driver.json` (legacy fallback). The resolution is best-effort, exactly as `skills/plan/SKILL.md` Step 0 resolves the shared keys. Read `integrations.trello` from it. **`integrations.trello` absent, OR the driver profile unreadable → silent no-op** (absent-means-skip; the driver's `docs/profile-schema.md` "Note on `integrations.trello`"; `.project/design-philosophy.md#Error & failure philosophy`): no card, no checklist, no back-link, and the GitHub deploy result (milestone + issues + Wave description) stays byte-unchanged. No new feeder key: the driver already resolves the destination.

**Target list = queue.** The card is created-or-adopted on the board's **queue** list, its name resolved from `integrations.trello.lists.queue` (default `"Queue"`; the driver's `docs/profile-schema.md` `integrations.trello.lists.queue` key + `trello-sync.md` Conv 4). This pass touches only the queue list: it never moves the card between lists (that is the driver's Conv 8 state machine, out of scope here).

**Execution order (the seed subset of `trello-sync.md`'s run-start order).** Run best-effort (Conv 1 throughout):

1. **Conv 2: availability probe.** Probe `mcp__trello__get_health`. If the `mcp__trello__*` tools are not loaded in this session, log the one documented line and skip every remaining Trello step. This "configured but tools absent" log is what distinguishes a degrade from the silent absent-config case.
2. **Conv 3: misconfiguration guard.** If `integrations.trello` is present but `boardId` is missing, log the one documented line and skip.
3. **Conv 4: ensure the queue list.** Resolve `lists.queue` (default `"Queue"`) by case-sensitive name on the configured `boardId`; create it if absent.
4. **Conv 5: card resolution (create-or-adopt).** Back-link anchor (the milestone description already carries `<!-- trello: <card-url> -->` → adopt that card) → name-match (a card whose name equals the milestone name on the queue list → adopt) → otherwise create the card on the queue list.
5. **Conv 7: "Issues" checklist (creation path only).** On **creation**, add one `#<n> — <issue title>` item per **open** milestone issue, **ordered by the Wave order pass (d) deployed**: read the `## Waves` block of the milestone description (equivalently the plan file's Wave order). This pins Conv 7's otherwise-unspecified ordering; it does not contradict it. On **adoption**, leave the existing checklist as-is (Conv 7 adoption path, no reconciliation).
6. **Conv 6: back-link.** Record `<!-- trello: <card-url> -->` as the final line of the milestone description, idempotent (skip the PATCH when the description already contains `<!-- trello:`). This is the only shell the pass emits, shipped as a bash + PowerShell 7+ twin below.

**Scope boundary (feeder seeds; driver drives).** This pass **seeds** the queue card only: create-or-adopt + checklist + back-link. It does **not** run the driver's card **state machine** (Conv 8) or the phase / loop / finish hooks (`trello-sync.md` Conv 10). Those stay the driver's build-time job. Because the feeder writes the same Conv 6 back-link, the driver's later `solve-milestone` Conv 5 resolution **adopts the same card** (no duplicate) when it picks the milestone up.

**Best-effort, non-blocking.** The GitHub deploy has already succeeded before this pass runs. Every Trello call is wrapped best-effort (Conv 1): a failure logs one line (`Trello: <operation> skipped — <error>`) and continues. It **never** fails the deploy, **never** parks, **never** blocks (`.project/design-philosophy.md#Error & failure philosophy`).

**The back-link read-modify-write (Conv 6 command shape): bash + PowerShell 7+ twins.** Fetch the current milestone description, then PATCH it with the back-link appended as the final line **only when the back-link is not already present** (Conv 6 idempotency: no second line, no duplicate). `<number>` is the milestone number from pass (b); `<card-url>` is the card URL resolved at step 4:

```bash
# bash. Record the Conv 6 back-link, idempotently (skip if already present).
current=$(gh api "repos/{owner}/{repo}/milestones/<number>" --jq '.description')
case "$current" in
  *'<!-- trello:'*)
    # back-link already present → skip the PATCH (Conv 6 idempotency; adoption re-run)
    echo "Trello: back-link already present, description PATCH skipped"
    ;;
  *)
    gh api --method PATCH "repos/{owner}/{repo}/milestones/<number>" \
      -f description="${current}

<!-- trello: <card-url> -->"
    ;;
esac
```

```powershell
# PowerShell 7+. Same idempotent Conv 6 back-link. Assign the multi-line description to a
# variable first, then pass it, so gh's -f reads it as a literal string (never @file).
$current = gh api "repos/{owner}/{repo}/milestones/<number>" --jq '.description'
if ($current -like '*<!-- trello:*') {
  # back-link already present → skip the PATCH (Conv 6 idempotency; adoption re-run)
  Write-Output "Trello: back-link already present, description PATCH skipped"
} else {
  $desc = @"
$current

<!-- trello: <card-url> -->
"@
  gh api --method PATCH "repos/{owner}/{repo}/milestones/<number>" -f "description=$desc"
}
```

Wrap this read-modify-write best-effort (Conv 1): a `gh` failure logs one line and continues. The deploy already succeeded. **Empty-description edge:** when the milestone description is empty the back-link becomes its only content (Conv 6 empty-description edge case). The twins above write it as the trailing line either way.

**How each acceptance criterion is met.**

| Criterion | Where it is satisfied |
|---|---|
| **Happy path**: one queue card + Wave-ordered checklist + back-link | Conv 5 create + Conv 7 (Wave-ordered) + Conv 6, above. |
| **Empty / no-op**: silent, deploy byte-unchanged | Read seam: `integrations.trello` absent OR profile unreadable → silent no-op. |
| **Error / degrade**: logged skip, deploy still succeeds | Conv 2 (tools absent) / Conv 3 (`boardId` missing) log one line and skip; Conv 1 best-effort throughout. |
| **Idempotent re-run**: adopt, no duplicate, PATCH skipped | Conv 5 step 1 (back-link anchor adopts), Conv 7 adoption path (checklist as-is), Conv 6 idempotency (PATCH skipped, both twins above). |
| **Cross-platform**: bash + pwsh twins, identical behavior | The two twins above (the only shell the pass emits). |

### Step 4: Offer the driver handoff (clean-run only)

After the deploy completes (Step 3), `create` can hand the freshly-built milestone straight to `milestone-driver` to start building, instead of ending the run and leaving the user to invoke the driver themselves. This is **build-kickoff only**; it invokes `/milestone-driver:solve-milestone "<milestone-title>"`, which builds to the integration branch and **never** crosses the release boundary (Gate 3 below). The behavior is governed by the `autoHandoff` key (Step 0) and three gates that must **ALL** hold to offer the handoff. (Resolved design: issue #148, 2nd comment, Ken, 2026-06-24.)

**Gate 1: clean run only (no gaps/parks).** Offer the handoff **only** when the plan file's `## Needs human input` pointer is **"none"** (the exact same signal pass (e) reads, `skills/create/SKILL.md` pass e, to decide whether to route a report): no product gap AND nothing parked/dropped.

If the pointer is **NOT** "none" (any candidate was parked / flagged / blocked), **do NOT offer the handoff**; the existing gap-surfacing behavior stands unchanged (pass e routes the gaps as today), and `create` ends as it does today. Handing a milestone with known gaps to an unattended build loop would build past the very gaps the feeder exists to surface; the clean-run gate (no gaps/parks) is what keeps the human in the loop.

**Gate 2: driver installed (else silently skip).** Detect whether `milestone-driver` is available in this session using the **same convention the feeder already uses** for the optional driver soft-dependency: attempt the invocation and treat "does not resolve (no such skill / agent in the session, `milestone-driver` not installed)" as **absent** (`docs/consumer-setup.md` §1, the optional `milestone-driver` soft-dependency **degrades silently** when absent). For the handoff, the cleanest detection is: **does `/milestone-driver:solve-milestone` resolve in this session?** If it does **NOT** resolve, **silently skip** this step (**no prompt, no error, no notice**) exactly as the optional soft-dependency degrades silently elsewhere. The handoff is a convenience on top of a clean deploy; its absence is not a failure.

**Gate 3: never crosses the release boundary.** The handoff invokes `/milestone-driver:solve-milestone "<milestone-title>"`, which **only merges to the integration branch** (`develop`) and never to the protected branch (`main`). Release (`integrationBranch` → `protectedBranch`), closing the GitHub milestone object, and deploy stay **manual and human-only**: that boundary is what makes unattended operation safe (`milestone-driver/skills/solve-milestone/SKILL.md`, the "Bounded blast radius" note: "merges only to `integrationBranch`, never to `protectedBranch`. Release … and deploy stay manual and human-only"). `create`'s handoff is **build-kickoff only**: it does not auto-merge to a protected branch, does not remove the release gate, and `develop → main` stays a manual human call. `solve-milestone` already enforces this; the handoff simply invokes it.

**Behavior by `autoHandoff` (Step 0):**

| `autoHandoff` | When gates 1 + 2 hold | When gate 1 OR 2 fails |
|---|---|---|
| `"off"` | **Never offer**, no prompt: skip this step (today's no-handoff behavior). | Skip this step (no-op either way). |
| `"prompt"` (**default**) | **Ask:** *"milestone-driver is installed: start building this milestone now, or review it first?"* → **yes** invokes `/milestone-driver:solve-milestone "<milestone-title>"`; **no** stops (today's behavior). | **Do not offer.** Gate 1 fail (gaps/parks present): surface the gaps as today (pass e). Gate 2 fail: silently skip (no prompt, no error). |
| `"auto"` | **Invoke immediately**, no prompt: `/milestone-driver:solve-milestone "<milestone-title>"`. Print a one-line notice for legibility: `create: clean run, handing "<milestone-title>" to milestone-driver to start building (autoHandoff: auto)`. (Driver-side precondition: see the numeric-title caveat below.) | **Do not invoke.** Gate 1 fail (gaps/parks present): surface the gaps as today (pass e). Gate 2 fail: silently skip. |

**Numeric-title caveat (`"auto"` defers to the driver's own preconditions).** `autoHandoff: "auto"` kicks off the driver with no prompt, but it does **not** override the driver's own entry preconditions. If the deployed milestone title is **purely numeric**, `/milestone-driver:solve-milestone` **halts and prompts the human for a rename** regardless of `autoHandoff: "auto"`. It interprets a bare number as single-issue mode and refuses to drive a numeric-titled milestone unattended (`milestone-driver/skills/solve-milestone/SKILL.md`, the numeric-title precondition: "if it is purely numeric, halt immediately and prompt the human … do not proceed to Phase 0"). So auto mode's "no question asked" contract ends at the driver boundary: auto kicks off the driver, but the driver enforces a non-numeric-title precondition for unattended operation. This is **narrow**: a feeder-deployed milestone normally carries the user-owned semver in its title (non-numeric), so the caveat rarely bites; no special handling is added here, the doc is simply honest that auto defers to the driver's preconditions.

**The exact milestone title.** The invocation passes the **exact** `Milestone title (exact)` line from the plan file, the same identity string `create` deployed at pass (b) (Step 2; the plan-file `Milestone title (exact)` field). Never a re-derived or goal-derived name: the title carries the user-owned semver and is the handle the driver resolves the milestone by. Pass it verbatim to `solve-milestone "<milestone-title>"`.

**This is a skill invocation, not a shell command.** `/milestone-driver:solve-milestone` is invoked as a Claude Code skill (the same way `create` runs `plan` first on the absent path): there is no bash/pwsh form to ship for the invocation itself. The `autoHandoff` value is already in hand from Step 0; this step needs no additional config read.

**Multi-milestone roadmap note (Step 1R).** When a **roadmap manifest** drove the deploy (Step 1R, multi-milestone path), this single-plan handoff is **not** auto-fired across the roadmap. `create`'s roadmap responsibility ends at deploying all N milestones and recording each one's `build order: milestone X of N` line, which is exactly the cross-milestone order the driver reads. A roadmap deploy therefore completes by reporting the N deploy receipts and the recorded build order; starting the build stays a human call. The single-plan handoff above (Gates 1–3, `autoHandoff`) is **unchanged** for the N=1 / no-manifest path.
