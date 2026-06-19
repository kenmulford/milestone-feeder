#!/usr/bin/env python3
"""validate-plugin-structure.py — the plugin-structure validation gate.

What this checks, in plain terms:
  A Claude Code plugin only loads if its manifests are valid JSON and its
  skills/agents/commands each start with a well-formed frontmatter block
  carrying the keys Claude Code reads. This script confirms exactly that, so a
  pull request that breaks a manifest or a frontmatter block fails before merge.

It checks:
  1. .claude-plugin/plugin.json      — parses as JSON, has required key `name`.
  2. .claude-plugin/marketplace.json — parses as JSON, has required keys
                                       `name` and `plugins` (a non-empty list).
  3. Every skills/**/SKILL.md and agents/**/*.md  — opens with a `---`-fenced
     frontmatter block carrying non-empty `name` and `description`. Every
     commands/**/*.md needs `description` (a command's name comes from its
     filename, so `name` is not required there).

Why a lenient line parser (NOT strict YAML — read before "upgrading" this):
  Claude Code's frontmatter reader is tolerant: it takes everything after the
  first colon on a `key:` line as that key's value. This repo's real, working
  skills rely on that — e.g. skills/plan/SKILL.md has
  `description: ... Read-only on GitHub: writes a single ...`, whose embedded
  ": " a STRICT YAML parser (PyYAML safe_load) rejects with "mapping values are
  not allowed here". Validating with strict YAML therefore FALSE-FAILS files
  that load fine in Claude Code — the worst thing a gate can do. So this parser
  deliberately mirrors the loader: split each top-level `key:` on its first
  colon, keep the rest as the value. It does not try to be a full YAML engine.
  Files are read as utf-8-sig so a leading BOM (e.g. from a Windows editor) is
  stripped rather than wrongly failing the line-1 fence check.

Dependencies: Python standard library only.

Run it locally from the repo root:  python3 scripts/validate-plugin-structure.py
Exit 0 = valid. Exit 1 = at least one structural problem (each printed).
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

errors: list[str] = []
warnings: list[str] = []
checked = 0


def err(path: Path, msg: str) -> None:
    errors.append(f"{path.relative_to(REPO_ROOT)}: {msg}")


def warn(path: Path, msg: str) -> None:
    warnings.append(f"{path.relative_to(REPO_ROOT)}: {msg}")


def load_json(path: Path) -> dict | None:
    """Parse a JSON file; record an error and return None on any failure."""
    if not path.is_file():
        err(path, "required manifest is missing")
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError as exc:
        err(path, f"is not valid JSON ({exc})")
        return None
    if not isinstance(data, dict):
        err(path, "must be a JSON object at the top level")
        return None
    return data


def parse_frontmatter(path: Path) -> dict | None:
    """Extract the leading `---` frontmatter block as a key->value dict.

    Lenient, dependency-free parser that mirrors Claude Code's tolerant reader
    (see the module docstring for why this is NOT strict YAML). Handles the flat
    `key: value` and `key: |`-style block-scalar shapes these files use. The
    file MUST open with `---` on line 1 and the block MUST close with a later
    `---`. Returns the parsed keys, or None if the fence is missing/unterminated
    (an error is recorded in that case).
    """
    text = path.read_text(encoding="utf-8-sig")
    lines = text.splitlines()

    if not lines or lines[0].strip() != "---":
        err(path, "missing opening '---' frontmatter fence on line 1")
        return None

    # Find the closing fence.
    close_idx = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            close_idx = i
            break
    if close_idx is None:
        err(path, "frontmatter opened with '---' but is never closed")
        return None

    body = lines[1:close_idx]
    data: dict[str, str] = {}
    current_key: str | None = None
    collecting_block = False  # inside a `key: |` block scalar

    for raw in body:
        # A top-level key is unindented and matches `key:` or `key: value`.
        stripped = raw.strip()
        is_indented = raw[:1] in (" ", "\t")

        if not is_indented and ":" in raw and not collecting_block:
            key, _, value = raw.partition(":")
            key = key.strip()
            value = value.strip()
            if value in ("|", ">", "|-", ">-", "|+", ">+"):
                # Block scalar — value continues on indented lines below.
                current_key = key
                data[key] = ""
                collecting_block = True
            else:
                # Inline value (may be quoted; strip matching quotes).
                if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                    value = value[1:-1]
                data[key] = value
                current_key = key
                collecting_block = False
        elif collecting_block and current_key is not None:
            if is_indented or stripped == "":
                # Continuation of the block scalar.
                data[current_key] = (data[current_key] + "\n" + stripped).strip()
            else:
                # An unindented non-key line ends the block; reprocess as a key.
                collecting_block = False
                if ":" in raw:
                    key, _, value = raw.partition(":")
                    key = key.strip()
                    value = value.strip()
                    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                        value = value[1:-1]
                    data[key] = value
                    current_key = key

    return data


def require_keys(path: Path, data: dict, keys: list[str]) -> None:
    for key in keys:
        if key not in data:
            err(path, f"frontmatter is missing required key '{key}'")
        elif not str(data[key]).strip():
            err(path, f"frontmatter key '{key}' is empty")


# --- 1 & 2: manifests -------------------------------------------------------

plugin_json = REPO_ROOT / ".claude-plugin" / "plugin.json"
marketplace_json = REPO_ROOT / ".claude-plugin" / "marketplace.json"

pj = load_json(plugin_json)
if pj is not None:
    checked += 1
    if not str(pj.get("name", "")).strip():
        err(plugin_json, "missing required key 'name'")
    for rec in ("version", "description"):
        if rec not in pj:
            warn(plugin_json, f"recommended key '{rec}' is absent")

mj = load_json(marketplace_json)
if mj is not None:
    checked += 1
    if not str(mj.get("name", "")).strip():
        err(marketplace_json, "missing required key 'name'")
    plugins = mj.get("plugins")
    if not isinstance(plugins, list) or len(plugins) == 0:
        err(marketplace_json, "required key 'plugins' must be a non-empty list")

# --- 3: skill / agent / command frontmatter ---------------------------------

# Skills: every skills/**/SKILL.md — require name + description.
for skill_md in sorted((REPO_ROOT / "skills").rglob("SKILL.md")):
    checked += 1
    fm = parse_frontmatter(skill_md)
    if fm is not None:
        require_keys(skill_md, fm, ["name", "description"])

# Agents: every agents/**/*.md (recursive) — require name + description.
# Also collect each agent's `name` for the no-source-edit drift-guard below.
agent_names: list[str] = []
agents_dir = REPO_ROOT / "agents"
if agents_dir.is_dir():
    for agent_md in sorted(agents_dir.rglob("*.md")):
        checked += 1
        fm = parse_frontmatter(agent_md)
        if fm is not None:
            require_keys(agent_md, fm, ["name", "description"])
            name = str(fm.get("name", "")).strip()
            if name:
                agent_names.append(name)

# Commands: every commands/**/*.md (recursive) — require description only
# (a command's name is derived from its filename). None exist today.
commands_dir = REPO_ROOT / "commands"
if commands_dir.is_dir():
    for cmd_md in sorted(commands_dir.rglob("*.md")):
        checked += 1
        fm = parse_frontmatter(cmd_md)
        if fm is not None:
            require_keys(cmd_md, fm, ["description"])

# --- 4: no-source-edit actor-gate drift-guard -------------------------------
#
# Why this exists: hooks/no-source-edit.{sh,ps1} carry a HARDCODED set of the
# feeder's OWN agent names. That set is a security control — it must live inside
# the protected hooks/** boundary, NOT be read from feeder.json — so it cannot be
# auto-derived at runtime. This guard prevents the safety-relevant drift: if
# someone adds or renames an agents/*.md without updating the hooks, that agent
# would be MISSING from the hook set, so the gate would mis-classify it (treating
# a feeder subagent as an outside actor and letting it write source).
#
# Each hook carries the set TWICE and the two must agree:
#   1. A machine-parseable COMMENT literal:  # FEEDER_OWN_AGENTS: <name> <name>
#      (identical text in both scripts; one regex parses it for sh and ps1).
#   2. The RUNTIME literal the hook actually executes — language-specific:
#        sh:   FEEDER_OWN_AGENTS="architect issue-author"   (space-separated)
#        ps1:  $FeederOwnAgents = @('architect', 'issue-author')  (PS array)
# The guard verifies BOTH literals: it parses the runtime set the hook truly
# uses, asserts it equals the comment set (so neither a stale comment nor a stale
# runtime line can pass silently — a maintainer who updates one but not the other
# is caught), and coverage-checks the RUNTIME set against agents/*.md (the runtime
# set is the one the live gate executes, so it is the safety-relevant one to
# cover). The comment set is also coverage-checked as belt-and-suspenders.
#
# The coverage check is intentionally ONE-DIRECTIONAL: it asserts every agent
# name in agents/*.md appears in each hook's set. It does NOT flag a stale extra
# name that is in a hook set but no longer in agents/*.md — that direction is
# fail-CLOSED (a non-existent agent name can never match a real actor, so at worst
# it is dead weight). The comment-vs-runtime check, by contrast, IS strict set
# equality, because a disagreement there is exactly the false-PASS this guard
# exists to catch. All parsing is stdlib `re` only — NO shell/pwsh execution.

FEEDER_AGENT_SET_RE = re.compile(r"^#\s*FEEDER_OWN_AGENTS:\s*(.+?)\s*$", re.MULTILINE)

# Runtime literals, keyed by hook-script type (see the block comment above).
#   sh:  capture the value inside FEEDER_OWN_AGENTS="...".
#   ps1: capture the inside of $FeederOwnAgents = @( ... ), then pull each
#        single- or double-quoted token out of that captured group.
RUNTIME_SH_RE = re.compile(r'^FEEDER_OWN_AGENTS="([^"]*)"', re.MULTILINE)
RUNTIME_PS1_RE = re.compile(r"\$FeederOwnAgents\s*=\s*@\(([^)]*)\)")
PS1_TOKEN_RE = re.compile(r"""['"]([^'"]*)['"]""")


def parse_hook_agent_set(path: Path) -> set[str] | None:
    """Extract the COMMENT-literal feeder-agent set from a hook script.

    Reads the `# FEEDER_OWN_AGENTS: a b c` comment literal both hook scripts
    carry and returns the names as a set. This is only one of the two literals
    the drift-guard verifies: it ALSO parses each script's RUNTIME literal (see
    parse_hook_runtime_set) and asserts the two agree and both cover every agent,
    so neither a stale comment nor a stale runtime line can pass silently.
    Records an error and returns None if the comment literal is missing or empty
    (a hook that lost the set can no longer be drift-checked).
    """
    if not path.is_file():
        err(path, "required hook script is missing")
        return None
    text = path.read_text(encoding="utf-8-sig")
    m = FEEDER_AGENT_SET_RE.search(text)
    if m is None:
        err(path, "missing the '# FEEDER_OWN_AGENTS: ...' set literal "
                  "(required for the actor-gate drift-guard)")
        return None
    names = {n for n in m.group(1).split() if n}
    if not names:
        err(path, "'# FEEDER_OWN_AGENTS:' literal is empty")
        return None
    return names


def parse_hook_runtime_set(path: Path, label: str) -> set[str] | None:
    """Extract the RUNTIME feeder-agent literal the hook actually executes.

    Language-specific (keyed by `label`, the hook_scripts dict key): the sh
    `FEEDER_OWN_AGENTS="..."` string or the ps1 `$FeederOwnAgents = @(...)`
    array. Returns the names as a set, or records an error and returns None if
    the runtime literal is missing or empty (a hook that lost its executable set
    can mis-classify actors). stdlib `re` only — the script is never executed.
    """
    text = path.read_text(encoding="utf-8-sig")
    if label == "sh":
        m = RUNTIME_SH_RE.search(text)
        names = {n for n in m.group(1).split() if n} if m else None
    elif label == "ps1":
        m = RUNTIME_PS1_RE.search(text)
        names = {t for t in PS1_TOKEN_RE.findall(m.group(1)) if t} if m else None
    else:  # pragma: no cover — guard against an unknown script type.
        names = None
    if not names:
        err(path, "missing or empty RUNTIME FEEDER_OWN_AGENTS literal "
                  "(the set the hook actually executes) — required for the "
                  "actor-gate drift-guard")
        return None
    return names


hook_scripts = {
    "sh": REPO_ROOT / "hooks" / "no-source-edit.sh",
    "ps1": REPO_ROOT / "hooks" / "no-source-edit.ps1",
}
for _label, hook_path in hook_scripts.items():
    checked += 1
    comment_set = parse_hook_agent_set(hook_path)
    runtime_set = parse_hook_runtime_set(hook_path, _label) if hook_path.is_file() else None
    if comment_set is None or runtime_set is None:
        continue
    # Comment-vs-runtime: strict equality. A disagreement is the false-PASS this
    # guard exists to catch (e.g. comment updated but runtime line left stale).
    if comment_set != runtime_set:
        err(hook_path, f"FEEDER_OWN_AGENTS comment literal "
                       f"{sorted(comment_set)} disagrees with the runtime literal "
                       f"{sorted(runtime_set)} the hook executes — update both so "
                       f"the live actor gate matches its documented set")
    # Coverage: every declared agent must appear in BOTH sets. The runtime set is
    # the safety-relevant one (it is what the live gate executes); the comment set
    # is checked too as belt-and-suspenders.
    for agent_name in agent_names:
        if agent_name not in runtime_set:
            err(hook_path, f"runtime FEEDER_OWN_AGENTS set is missing agent "
                           f"'{agent_name}' (declared in agents/*.md) — the "
                           f"no-source-edit actor gate the hook executes has "
                           f"drifted from the real agent set; add it to keep the "
                           f"safety gate correct")
        if agent_name not in comment_set:
            err(hook_path, f"FEEDER_OWN_AGENTS comment literal is missing agent "
                           f"'{agent_name}' (declared in agents/*.md) — the "
                           f"actor-gate drift-guard comment has drifted from the "
                           f"real agent set; add it to keep the safety gate correct")

# --- report -----------------------------------------------------------------

for w in warnings:
    print(f"WARN: {w}", file=sys.stderr)

if errors:
    print(f"FAIL: plugin structure invalid ({len(errors)} problem(s)):", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)

print(f"PASS: plugin structure valid ({checked} file(s) checked, "
      f"{len(warnings)} warning(s)).")
sys.exit(0)
