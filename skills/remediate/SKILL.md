---
name: remediate
description: >-
  This skill should be used when the user invokes "/milestone-feeder:remediate <issue-number>", or asks to "fix the issue the driver blocked", "apply the triage findings to this issue", or "turn this triage comment into a corrected issue body". Corrects one GitHub issue body against the driver's recorded triage findings, editing the text each finding names in place.
---

# remediate: a driver triage Blocker → a corrected issue body

Resolve one issue, take the driver's last `🔴 Triage` comment as the authoritative finding set plus every `🟢 Resolved` edit, dispatch the `remediator` agent once for a corrected body, verify mechanically that each superseded span is gone, then show the diff and patch the body. `milestone-driver:triage` posts that comment and never edits the issue body or its labels, so the findings sit there as a durable handoff with **no consumer that turns them back into a buildable body**; `remediate` is that consumer.

`remediate` **edits the text a finding names, IN PLACE**. Appending a correction section that restates a constraint on unedited text is the **named failure mode this verb exists to prevent**: it leaves two live statements for one decision, and the driver's next triage pass reports that contradiction as a fresh Blocker (observed on `milestone-driver` issues #374 and #376). After a run the body carries **exactly one statement per decision**, and the superseded statement is **gone**, not merely superseded in prose.

A finding that cannot be resolved without a product or architecture decision is **parked, never guessed** (`.project/design-philosophy.md#One-way doors`), and the issue stays parked with it. Partial remediation is valid: the correctable findings are applied and the rest are reported. **No flags**: the only argument is a bare issue number, and one run remediates one issue. It authors no code, opens no PRs, never touches branches; the dispatched agent is read-only and the skill performs the one GitHub write itself, so the agent-read-only invariant holds (`.project/design-philosophy.md#Layering & boundaries`).

## Announce first

Say this to the user before doing any work:

> Standing by while I remediate issue #<n>. I'll read its triage comments, then correct the text each finding names in place: never by appending a correction section, because that is what turns one Blocker into a contradiction Blocker. Before I write anything I'll check that the superseded wording is actually gone from the corrected body, then show you the diff and patch the issue body. Any finding that needs a product or architecture call from you stays parked: I'll list it and leave your labels alone. If the body already matches the recorded corrections, this is a no-op: I'll say so and write nothing.

## Procedure

### Step 0: Read config + run the notices (best-effort)

Read `.milestone-config/feeder.json`. **Absent → invoke `milestone-feeder:setup`** (it bootstraps the profile, aligns the label taxonomy, and returns control), then continue: the user does not re-run the command (`skills/setup/SKILL.md` Phase 5). The one own-key `remediate` consumes is `projectDocs` (default `.project/`, the same key `plan` resolves at `skills/plan/SKILL.md` Step 0), read best-effort and handed to the agent as standing-docs grounding. An absent or unreadable path degrades to no grounding, never an error (`.project/design-philosophy.md#Error & failure philosophy`). Beyond that, `remediate` needs GitHub read access plus the single body write at Step 5.

**Run `remediate`'s one-time Step-0 notices.** From the repo root, run the notice emitter once: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/emit-notice.sh" remediate` on a host with bash, `pwsh -NoProfile -File "${CLAUDE_PLUGIN_ROOT}/scripts/emit-notice.ps1" remediate` on a Windows host without one. It walks `scripts/emit-notice.json` **in file order**, selects every unit whose `skills` list names `remediate`, and for each performs the marker gate, the trigger check, the print, and the marker write in one step. Never re-type a notice as free-form agent text. What each unit says, when it fires, and why is recorded at `docs/one-time-notices.md (How each skill runs this file)`. **No unit currently names `remediate`**: the discovery notice for this verb rides `plan` and `update`, where existing users already work, so this call selects nothing today and picks up whatever a later release adds. The emitter is **best-effort** and never aborts the run; read-only except the `.runtime/` dir and the marker. A bash host without `jq` emits nothing; a missing script, an unusable data file, or a malformed unit is **skipped for that entry only**.

### Step 1: Resolve the issue

A **bare issue number is the only argument form**. Fetch the issue and everything the findings live in:

```
gh issue view <n> --json number,title,body,labels,comments,milestone
```

| Result | Action |
|---|---|
| **Found** | Hold the live `body` verbatim: it is the diff baseline (Step 5) and **the string every `superseded_span` must be found in** (Step 4, check (a), leg 1). Hold the `labels` too: they carry the freshness signal (Step 2). |
| **Not found** | 🔴 **ERROR-AND-STOP.** Print `🔴 remediate: no issue #<n> in this repo: remediate corrects an EXISTING issue and creates none.` and end the run, mirroring `update`'s milestone-not-found register (`skills/update/SKILL.md` Step 3b). |

### Step 2: Collect the findings

From the fetched comments, in one pass:

- **The finding set.** Every comment whose body opens with the byte-fixed `🔴 Triage` opener (`milestone-driver/skills/triage/SKILL.md` Step 6). `gh` returns comments oldest-first and the driver may post one per triage pass, so take the **LAST** one: it is the authoritative set. Its structured gap rows are the findings, one per row. The driver renders each row as lens/type, **Blocker**, evidence, what clears it: the **Blocker** cell is the finding's identity and the string to carry verbatim; the *what clears it* cell is what the correction must satisfy.
- **The recorded corrections.** The `🟢 Resolved` comment when one exists (`milestone-driver/skills/output-style.md (Resolved comment)`). Each row's **the edit a builder applies** cell is a correction to apply in place, on the same terms as a finding. **At most one such comment ever exists, and it is not a complete record**: the driver posts it only when no prior comment on the issue opens with that marker, and accepts that a later run's newly-dropped Blocker posts no second one (`milestone-driver/skills/triage/blocker-resolver-dispatch.md (Unparking)`). Read it when present; never read its absence as proof that nothing was resolved.

**Freshness: the park label is the signal, and it is one-directional.** A `🔴 Triage` comment is never deleted, so its presence proves only that triage once found a Blocker. The live park label is what says the finding still stands: the driver's triage recommends `needs design` or `needs decision` per parked issue and the caller applies it (`milestone-driver/skills/triage/SKILL.md` Step 6, the recommended-label routing), and a human clears it when the issue is ready.

| Label state | Reading |
|---|---|
| `needs design` or `needs decision` present | The findings stand. Proceed. |
| Neither present | Print `remediate: issue #<n> carries no park label: its triage findings may already be settled` and **proceed anyway**. Absence is **not** proof of staleness: a standalone `/milestone-driver:triage` run applies no label at all (`milestone-driver/skills/triage/SKILL.md` Step 6, "triage does NOT apply labels"), so a hard stop here would break the manual path. A genuinely settled issue costs nothing: every already-corrected finding returns `ALREADY_APPLIED` (Step 3) and the byte-identical diff-gate (Step 5) writes nothing. |

`blocked` is not a triage finding: the driver derives it from the dependency graph at loop time, so it never makes a finding fresh or stale.

| Collected | Action |
|---|---|
| **At least one `🔴 Triage` comment OR a `🟢 Resolved` comment** | Proceed to Step 3. Whether a given edit is **already applied** is deliberately **not** decided here: it is decidable only against the body, which is the agent's job (`ALREADY_APPLIED`, Step 3), and Step 5's byte-identical gate is the backstop that makes a fully-applied issue a no-op. |
| **Neither** | **NO-OP**: perform **ZERO** `gh` writes and **SAY SO**: `remediate: issue #<n> carries no triage findings to apply: nothing to remediate (no-op)`. End the run. |

### Step 3: Dispatch the remediator agent

Dispatch `milestone-feeder:remediator` (`agents/remediator.md`) **once per run, plus at most ONE bounded re-dispatch**: either because the dispatch itself failed (below) or because Step 4's verification failed. Never a third attempt, and never two agents in flight. Brief it with the issue body verbatim, the Step-2 finding rows, the `🟢 Resolved` edits, and the resolved `projectDocs` root.

It returns the structured `ISSUE` / `FINDINGS` / `CORRECTED_BODY` block its own output format defines: per finding a `status` of `CORRECTED`, `ALREADY_APPLIED`, or `NEEDS_HUMAN`, plus the `superseded_span` and `replacement` that make the first two verifiable.

| Dispatch outcome | Action |
|---|---|
| **A parseable block** | Proceed to Step 4. |
| **Empty, or the returned text does not parse as the block** | **Re-dispatch ONCE**, re-feeding the **identical** brief plus which check failed, mirroring `plan`'s bounded per-dispatch retry (`skills/plan/SKILL.md` (Per-dispatch verify + one bounded retry)). Both attempts are same-run, immediate re-dispatches of the same agent. |
| **Still empty or unparseable** | 🔴 **STOP and write NOTHING.** Report the failure and leave the issue exactly as it was. |

The agent is **read-only**: it reads the repo and the standing docs to ground a correction, writes no file, and touches nothing on GitHub. Every GitHub write in this procedure is performed by this skill (`.project/design-philosophy.md#Layering & boundaries`). There is deliberately **no `remediatorAgent` override key** in `feeder.json`: a profile key is added only when a real consumer needs one (`SPEC.md` §7; `.project/design-philosophy.md#One-way doors`).

### Step 4: Verify mechanically, before any write

Run these checks over the returned block, the **live** body from Step 1, and the returned `CORRECTED_BODY`. Every one is a **string search decidable from text this skill already holds**. None of them re-judges the agent's reasoning:

| Check | Scope | What must hold |
|---|---|---|
| **(a) The span was real, and is gone** | each `CORRECTED` finding | **Both legs.** The `superseded_span` is a **literal substring of the LIVE body** (leg 1: it names text that actually existed), AND it is **literally ABSENT from `CORRECTED_BODY`** (leg 2: it was removed, not merely written around). Leg 1 is what stops a paraphrased or invented span from clearing this step vacuously against an unchanged body. |
| **(b) The replacement landed, exactly once** | each `CORRECTED` finding | The `replacement` occurs in `CORRECTED_BODY` **exactly once**. Zero occurrences is "deleted the old text and inserted nothing"; two is the decision restated twice. |
| **(c) No correction section was added** | whole body | No heading the corrected body adds at **any depth** (`#` through `######`) carries the correction-naming vocabulary: correction, addendum, update, erratum, clarification (match case-insensitively). Depth matters: a `### Correction` nested under an existing section is the same defect as a top-level one. |
| **(d) No section was dropped** | whole body | Every heading present in the live body is still present in `CORRECTED_BODY`. A correction removes superseded **text**, never a whole section the findings did not name. |
| **(e) Already-applied claims are true** | each `ALREADY_APPLIED` finding | The `superseded_span` is **absent from the LIVE body** AND the `replacement` is **present in the LIVE body**. A finding meeting neither is not already applied, and the claim fails. |

**What check (b) does and does not guarantee.** It is the mechanical proxy for AC3's one-statement-per-decision rule, and it catches the two shapes that actually occur: the superseded text surviving (caught by (a) leg 2) and the replacement appearing twice. It cannot catch a decision restated a third time in wholly new words: that is the agent's contract rule 3 (`agents/remediator.md (## The contract)`), enforced by the agent, re-read by the human at the Step-5 diff. This step does not claim to decide it.

**A finding whose fix needs a new section.** "Record the design decisions this issue never states" is a legitimate Blocker whose correction adds the section the issue-body template names (`## Design (recorded, consistent)`). That heading carries no correction vocabulary, so it passes (c) and is the correct fix. What (c) refuses is a section named for the correction itself. A finding that cannot be resolved except by such a section has no in-place edit available, and the agent returns it `NEEDS_HUMAN` rather than burning the run.

| Outcome | Action |
|---|---|
| **All checks pass** | Proceed to Step 5. |
| **Any check fails** | **Re-dispatch the agent ONCE** (the same bounded retry Step 3 allows, never a second one), briefed with the failing check and the span that proves it. |
| **Still failing after the re-dispatch** | 🔴 **STOP and write NOTHING.** Print the failing check and the span, and leave the issue exactly as it was. Never PATCH an unverified body. |

### Step 5: Diff-gate the write

| Case | Action |
|---|---|
| **Corrected body byte-identical to the live body** | **NO-OP**: perform **ZERO** `gh` writes and **SAY SO**: `remediate: issue #<n> already matches the recorded corrections: nothing to remediate (no-op)`. This is the steady state of a re-run, where every finding came back `ALREADY_APPLIED`. |
| **They differ** | **ANNOUNCE-THEN-WRITE.** Print a unified-style diff of the live body → the corrected body (changed hunks only), **THEN** apply it. **NEVER a silent clobber**, the same discipline as `update`'s body patch (`skills/update/SKILL.md` Step 4). |

Write the corrected body to a temp file and pass it by path:

```
gh issue edit <n> --body-file <path>
```

**`--body-file`, never `--body`.** A corrected issue body is always multi-line and routinely carries backticks and `$`, and there is **no shell-quoting path for a multi-line body**: this is the same reason `create` writes every issue body from a file (`docs/create-deploy-sequence.md (no shell-quoting path for a multi-line body)`). Identical bytes land on GitHub either way; only one of them survives the shell.

`gh issue edit <n> --body-file` is the **only** GitHub write in this procedure.

### Step 6: Report

Report in three parts, concise, table form. Each status gets its own line, and **only the third one speaks about parking**:

- **Corrected**: one row per `CORRECTED` finding, naming the decision it settled and the superseded wording removed.
- **Already applied**: one row per `ALREADY_APPLIED` finding, naming the finding and where the correction now lives. These are findings an earlier run corrected. They re-appear on **every** later run because `remediate` posts no comment and clears no label, so the `🔴 Triage` comment outlives the fix and Step 2 keeps re-reading it. **This line never says the issue is parked**, and an issue whose findings are all `ALREADY_APPLIED` is reported as already remediated, not as blocked.
- **Needs human**: one row per `NEEDS_HUMAN` finding, carrying the agent's reason. **The issue STAYS PARKED and the report says so**, and this is the **only** line that makes that claim. `remediate` never guesses a product or architecture call.

**`remediate` NEVER touches labels.** Clearing a park label and re-running the driver's triage is human-owned: the person who made the call is the person who decides the issue is ready. Partial remediation is a valid outcome, so a run that corrected some findings and parked others reports both and leaves the labels alone.

## IDEMPOTENCY: the explicit contract

This is the keystone behavior. It holds by construction, from the diff-gate at Step 5 and the collect gate at Step 2:

| Condition | Behavior |
|---|---|
| The issue carries **no `🔴 Triage` comment and no `🟢 Resolved` comment** | **NO-OP** at Step 2: the agent is never dispatched, **ZERO** `gh` writes, and `remediate` says so. Presence, not applied-ness, is what Step 2 decides: applied-ness is the agent's call and Step 5's gate is the backstop. |
| The corrected body is **byte-identical** to the live body | **NO-OP** at Step 5: no `gh issue edit`, no diff, and `remediate` says so. |
| Re-running `remediate` on an issue it just corrected | A **no-op** by construction, and the **normal steady state**: the `🔴 Triage` comment survives the fix, so the same findings are re-read, each returns `ALREADY_APPLIED` (its span gone from the live body, its replacement present), the corrected body equals the live one, and Step 5 writes nothing. The report says already applied, **not** parked. |
| Re-running against an issue whose findings are **all `NEEDS_HUMAN`** | A **no-op** for the body: nothing is correctable, the corrected body equals the live one, and the run re-reports the same parked findings. |
| A **new** `🔴 Triage` comment landed since the last run | Step 2 takes the LAST comment, so the new finding set is the one remediated. A finding it repeats from the previous pass returns `ALREADY_APPLIED` and writes nothing. |

**Honest bound (the triage comment outlives the fix).** Nothing on the issue records that a finding was remediated: `remediate` posts no comment and clears no label, and triage never deletes its own. `ALREADY_APPLIED` is what keeps that survivable, and it is decided from the body alone (span gone, replacement present), so it is exact only while the corrected text stands. A later hand edit that rewrites a replacement out of the body puts the finding back in the ambiguous zone: the span is gone but so is the replacement, which is neither corrected nor already applied, and the agent returns `NEEDS_HUMAN` naming the missing text rather than inventing a target. Correct the issue through this verb, or re-run the driver's triage after a hand edit, so the findings and the body describe the same text.

## Output style

Defined once at `docs/style-contracts.md#output-style`: read it there; it is not restated here.

## Non-negotiables

- **Edit the named text IN PLACE; never append a correction section.** A correction section that restates a constraint on unedited text is the failure mode this verb exists to prevent: it leaves two live statements for one decision, which the driver's next triage reports as a contradiction Blocker. Step 4's check (c) fails the run mechanically, at any heading depth, rather than trusting the intent.
- **The superseded text is GONE, and it was real.** Both legs are string searches (Step 4, check (a)): the span existed in the live body, and it is absent from the corrected one. **One statement per decision** is enforced mechanically only to the extent check (b) reaches it (the replacement appears exactly once); the full semantic rule is the agent's contract, re-read by the human at the Step-5 diff. This skill does not claim to decide it.
- **Park, don't guess.** A finding that needs a product or architecture decision returns `NEEDS_HUMAN` and stays parked, mirroring the issue-author's refusal to invent product scope (`agents/issue-author.md (## What you refuse)`). Partial remediation is valid: the correctable findings still land.
- **One GitHub write, and only after verification.** `gh issue edit <n> --body-file` is the entire write-set: no labels, no comments, no milestone writes. A failed Step-4 check after one re-dispatch stops the run with the body untouched.
- **Idempotent: nothing to apply, or nothing differs → zero writes, and `remediate` says so.** See the explicit `## IDEMPOTENCY` contract above.
- **Labels stay human-owned.** Clearing a park label and re-running the driver's triage is the user's call, never this skill's.
- **No flags, one issue per run.** `remediate` is a verb taking a bare issue number; there is nothing else to argument-parse.
- **Reads the driver's triage output, never changes it.** `milestone-driver:triage` stays read-only and this skill consumes what it posted; `remediate` posts no comment of its own and re-runs no triage.
- **Authors no code, opens no PRs, never touches branches.** Editing one issue body is not code, a PR, or a branch. The dispatched agent is read-only against provided text and the repo; the skill performs the one `gh` write itself, so the agent-read-only invariant holds.
