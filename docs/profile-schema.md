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
(`SPEC.md` §7). Nearly every own-key has a bundled default, so a profile may omit
any key it does not override; an empty `{}` is valid (defaults apply where they exist). The one
exception is `versioning`, which has **no** bundled default — absent is a distinct
"infer-or-ask" state, not a default value (see its per-key note). The only
key the feeder's own repo must carry is the self-protection `sourceGlobs` (so the
`no-source-edit` hook has a primary source to read).

## Own keys

These keys are owned by the feeder and resolved from `feeder.json`. All are
optional in the file. Every key except `versioning` has a bundled default;
`versioning` has none — absent is its own "infer-or-ask" state (see its note).

| Key | Type | Default | Purpose |
|---|---|---|---|
| `projectDocs` | string | `.project/` | Where your project's standing docs live. |
| `autoHandoff` | `"prompt" \| "auto" \| "off"` | `"prompt"` | After `create` builds a milestone, whether the feeder offers to hand it to milestone-driver to start building (prompt = ask; auto = start immediately; off = never). |
| `architectAgent` | string | `milestone-feeder:architect` | Override the breakdown agent (default-filled). |
| `issueAuthorAgent` | string | `milestone-feeder:issue-author` | Override the authoring agent (default-filled). |
| `issueSize` | string | *(none)* | Optional natural-language sizing rule (e.g. "≤1 PR, ≤1 new screen"). |
| `versioning` | `"semver" \| "none"` | *(none)* | Whether this project is semver-versioned. Drives milestone-version resolution at plan time. Three-way (see note). |
| `sourceGlobs` | string[] | `["skills/**","agents/**","hooks/**"]` | **Self-protection only** — the paths the feeder's own `no-source-edit` hook guards in the feeder's *own* repo. Distinct from the consumer's shared `sourceGlobs`. Resolution chain below. |

### Per-key notes

**`projectDocs`.** Points the plan procedure at your project's standing docs
(vision, architecture, conventions) it grounds issue authoring in. Default
`.project/`.

**`autoHandoff`.** After `create` finishes building a milestone and its issues,
this key decides whether the feeder offers to hand the milestone **straight to
`milestone-driver`** to start building — instead of ending the run and leaving you
to invoke the driver yourself. It is **build-kickoff only**: it invokes
`/milestone-driver:solve-milestone "<milestone title>"`. Three values:

- `"prompt"` (**default**) — on a clean run, `create` asks *"milestone-driver is
  installed — start building this milestone now, or review it first?"*; **yes**
  starts the build, **no** stops.
- `"auto"` — on a clean run, `create` kicks off the driver **immediately**, with no
  prompt (a one-line notice for legibility).
- `"off"` — `create` **never** offers the handoff and never prompts (exactly
  today's no-handoff behavior).

**Three gates — all must hold for the handoff to be offered:** (1) **clean run
only — no gaps/parks** — the run produced no product gap and parked / dropped
nothing (the plan file's needs-input pointer is "none"). A gapped run surfaces its
gaps as today and offers no handoff; (2) **driver
installed, else silent skip** — `create` detects
whether `/milestone-driver:solve-milestone` resolves in this session and, if it
does **not**, silently skips with no prompt and no error (the same way the optional
`milestone-driver` soft-dependency degrades silently elsewhere); (3) **never
crosses `develop → main`** — the handoff is build-kickoff only; the driver builds
to the integration branch and the release (`develop → main`) stays a manual human
call, never auto-merged.

An **invalid or unrecognized value** (anything that is not exactly `"prompt"`,
`"auto"`, or `"off"`) is treated as the **default `"prompt"`** — `create` never
errors on the key (mirrors how `versioning` treats an invalid value as absent). The
key is **optional and follows the
[absent-means-default discipline](#absent-means-default-discipline)** (omit it on
skip; the default applies at runtime). Note the default is a **new behavior**:
absent `autoHandoff` means `create` offers the prompt on a clean run when the
driver is installed — to keep exactly today's no-handoff behavior, set
`"off"`.

**`architectAgent` / `issueAuthorAgent`.** Default-filled agent identifiers
(`milestone-feeder:architect`, `milestone-feeder:issue-author`). Auto-filled;
rarely overridden. Omit them from the profile unless pointing at a custom agent.

**`issueSize`.** Optional free-text sizing rule the author honours when
splitting work into issues. Absent → no sizing constraint beyond the procedure's
defaults.

**`versioning`.** Answers only one question — *is this project
semver-versioned?* — with a three-way contract (grounded in
`docs/specs/v0.3.1-driver-handoff.md` §7 and the versioning model in
`docs/specs/v0.3.1-driver-handoff.md` §2):

- `"semver"` = the project is versioned: `plan` versions every milestone, finding
  the actual number via the layered ladder.
- `"none"` = the project is non-versioned: `plan` never adds a version and never
  prompts for one.
- **Absent** = unknown: `plan` infers from repo signals (existing milestone
  titles, then git tags), and only asks when nothing is inferable.

Unlike every other own-key, `versioning` has **no bundled default** — absent is a
distinct documented state, *not* a default value. So it follows the
[absent-means-default discipline](#absent-means-default-discipline) the same way:
when it is skipped, it is **omitted** from the profile (never written as a
placeholder), and the absent state means infer-or-ask. An **invalid or
unrecognized value** (anything that is not exactly `"semver"` or `"none"`) is
treated as absent — `plan` falls back to infer-or-ask and never errors on the key.

**`sourceGlobs` (self-protection).** The paths the feeder's `no-source-edit` hook
guards in the feeder's **own** repo. This is **semantically distinct** from the
consumer's shared `sourceGlobs` (which the feeder reads from the driver config
when planning a target repo). Its presence in `feeder.json` is justified by
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
into `feeder.json`. The feeder reads these from the driver config when planning
a target repo. They resolve in this order:

1. **`.milestone-config/driver.json`** (primary).
2. **Root `milestone-driver.json`** (legacy fallback).
3. **Absent-means-default** — an unset key uses its documented default; the feeder
   does not invent a value.

**Precedence.** When both driver files exist, `.milestone-config/driver.json`
wins. The consumer's shared `sourceGlobs` here is the path set the feeder uses
when authoring issues for a target repo — distinct from the self-protection
`sourceGlobs` of resolution chain 1.

### `.milestone-config/` migration note

Adopting `.milestone-config/` suite-wide means the driver resolves its profile
from `.milestone-config/driver.json` first, falling back to the legacy root
`milestone-driver.json` (backward-compatible — existing repos keep working). That
resolution was realized by [milestone-driver#144](https://github.com/kenmulford/milestone-driver/issues/144),
which shipped in driver **v1.9.0** (`SPEC.md` §7). The feeder's own fallback
(resolution chains above) reads both locations, so it works **whether or not**
that driver change has shipped in a given consumer's pinned version.

## The implied-surfaces overlay (a config file, not a key)

When `plan` breaks your brief into issues, the architect consults a bundled
**implied-surfaces reference** ([`implied-surfaces.md`](implied-surfaces.md)) — the
standard companion surfaces a capability name or a new entity quietly implies. A
project can extend that reference with an **optional project-local overlay**.

The overlay is **not a `feeder.json` own-key** — there is no key in the table above
that points at it, and there is nothing to set in the profile for it. It is a
separate **markdown file**, discovered by a **fixed path**, a sibling of
`feeder.json` in the suite config directory:

```
<repo-root>/.milestone-config/implied-surfaces.md
```

Discovery by a fixed conventional location — not a config key — is the same
discipline the plan file and the `.milestone-config/` profiles already follow, and
the same **new keys only when a real consumer needs them** rule as the
[Design principle](#design-principle) above: the overlay needed no new key, so none
was added.

**Its shape.** The same markdown `##`-section shape as the bundled reference: one
capability per `##` heading, its implied surfaces listed beneath
(`docs/implied-surfaces.md` → "Project-local overlay").

**How it merges — additive only.** `plan` Step 0 resolves the overlay and merges it
into the bundled reference **additively**: an overlay can **add** a capability the
global reference doesn't carry and **extend** an existing capability with surfaces
specific to your project — but it can **never remove** a surface the global reference
defines. Dropping a surface you don't want for a given milestone is the **plan
review's** job (a per-run "trim this line before approving" call), not a standing
config-level delete.

**Optional, and absent by default.** Most projects ship no overlay — that is the
common case, never an error. With no overlay, the bundled reference alone applies and
there is nothing to configure. When a project does add one, it is ordinary committed
configuration tracked in git like the rest of `.milestone-config/`; a malformed or
wrong-shape overlay is skipped best-effort and never breaks a plan run.

## Absent-means-default discipline

**Omit a key rather than write its default value.** Almost every own-key has a
bundled default; writing the default explicitly adds noise and drifts when the
default changes. `versioning` is the exception — it has no default, so "skip"
means **omit it** and let its absent state (infer-or-ask) apply, never write a
placeholder. Either way the rule is the same: omit on skip. A minimal profile
carries only the keys that diverge from default — for the feeder's own repo, that
is just the self-protection `sourceGlobs` (so the hook has a primary source). An
empty `{}` is a valid profile.

## Minimal example

A couple of commonly-set own-keys, with everything else defaulted:

```json
{
  "projectDocs": ".project/",
  "issueSize": "≤1 PR, ≤1 new screen"
}
```

## Full example

Adds an optional sizing rule and the self-protection `sourceGlobs`:

```json
{
  "projectDocs": ".project/",
  "issueSize": "≤1 PR, ≤1 new screen",
  "sourceGlobs": ["skills/**", "agents/**", "hooks/**"]
}
```

The default-filled agent keys (`architectAgent`, `issueAuthorAgent`) are omitted
in both examples; their bundled defaults apply automatically.
