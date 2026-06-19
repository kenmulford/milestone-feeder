---
name: setup
description: This skill should be used when "milestone-feeder:setup" is invoked directly, OR auto-invoked by `plan` when `.milestone-config/feeder.json` is absent. Guides an interactive first-run bootstrap that infers every profile key from repo signals, presents detected defaults with plain-language descriptions, lets the user accept/edit/skip optional keys (stating each skip-consequence), writes `.milestone-config/feeder.json`, aligns the issue-label taxonomy with the driver's, and returns control so the original task continues. Mirrors milestone-driver:setup.
---

# setup — first-run profile bootstrap

Generate or repair the feeder profile through a guided, inference-first flow. Every key is presented with a plain-language description and a detected default. Optional keys state their skip-consequence. No blank prompts — if a default cannot be inferred, an example is shown.

The canonical profile location is `<repo-root>/.milestone-config/feeder.json` — the suite-wide `.milestone-config/` directory the sibling `milestone-driver` plugin also reads from (it stores `driver.json` alongside). **Unlike the driver, the feeder has no required hard-stop key:** the feeder writes no branches and runs fully on bundled defaults, so an empty `{}` profile is valid (all defaults apply). Setup still writes the file — even when every key defaults — so config-presence detection (`plan`'s Step 0 → auto-invoke setup when the file is absent) is unambiguous.

**After writing the file, return control to the caller** (`plan`) so the original task continues immediately. The user does not need to re-run the command.

## When this runs

- **Auto-invoked** by `plan` when `.milestone-config/feeder.json` is absent (Step 0 of the `plan` procedure, `SPEC.md` §6).
- **Direct invocation** (`/milestone-feeder:setup`) when onboarding a new repo or repairing an existing profile.

## Procedure

### Phase 1 — Silent project-evaluation pass

Before asking anything, gather signals from the repo. Run these checks silently (no output to the user yet):

| Signal | Command / check | Drives |
|---|---|---|
| Project docs directory | `.project/` present at repo root? | `projectDocs` default `.project/`; if the standing docs live elsewhere, that path is the suggested value |
| Resolvable driver profile | `.milestone-config/driver.json` present, else legacy root `milestone-driver.json` present? | Confirms the shared keys the feeder reads (`uiSurfaceGlobs`, `integrationBranch`, the consumer's `sourceGlobs`) are available from the driver config (`SPEC.md` §7) — informational, not written into `feeder.json` |
| Reviewer availability | Does `milestone-driver:triage-reviewer` resolve in this session? | `reviewer` default `"milestone-driver"` when it resolves, else `"internal"` (degrade to the feeder's own checklist mirroring the five triage criteria, `SPEC.md` §5) |
| Existing profile | Read `.milestone-config/feeder.json` if present | Pre-fill any already-set keys (re-run handling below). If the file carries old key names, offer the courtesy migration below before pre-filling |

#### Courtesy migration — old key names → new (a notice, not a contract)

Earlier feeder profiles used four older key names. The skills now read **only** the new names — there is **no silent old-key fallback** in any skill body: an old key is either migrated here (with the notice below) or ignored, never honoured in place. When Phase 1 reads an existing `.milestone-config/feeder.json` that still carries any of these old keys, present this old→new mapping and offer to rewrite them to the new names in place. This is a courtesy, not a contract.

| Old key (in file) | New key (written) | Value handling |
|---|---|---|
| `substrateDir` | `projectDocs` | value carried over unchanged |
| `selfCheck` | `reviewer` | value carried over unchanged (`"milestone-driver"` \| `"internal"` \| `false`) |
| `issueSizeGuidance` | `issueSize` | value carried over unchanged |
| `decomposerAgent` | `architectAgent` | value carried over; if it is the old bundled default `"milestone-feeder:decomposer"`, update it to `"milestone-feeder:architect"` |

`issueAuthorAgent` and `sourceGlobs` are unchanged — leave them exactly as they are. Present the mapping as a simple accept/decline: on accept, rewrite the file with the new key names (preserving values per the table) and continue Phase 2 with the migrated values pre-filled; on decline, leave the file as-is and continue with the new-key defaults (the old keys are ignored, never silently honoured). No 🔴 — this is a plain accept-or-decline choice, not a blocking decision.

### Phase 2 — Tier-by-tier confirmation

Present keys in these tiers: **Core → Agents → Sizing**, plus the self-protection `sourceGlobs` key. Within each tier, show one key at a time (or a logical group). For every key:

- State the plain-language label.
- Show the detected default (or an illustrative example if none was detected).
- For optional keys: state the skip-consequence on the same line.
- Accept, edit, or skip — never leave a field blank without an explicit skip choice.

**No required hard-stop key.** Unlike the driver (whose Core keys `integrationBranch` / `protectedBranch` / `sourceGlobs` hard-stop), the feeder has **no** key that blocks the write. The feeder writes no branches and runs fully on defaults, so every tier below is acceptable as a one-keystroke accept-the-default. An empty `{}` is a valid result — and setup still writes the file regardless, so config-presence detection is unambiguous.

**Tier: Core** (optional; show the detected default — accept with one keystroke)

| Key | Plain-language label | Skip-consequence |
|---|---|---|
| `projectDocs` | "Where do your project's standing docs (vision, architecture, conventions) live? `plan` grounds issue authoring in them." | Skip → default `.project/` used at runtime. |
| `reviewer` | "Which reviewer checks each generated issue before any GitHub write? (Detected: `milestone-driver` if its reviewers resolve, else `internal`.)" | Skip → default `"milestone-driver"` (or `"internal"` when the driver's reviewers don't resolve); `false` disables the gate. |

**Tier: Agents** (optional; auto-filled with the bundled defaults — show, confirm, move on)

| Key | Plain-language label | Skip-consequence |
|---|---|---|
| `architectAgent` | "Which agent produces the issue breakdown + dependency graph? (Rarely changed — the bundled default is fine for most repos.)" | Auto-fill `"milestone-feeder:architect"` — show it, confirm, move on. Skip → bundled default used; key omitted. |
| `issueAuthorAgent` | "Which agent authors each issue's full spec? (Rarely changed — the bundled default is fine for most repos.)" | Auto-fill `"milestone-feeder:issue-author"` — show it, confirm, move on. Skip → bundled default used; key omitted. |

**Tier: Sizing** (optional)

| Key | Plain-language label | Skip-consequence |
|---|---|---|
| `issueSize` | "Any natural-language sizing rule the author should honour when splitting work? (e.g. `≤1 PR, ≤1 new screen`)" | Skip → "No sizing constraint beyond the procedure's defaults." |

**Self-protection key (the feeder's OWN repo)**

| Key | Plain-language label | Skip-consequence |
|---|---|---|
| `sourceGlobs` | "Which path patterns are 'source' that the feeder's own `no-source-edit` hook guards **in this (the feeder's own) repo**? Distinct from the consumer's shared `sourceGlobs`, which is read from the driver config — never duplicated here." | Default `["skills/**","agents/**","hooks/**"]`. Skip → the hook resolves `sourceGlobs` from the driver config, then fail-open (`SPEC.md` §7); set it here to give the hook a primary source in the feeder's own repo. |

### Phase 3 — Write and confirm

The canonical profile location is `<repo-root>/.milestone-config/feeder.json`.

- Create the `.milestone-config/` directory if absent (`mkdir -p .milestone-config`).
- Assemble the profile object from the keys the user accepted or edited. **Omit any key left at its bundled default** (absent-means-default, `docs/profile-schema.md`): writing the default explicitly adds noise and drifts when the default changes. A minimal feeder-own-repo profile carries only the self-protection `sourceGlobs`; an empty `{}` is valid.
- Write the assembled object to `.milestone-config/feeder.json`. **Always write the file**, even when the result is `{}` — config-presence is the signal `plan`'s Step 0 reads to decide whether to auto-invoke setup, so an absent file and an empty file are deliberately distinct.
- Print the final file contents so the user can verify.

Writing the file is sufficient for `plan` to read it immediately this session — no commit is required for it to function.

```
.milestone-config/feeder.json written.

{
  "projectDocs": ".project/",
  "reviewer": "milestone-driver"
}
```

### Phase 4 — Provision and align the label taxonomy

After the profile is written (Phase 3) and before returning control, provision the feeder's classification labels in the target repo, aligned to the driver's taxonomy so the driver's triage/solve read them natively. This step runs both during direct `/milestone-feeder:setup` invocations and any time setup is auto-invoked by `plan`.

#### Taxonomy (aligned to the driver)

| Label | Color (hex) | Description |
|---|---|---|
| `ui` | `5319E7` | UI-surface issue (design review applies) |
| `logic` | `0E8A16` | Logic / non-UI issue |
| `risk:light` | `C2E0C6` | Reduced-ceremony build profile (driver override) |
| `risk:heavy` | `B60205` | Full-ceremony build profile (driver override) |

#### Idempotent provisioning

Use `gh label create --force` for all four labels. The `--force` flag upserts: it creates the label if absent and updates color/description if it already exists. Re-runs produce no duplicates.

```
gh label create "ui"          --color 5319E7 --description "UI-surface issue (design review applies)" --force
gh label create "logic"       --color 0E8A16 --description "Logic / non-UI issue" --force
gh label create "risk:light"  --color C2E0C6 --description "Reduced-ceremony build profile (driver override)" --force
gh label create "risk:heavy"  --color B60205 --description "Full-ceremony build profile (driver override)" --force
```

These commands are identical on bash and PowerShell 7+. Run them as a flat list (no shell loop required), which keeps them portable across both platforms. This is the same canonical apply-time `gh label create --force` idiom the driver's setup uses (`milestone-driver/skills/setup/SKILL.md` Phase 4) — re-used, not re-invented.

#### Design note — `ui`/`logic` are human-facing metadata, NOT the driver's UI signal

The driver derives **UI vs logic** from a **`uiSurfaceGlobs` diff-match** (it checks whether an issue's changed paths intersect the configured UI-surface globs), **not** from a literal `ui` / `logic` label. These `ui` / `logic` labels are therefore **feeder-introduced, human-facing classification metadata** — readable on the issue list, aligned with the driver's taxonomy — but they are **not** the input the driver consumes to decide whether design review applies. The `risk:light` / `risk:heavy` labels, by contrast, **do** set the driver's `risk:*` build-profile override (`SPEC.md` §4). Provisioning all four keeps the issue surface self-describing without changing how the driver makes the UI call.

### Phase 5 — Return control

Return control to the caller (`plan`) immediately. Do **not** ask the user to re-run `/milestone-feeder:plan`. The bootstrap is a sub-step, not a restart.

## Re-run behavior (idempotency)

- **Existing profile.** If `.milestone-config/feeder.json` already exists, Phase 1 pre-fills from it and Phase 2 re-confirms every key with the existing value shown as the default (accept, edit, or re-configure) — mirroring the driver setup's existing-profile handling. The full flow still runs, but with current values pre-filled. If the file carries old key names, Phase 1 first offers the courtesy migration (old→new mapping with a notice) before pre-filling; the skills read only the new keys, so any old key the user declines to migrate is ignored, never silently honoured.
- **Labels.** Provisioning is idempotent via `--force`: re-running when a label already exists upserts its color/description and creates no duplicates.

## Output style

Be concise — report status and outcomes flatly, no wall-of-text. Present steps, gates, lists, and options as **tables**, not inline prose. Mark anything that needs a human with 🔴. (Mirrors the agents' communication-style contract.)

## Non-negotiables

- Never present a blank prompt. Every key shows either a detected default or an illustrative example.
- Skip always states its consequence. A user who skips knows exactly what default or behavior applies.
- No required hard-stop key. Unlike the driver, the feeder writes no branches and runs fully on defaults — there is no key whose absence blocks the write.
- Always write the file. Even an all-defaults result writes `.milestone-config/feeder.json` (an empty `{}` is valid), so config-presence detection is unambiguous. Omit default-filled keys from the written object (absent-means-default).
- **Committing the profile:** writing the file is enough for `plan` to read it this session. When `setup` is invoked **directly** (`/milestone-feeder:setup`), suggest the user commit it (`git add .milestone-config/feeder.json && git commit -m "chore: add milestone-feeder profile"`) so every clone and CI has it. When `setup` is auto-invoked **by `plan`**, leave the commit to the normal flow — do not create a commit on the current branch.
