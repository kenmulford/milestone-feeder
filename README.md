<p align="center">
  <img src="assets/milestone-feeder.svg" alt="milestone-feeder — a milestone suite plugin" width="590">
</p>

Turn a rough idea into a build-ready GitHub milestone — a tidy list of small, well-formed issues, in the order they should be built.

milestone-feeder is a Claude Code plugin. You hand it a brief — a file, a few lines of text, or a GitHub epic issue — and it writes a reviewable plan: each piece of work as its own issue, with a full spec, the decisions an engineer would otherwise have to invent, and a build order. You read the plan, then tell it to build the milestone on GitHub. Its sibling plugin, [`milestone-driver`](https://github.com/kenmulford/milestone-driver), can then pick the issues up and build them with no further clarification. Once a change is built, [`milestone-coherence-reviewer`](https://github.com/kenmulford/milestone-coherence-reviewer) reviews the result and, if it drifted far from intent, hands a follow-up brief back to the feeder.

**Before you install, add `superpowers` first.** milestone-feeder needs the `superpowers` plugin to plan — it is a required prerequisite you now install yourself (it is no longer pulled in automatically). Add the `claude-plugins-official` marketplace and install `superpowers` from it, then install milestone-feeder from one of the marketplaces below, then restart Claude Code so the plugin's hook loads. Skip `superpowers` and the planning commands won't work.

**Recommended — the milestone-suite marketplace.** One marketplace carries all four milestone plugins (`milestone-bootstrapper`, `milestone-feeder`, `milestone-driver`, `milestone-coherence-reviewer`), so you add it once and install whichever you want:

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
- **`milestone-driver` is optional.** The feeder drafts every issue to pass the driver's triage clean, and on a clean run `create` can hand the milestone straight to the driver to start building. If it isn't installed, the feeder still plans and deploys — you just run the driver later, or not at all.

One thing worth knowing: **`plan` never writes to GitHub.** It only *reads* — and only when you hand it an epic issue as the brief (it runs `gh issue view` on that one issue). Everything `plan` produces is a local file you review. The GitHub writes above are what `create`, `update`, and `setup` need — not `plan`.

## How it works

You hand `plan` your idea. It reads your project's standing docs and breaks the idea into small, buildable issues — recording, for each one, the decisions an engineer would otherwise have to invent, and citing the house rule it followed. Each issue is written to pass the same triage `milestone-driver` runs before it starts a build, so what you approve is ready to build. A decision with no conventional default it never guesses — it flags it for you to make. Then `create` builds exactly what you approved.

Two things make that work, in plain terms:

- **It grounds every issue in your real conventions.** Instead of inventing a design, it reads your project's standing docs and reuses what's already there — recording "reuse the shared `FormField` component", with a citation, rather than making something up. A rule that applies everywhere (say, "all tables paginate at 30 rows per page") flows into every issue it touches.
- **It drafts each issue to the bar your builder uses — and flags what it can't answer, never guesses.** Every issue is written to pass the same triage `milestone-driver` runs before it starts a build (that's where the bar is actually enforced, once the driver picks the milestone up). A decision with no conventional default — a real product call only you can make — it sets aside and lists for you in a needs-input report, rather than guessing an answer to make the issue look finished.

The richer your project docs, the better the issues and the fewer decisions land back on your plate. Nothing here is new machinery — it's the grounding and the drafting-to-the-bar, described in plain terms.

A few more things the feeder does for you:

- **Name your milestone with a version up front.** Add a line like `Milestone: myapp v1.2.0` to your brief (or just say it inline). The feeder reads the version straight from the milestone's name so its sibling, `milestone-driver`, knows exactly what version to build toward. If you don't name one, the feeder proposes a version — pulled from your existing milestones or git tags — and shows it to you to confirm or change before it builds anything. You're never handed a milestone whose name you didn't get to see.
- **A whole-app brief becomes a sequenced roadmap of milestones.** If your idea really reads as several separate releases, `plan` hands it to a roadmap step first: it carves the brief into a build-ordered set of milestones and shows you the split, so you can confirm it, merge or split a milestone, reorder them, or reject it — before it plans anything. Once you confirm, `plan` plans every milestone in the roadmap (in parallel), and `create` deploys them in build order. A normal, single-release brief is unchanged — no roadmap step, no extra prompt. Never a silent giant milestone, and never a hard stop — the call is yours.
- **That roadmap deploy also creates a parent issue for the build engine.** It ties the milestones together, in build order, so `milestone-driver` builds them in sequence.
- **It puts your milestone on your Trello board, if you use one.** When your `milestone-driver` is set up with Trello, `create` also drops a card for the new milestone on your board — with its issues as a checklist — so the work shows up where you track it the moment it's created. There's no Trello setting of your own to add: `create` reads the board from your driver config, and if you don't use Trello, nothing changes.

## Config

Configuration is **optional** — every setting has a sensible default, so the tool runs with no config at all. When you do want to tune it, the settings live in `.milestone-config/feeder.json` (the same folder `milestone-driver` keeps its `driver.json` in). The first `plan` run writes this file for you.

- **`projectDocs`** (default `.project/`) — the folder where your project's standing docs live: architecture notes, coding conventions, a design system. This is what the feeder reads to ground every issue in your real conventions.
- **`issueSize`** (optional) — a natural-language sizing rule the breakdown should honor, e.g. `"≤1 PR, ≤1 new screen"`. Leave it out for no constraint beyond the defaults.

The build-side settings — your UI-surface paths, your integration branch, your source paths — are **read from your `milestone-driver` config**, not repeated here.

Full setup walkthrough: [docs/consumer-setup.md](docs/consumer-setup.md). Every setting explained: [docs/profile-schema.md](docs/profile-schema.md).

## Status

v0.9.0 — the live surface (`plan` / `create` / `update`, no flags, plan-file-as-contract). `plan` **drafts** each issue to clear `milestone-driver`'s triage on the first pass — the driver's triage is the single automated check, so the feeder aims squarely at that bar instead of re-running it before anything exists (a leaner, faster plan run). It now **breaks the work down along your project's architecture** — each issue assigned to the layer your `.project` conventions dictate, ordered so a layer lands before the layers that depend on it — and **points each issue at the relevant `.project` config** (color tokens, design-system, environment) by path, so the driver reads your source of truth at build time rather than a value baked into the issue. When your brief names a capability — "add email", "user management", "sync" — or introduces a new kind of record, `plan` now proposes the standard companion surfaces that capability implies (a delivery-failure log, activate / deactivate / reset-password, a list and detail screen) as reviewable candidates, each marked for you to keep, trim, or augment — and asks, out loud, "this is a starting set for YOUR app — what's missing?" — before any issue is created; a real product call with no obvious default is still set aside for your decision, never guessed. Hand `plan` a whole-app brief that spans several releases and it carves it into a sequenced roadmap of milestones, confirms the split with you once, and plans them all in parallel; `create` then deploys them in build order. Name your milestone with a version up front and the feeder hands it cleanly to `milestone-driver` — and on a clean run `create` can hand the milestone straight to the driver to start building (v0.5.0). After the build, `milestone-coherence-reviewer` reviews the result and hands a follow-up brief back to the feeder when a change drifted far from intent. A single-release brief that invokes no new capability or entity is unchanged — no roadmap step, no implied-surface prompt. Self-hosted: the feeder is planned as its own milestone and built by milestone-driver.

## Docs

- [docs/consumer-setup.md](docs/consumer-setup.md): setup and wiring.
- [docs/profile-schema.md](docs/profile-schema.md): every profile setting.
- [docs/architecture.md](docs/architecture.md): the as-built design and how it grounds each issue.
- [SPEC.md](SPEC.md): the full design and spec.

## License

[MIT](LICENSE).
