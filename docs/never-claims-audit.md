# Never-claims audit (skills/)

**What this is.** Brief item 4(b) asked: for every "never" claim in `skills/` that has no
gate and no passing scenario, either add a cheap gate or soften the wording to design
intent. The acceptance was a grep audit finding **each instance gate-backed, scenario-backed,
or softened**. This file records that classification so the map from claim to backing is
legible, and so nobody re-raises "N never-claims backed by one gate" without the breakdown.

**Scope.** The five skill procedures: `plan`, `create`, `update`, `build-roadmap`, `setup`.
Re-run the audit at any time:

```
grep -rniE '\bnever\b|\balways\b' skills/*/SKILL.md
```

That returns ~191 occurrences across ~113 lines (plan 40, update 32, create 19,
build-roadmap 12, setup 10 lines carrying "never").

## Finding

The brief's evidence line ("~132 never/always claims backed by exactly one mechanical gate,
`no-source-edit`") conflates **four different deterministic backings** with the one hook.
Classified against what actually enforces them, essentially every instance is already
gate-backed, code-path-backed, or scenario-asserted. The genuinely soft residual (a
behavioral promise leaning only on a fixture that has never executed) is small, lives inside
the skill prose that *issues* the directive (not a user-facing guarantee), and is already
disclosed as unrun in `tests/RESULTS.md`.

**Consequence for the remediation:** bulk inline softening is the wrong fix here. It would
(1) fight the per-file word ceilings items 1 and 10 of this same brief re-established,
(2) *understate* real code-path guarantees (softening "create-or-adopt never deletes" to
"instructed never to delete" is dishonest in the other direction: the write-set has no delete
operation at all), and (3) reword directives inside the very skills that issue them. The
honest deliverable is this claim-to-backing map plus the residual note below, not ~100 edits.

## Backing classes

| Class | What backs it | Representative instances | Disposition |
|---|---|---|---|
| **1. Write-path code fact** | The write-set is `gh` create / adopt / edit / PATCH only. No delete, close, or reopen operation exists in the sequence the skill runs itself. Verified: `grep -rniE 'gh (issue\|milestone\|api).*(delete\|close)' skills/create skills/update docs/create-deploy-sequence.md` returns no operation, only prose "delete nothing" and the not-found error path. | create "create-or-adopt NEVER deletes", "NEVER creates parked or dropped issues", "never duplicates"; update "NEVER closes, NEVER deletes", "never reopened", "adopt... never delete it or its issues"; setup "Always write the file" | **gate-backed** (deterministic; no LLM discretion) |
| **2. Hook-gated** | `hooks/no-source-edit.sh` / `.ps1` deny `Write\|Edit\|MultiEdit\|NotebookEdit` on `sourceGlobs` paths (exit 2), for the feeder's own actors. | plan / create / update "Authors no code, opens no PRs, never touches branches", "never edits a source file" | **gate-backed** |
| **3. Structural invariant** | Deterministic control flow of the Step-0 outer boundary and the inner-routine refactor. | plan "resolved ONCE at Step 0... NEVER re-resolves per invocation", "never re-enters Step 3.6 or 3.7 (no recursion)"; create / update "read the manifest (never regenerate it)"; the additive merge "the global reference is the FLOOR, never reduced... no removal path", setup overlay "can never remove a surface" | **gate-backed** (control-flow / no-op-by-construction) |
| **4. Error-philosophy branch** | The best-effort degrade behavior each step implements (`.project/design-philosophy.md#Error & failure philosophy`). | plan / create / update one-time notices "best-effort and never aborts", "skipped for that entry only, never a crash"; build-roadmap "surfaced, never silently dropped", "never leave a partial or corrupt manifest"; setup "never overwrite a user-edited .gitignore", "an absent overlay is never an error" | **gate-backed** (deterministic branch) |
| **5. Scenario-asserted behavioral claim** | A behavioral promise a dispatched agent (architect / issue-author) delivers, asserted by a `tests/scenarios/` fixture. | plan "Parks product gaps, never invents scope" / "Never guessed" (scenarios 02, 12); "read best-effort, never fabricated... never grounded on" (03); the flagship directive-holds-unweakened claim (06) | **scenario-backed**, with the standing caveat below |

## The residual (class 5) and its caveat

The class-5 claims are the only ones whose backing is behavioral rather than deterministic.
**Update (2026-07-06):** four class-5 fixtures were executed against the installed plugin with
the real agents dispatched (`tests/RESULTS.md` run record). Three load-bearing claims are now
**demonstrated** on the current pipeline: never-invents-scope (02, PASS), resolve-and-cite-not-
over-park (03, PASS), and directive-consistency-at-scale (06, PASS). The implied-surfaces claim
graded **PARTIAL** (12): the parking and anti-fixation behavior held, but companion surfaces
that already exist as app-wide infra were absorbed as grounded rather than marked `implied`
(tracked as #284). The remaining class-5 fixtures have not been run, so those claims stay
"scenario-*asserted*", not "scenario-*demonstrated*".

This is honest as written for two reasons:

1. These live in `SKILL.md`, which the executing agent reads as its **instruction**. "never
   invents scope" is the directive that produces the behavior, not a guarantee sold to a user.
   The user-facing versions live in the README and the agent frontmatter descriptions; the
   brief scopes the README out ("audited clean") and handles the agent descriptions in item 2.
2. `tests/RESULTS.md` already discloses, plainly, that these fixtures have not run.

**One instruction-only instance has no fixture at all:** plan Step 7 "Never fabricate" the
persisted original brief. It is already self-disclosing (it states its own fallback: "if the
brief text genuinely cannot be captured, omit the section rather than inventing one"), so it
reads as a directive with a stated failure mode, not an enforced guarantee.

**Follow-up (done 2026-07-06):** scenarios 02 / 03 / 06 / 12 were run against the installed
plugin and verdicts recorded in `tests/RESULTS.md` (brief item 4a). This upgraded three class-5
claims from asserted to demonstrated and surfaced the implied-surfaces PARTIAL (#284). The
remaining class-5 fixtures (and the six unrun scenarios generally) are the next candidates for
the same treatment when budget allows.
