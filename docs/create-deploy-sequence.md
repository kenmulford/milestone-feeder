# create deploy sequence — the relocated deploy mechanics

This is the create-scoped reference holding the **full mechanics** of `create`'s heavy deploy steps. The skill `skills/create/SKILL.md` keeps a lean orchestration skeleton — the step names, their fixed order, the gates, and one-level pointers — and `create` reads this reference **on demand** when it needs the mechanics. Each section below was relocated **byte-for-byte** from `skills/create/SKILL.md` (its Step 1R, the Step 3 write-sequence passes a–d, and Step 4), so **nothing here changes what `create` deploys** — the relocation is behavior-neutral. Read each section as the verbatim procedure for the step the skill names; `create`'s own pass (e) (the needs-input report) and its invariants stay in the skill.

- [Step 1R — Resolve the deploy target](#step-1r--resolve-the-deploy-target-a-single-plan-or-a-roadmap-of-n-milestones)
- [Step 3 — deploy write-sequence (passes a-d)](#step-3--deploy-write-sequence-passes-a-d)
- [Step 3 — pass f (mirror the milestone to Trello)](#step-3--pass-f-mirror-the-milestone-to-trello)
- [Step 4 — Offer the driver handoff](#step-4--offer-the-driver-handoff-clean-run-only)

### Step 1R — Resolve the deploy target: a single plan, or a roadmap of N milestones

Before resolving a plan file, check whether `plan`'s roadmap flow left a **roadmap manifest** for this brief. Derive `<slug>` **exactly as Step 1 does** (the same deterministic rule, `skills/plan/SKILL.md` Step 7 — the slug-derivation rule), then resolve the manifest at the path `build-roadmap` writes — the cross-milestone build artifact `create` deploys (`skills/build-roadmap/SKILL.md` "Manifest format"; `.project/design-philosophy.md#Layering & boundaries` — the plan file / manifest is the build artifact):

```
.milestone-feeder/roadmap-<slug>.md
```

| Resolution | Action |
|---|---|
| **Absent** (no manifest) | **Single-plan path — UNCHANGED.** Fall through to **Step 1** below and run **Steps 1 → 4 once, exactly as today**. This is the **N=1** case; the single-plan path sees zero behavior change. Skip the rest of this section. |
| **Found** (a manifest) | **Multi-milestone roadmap deploy.** Read the manifest and run the **outer loop** below. The manifest is **read, never regenerated** — `create` re-dispatches no agent and re-runs no gate on the found path, exactly as for a plan file (`SPEC.md` §3.1). Do **NOT** also run the single-plan Step 1 resolution for the whole brief: the roadmap replaces it — each of its milestones has its own `plan-<slug>.md`, and there is no whole-brief plan file. |

**The outer loop (manifest found) — loop the per-plan deploy over the manifest's milestones.** The manifest's `## Milestones (in build order)` section lists the milestones, each `### <position>. <milestone name>` with a `Build-order position: <position>` line **and a `Plan file:` path** (the exact plan-file handle the planning fan-out recorded, `skills/build-roadmap/SKILL.md` "Manifest format"; `skills/plan/SKILL.md` Step 3.7.g), in build order. Let **N** be that milestone count. Only the **outer loop** is added — the per-milestone deploy is **Step 3 passes a–e reused unchanged**. **For each milestone, in build order (position 1 → N):**

| Per-milestone step | What runs |
|---|---|
| **i. Resolve this milestone's plan file** | **Read the recorded `Plan file:` path from this manifest entry** — the exact `.milestone-feeder/plan-<assignedSlug>.md` the planning fan-out populated (`skills/build-roadmap/SKILL.md` "Manifest format"; `skills/plan/SKILL.md` Step 3.7.g). **Do NOT re-derive a slug from the milestone name** — the plan-file slug is goal-derived with an `-m<index>` collision tiebreaker the manifest name does not encode (`skills/plan/SKILL.md` Step 3.7.d), so a name-derived path would miss. Read that plan file and treat it as Step 1's **Found** row, then deploy it. If the entry's `Plan file:` is **pending/empty**, or the file at that path is **absent** (this milestone never finished planning), STOP the loop and report it as a mid-loop failure (🔴, Partial-failure path below) — do **NOT** re-plan from `create`. |
| **ii. Read its plan-file contract** | **Step 2**, unchanged. |
| **iii. Deploy it** | **Step 3 passes a–e**, entirely unchanged — ensure labels (a) / create-or-adopt the milestone by exact title (b) / create-or-reuse each surviving issue by exact title (c) / slug→`#n` rewrite + Wave-description PATCH (d) / route the needs-input report (e). Per-milestone idempotency is the existing **create-or-adopt**, inherited per iteration: never delete a milestone or issue, never duplicate a same-title open issue. |
| **iv. Record the build-order line** | When pass (d) PATCHes this milestone's description, include the canonical `build order: milestone X of N` line in the PATCHed description, alongside the `## Waves` block (see "The build-order line" below). |

After the loop deploys all N, report each milestone's deploy receipt (`#`) and the recorded build order, then continue to **Step 4** (its multi-milestone note).

**The build-order line (the cross-milestone metadata).** Pin **one** canonical literal — `build order: milestone X of N` — where **X** is this milestone's `Build-order position` (1..N) and **N** is the manifest's milestone count. It extends the Wave-order-in-description convention (`SPEC.md` §4): the description already encodes the *intra*-milestone Wave order (`## Waves`); this single line encodes the *cross*-milestone position the driver reads to build the roadmap in sequence. Place it as a standalone line directly under the one-paragraph milestone goal and above the `## Waves` block, so milestone X's PATCHed description reads:

```markdown
<one-paragraph milestone goal>

build order: milestone X of N

## Waves
- Wave 1 (parallel): #A, #B, ...
- ...
```

**Idempotency is INHERITED from pass (d), not re-implemented.** Pass (d) PATCHes the description with the **REPLACE form** (`gh api --method PATCH .../milestones/<number> -f description=...`, Step 3 pass d) — it replaces the whole description every run. The build-order line rides **inside that one REPLACE payload**, so a re-run over an already-deployed manifest **overwrites** the line in place; the line count never grows (the same overwrite guarantee pass (d) already makes for the Wave order). **No new read-modify-write of the description is added** — only pass (d)'s payload gains the one canonical line. Assemble the augmented description (bash + PowerShell 7+ twins), then PATCH it with pass (d)'s existing REPLACE-form command:

```bash
# bash — assemble milestone X's description: goal + the ONE canonical build-order line + the
# slug-rewritten Waves block, then PATCH via pass (d)'s REPLACE form. X = Build-order position; N = count.
# $goal and $waves are the two halves of the description pass (d) already builds (slugs rewritten to #n).
desc="$(printf '%s\n\nbuild order: milestone %s of %s\n\n%s\n' "$goal" "$X" "$N" "$waves")"
gh api --method PATCH "repos/{owner}/{repo}/milestones/<number>" -f "description=$desc"
```

```powershell
# PowerShell 7+ — same assembly + pass (d)'s REPLACE-form PATCH; the ONE canonical line.
$desc = @"
$goal

build order: milestone $X of $N

$waves
"@
gh api --method PATCH "repos/{owner}/{repo}/milestones/<number>" -f "description=$desc"
```

Re-PATCHing on a re-run overwrites the line — idempotent by construction, so the `build order: milestone X of N` count stays exactly one per milestone, never growing.

### Step 3 — deploy write-sequence (passes a-d)

The full mechanics of the deploy write-sequence passes **a, b, c, d** — every `gh` form with its bash + PowerShell 7+ twin, the create-or-adopt resolution table, the deploy-receipt back-write, the slug→`#n` map, and the substring-safe rewrite rule. Pass **e** (the needs-input report) stays in `skills/create/SKILL.md` Step 3. (`create`'s Step 3 skeleton names all five passes in fixed order and points here for a–d.)

This is the v0.2.0 apply write-sequence, moved wholesale into `create` and preserved verbatim — only the **source** of the issue bodies / labels / waves / milestone title / source-brief reference changes: `create` reads them **from the plan file** (Step 2), it regenerates nothing (`docs/specs/v0.3.0-humanize-the-surface.md` §3: *"What changes is only the source of the issue bodies/labels/waves: read from the plan file, not regenerated"*; §4: the write sequence is *"unchanged"*). All `gh` invocations below are run **by the skill itself**, not by any dispatched agent — the agent-read-only invariant holds. The commands are shell-neutral (`gh` is cross-platform); where a read-modify-write needs a variable, both a bash and a PowerShell 7+ form are given, consistent with the rest of the suite.

#### a. Ensure labels idempotently (BEFORE creating any issue)

Run the four `gh label create … --force` commands **first**, so the labels exist before any `gh issue create --label` references them. `--force` **upserts** (creates if absent, updates color/description if present) — re-runs produce no duplicates. These are the canonical four (the same taxonomy `setup` provisions, `skills/setup/SKILL.md`); run them as a **flat list — no shell loop** — so they are portable across bash and PowerShell 7+:

```
gh label create "ui"          --color 5319E7 --description "UI-surface issue (design review applies)" --force
gh label create "logic"       --color 0E8A16 --description "Logic / non-UI issue" --force
gh label create "risk:light"  --color C2E0C6 --description "Reduced-ceremony build profile (driver override)" --force
gh label create "risk:heavy"  --color B60205 --description "Full-ceremony build profile (driver override)" --force
```

These four lines are identical on bash and PowerShell 7+.

#### b. Create-or-adopt the milestone (by EXACT title)

Resolve the milestone by the **exact** `Milestone title (exact)` line from the plan file (Step 2), against all existing milestones. Pass the title via an **environment variable** `t` that `gh`'s embedded jq reads as `env.t` — **NEVER string-interpolate the title into the jq filter literal**. `gh api` has **no `--arg` flag** (that belongs to standalone `jq`), and a title containing a `"` would break an inlined filter and yield a spurious no-match (→ a duplicate milestone). Reading `env.t` from the process environment is the portable, quote-safe approach:

```
# bash — title read from the environment (quote-safe; no --arg, which gh api does not support)
t="<milestone-title>" gh api "repos/{owner}/{repo}/milestones?state=all&per_page=100" --paginate \
  --jq '.[] | select(.title==env.t) | {number, state}'
```

PowerShell 7+ is the same form — set `$env:t = "<milestone-title>"` first, then run `gh api … --jq '.[] | select(.title==env.t) | {number, state}'` — keep the title in the environment, never inlined into the filter.

| Result | Action |
|---|---|
| **No title match** | **Create:** `gh api --method POST "repos/{owner}/{repo}/milestones" -f title="<milestone-title>" -f description="<placeholder>"`. Capture the returned `.number`. The description is a placeholder — it is rewritten with the real Wave order in pass (d), once the slug→`#n` numbers exist. |
| **Exactly one title match, `state: open`** | **Adopt:** record its `.number`. Re-use it; never delete it or its issues. |
| **Exactly one title match, `state: closed`** | **Adopt + reopen:** `gh api --method PATCH "repos/{owner}/{repo}/milestones/<number>" -f state=open`, then record its `.number`. **Never delete** the milestone or any of its issues. |
| **Multiple title matches** (GitHub permits same-title milestones) | **Adopt the FIRST returned**, reopen it if closed, and log a notice — `create: multiple milestones titled "<t>" — adopted first returned (#<n>)`. Never delete the others. |

**Write the deploy receipt (the concluding action of pass b).** As soon as pass (b) has resolved the milestone `.number` — **any** outcome above (created / adopted-open / adopted-reopened / first-of-multiple) — write that number back into the **same plan file Step 1 resolved** (`.milestone-feeder/plan-<slug>.md`, `skills/create/SKILL.md` Step 1) as a single labeled receipt field. This is the stable handle `update` will resolve by after a later title change (`docs/specs/v0.3.1-driver-handoff.md` §4 *"The deploy receipt — a stable handle for rename"*; the plan-file additive-fields row, §6: *"`Milestone number (GitHub):` `<n>` — the deploy receipt … `create` writes it post-deploy"*). The receipt is the create-SIDE back-write only — the `update`-side READ is a separate issue and is **not** part of `create`.

- **Field shape.** Exactly one labeled line, a **sibling to the plan file's existing header lines** (`Milestone title (exact):`, `Version provenance:`, `Source brief:` near the top — the format block at `skills/plan/SKILL.md` Step 7 — "Plan-file format"):

  ```
  Milestone number (GitHub): <n>
  ```

- **Guard — write ONLY when a real number was resolved.** If pass (b) resolved **no** `.number` (it neither created nor adopted a milestone), write **nothing** — no receipt line, no placeholder. Prior absence of the line is normal: a first deploy has none, and a plan file that never receives a receipt stays valid and deployable (the field is additive; `docs/specs/v0.3.1-driver-handoff.md` §6: *"A v0.3.0 plan file lacking them still parses (the consumers degrade gracefully)"*).
- **Idempotent read-modify-write.** Read the plan file; if a `Milestone number (GitHub):` line **already exists**, **rewrite its number in place** — exactly one such line, **never** a duplicate; if it is **absent**, **insert** one (as a sibling header line). This is a read-modify-write that **converges to exactly one receipt line carrying the current number**, so it is safe to re-run: a second `create` on an already-adopted milestone rewrites the same line to the same number (no duplicate, no second insert) — unlike pass (d)'s no-op idempotency (where re-applying changes nothing), the receipt actively overwrites, but the line count never grows. (Re-running `create` is safe and produces no duplicates — the same guarantee pass (d) makes for issue bodies, `skills/create/SKILL.md` "Partial-failure path".) Both shells below are idempotent by construction: the presence branch rewrites the existing line in place (exactly one), and the absent branch inserts exactly once.

  ```bash
  # bash — rewrite the receipt in place if present, else insert it after the header lines.
  # Uses awk (portable across BSD/macOS and GNU sed/awk); avoids GNU-sed-only `a`,
  # which exits 1 on BSD/macOS sed. n is the milestone number captured above; plan is
  # the path Step 1 resolved. On any write error, emit the notice and continue (don't block).
  plan=".milestone-feeder/plan-<slug>.md"
  n="<resolved-milestone-number>"
  notice="create: deployed milestone #$n but could not write the receipt to $plan — re-run to record it"
  tmp="$(mktemp)" || { echo "$notice"; }
  if [ -n "$tmp" ]; then
    if grep -q '^Milestone number (GitHub):' "$plan"; then
      # present → rewrite the FIRST receipt line in place (exactly one line; never a duplicate)
      awk -v n="$n" '!done && /^Milestone number \(GitHub\):/ { print "Milestone number (GitHub): " n; done=1; next } { print }' "$plan" > "$tmp" \
        && mv "$tmp" "$plan" || echo "$notice"
    elif grep -q '^Source brief:' "$plan"; then
      # absent, anchor present → insert exactly once after the Source brief header line
      awk -v n="$n" '{ print } !done && /^Source brief:/ { print "Milestone number (GitHub): " n; done=1 }' "$plan" > "$tmp" \
        && mv "$tmp" "$plan" || echo "$notice"
    else
      # absent AND no anchor (malformed/hand-edited plan) → degrade VISIBLY:
      # append the receipt at EOF (still exactly one line; the present-branch finds it next run)
      awk -v n="$n" '{ print } END { print "Milestone number (GitHub): " n }' "$plan" > "$tmp" \
        && mv "$tmp" "$plan" || echo "$notice"
    fi
  fi
  ```

  ```powershell
  # PowerShell 7+ — same idempotent rewrite-or-insert; write UTF-8 without a BOM.
  # On any write error, emit the notice and continue (don't block the deploy).
  $plan = ".milestone-feeder/plan-<slug>.md"
  $n    = "<resolved-milestone-number>"
  $notice = "create: deployed milestone #$n but could not write the receipt to $plan — re-run to record it"
  try {
    $lines = Get-Content -LiteralPath $plan
    if ($lines -match '^Milestone number \(GitHub\):') {
      # present → rewrite the number in place (exactly one line; never a duplicate)
      $out = $lines -replace '^Milestone number \(GitHub\):.*', "Milestone number (GitHub): $n"
    } elseif ($lines -match '^Source brief:') {
      # absent, anchor present → insert as a sibling after the Source brief header line
      $out = $lines | ForEach-Object {
        $_
        if ($_ -match '^Source brief:') { "Milestone number (GitHub): $n" }
      }
    } else {
      # absent AND no anchor (malformed/hand-edited plan) → degrade VISIBLY:
      # append the receipt at EOF (still exactly one line; the present branch finds it next run)
      $out = @($lines) + "Milestone number (GitHub): $n"
    }
    Set-Content -LiteralPath $plan -Value $out -Encoding utf8NoBOM -ErrorAction Stop
  } catch {
    Write-Output $notice
  }
  ```

- **Failure semantics — report, don't block.** A plan-file back-write failure is **REPORTED as a notice but does NOT block** — by this point the GitHub deploy already succeeded (the milestone exists; pass c is about to create the issues), and the plan file is **gitignored per-run scratch** (`docs/specs/v0.3.1-driver-handoff.md` §4: *"The plan file is gitignored per-run scratch, so this back-write is low-stakes"*). The receipt rewrites the **existing** plan file in place, so the scratch dir already self-ignores (`plan` ensured `.milestone-feeder/.gitignore` contains `*` when it first wrote the plan; `skills/plan/SKILL.md` Step 7) — the receipt write adds no new visible file. On a write error, emit a notice — `create: deployed milestone #<n> but could not write the receipt to <plan> — re-run to record it` — and continue to pass (c). Never abort the deploy over the receipt.

#### c. Create each surviving issue; build the slug→`#n` map

Create **only the SURVIVING** issues recorded in the plan file's `## Issues` section — the **non-parked, non-dropped** issues (Step 2). **Parked and dropped issues recorded in the plan file are NEVER created** (the report still routes the parked ones at pass e; dropped dependents are simply omitted).

On **CREATE** (the milestone had no prior issues), create every surviving issue. On **ADOPT** (the milestone already had issues), first list its existing OPEN issues so a re-run does not duplicate them — match each surviving issue against them **by exact title**:

```
gh issue list --milestone "<milestone-title>" --state open --json number,title
```

For each surviving issue, **in Wave order** (the plan file's Wave order):

| On adopt, title match? | Action |
|---|---|
| **Yes** — an open issue with the same title already exists | **Reuse** its number — do NOT create a duplicate. Map `slug → #<existing-n>`. Its body is **left as-is** (see body policy below). |
| **No** (or this is the create path) | **Create:** `gh issue create --title "<title>" --body "<the §4 ISSUE_BODY from the plan file, verbatim>" --milestone "<milestone-title>" --label <ui\|logic> --label <risk:light\|risk:heavy>`. Capture the returned number. Map `slug → #<new-n>`. |

Apply each issue's **labels exactly as recorded in the plan file** (its `ui`/`logic` label and its `risk:*` label — Step 2). Accumulate the full **slug→`#n` map** across every surviving issue (created or reused). The `--body` here still carries the **local slug** references from the plan file; they are rewritten in the second pass (d), once the full map exists.

**Adopted-issue body policy.** Adopted (title-matched) issues are **NOT** body-rewritten — their bodies are preserved as-is. A prior `create` run already resolved their slug→`#n` references, and any manual human edits are respected. **ONLY newly-CREATED issues** receive the slug→`#n` body rewrite in pass (d). This non-clobber behavior is intentional, not a gap.

**Re-run title-match constraint (stated limitation).** De-dup on re-run relies on **stable, exact, OPEN titles** — it matches each surviving issue's title against the milestone's open issues. If a title was edited on GitHub between runs, or a prior issue was **closed** (the list is `--state open`), the match misses and a **new** issue may be created. Titles must stay stable for idempotent re-run — a stated constraint, not a silent bug.

#### d. Second pass — rewrite slug→`#n` (the load-bearing two-pass mechanic)

Two passes are required: issue numbers do not exist until (c) creates them, and `gh issue create --milestone` cannot set the Wave-encoded milestone description. With the **complete** slug→`#n` map from (c):

**Substring-safe rewrite rule (load-bearing).** The architect rolls tags `#A`, `#B`, … `#Z`, then doubles to `#AA`, `#AB`, … past 26 (`agents/architect.md`). A naive string replace of `#A`→`#42` would corrupt `#AB` into `#42B`, and could also hit `#A` inside a word. So **every** slug→`#n` rewrite (issue bodies AND the milestone description) MUST:
  1. **Replace in descending slug-length order** (longest slug first — **all double-letter tags before any single-letter tag**), so a longer tag is consumed before a shorter prefix of it can match.
  2. **Match each `#<tag>` only at a token boundary** — the tag must be followed by a non-tag character (whitespace, punctuation, end-of-string), not by another tag-letter, and never be a substring inside a longer tag or a word. `#A` therefore never matches inside `#AB`.

Apply this rule to **every** slug occurrence, wherever it appears (both targets below) — it is the mechanic that keeps the rewrite correct.

1. **Each newly-CREATED issue** (adopted issues are skipped — see the pass-(c) body policy): rewrite **every slug occurrence in the issue's FULL body** to its mapped `#n` — `## Summary`, `## Design` prose, **and** `## Dependencies` (including the reason text after a dependency, e.g. "Depends on #A — references SyncStatusViewModel, introduced by #A" → **both** `#A` rewritten; `agents/issue-author.md`) — using the substring-safe rule, then `gh issue edit <n> --body "<rewritten body>"`. (A created issue whose full body contains no slug reference needs no edit.) Rewriting **only** `## Dependencies` would leave sibling-slug references in Summary/Design/reason text dangling — GitHub would auto-link them to whatever real issue happens to hold that number.
2. **The milestone description:** rewrite **every slug occurrence** in the plan file's Wave-order description from local slugs to real numbers (same substring-safe rule) and PATCH it onto the milestone (REPLACE form — both shells):

```
# bash
gh api --method PATCH "repos/{owner}/{repo}/milestones/<number>" \
  -f description="<Wave description with slugs rewritten to #n>"
```

```powershell
# PowerShell 7+ — assign the multi-line description to a variable first, then pass it;
# avoid the `=@` adjacency so gh's -f reads it as a literal string, not @file.
# -f/--raw-field always takes the value literally; @file applies only to -F.
$desc = @"
<Wave description with slugs rewritten to #n>
"@
gh api --method PATCH "repos/{owner}/{repo}/milestones/<number>" -f "description=$desc"
```

After (d), every `#n` on GitHub is a real issue number and the milestone description encodes the Wave order in real numbers — exactly the ordering source the driver's `solve-milestone` / `triage` read (`SPEC.md` §4).

### Step 3 — pass f (mirror the milestone to Trello)

The **final** deploy pass, added after passes a–d above (pass e — the needs-input report — stays inline in `skills/create/SKILL.md` Step 3). It runs **after passes a–e succeed and the milestone + issues exist** — it needs the milestone number from pass (b), the real `#n` issue numbers from pass (c), and the Wave order from pass (d) — and **before** the Step-4 driver handoff. Its job: make a freshly-planned milestone visible on the PM board immediately, instead of waiting for `milestone-driver` to seed a card on its first build run.

This pass **reuses the driver's existing Trello mechanism by reference** — it does **not** re-author it and adds **no** feeder-side Trello config key. The card shape, target list, auth, and idempotency conventions live in `milestone-driver`'s `skills/solve-milestone/trello-sync.md`, **Conventions 1–7** (point at that file — do not copy the conventions inline):

| Convention | What it governs |
|---|---|
| Conv 1 | Best-effort wrapper — every Trello call logs one line on failure and continues; never a gate. |
| Conv 2 | Availability probe — probe `mcp__trello__get_health` first; MCP tools absent → log once, skip the rest. |
| Conv 3 | Misconfiguration guard — `integrations.trello` present but `boardId` missing → log one line, skip. |
| Conv 4 | Ensure the **queue** list (case-sensitive name match, auto-create if absent). |
| Conv 5 | Card resolution — back-link anchor → name-match → create on the queue list. |
| Conv 6 | `<!-- trello: <card-url> -->` back-link on the milestone description; idempotent (skip when already present). |
| Conv 7 | "Issues" checklist — one `#<n> — <title>` item per open milestone issue. |

**Read seam (which profile, and when to skip).** Resolve the **driver** profile via the established feeder resolution chain — `.milestone-config/driver.json` (primary), root `milestone-driver.json` (legacy fallback) — best-effort, exactly as `skills/plan/SKILL.md` Step 0 resolves the shared keys. Read `integrations.trello` from it. **`integrations.trello` absent, OR the driver profile unreadable → silent no-op** (absent-means-skip; the driver's `docs/profile-schema.md` "Note on `integrations.trello`"; `.project/design-philosophy.md#Error & failure philosophy`): no card, no checklist, no back-link, and the GitHub deploy result (milestone + issues + Wave description) stays byte-unchanged. No new feeder key — the driver already resolves the destination.

**Target list = queue.** The card is created-or-adopted on the board's **queue** list, its name resolved from `integrations.trello.lists.queue` (default `"Queue"`; the driver's `docs/profile-schema.md` `integrations.trello.lists.queue` key + `trello-sync.md` Conv 4). This pass touches only the queue list — it never moves the card between lists (that is the driver's Conv 8 state machine, out of scope here).

**Execution order (the seed subset of `trello-sync.md`'s run-start order).** Run best-effort (Conv 1 throughout):

1. **Conv 2 — availability probe.** Probe `mcp__trello__get_health`. If the `mcp__trello__*` tools are not loaded in this session, log the one documented line and skip every remaining Trello step. This "configured but tools absent" log is what distinguishes a degrade from the silent absent-config case.
2. **Conv 3 — misconfiguration guard.** If `integrations.trello` is present but `boardId` is missing, log the one documented line and skip.
3. **Conv 4 — ensure the queue list.** Resolve `lists.queue` (default `"Queue"`) by case-sensitive name on the configured `boardId`; create it if absent.
4. **Conv 5 — card resolution (create-or-adopt).** Back-link anchor (the milestone description already carries `<!-- trello: <card-url> -->` → adopt that card) → name-match (a card whose name equals the milestone name on the queue list → adopt) → otherwise create the card on the queue list.
5. **Conv 7 — "Issues" checklist (creation path only).** On **creation**, add one `#<n> — <title>` item per **open** milestone issue, **ordered by the Wave order pass (d) deployed** — read the `## Waves` block of the milestone description (equivalently the plan file's Wave order). This pins Conv 7's otherwise-unspecified ordering; it does not contradict it. On **adoption**, leave the existing checklist as-is (Conv 7 adoption path — no reconciliation).
6. **Conv 6 — back-link.** Record `<!-- trello: <card-url> -->` as the final line of the milestone description, idempotent (skip the PATCH when the description already contains `<!-- trello:`). This is the only shell the pass emits — shipped as a bash + PowerShell 7+ twin below.

**Scope boundary (feeder seeds; driver drives).** This pass **seeds** the queue card only — create-or-adopt + checklist + back-link. It does **not** run the driver's card **state machine** (Conv 8) or the phase / loop / finish hooks (`trello-sync.md` Conv 10) — those stay the driver's build-time job. Because the feeder writes the same Conv 6 back-link, the driver's later `solve-milestone` Conv 5 resolution **adopts the same card** (no duplicate) when it picks the milestone up.

**Best-effort, non-blocking.** The GitHub deploy has already succeeded before this pass runs. Every Trello call is wrapped best-effort (Conv 1): a failure logs one line — `Trello: <operation> skipped — <error>` — and continues. It **never** fails the deploy, **never** parks, **never** blocks (`.project/design-philosophy.md#Error & failure philosophy`).

**The back-link read-modify-write (Conv 6 command shape) — bash + PowerShell 7+ twins.** Fetch the current milestone description, then PATCH it with the back-link appended as the final line **only when the back-link is not already present** (Conv 6 idempotency — no second line, no duplicate). `<number>` is the milestone number from pass (b); `<card-url>` is the card URL resolved at step 4:

```bash
# bash — record the Conv 6 back-link, idempotently (skip if already present).
current=$(gh api "repos/{owner}/{repo}/milestones/<number>" --jq '.description')
case "$current" in
  *'<!-- trello:'*)
    # back-link already present → skip the PATCH (Conv 6 idempotency; adoption re-run)
    echo "Trello: back-link already present — description PATCH skipped"
    ;;
  *)
    gh api --method PATCH "repos/{owner}/{repo}/milestones/<number>" \
      -f description="${current}

<!-- trello: <card-url> -->"
    ;;
esac
```

```powershell
# PowerShell 7+ — same idempotent Conv 6 back-link. Assign the multi-line description to a
# variable first, then pass it, so gh's -f reads it as a literal string (never @file).
$current = gh api "repos/{owner}/{repo}/milestones/<number>" --jq '.description'
if ($current -like '*<!-- trello:*') {
  # back-link already present → skip the PATCH (Conv 6 idempotency; adoption re-run)
  Write-Output "Trello: back-link already present — description PATCH skipped"
} else {
  $desc = @"
$current

<!-- trello: <card-url> -->
"@
  gh api --method PATCH "repos/{owner}/{repo}/milestones/<number>" -f "description=$desc"
}
```

Wrap this read-modify-write best-effort (Conv 1): a `gh` failure logs one line and continues — the deploy already succeeded. **Empty-description edge:** when the milestone description is empty the back-link becomes its only content (Conv 6 empty-description edge case) — the twins above write it as the trailing line either way.

**How each acceptance criterion is met.**

| Criterion | Where it is satisfied |
|---|---|
| **Happy path** — one queue card + Wave-ordered checklist + back-link | Conv 5 create + Conv 7 (Wave-ordered) + Conv 6, above. |
| **Empty / no-op** — silent, deploy byte-unchanged | Read seam: `integrations.trello` absent OR profile unreadable → silent no-op. |
| **Error / degrade** — logged skip, deploy still succeeds | Conv 2 (tools absent) / Conv 3 (`boardId` missing) log one line and skip; Conv 1 best-effort throughout. |
| **Idempotent re-run** — adopt, no duplicate, PATCH skipped | Conv 5 step 1 (back-link anchor adopts), Conv 7 adoption path (checklist as-is), Conv 6 idempotency (PATCH skipped — both twins above). |
| **Cross-platform** — bash + pwsh twins, identical behavior | The two twins above (the only shell the pass emits). |

### Step 4 — Offer the driver handoff (clean-run only)

After the deploy completes (Step 3), `create` can hand the freshly-built milestone straight to `milestone-driver` to start building — instead of ending the run and leaving the user to invoke the driver themselves. This is **build-kickoff only**; it invokes `/milestone-driver:solve-milestone "<milestone-title>"`, which builds to the integration branch and **never** crosses the release boundary (Gate 3 below). The behavior is governed by the `autoHandoff` key (Step 0) and three gates that must **ALL** hold to offer the handoff. (Resolved design: issue #148, 2nd comment — Ken, 2026-06-24.)

**Gate 1 — clean run only (no gaps/parks).** Offer the handoff **only** when the plan file's `## Needs human input` pointer is **"none"** (the exact same signal pass (e) reads, `skills/create/SKILL.md` pass e, to decide whether to route a report): no product gap AND nothing parked/dropped.

If the pointer is **NOT** "none" — any candidate was parked / flagged / blocked — **do NOT offer the handoff**; the existing gap-surfacing behavior stands unchanged (pass e routes the gaps as today), and `create` ends as it does today. Handing a milestone with known gaps to an unattended build loop would build past the very gaps the feeder exists to surface; the clean-run gate (no gaps/parks) is what keeps the human in the loop.

**Gate 2 — driver installed (else silently skip).** Detect whether `milestone-driver` is available in this session using the **same convention the feeder already uses** for the optional driver soft-dependency: attempt the invocation and treat "does not resolve (no such skill / agent in the session — `milestone-driver` not installed)" as **absent** (`docs/consumer-setup.md` §1 — the optional `milestone-driver` soft-dependency **degrades silently** when absent). For the handoff, the cleanest detection is: **does `/milestone-driver:solve-milestone` resolve in this session?** If it does **NOT** resolve, **silently skip** this step — **no prompt, no error, no notice** — exactly as the optional soft-dependency degrades silently elsewhere. The handoff is a convenience on top of a clean deploy; its absence is not a failure.

**Gate 3 — never crosses the release boundary.** The handoff invokes `/milestone-driver:solve-milestone "<milestone-title>"`, which **only merges to the integration branch** (`develop`) and never to the protected branch (`main`). Release (`integrationBranch` → `protectedBranch`), closing the GitHub milestone object, and deploy stay **manual and human-only** — that boundary is what makes unattended operation safe (`milestone-driver/skills/solve-milestone/SKILL.md` — the "Bounded blast radius" note: "merges only to `integrationBranch`, never to `protectedBranch`. Release … and deploy stay manual and human-only"). `create`'s handoff is **build-kickoff only**: it does not auto-merge to a protected branch, does not remove the release gate, and `develop → main` stays a manual human call. `solve-milestone` already enforces this; the handoff simply invokes it.

**Behavior by `autoHandoff` (Step 0):**

| `autoHandoff` | When gates 1 + 2 hold | When gate 1 OR 2 fails |
|---|---|---|
| `"off"` | **Never offer**, no prompt — skip this step (today's no-handoff behavior). | Skip this step (no-op either way). |
| `"prompt"` (**default**) | **Ask:** *"milestone-driver is installed — start building this milestone now, or review it first?"* → **yes** invokes `/milestone-driver:solve-milestone "<milestone-title>"`; **no** stops (today's behavior). | **Do not offer** — Gate 1 fail (gaps/parks present): surface the gaps as today (pass e). Gate 2 fail: silently skip (no prompt, no error). |
| `"auto"` | **Invoke immediately**, no prompt: `/milestone-driver:solve-milestone "<milestone-title>"`. Print a one-line notice for legibility — `create: clean run — handing "<milestone-title>" to milestone-driver to start building (autoHandoff: auto)`. (Driver-side precondition: see the numeric-title caveat below.) | **Do not invoke** — Gate 1 fail (gaps/parks present): surface the gaps as today (pass e). Gate 2 fail: silently skip. |

**Numeric-title caveat (`"auto"` defers to the driver's own preconditions).** `autoHandoff: "auto"` kicks off the driver with no prompt, but it does **not** override the driver's own entry preconditions. If the deployed milestone title is **purely numeric**, `/milestone-driver:solve-milestone` **halts and prompts the human for a rename** regardless of `autoHandoff: "auto"` — it interprets a bare number as single-issue mode and refuses to drive a numeric-titled milestone unattended (`milestone-driver/skills/solve-milestone/SKILL.md` — the numeric-title precondition: "if it is purely numeric, halt immediately and prompt the human … do not proceed to Phase 0"). So auto mode's "no question asked" contract ends at the driver boundary: auto kicks off the driver, but the driver enforces a non-numeric-title precondition for unattended operation. This is **narrow** — a feeder-deployed milestone normally carries the user-owned semver in its title (non-numeric), so the caveat rarely bites; no special handling is added here, the doc is simply honest that auto defers to the driver's preconditions.

**The exact milestone title.** The invocation passes the **exact** `Milestone title (exact)` line from the plan file — the same identity string `create` deployed at pass (b) (Step 2; the plan-file `Milestone title (exact)` field). Never a re-derived or goal-derived name — the title carries the user-owned semver and is the handle the driver resolves the milestone by. Pass it verbatim to `solve-milestone "<milestone-title>"`.

**This is a skill invocation, not a shell command.** `/milestone-driver:solve-milestone` is invoked as a Claude Code skill (the same way `create` runs `plan` first on the absent path) — there is no bash/pwsh form to ship for the invocation itself. The `autoHandoff` value is already in hand from Step 0; this step needs no additional config read.

**Multi-milestone roadmap note (Step 1R).** When a **roadmap manifest** drove the deploy (Step 1R, multi-milestone path), this single-plan handoff is **not** auto-fired across the roadmap. `create`'s roadmap responsibility ends at deploying all N milestones and recording each one's `build order: milestone X of N` line — which is exactly the cross-milestone order the driver reads. A roadmap deploy therefore completes by reporting the N deploy receipts and the recorded build order; starting the build stays a human call. The single-plan handoff above (Gates 1–3, `autoHandoff`) is **unchanged** for the N=1 / no-manifest path.
