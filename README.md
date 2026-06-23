# milestone-feeder

Turn a rough idea into a build-ready GitHub milestone — a tidy list of small, well-formed issues, in the order they should be built.

milestone-feeder is a Claude Code plugin. You hand it a brief — a file, a few lines of text, or a GitHub epic issue — and it writes a reviewable plan: each piece of work as its own issue, with a full spec, the decisions an engineer would otherwise have to invent, and a build order. You read the plan, then tell it to build the milestone on GitHub. Its sibling plugin, [`milestone-driver`](https://github.com/kenmulford/milestone-driver), can then pick the issues up and build them with no further clarification.

**Install it** — either marketplace below pulls in the required `superpowers` plugin. Restart Claude Code afterward so the plugin's hook loads.

**Recommended — the milestone-suite marketplace.** One marketplace carries all three milestone plugins (`milestone-bootstrapper`, `milestone-feeder`, `milestone-driver`), so you add it once and install whichever you want:

```
/plugin marketplace add kenmulford/milestone-suite
/plugin install milestone-feeder@milestone-suite
```

**Alternative — this repo's own marketplace.** Still supported if you only want milestone-feeder:

```
/plugin marketplace add kenmulford/milestone-feeder
/plugin install milestone-feeder@milestone-feeder
```

## Quick start

The whole tool is three commands — `plan`, then `create`, and `update` when your idea changes later. The loop:

1. **`plan` your idea.** Put your idea in a file (a paragraph is plenty), or paste it inline, or point at a GitHub epic issue (e.g. `#42`):

   ```
   /milestone-feeder:plan myidea.md
   ```

   It reads your project's docs, breaks the idea into small issues, checks each one against your conventions, and writes a **plan file** you can read. It creates nothing on GitHub yet.

2. **Read the plan.** Open the plan file it points you to and check the issues, the design decisions it recorded, and the build order. This is your review — change your idea and re-run `plan` if anything's off.

3. **`create` it.** When the plan looks right, build it on GitHub:

   ```
   /milestone-feeder:create myidea.md
   ```

   It creates the milestone, opens every issue, applies the labels, and writes the build order into the milestone description — exactly the plan you read, nothing re-decided.

4. **`update` when your idea changes.** Edit your brief, re-run `plan` to refresh the plan, then sync it onto the milestone you already have:

   ```
   /milestone-feeder:update myidea.md
   ```

   It creates any new issue, patches any issue whose spec drifted (showing you the diff first), adds any new dependency to the build order, and **flags** — never closes — any live issue your plan no longer mentions.

The very first time you run `plan` in a repo with no config, it sets up a small profile for you and then carries on — you don't re-run anything.

## Before you start

For us to build your milestone and issues, a few things need to be in place. Each one below comes with what breaks if it's missing.

- **`gh` (the GitHub CLI) installed and signed in**, and you're working in a directory connected to a GitHub repository — otherwise we won't be able to create your milestone or issues.
- **Claude allowed to run the GitHub write commands** that `create`, `update`, and `setup` use, plus **Read access to your project docs**:
  - `gh label create` — to provision the `ui` / `logic` / `risk:*` labels.
  - `gh api .../milestones` (POST and PATCH) — to create or adopt the milestone and write the build order into its description.
  - `gh issue create` / `edit` / `list` / `view` / `comment` — to open issues, fix their cross-references, find existing ones on a re-run, read an epic brief, and post a needs-input report.
  - **Read** on your project's standing docs — so we can ground each issue in your real conventions.

  Without these grants, `create` and `update` can't write to GitHub.
- **git.**
- **bash with `jq`** (or **PowerShell 7+**) — for the small hook that keeps the plugin from editing your source while it works.
- **`milestone-driver` is optional.** It backs the default reviewer (`reviewer: "milestone-driver"`), which checks each issue with the driver's own reviewers. If it isn't installed, the check quietly falls back to a built-in checklist (`reviewer: "internal"`) — nothing fails.

One thing worth knowing: **`plan` never writes to GitHub.** It only *reads* — and only when you hand it an epic issue as the brief (it runs `gh issue view` on that one issue). Everything `plan` produces is a local file you review. The GitHub writes above are what `create`, `update`, and `setup` need — not `plan`.

## How it works

You hand `plan` your idea. It reads your project's standing docs and breaks the idea into small, buildable issues — recording, for each one, the decisions an engineer would otherwise have to invent, and citing the house rule it followed. Before it finishes, it checks each issue against your conventions and fixes or flags anything that doesn't hold up. A decision with no conventional default it never guesses — it flags it for you to make. Then `create` builds exactly what you approved.

That check is the guardrail. Two parts, in plain terms:

- **It grounds every issue in your real conventions.** Instead of inventing a design, it reads your project's standing docs and reuses what's already there — recording "reuse the shared `FormField` component", with a citation, rather than making something up. A rule that applies everywhere (say, "all tables paginate at 30 rows per page") flows into every issue it touches.
- **It checks each issue before it's created, and fixes or flags — never guesses.** Every issue is reviewed against the same bar `milestone-driver` uses to start a build. A gap your conventions can answer, it fixes. A decision with no conventional default — a real product call only you can make — it sets aside and lists for you in a needs-input report, rather than guessing an answer to make the issue look finished.

The richer your project docs, the better the issues and the fewer decisions land back on your plate. Nothing here is new machinery — it's the grounding and the check, described in plain terms.

Two more things the feeder does for you:

- **Name your milestone with a version up front.** Add a line like `Milestone: myapp v1.2.0` to your brief (or just say it inline). The feeder reads the version straight from the milestone's name so its sibling, `milestone-driver`, knows exactly what version to build toward. If you don't name one, the feeder proposes a version — pulled from your existing milestones or git tags — and shows it to you to confirm or change before it builds anything. You're never handed a milestone whose name you didn't get to see.
- **It flags a brief that looks like several milestones.** If your idea really reads as a few separate releases, the feeder still builds one milestone — but it tells you up front, "this looks like ~N milestones," and shows you how it would split them, so you can break the brief up and re-run if you want. Never a silent giant milestone, and never a hard stop — the call is yours.

## Config

Configuration is **optional** — every setting has a sensible default, so the tool runs with no config at all. When you do want to tune it, the settings live in `.milestone-config/feeder.json` (the same folder `milestone-driver` keeps its `driver.json` in). The first `plan` run writes this file for you.

- **`projectDocs`** (default `.project/`) — the folder where your project's standing docs live: architecture notes, coding conventions, a design system. This is what the feeder reads to ground every issue in your real conventions.
- **`reviewer`** (default `"milestone-driver"`) — who checks each issue against your conventions before it's created. `"milestone-driver"` uses the driver's own reviewers; `"internal"` uses a built-in checklist; `false` turns the check off (you'll get a visible warning if you do).
- **`issueSize`** (optional) — a natural-language sizing rule the breakdown should honor, e.g. `"≤1 PR, ≤1 new screen"`. Leave it out for no constraint beyond the defaults.

The build-side settings — your UI-surface paths, your integration branch, your source paths — are **read from your `milestone-driver` config**, not repeated here.

Full setup walkthrough: [docs/consumer-setup.md](docs/consumer-setup.md). Every setting explained: [docs/profile-schema.md](docs/profile-schema.md).

## Status

v0.4.2 — the live surface (`plan` / `create` / `update`, no flags, plan-file-as-contract): name your milestone with a version up front and the feeder hands it cleanly to `milestone-driver`; `plan` reads your house docs once up front and parks real product gaps before it fans out; and you get a heads-up when your brief looks like several milestones. v0.4.2 itself is a docs-hygiene release — no behavior change. Self-hosted: the feeder is planned as its own milestone and built by milestone-driver.

## Docs

- [docs/consumer-setup.md](docs/consumer-setup.md): setup and wiring.
- [docs/profile-schema.md](docs/profile-schema.md): every profile setting.
- [docs/architecture.md](docs/architecture.md): the as-built design and the checks.
- [SPEC.md](SPEC.md): the full design and spec.

## License

[MIT](LICENSE).
