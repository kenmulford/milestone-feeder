---
name: setup
description: This skill should be used when "milestone-feeder:setup" is invoked directly, OR auto-invoked by `plan` when `.milestone-config/feeder.json` is absent. Guides an interactive first-run bootstrap that infers every profile key from repo signals, presents detected defaults with plain-language descriptions, lets the user accept/edit/skip optional keys (stating each skip-consequence), writes `.milestone-config/feeder.json`, aligns the issue-label taxonomy with the driver's, and returns control so the original task continues. Mirrors milestone-driver:setup.
---

# setup — first-run profile bootstrap

Generate or repair the feeder profile through a guided, inference-first flow. Every key is presented with a plain-language description and a detected default. Optional keys state their skip-consequence. No blank prompts — if a default cannot be inferred, an example is shown.

The canonical profile location is `<repo-root>/.milestone-config/feeder.json` — the suite-wide `.milestone-config/` directory the sibling `milestone-driver` plugin also reads from (it stores `driver.json` alongside). **Unlike the driver, the feeder has no required hard-stop key:** the feeder writes no branches and no key hard-stops the write, so an empty `{}` profile is valid — nearly every key falls back to a bundled default (the exception is `versioning`, which has no default: skipping it means infer-or-ask, not a default value). Setup still writes the file — even when every key is left at its default or skipped — so config-presence detection (`plan`'s Step 0 → auto-invoke setup when the file is absent) is unambiguous.

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
| Existing profile | Read `.milestone-config/feeder.json` if present | Pre-fill any already-set keys (re-run handling below) |

### Phase 2 — Tier-by-tier confirmation

Present keys in these tiers: **Core → Agents → Sizing**, plus the self-protection `sourceGlobs` key. Within each tier, show one key at a time (or a logical group). For every key:

- State the plain-language label.
- Show the detected default (or an illustrative example if none was detected).
- For optional keys: state the skip-consequence on the same line.
- Accept, edit, or skip — never leave a field blank without an explicit skip choice.

**No required hard-stop key.** Unlike the driver (whose Core keys `integrationBranch` / `protectedBranch` / `sourceGlobs` hard-stop), the feeder has **no** key that blocks the write. The feeder writes no branches and no key hard-stops, so every tier below is a one-keystroke accept-or-skip. Most keys accept the detected default; the exception is `versioning` (in the Sizing tier), which has no default — so its one-keystroke choice is accept-or-skip, and skip means infer-or-ask, not a default value. An empty `{}` is a valid result — and setup still writes the file regardless, so config-presence detection is unambiguous.

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

**Tier: Sizing & versioning** (optional)

| Key | Plain-language label | Skip-consequence |
|---|---|---|
| `issueSize` | "Any natural-language sizing rule the author should honour when splitting work? (e.g. `≤1 PR, ≤1 new screen`)" | Skip → "No sizing constraint beyond the procedure's defaults." |
| `versioning` | "Is this project semver-versioned? Drives whether `plan` adds a version to the milestone. Accept `\"semver\"` (versioned — version every milestone), `\"none\"` (non-versioned — never add a version), or skip." | Skip → the key is **omitted** (it has no default) and `plan` infers-or-asks at plan time. |

**Self-protection key (the feeder's OWN repo)**

| Key | Plain-language label | Skip-consequence |
|---|---|---|
| `sourceGlobs` | "Which path patterns are 'source' that the feeder's own `no-source-edit` hook guards **in this (the feeder's own) repo**? Distinct from the consumer's shared `sourceGlobs`, which is read from the driver config — never duplicated here." | Default `["skills/**","agents/**","hooks/**"]`. Skip → the hook resolves `sourceGlobs` from the driver config, then fail-open (`SPEC.md` §7); set it here to give the hook a primary source in the feeder's own repo. |

### Phase 3 — Write and confirm

The canonical profile location is `<repo-root>/.milestone-config/feeder.json`.

- Create the `.milestone-config/` directory if absent (`mkdir -p .milestone-config`).
- **Self-heal the scratch-ignore (best-effort, create-only — never clobber).** With the directory now ensured, write a **committed** `.milestone-config/.gitignore` so per-clone scratch (`preflight-notice`, `trello-notice`, `triage-cache.json`, `tests-stamp`, plus the `.runtime/` and `worktrees/` dirs) is git-invisible in the consumer repo from the first write, with zero user setup — while tracked config (`driver.json`, `feeder.json` — intentionally NOT listed) stays tracked. A feeder-first adopter (setup runs before any milestone-driver hook has fired) would otherwise have no scratch-ignore until a driver run happens; this closes that gap. **Write the file only when it is absent** (`[ ! -f ]` / `-not (Test-Path …)`), so a user-edited `.gitignore` is never overwritten, appended to, or truncated, and a re-run is a no-op. The write is **best-effort**: swallow any failure and continue to write `feeder.json` and return control — a failed self-heal must never abort setup. This mirrors the driver's canonical block verbatim (`milestone-driver/hooks/tests-green.sh` / `tests-green.ps1`); keep the two in sync.

  <!-- KEEP THIS BLOCK IN SYNC with the committed .milestone-config/.gitignore in this repo and with feeder plan, driver solve-issue / solve-milestone / triage. -->
  ```gitignore
  # milestone-driver / milestone-feeder per-clone scratch — git-invisible by default.
  # Committed so per-run scratch stays out of `git status` with zero user setup.
  # Patterns are relative to this .milestone-config/ directory. Tracked config
  # (driver.json, feeder.json) is intentionally NOT listed, so it stays tracked.
  preflight-notice
  trello-notice
  triage-cache.json
  tests-stamp
  .runtime/
  worktrees/
  ```

  ```bash
  # bash — create-only self-heal; never clobbers a user-edited file, never aborts setup.
  ignore_path=".milestone-config/.gitignore"
  if [ ! -f "$ignore_path" ]; then
    printf '%s\n' \
      '# milestone-driver / milestone-feeder per-clone scratch — git-invisible by default.' \
      '# Committed so per-run scratch stays out of `git status` with zero user setup.' \
      '# Patterns are relative to this .milestone-config/ directory. Tracked config' \
      '# (driver.json, feeder.json) is intentionally NOT listed, so it stays tracked.' \
      'preflight-notice' 'trello-notice' 'triage-cache.json' 'tests-stamp' \
      '.runtime/' 'worktrees/' > "$ignore_path" 2>/dev/null || true
  fi
  ```

  ```powershell
  # PowerShell 7+ — same create-only self-heal; no-BOM UTF-8; never clobbers, never aborts.
  try {
    $ignorePath = Join-Path '.milestone-config' '.gitignore'
    if (-not (Test-Path $ignorePath)) {
      $ignoreBody = @(
        '# milestone-driver / milestone-feeder per-clone scratch — git-invisible by default.'
        '# Committed so per-run scratch stays out of `git status` with zero user setup.'
        '# Patterns are relative to this .milestone-config/ directory. Tracked config'
        '# (driver.json, feeder.json) is intentionally NOT listed, so it stays tracked.'
        'preflight-notice'; 'trello-notice'; 'triage-cache.json'; 'tests-stamp'
        '.runtime/'; 'worktrees/'
      ) -join "`n"
      [System.IO.File]::WriteAllText($ignorePath, $ignoreBody + "`n", [System.Text.UTF8Encoding]::new($false))
    }
  } catch {}
  ```

- Assemble the profile object from the keys the user accepted or edited. **Omit any key left at its bundled default** (absent-means-default, `docs/profile-schema.md`): writing the default explicitly adds noise and drifts when the default changes. `versioning` has **no** default, so a skipped `versioning` is likewise **omitted** — never written as a placeholder; its absent state means `plan` infers-or-asks. A minimal feeder-own-repo profile carries only the self-protection `sourceGlobs`; an empty `{}` is valid.
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

- **Existing profile.** If `.milestone-config/feeder.json` already exists, Phase 1 pre-fills from it and Phase 2 re-confirms every key with the existing value shown as the default (accept, edit, or re-configure) — mirroring the driver setup's existing-profile handling. The full flow still runs, but with current values pre-filled.
- **Labels.** Provisioning is idempotent via `--force`: re-running when a label already exists upserts its color/description and creates no duplicates.

## Output style

Be concise — report status and outcomes flatly, no wall-of-text. Present steps, gates, lists, and options as **tables**, not inline prose. Mark anything that needs a human with 🔴. (Mirrors the agents' communication-style contract.)

## Non-negotiables

- Never present a blank prompt. Every key shows either a detected default or an illustrative example.
- Skip always states its consequence. A user who skips knows exactly what default or behavior applies.
- No required hard-stop key. Unlike the driver, the feeder writes no branches and no key hard-stops the write — every key falls back to its default, except `versioning`, which has none (skip = infer-or-ask).
- Always write the file. Even an all-defaults result writes `.milestone-config/feeder.json` (an empty `{}` is valid), so config-presence detection is unambiguous. Omit default-filled keys from the written object (absent-means-default); also omit `versioning` when skipped — it has no default, so a skip means omit (infer-or-ask), never a placeholder.
- **Committing the profile:** writing the file is enough for `plan` to read it this session. When `setup` is invoked **directly** (`/milestone-feeder:setup`), suggest the user commit it (`git add .milestone-config/feeder.json && git commit -m "chore: add milestone-feeder profile"`) so every clone and CI has it. When `setup` is auto-invoked **by `plan`**, leave the commit to the normal flow — do not create a commit on the current branch.
