# milestone-feeder

Turn a feature brief into a build-ready milestone.

milestone-feeder is a Claude Code plugin. You hand it a feature brief — a file, inline text, or a GitHub epic issue — and it produces a GitHub milestone of small, well-formed issues that [`milestone-driver`](https://github.com/kenmulford/milestone-driver) can build with no human clarification. It decomposes the brief into independently-buildable issues, authors each one's full spec, encodes the Wave/dependency order in the milestone description, and self-checks every issue before anything is created. The feeder is the driver's direct predecessor: it produces the input the driver assumes already exists.

The point is quality at the front of the pipeline. The bigger the ask of AI, the worse the quality is — so the feeder keeps each authoring step small and runs the whole set through a single hard gate. Its quality bar is concrete: every issue it emits passes the driver's own triage clean (`GAPS: none`), because the feeder reuses the driver's actual reviewer agents as a pre-creation self-check.

Issue creation is consequential, so it previews a reviewable plan by default and writes nothing to GitHub until you pass `--apply`. Anything risky — a product decision with no conventional default, a non-converging design — parks to a "needs product input" report instead of guessing. The feeder authors no code, opens no PRs, and never touches branches. Authoring scope stays your call.

## At a glance

- **Input:** a feature brief (file, inline, or a GitHub epic issue) + the project substrate (`.project/`).
- **Output:** a milestone whose description encodes the Wave/dependency order, and small issues each carrying complete acceptance criteria, recorded consistent design, declared dependencies, and UI/logic + risk classification.
- **Safety:** previews a reviewable plan by default; `--apply` creates the milestone/issues. Authors no code, opens no PRs. Parks product decisions rather than inventing scope.

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

**3. Ground it in your project (optional — but it's where the quality comes from).** The feeder writes far better, more consistent issues when it can read your project's standing docs. Configure it in `.milestone-config/feeder.json`; every key has a default, so this is optional:

- **`substrateDir`** (default `.project/`) — the folder holding your project's *standing docs*: architecture notes, coding conventions, a design system. The feeder reads these and **grounds every issue in your actual conventions** — it records "reuse the shared `FormField` component" with a citation instead of inventing a design. A cross-cutting rule you put here (e.g. "all tables paginate at 30 rows/page") propagates into every issue it touches. The richer this folder, the better the issues and the fewer decisions the feeder has to hand back to you.
- **`selfCheck`** (default `"milestone-driver"`) — the quality gate that vets every issue *before* it's created: `"milestone-driver"` uses the driver's real reviewers, `"internal"` uses a built-in checklist that mirrors them, `false` turns it off (with a visible warning). Leave it on.
- The build-side keys it needs (`uiSurfaceGlobs`, `integrationBranch`, and your repo's `sourceGlobs`) are **read from your milestone-driver config** — you don't repeat them here.

A minimal profile, then, is just the bits that differ from the defaults — often nothing:

```json
{
  "substrateDir": ".project/",
  "selfCheck": "milestone-driver"
}
```

Full setup walkthrough: [docs/consumer-setup.md](docs/consumer-setup.md). Every profile key explained: [docs/profile-schema.md](docs/profile-schema.md).

## What makes it different

Most brief-to-issues assistants ship their own notion of a "well-formed" issue — a second definition that drifts from whatever actually gates the build. milestone-feeder has no second definition. Its quality bar *is* the driver's entry gate: before creating anything, it dispatches the driver's real `triage-reviewer` (and `design-reviewer` for UI issues) against each generated issue as a pre-creation self-check. An issue is only emitted once it passes that gate clean, so what the feeder hands the driver passes the driver's triage the first time — no drift, no rework loop between the two tools.

## When to use it

- You have a brief or an epic to turn into a buildable milestone, not a single ad-hoc task.
- You want issues that pass the driver's triage clean the first time, with no clarification loop.
- You want product decisions parked for you — recorded in a report, never invented to make an issue buildable.
- You want a reviewable preview before anything is created on GitHub.

## How it works

milestone-feeder runs a pipeline of small, gated steps, so no single step asks the model to hold too much at once.

1. Decompose. It dispatches the decomposer once: the brief plus the substrate become a candidate issue set, a dependency graph, and a Wave order. Decisions with no conventional default are separated out and parked, not guessed.
2. Author. It dispatches the issue-author per candidate (parallelizable). Each issue gets its full spec — acceptance criteria covering empty/error/disabled states, recorded consistent design grounded in the substrate or a cited sibling pattern, declared dependency edges, and UI/logic + risk classification.
3. Self-check gate. Before emitting, it vets every generated issue against the same gate that fronts the driver's build loop. A `GAPS: none` issue passes; a Blocker is re-authored (bounded to ≤2 retries) or parked. The gate has three backends — the driver's reviewers (`"milestone-driver"`, the default), an internal checklist mirroring the five triage criteria (`"internal"`), or off (`false`, with a visible warning). It runs on every path and writes no GitHub state.
4. Emit. Preview (the default) writes a reviewable plan file — the Wave-ordered milestone description plus every gate-surviving issue body — and a "needs product input" report when product gaps remain. `--apply` then creates the GitHub artifacts: the labels, the milestone (created-or-adopted by title, never deleted), each gate-surviving issue, and the Wave-encoded milestone description.

`refine` is the maintenance counterpart: an idempotent re-run against an existing milestone that re-vets its live issues through the same gate, patches gapped bodies, fills missing dependency edges, and re-renders the Wave order. It creates and deletes no issues; an issue already at `GAPS: none` is left byte-unchanged, and a fully-clean milestone is a true no-op.

Every dispatched agent is read-only and runs against provided text; the feeder reads code to ground decisions but never writes it. The full architecture, the gate, and the `--apply` write order live in [docs/architecture.md](docs/architecture.md).

## Requirements

- The superpowers plugin. It is a hard dependency, auto-installed on install provided you have the official marketplace added.
- GitHub CLI (`gh`), authenticated, for milestone, issue, and label operations.
- git.
- bash (preferred) or PowerShell 7+ for the `no-source-edit` hook. `jq` is required for the bash path.
- milestone-driver is **optional**. It backs the default `selfCheck: "milestone-driver"` mode — the feeder dispatches the driver's own reviewers as the self-check gate. Absent, the feeder degrades to the built-in `"internal"` checklist and the pipeline still runs.

## Status

v0.2.0 shipped — the self-check gate, `--apply`, and `refine` are all delivered (v0.1.0 shipped the preview slice). The feeder was built as its own milestone, driven end-to-end by milestone-driver.

## Docs

- [docs/consumer-setup.md](docs/consumer-setup.md): full setup and wiring.
- [docs/profile-schema.md](docs/profile-schema.md): every profile key.
- [docs/architecture.md](docs/architecture.md): the as-built design and the gates.
- [SPEC.md](SPEC.md): the full design and spec.

## License

[MIT](LICENSE).
