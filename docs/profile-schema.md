# milestone-feeder — project profile schema

The feeder reads a thin, committed per-repo profile that carries only the keys
the feeder itself owns. Consumer-facing shared keys are **not** duplicated here —
the feeder reads those from the driver's profile (see
[Shared keys](#shared-keys-resolved-from-the-driver-profile) below). This file
documents `.milestone-config/feeder.json`: the contract Step 0 of every skill
and the `no-source-edit` hook read.

> **See also:** the [milestone-driver profile schema](https://github.com/kenmulford/milestone-driver/blob/main/docs/profile-schema.md) — the source of the shared keys the feeder consumes (`uiSurfaceGlobs`, `integrationBranch`, the consumer's `sourceGlobs`).

## Location

The canonical profile location is:

```
<repo-root>/.milestone-config/feeder.json
```

This is the suite-wide `.milestone-config/` config directory that the sibling
`milestone-driver` plugin also reads from (it stores `driver.json` alongside).

**Commit it.** The `no-source-edit` hook reads the profile, so it must be present
in every clone for the gate to behave identically for every contributor and on
CI.

## Design principle

Keep it thin and consumer-driven, the same discipline as the driver: **new keys
are added only when a real consumer needs them — never speculatively**
(`SPEC.md` §7). Every own-key has a bundled default, so a profile may omit any
key it does not override; an empty `{}` is valid (all defaults apply). The only
key the feeder's own repo must carry is the self-protection `sourceGlobs` (so the
`no-source-edit` hook has a primary source to read).

## Own keys

These keys are owned by the feeder and resolved from `feeder.json`. All are
optional in the file (each has a bundled default).

| Key | Type | Default | Purpose |
|---|---|---|---|
| `substrateDir` | string | `.project/` | Where the project-constitution docs live. |
| `selfCheck` | `"milestone-driver" \| "internal" \| false` | `"milestone-driver"` | Which reviewer backs the self-check gate. |
| `decomposerAgent` | string | `milestone-feeder:decomposer` | Override the breakdown agent (default-filled). |
| `issueAuthorAgent` | string | `milestone-feeder:issue-author` | Override the authoring agent (default-filled). |
| `issueSizeGuidance` | string | *(none)* | Optional natural-language sizing rule (e.g. "≤1 PR, ≤1 new screen"). |
| `sourceGlobs` | string[] | `["skills/**","agents/**","hooks/**"]` | **Self-protection only** — the paths the feeder's own `no-source-edit` hook guards in the feeder's *own* repo. Distinct from the consumer's shared `sourceGlobs`. Resolution chain below. |

### Per-key notes

**`substrateDir`.** Points the decompose procedure at the project-constitution
docs (vision, architecture, conventions) it grounds issue authoring in. Default
`.project/`.

**`selfCheck`.** Selects the reviewer backing the self-check gate — the keystone
that prevents the feeder from authoring issues it cannot itself substantiate.
`"milestone-driver"` (default) backs the gate with the driver's review agents;
`"internal"` uses the feeder's own reviewer; `false` disables the gate.

**`decomposerAgent` / `issueAuthorAgent`.** Default-filled agent identifiers
(`milestone-feeder:decomposer`, `milestone-feeder:issue-author`). Auto-filled;
rarely overridden. Omit them from the profile unless pointing at a custom agent.

**`issueSizeGuidance`.** Optional free-text sizing rule the author honours when
splitting work into issues. Absent → no sizing constraint beyond the procedure's
defaults.

**`sourceGlobs` (self-protection).** The paths the feeder's `no-source-edit` hook
guards in the feeder's **own** repo. This is **semantically distinct** from the
consumer's shared `sourceGlobs` (which the feeder reads from the driver config
when decomposing a target repo). Its presence in `feeder.json` is justified by
the dogfood consumer — the feeder protecting its own source — under the
"new keys only when a real consumer needs them" rule. See its resolution chain in
[Shared keys](#shared-keys-resolved-from-the-driver-profile).

## Shared keys (resolved from the driver profile)

Two distinct resolutions apply. Neither shared chain duplicates the driver's keys
into `feeder.json`.

### 1. The `no-source-edit` hook's `sourceGlobs` (self-protection)

The `no-source-edit` hook guards the feeder's **own** repo. It resolves the paths
to guard in this order:

1. **`.milestone-config/feeder.json`** (primary) — the self-protection
   `sourceGlobs` documented above.
2. **The resolved driver config** — `.milestone-config/driver.json`, falling back
   to root `milestone-driver.json`.
3. **Fail-open** — if neither carries `sourceGlobs`, the hook does not block (a
   robustness measure so a hook bug never bricks the repo).

This is the feeder protecting its own source. The self-protection `sourceGlobs`
in `feeder.json` is the primary; the driver config is a fallback so a repo that
declares its source paths only in `driver.json` is still guarded.

### 2. The consumer-facing shared keys

The consumer-facing shared keys — `uiSurfaceGlobs`, `integrationBranch`, and the
**consumer's** `sourceGlobs` — are **read from the driver config, not duplicated**
into `feeder.json`. The feeder reads these from the driver config when decomposing
a target repo. They resolve in this order:

1. **`.milestone-config/driver.json`** (primary).
2. **Root `milestone-driver.json`** (legacy fallback).
3. **Absent-means-default** — an unset key uses its documented default; the feeder
   does not invent a value.

**Precedence.** When both driver files exist, `.milestone-config/driver.json`
wins. The consumer's shared `sourceGlobs` here is the path set the feeder uses
when authoring issues for a target repo — distinct from the self-protection
`sourceGlobs` of resolution chain 1.

**`nonNegotiables` — the self-check gate's additional reviewer input.** Beyond the
three shared keys above, the self-check gate (decompose Step 6) also reads
`nonNegotiables` from the driver profile, resolved down the **same chain**
(`.milestone-config/driver.json` → root `milestone-driver.json` → absent →
**omitted**, never invented). It is **not** a fourth shared key — it is the
additional reviewer-profile input the gate passes through to the driver's
`triage-reviewer`: the framework / platform / version constraints the reviewer
checks each issue against. Absent → the reviewer simply has no version/platform
constraints to check.

### `.milestone-config/` migration note

Adopting `.milestone-config/` suite-wide means the driver resolves its profile
from `.milestone-config/driver.json` first, falling back to the legacy root
`milestone-driver.json` (backward-compatible — existing repos keep working). That
resolution was realized by [milestone-driver#144](https://github.com/kenmulford/milestone-driver/issues/144),
which shipped in driver **v1.9.0** (`SPEC.md` §7). The feeder's own fallback
(resolution chains above) reads both locations, so it works **whether or not**
that driver change has shipped in a given consumer's pinned version.

## Absent-means-default discipline

**Omit a key rather than write its default value.** Every own-key has a bundled
default; writing the default explicitly adds noise and drifts when the default
changes. A minimal profile carries only the keys that diverge from default — for
the feeder's own repo, that is just the self-protection `sourceGlobs` (so the
hook has a primary source). An empty `{}` is a valid profile.

## Minimal example

The two most commonly-set own-keys, with everything else defaulted:

```json
{
  "substrateDir": ".project/",
  "selfCheck": "milestone-driver"
}
```

## Full example

Adds an optional sizing rule and the self-protection `sourceGlobs`:

```json
{
  "substrateDir": ".project/",
  "selfCheck": "milestone-driver",
  "issueSizeGuidance": "≤1 PR, ≤1 new screen",
  "sourceGlobs": ["skills/**", "agents/**", "hooks/**"]
}
```

The default-filled agent keys (`decomposerAgent`, `issueAuthorAgent`) are omitted
in both examples; their bundled defaults apply automatically.
