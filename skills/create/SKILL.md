---
name: create
description: This skill should be used when the user invokes "/milestone-feeder:create <brief>", or asks to "create the milestone", "deploy the approved plan", or "build the milestone and issues". Deploys the plan you approved to GitHub — labels, the milestone, every issue, and the build order — trusting the review the plan file already recorded; it does NOT re-check or re-plan. If you have no plan file yet for this brief, it runs `plan` first to make one, then deploys. No flags. Authors no code; opens no PRs.
---

# create — deploy the approved plan to GitHub (read-the-plan, faithful)

Resolve the plan file `plan` wrote for this brief (by the same deterministic slug), then deploy **exactly it** to GitHub: ensure the labels, create-or-adopt the milestone by its exact title, open each surviving issue, rewrite the local slug references to real issue numbers, PATCH the build-order description onto the milestone, and file the needs-input report. The deploy step of the feeder pipeline: where `plan` *compiles* the plan file, `create` *deploys* it.

`create` is **faithful** — it builds what you approved. On the found path it does **NOT** re-dispatch the architect or the issue-author, and does **NOT** re-run the self-check gate (the reviewer). The plan file already recorded the gate-surviving issue set and its verdict; `create` trusts that verdict and writes the recorded issues — it regenerates nothing (`docs/specs/v0.3.0-humanize-the-surface.md` §4: *"on the found path, `create` does not re-dispatch the architect / issue-author, and does not re-run the self-check gate"*). The only path that runs the gate from `create` is the run-`plan`-first fallback (the plan file was absent, so there is nothing yet to deploy). **No flags** — `create` *is* the write verb of the plan/create pair; there is nothing to argument-parse (`docs/specs/v0.3.0-humanize-the-surface.md` §2: zero flags anywhere). Authors no code, opens no PRs, never touches branches; every dispatched agent — only on the run-`plan`-first fallback — stays read-only against provided text. The GitHub writes are performed by the skill itself via `gh`, so the agent-read-only invariant holds.

## Announce first

Say this to the user before doing any work — pick the line that matches the resolution outcome (the plan file was found, or it was absent):

> **Plan file found:** Standing by while I deploy the approved plan to GitHub — I'll ensure the labels, create-or-adopt the milestone, open each issue, rewrite the slug references to real numbers, and PATCH the build order. I'm deploying **exactly the plan you approved** — I trust the review it already recorded and re-check nothing.

> **No plan file yet:** I don't have a plan file for this brief, so I'll run `plan` first to make one (it reads your project docs, breaks the idea into issues, and checks each against your conventions), then deploy that plan to GitHub.

## Procedure

### Step 0 — Read config (best-effort)

Read `.milestone-config/feeder.json`. **Absent → invoke `milestone-feeder:setup`** (it bootstraps the profile, aligns the label taxonomy, and returns control), then continue — the user does not re-run the command (`skills/setup/SKILL.md` Phase 5). `create` reads the same own-keys as `plan` (`projectDocs`, `reviewer`, `architectAgent`, `issueAuthorAgent`, `issueSize` — `skills/plan/SKILL.md` Step 0); on the found path it consumes **none** of them (it deploys the recorded plan and regenerates nothing), and on the run-`plan`-first fallback `plan` itself consumes them. The only configuration `create` itself needs is GitHub write access (the `gh` surface in the passes below).

**`create` additionally reads its own `autoHandoff` key** (Step 4 — the driver handoff). This is the one own-key `create` consumes on **both** paths (it is not a `plan` key). Extract it with its bundled default, same absent-means-default discipline as the `plan` key-extraction table (`skills/plan/SKILL.md` Step 0; `docs/profile-schema.md`):

| Key | Default | Use |
|---|---|---|
| `autoHandoff` | `"prompt"` | After the deploy, whether `create` offers to hand the milestone to `milestone-driver` to start building (Step 4). `"prompt"` → ask (default); `"auto"` → kick off immediately, no prompt; `"off"` → never offer. An **unrecognized value** (anything that is not exactly `"prompt"`, `"auto"`, or `"off"`) is treated as the default `"prompt"` — mirrors how `versioning` treats an invalid value as absent (`docs/profile-schema.md` `versioning` per-key note); never error on the key. |

### Step 1 — Resolve the plan file for the brief

Derive `<slug>` **deterministically** from the one-line milestone goal of the brief, using the **same derivation `plan` uses** (`skills/plan/SKILL.md:262`): lowercase the goal, replace every run of non-alphanumeric characters with a single hyphen, strip any leading/trailing hyphen, and cap the length at the same bound (trimming a trailing hyphen if the cut lands on one). The same brief always resolves to the same path:

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

The plan file is the **load-bearing build artifact** — `create` reads it and writes GitHub from it, regenerating nothing (`docs/specs/v0.3.0-humanize-the-surface.md` §3). Parse every field below by name (the format is `skills/plan/SKILL.md` Step 7; the field requirements are its plan-file-contract table and `docs/specs/v0.3.0-humanize-the-surface.md` §3):

| Plan-file field | What `create` reads it for |
|---|---|
| **Milestone title (exact)** | The load-bearing identity field — `create` resolves the milestone by THIS exact string (pass b). Distinct from the one-line goal (descriptive only). |
| **Milestone description (Wave order)** | The Step-5 build-order description, verbatim, with **local slugs** (`#A`/`#B`). `create` rewrites the slugs to real `#n` and PATCHes it onto the milestone (pass d). |
| **Per surviving issue** — slug, title, the FULL §4 `ISSUE_BODY` verbatim, labels (`ui`\|`logic` + `risk:*`), surface/risk | The issues to create — read verbatim, **no regeneration** (pass c). Only the **surviving** (gate-clean / Advisory-only) issues in the plan file's `## Issues` section are created. |
| **Parked issues** — read from the **bracketed marker on the `### #X — <title>` heading** (`[parked — needs product input]` or `[parked — needs human direction …]`, `skills/plan/SKILL.md` Step 7 format), not a discrete `kind:` field | Marked in the plan file, **NEVER created**. Routed to the needs-input report (pass e). |
| **Dropped issues** — read from the **bracketed marker on the `### #X — <title>` heading** (`[dropped — depends on parked #X]`, `skills/plan/SKILL.md` Step 7 format) | Marked in the plan file, **NEVER created** (a dependent of a parked issue can't build). |
| **Self-check verdict** — the plan file's `Self-check:` line (the literal label `plan` writes, `skills/plan/SKILL.md` Step 7) | `create` reports its recorded token (PASS / INTERNAL / PARKED / SKIPPED(reviewer:false)) and **trusts it — no re-vet** (`docs/specs/v0.3.0-humanize-the-surface.md` §4). |
| **Source brief reference** — `inline` \| `file:<path>` \| `epic #<n>` | Drives the report routing (pass e). An `epic #<n>` reference is the `epicIssueNumber` for the epic-comment branch. |

`create` does **not** re-derive any of these — it does not re-dispatch the architect for the candidates, the issue-author for the bodies/labels, or the reviewer for the verdict. It reads the recorded values and deploys them.

### Step 3 — Deploy (the write sequence, in this fixed order)

This is the v0.2.0 apply write-sequence, moved wholesale into `create` and preserved verbatim — only the **source** of the issue bodies / labels / waves / milestone title / verdict / source-brief reference changes: `create` reads them **from the plan file** (Step 2), it regenerates nothing (`docs/specs/v0.3.0-humanize-the-surface.md` §3: *"What changes is only the source of the issue bodies/labels/waves: read from the plan file, not regenerated"*; §4: the write sequence is *"unchanged"*). All `gh` invocations below are run **by the skill itself**, not by any dispatched agent — the agent-read-only invariant holds. The commands are shell-neutral (`gh` is cross-platform); where a read-modify-write needs a variable, both a bash and a PowerShell 7+ form are given, consistent with the rest of the suite.

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

- **Field shape.** Exactly one labeled line, a **sibling to the plan file's existing header lines** (`Milestone title (exact):`, `Self-check:`, `Source brief:` near the top — the format block at `skills/plan/SKILL.md:282-288`):

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

Create **only the SURVIVING** issues recorded in the plan file's `## Issues` section — the gate-clean / Advisory-only, **non-parked, non-dropped** issues (Step 2). **Parked and dropped issues recorded in the plan file are NEVER created** (the report still routes the parked ones at pass e; dropped dependents are simply omitted).

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

#### e. File the needs-input report

The plan file records the **Source brief reference** (`inline` \| `file:<path>` \| `epic #<n>`) and its `## Needs human input` pointer (Step 2). Route the report whenever the plan file's `## Needs human input` section points to a report (its pointer is NOT "none") — equivalently, whenever the plan recorded **any product gap OR any parked issue** (`skills/plan/SKILL.md` Step 7 writes that pointer under the broader condition: `productGaps[]` non-empty OR the self-check parked any issue; a carried-forward product gap can set it with zero parked issues). Route by the recorded brief form. The report **body already exists** in the `plan` run's output (`.milestone-feeder/needs-product-input-<slug>.md`, `skills/plan/SKILL.md` Step 7); `create` **routes** it — it does not regenerate the gaps:

| Brief form (from the plan file's Source brief reference) | Where the report goes |
|---|---|
| **GitHub epic issue** (`epic #<n>` recorded) | Post the report as a **comment on the epic issue:** `gh issue comment <epicIssueNumber> --body "<report>"`. |
| **File path / inline text** (no epic) | Write / keep the **local file** `.milestone-feeder/needs-product-input-<slug>.md` and **PRINT a notice** that the report is local (no epic issue to comment on). |

Before writing the local report, ensure the scratch dir self-ignores (it normally already does — `plan` wrote the plan file under `.milestone-feeder/` and ensured `.milestone-feeder/.gitignore` contains `*`; `skills/plan/SKILL.md` Step 7): create `.milestone-feeder/` if absent and ensure `.milestone-feeder/.gitignore` contains a single `*` line, so the report is git-invisible in the consumer repo with zero user setup.

If the plan file's `## Needs human input` pointer is "none" (no product gap and nothing parked), there is no report to route — say so and skip this pass.

### Step 4 — Offer the driver handoff (clean-run only)

After the deploy completes (Step 3), `create` can hand the freshly-built milestone straight to `milestone-driver` to start building — instead of ending the run and leaving the user to invoke the driver themselves. This is **build-kickoff only**; it invokes `/milestone-driver:solve-milestone "<milestone-title>"`, which builds to the integration branch and **never** crosses the release boundary (Gate 3 below). The behavior is governed by the `autoHandoff` key (Step 0) and three gates that must **ALL** hold to offer the handoff. (Resolved design: issue #148, 2nd comment — Ken, 2026-06-24.)

**Gate 1 — clean run only (no gaps/parks AND the self-check actually ran).** Offer the handoff **only** when **BOTH** conditions hold:

  1. **No gaps/parks** — the plan file's `## Needs human input` pointer is **"none"** (the exact same signal pass (e) reads, `skills/create/SKILL.md` pass e, line ~232, to decide whether to route a report): no product gap AND nothing parked/dropped.
  2. **The self-check actually ran** — the plan file's `Self-check:` verdict (already read at Step 2; the plan-file contract row) is a **real PASS or INTERNAL** verdict, **NOT** `SKIPPED(reviewer:false)`. A `reviewer: false` run **skips the self-check gate entirely** — its issues are explicitly **NOT vetted** against the driver's entry gate (`plan` records `SKIPPED(reviewer:false)` with a visible 🔴 warning; `skills/plan/SKILL.md:470`, `docs/architecture.md` reviewer-backends table). Such a run can have no product gaps and nothing parked → pointer "none" → it would otherwise read as "clean" while harboring exactly the **unsurfaced** gaps the gate exists to catch. So a `SKIPPED(reviewer:false)` verdict is a **Gate 1 fail**.

If **either** condition is not met — any candidate was parked / flagged / blocked (the pointer is NOT "none"), **OR** the self-check was skipped (`SKIPPED(reviewer:false)`) — **do NOT offer the handoff**; the existing gap-surfacing / reviewer-skipped behavior stands unchanged (pass e routes the gaps as today; the 🔴 reviewer-skipped warning already stands), and `create` ends as it does today. Handing a milestone with known gaps — or with issues that were never vetted — to an unattended build loop would build past the very gaps the feeder exists to surface; the clean-run gate (no gaps/parks AND the self-check ran) is what keeps the human in the loop.

**Gate 2 — driver installed (else silently skip).** Detect whether `milestone-driver` is available in this session using the **same convention the feeder already uses** for the optional driver soft-dependency: attempt the invocation and treat "does not resolve (no such skill / agent in the session — `milestone-driver` not installed)" as **absent** (`skills/plan/SKILL.md:472` — the runtime degrade-to-internal trigger: a dispatch that does not resolve = the agent is not installed; `docs/consumer-setup.md:17-20` — the optional `milestone-driver` soft-dependency **degrades silently** when absent). For the handoff, the cleanest detection is: **does `/milestone-driver:solve-milestone` resolve in this session?** If it does **NOT** resolve, **silently skip** this step — **no prompt, no error, no notice** — exactly as the optional soft-dependency degrades silently elsewhere. The handoff is a convenience on top of a clean deploy; its absence is not a failure.

**Gate 3 — never crosses the release boundary.** The handoff invokes `/milestone-driver:solve-milestone "<milestone-title>"`, which **only merges to the integration branch** (`develop`) and never to the protected branch (`main`). Release (`integrationBranch` → `protectedBranch`), closing the GitHub milestone object, and deploy stay **manual and human-only** — that boundary is what makes unattended operation safe (`milestone-driver/skills/solve-milestone/SKILL.md:11` — the "Bounded blast radius" note: "merges only to `integrationBranch`, never to `protectedBranch`. Release … and deploy stay manual and human-only"). `create`'s handoff is **build-kickoff only**: it does not auto-merge to a protected branch, does not remove the release gate, and `develop → main` stays a manual human call. `solve-milestone` already enforces this; the handoff simply invokes it.

**Behavior by `autoHandoff` (Step 0):**

| `autoHandoff` | When gates 1 + 2 hold | When gate 1 OR 2 fails |
|---|---|---|
| `"off"` | **Never offer**, no prompt — skip this step (today's no-handoff behavior). | Skip this step (no-op either way). |
| `"prompt"` (**default**) | **Ask:** *"milestone-driver is installed — start building this milestone now, or review it first?"* → **yes** invokes `/milestone-driver:solve-milestone "<milestone-title>"`; **no** stops (today's behavior). | **Do not offer** — Gate 1 fail (gaps/parks present, **OR** `SKIPPED(reviewer:false)` — the issues were never vetted): surface the gaps as today (pass e); the 🔴 reviewer-skipped warning already stands. Gate 2 fail: silently skip (no prompt, no error). |
| `"auto"` | **Invoke immediately**, no prompt: `/milestone-driver:solve-milestone "<milestone-title>"`. Print a one-line notice for legibility — `create: clean run — handing "<milestone-title>" to milestone-driver to start building (autoHandoff: auto)`. (Driver-side precondition: see the numeric-title caveat below.) | **Do not invoke** — Gate 1 fail (gaps/parks present, **OR** `SKIPPED(reviewer:false)` — the issues were never vetted, so auto-firing would build past un-vetted design): surface the gaps as today (pass e); the 🔴 reviewer-skipped warning already stands. Gate 2 fail: silently skip. |

**Numeric-title caveat (`"auto"` defers to the driver's own preconditions).** `autoHandoff: "auto"` kicks off the driver with no prompt, but it does **not** override the driver's own entry preconditions. If the deployed milestone title is **purely numeric**, `/milestone-driver:solve-milestone` **halts and prompts the human for a rename** regardless of `autoHandoff: "auto"` — it interprets a bare number as single-issue mode and refuses to drive a numeric-titled milestone unattended (`milestone-driver/skills/solve-milestone/SKILL.md:86` — "if it is purely numeric, halt immediately and prompt the human … do not proceed to Phase 0"). So auto mode's "no question asked" contract ends at the driver boundary: auto kicks off the driver, but the driver enforces a non-numeric-title precondition for unattended operation. This is **narrow** — a feeder-deployed milestone normally carries the user-owned semver in its title (non-numeric), so the caveat rarely bites; no special handling is added here, the doc is simply honest that auto defers to the driver's preconditions.

**The exact milestone title.** The invocation passes the **exact** `Milestone title (exact)` line from the plan file — the same identity string `create` deployed at pass (b) (Step 2; the plan-file `Milestone title (exact)` field). Never a re-derived or goal-derived name — the title carries the user-owned semver and is the handle the driver resolves the milestone by. Pass it verbatim to `solve-milestone "<milestone-title>"`.

**This is a skill invocation, not a shell command.** `/milestone-driver:solve-milestone` is invoked as a Claude Code skill (the same way `create` runs `plan` first on the absent path) — there is no bash/pwsh form to ship for the invocation itself. The `autoHandoff` value is already in hand from Step 0; this step needs no additional config read.

### Partial-failure path (resume on re-run)

A `create` run is **not "done"** until the milestone description AND every created-issue body carry real `#n` numbers. A failure can land in pass (c) (an issue create) or pass (d) (a body edit or the milestone-description PATCH); the table below maps each to its action. **Pass (d) is IDEMPOTENT** — re-applying the slug→`#n` rewrite to an already-numeric body or description is a no-op (the substring-safe rule finds no slug to rewrite), and the PATCH overwrites — so a re-run can always safely re-execute pass (d) against the captured (or re-derivable, from the now-complete title→`#n` map) slug→`#n` map, **even when pass (c) created nothing** because every issue was already adopted by title.

| Failure point | Immediate action | Resume on re-run |
|---|---|---|
| **Pass (c)** — a `gh issue create` fails mid-loop | **Abort pass (d)** — the slug→`#n` map is incomplete; rewriting against it would write dangling references. **Report** what was created + the captured partial map + which candidate failed. | The adopt + match-by-title path (b → c) reuses the already-created issues by title (no duplicates), creates the remaining surviving issues, then runs pass (d) against the now-complete map. |
| **Pass (d), milestone-description PATCH** fails — after all issues were created | **Report** that the issues exist but the milestone description still shows local slugs; the description is unresolved. | Re-run re-executes pass (d): it rebuilds the slug→`#n` map from the adopted issues (match-by-title) and re-PATCHes the description (PATCH overwrites — idempotent). |
| **Pass (d), a `gh issue edit` (body rewrite)** fails — after all issues were created | **Report** which created issue still carries local slugs in its body. | Re-run re-executes pass (d): re-applying the rewrite to already-numeric bodies is a no-op, and the still-slugged body is rewritten and edited. Adopted (pre-existing) issue bodies are left as-is per the pass-(c) body policy. |

In all cases the failure path is **defined, not silent**, and re-running `create` always re-attempts pass (d) until the milestone description and all created-issue bodies carry real numbers — the resume re-uses the match-by-title de-dup (least-code).

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
