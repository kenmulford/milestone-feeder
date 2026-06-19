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
agents_dir = REPO_ROOT / "agents"
if agents_dir.is_dir():
    for agent_md in sorted(agents_dir.rglob("*.md")):
        checked += 1
        fm = parse_frontmatter(agent_md)
        if fm is not None:
            require_keys(agent_md, fm, ["name", "description"])

# Commands: every commands/**/*.md (recursive) — require description only
# (a command's name is derived from its filename). None exist today.
commands_dir = REPO_ROOT / "commands"
if commands_dir.is_dir():
    for cmd_md in sorted(commands_dir.rglob("*.md")):
        checked += 1
        fm = parse_frontmatter(cmd_md)
        if fm is not None:
            require_keys(cmd_md, fm, ["description"])

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
