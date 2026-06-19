# milestone-feeder

Turn a feature brief into a build-ready milestone.

milestone-feeder is a Claude Code plugin. Hand it a feature brief — a file, inline text, or a GitHub epic issue — and it produces a GitHub milestone of small, well-formed issues that [`milestone-driver`](https://github.com/kenmulford/milestone-driver) can build with no human clarification. It decomposes the brief into independently-buildable issues, writes each issue's full spec, encodes the dependency/Wave order in the milestone description, and self-checks every issue with the driver's own reviewers before anything is created — so what it hands the driver passes the driver's triage the first time.

It previews a reviewable plan by default and writes nothing to GitHub until you pass `--apply`. A decision with no conventional default parks to a report rather than being guessed. It authors no code, opens no PRs, and never touches branches.

## At a glance

- **Input:** a feature brief (file, inline, or a GitHub epic issue) + your project's standing docs (`.project/`).
- **Output:** a milestone whose description encodes the Wave/dependency order, and small issues each with complete acceptance criteria, recorded design, declared dependencies, and a UI/logic + risk label.
- **Safety:** preview by default; `--apply` creates the milestone/issues; authors no code, opens no PRs; parks product decisions instead of inventing them.

## Quickstart

**1. Install** (it pulls in the required superpowers dependency), then restart Claude Code so the hook loads:

```
/plugin marketplace add kenmulford/milestone-feeder
/plugin install milestone-feeder@milestone-feeder
```

**2. Run it — no config needed to start.** Put your feature idea in a file (a paragraph is plenty), preview the milestone it *would* create, then create it:

```
# A brief can be a file, inline text, or a GitHub epic issue (e.g. #42).
/milestone-feeder:decompose myfeature.md
#   → writes a reviewable plan file and creates NOTHING on GitHub. Read it first.

/milestone-feeder:decompose myfeature.md --apply
#   → now creates the milestone + issues + labels on GitHub.
```

That's the whole loop: **preview → read the plan → `--apply`**. No profile yet? The first run bootstraps one with you. To re-vet a milestone you already created — re-triage it, patch gappy issues, fill missing dependency edges — run `/milestone-feeder:refine "<milestone title>"`.

**3. Customize it (optional).** Configure the feeder in `.milestone-config/feeder.json`; every key has a default, so this is optional:

- **`substrateDir`** (default `.project/`) — the folder of your project's *standing docs*: architecture notes, coding conventions, a design system. The feeder reads these and **grounds every issue in your actual conventions** — it records "reuse the shared `FormField` component" with a citation instead of inventing a design, and a cross-cutting rule there (e.g. "all tables paginate at 30 rows/page") propagates into every issue it touches. The richer this folder, the better the issues and the fewer decisions the feeder hands back to you.
- **`selfCheck`** (default `"milestone-driver"`) — the quality gate that vets every issue *before* it's created: `"milestone-driver"` uses the driver's real reviewers, `"internal"` uses a built-in checklist, `false` turns it off. Leave it on.
- The build-side keys (`uiSurfaceGlobs`, `integrationBranch`, your repo's `sourceGlobs`) are **read from your milestone-driver config** — you don't repeat them here.

Full setup: [docs/consumer-setup.md](docs/consumer-setup.md). Every key explained: [docs/profile-schema.md](docs/profile-schema.md).

## How it works

A pipeline of small, gated steps: **decompose** the brief into candidate issues + a dependency graph, **author** each issue's full spec, **self-check** every issue against the driver's real reviewers (re-author on a fixable gap, park a decision with no conventional default), then **emit** — a preview plan by default, or the milestone + issues on `--apply`. `refine` runs the same pipeline against an existing milestone (idempotent; creates and deletes nothing).

The gate, the parking rules, and the `--apply` write order are documented in [docs/architecture.md](docs/architecture.md).

## Requirements

- The superpowers plugin — a hard dependency, auto-installed on install if you have the official marketplace added.
- GitHub CLI (`gh`), authenticated, for milestone, issue, and label operations.
- git.
- bash (preferred) or PowerShell 7+ for the `no-source-edit` hook; `jq` for the bash path.
- milestone-driver is **optional** — it backs the default `selfCheck: "milestone-driver"` gate; absent, the feeder degrades to the built-in `"internal"` checklist.

## Status

v0.2.0 — the self-check gate, `--apply`, and `refine` are shipped (v0.1.0 was the preview slice). Self-hosted: the feeder was built as its own milestone, driven by milestone-driver.

The preview pipeline and the self-check gate are exercised by a scenario harness ([`tests/`](tests/), scorecard in [`tests/RESULTS.md`](tests/RESULTS.md)) — all green, with the gate running milestone-driver's real reviewers. The `--apply` and `refine` write paths are covered by design and a sandbox follow-up, not yet exercised end-to-end.

## Docs

- [docs/consumer-setup.md](docs/consumer-setup.md): setup and wiring.
- [docs/profile-schema.md](docs/profile-schema.md): every profile key.
- [docs/architecture.md](docs/architecture.md): the as-built design and the gates.
- [SPEC.md](SPEC.md): the full design and spec.

## License

[MIT](LICENSE).
