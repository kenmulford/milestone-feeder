# Library manifest

<!--
Project doc (.project/). Cite as `.project/library-manifest.md#<section>`. The
implementer's "new dependency = PAUSE" gate reads this; the coherence-reviewer
flags a new library that duplicates one listed here. Keep it current. Keep ##
headings stable — they are citation anchors.
-->

## Runtime & frameworks
The platform/runtime and primary frameworks, with versions. (Mirror these into milestone-driver `nonNegotiables` where they're hard constraints.)
Claude Code plugin: markdown **skills** (frontmatter triggers) + markdown **agents** + **hooks** shipped as cross-platform **bash (`jq`) and PowerShell 7+** twins, BOM-free, LF line endings. No compiled runtime. Hard dependency: the `superpowers` plugin (declared in `.claude-plugin/plugin.json`). The plugin version is pinned in `.claude-plugin/plugin.json` (`version: 0.4.5`). Mirror into `milestone-driver` `nonNegotiables` — already present: "Claude Code plugin: markdown skills + bash-first/pwsh-fallback hooks"; "Cross-platform: bash (jq) and PowerShell 7+". (Grounded in `.claude-plugin/plugin.json`; `.milestone-config/driver.json` nonNegotiables; `.gitattributes`; stack detection.)

## Approved libraries (by purpose)
One approved choice per purpose, so a redundant alternative is easy to spot.

| Purpose | Library | Notes |
|---|---|---|
| GitHub writes/reads | `gh` (GitHub CLI) | `gh label/issue/api` — the only way the feeder touches GitHub (`docs/consumer-setup.md` Before you start). |
| JSON parsing in hooks | `jq` (bash path) | The bash hook form; the PowerShell 7+ twin uses native `ConvertFrom-Json`. |
| Cross-platform shell | bash + PowerShell 7+ | Every hook/script ships as a twin (`.sh` + `.ps1`) via the `run-hook.cmd` polyglot launcher. |
| Reviewer backend (optional) | `milestone-driver` plugin | Backs `reviewer: "milestone-driver"`; absent → degrades to `"internal"`. |
| Plan pipeline dependency | `superpowers` plugin | Hard dependency declared in the manifest. |

## Adding a dependency (the gate)
A new dependency is a PAUSE, not an autonomous call. Record what it buys, its license / OSS status, and why nothing approved suffices; a human approves before it's added.
A new dependency is a PAUSE, not an autonomous call — record what it buys, its license / OSS status, and why nothing approved suffices; a human approves before it's added. Profile keys follow the same discipline: **added only when a real consumer needs them, never speculatively**. Proposals go to a GitHub issue labeled `needs decision`. (Grounded in `docs/profile-schema.md` Design principle; suite convention.)

## Avoid / banned
Libraries explicitly not to use, and why.
No CRLF line endings in `*.cmd` / `*.sh` / `*.ps1` (CRLF breaks the bash heredoc delimiter and produces "bad interpreter" — enforced by `.gitattributes`). No BOM in scripts. No bash-only or pwsh-only hook — every hook/script must ship **both** twins with identical behavior. No `version` field in `.claude-plugin/marketplace.json` (Claude Code resolves `plugin.json` first). The feeder must never write source, open a PR, or touch a branch. (Grounded in `.gitattributes`; `docs/architecture.md` Plugin version, The mechanical gate.)
