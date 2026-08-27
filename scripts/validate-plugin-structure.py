#!/usr/bin/env python3
"""validate-plugin-structure.py: the plugin-structure validation gate.

What this checks, in plain terms:
  A Claude Code plugin only loads if its manifests are valid JSON and its
  skills/agents/commands each start with a well-formed frontmatter block
  carrying the keys Claude Code reads. This script confirms exactly that, so a
  pull request that breaks a manifest or a frontmatter block fails before merge.

It checks:
  1. .claude-plugin/plugin.json:      parses as JSON, has required key `name`.
  2. .claude-plugin/marketplace.json: parses as JSON, has required keys
                                      `name` and `plugins` (a non-empty list).
  3. Every skills/**/SKILL.md and agents/**/*.md: opens with a `---`-fenced
     frontmatter block carrying non-empty `name` and `description`. Every
     commands/**/*.md needs `description` (a command's name comes from its
     filename, so `name` is not required there). Governed frontmatter
     (skills/**/SKILL.md, agents/**/*.md, commands/**/*.md) is additionally
     strict-scalar checked: no unquoted plain scalar may carry a colon+space that
     Claude Desktop's strict YAML loader would reject (issue #292; see the
     strict-scalar note below).
  4. Size budgets (issue #270): every governed prose file stays at or under
     its own per-file word-count ceiling: the six skills/**/SKILL.md, the
     four agents/**/*.md, SPEC.md, and the twelve docs/*.md a skill or an
     agent references at run time. Every agents/**/*.md frontmatter
     `description` also stays at or under a flat 150-word ceiling. A
     written size standard with no gate is exactly what let these regrow past
     their targets before (see "--- 6: size budgets ---" below).
  5. The nested .milestone-config/.gitignore self-heal block (issue #492): its
     three hand-synced copies stay equal line for line. Those are
     scripts/emit-notice.json's `writes.lines` array, the fenced block in
     docs/one-time-notices.md, and this repo's own committed
     .milestone-config/.gitignore. A drifted copy is named, and so is a
     missing one (see "--- 7: nested .gitignore three-copy pin ---" below).

Two readers, two rules (read before "upgrading" this):
  Claude Code's frontmatter reader is tolerant: it takes everything after the
  first colon on a `key:` line as that key's value. So the parser below
  deliberately mirrors it for key extraction: split each top-level `key:` on its
  first colon, keep the rest as the value. It does not try to be a full YAML
  engine. Files are read as utf-8-sig so a leading BOM (e.g. from a Windows
  editor) is stripped rather than wrongly failing the line-1 fence check.

  Claude Desktop's loader, by contrast, is STRICT (js-yaml): an unquoted plain
  scalar whose value contains a colon+space (": ") is read as a nested mapping,
  so the skill silently fails to register (issue #292). That strict loader is
  ground truth for whether a skill loads in Desktop. So the strict-scalar check
  below FAILS any governed frontmatter (skills/**/SKILL.md, agents/**/*.md,
  commands/**/*.md) carrying that exact construct. This is not a false-fail risk: the governed
  files' long descriptions are folded block scalars (`description: >-`), which
  the strict loader accepts, and block-scalar or quoted values are exempt by
  construction. The check stays stdlib-only by design: it detects the one
  rejected construct without parsing YAML, so CI needs no PyYAML and no
  dependency-install step.

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


# Block-scalar indicators a top-level value may legitimately be (no inline value
# follows on the header line; the real value is on the indented lines below).
# Defined once here and consumed by BOTH walkers: parse_frontmatter (key
# extraction) and check_strict_scalars (strict-loader gate). The set can
# therefore never drift between them.
_BLOCK_SCALAR_INDICATORS = ("|", ">", "|-", ">-", "|+", ">+")


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
            if value in _BLOCK_SCALAR_INDICATORS:
                # Block scalar: value continues on indented lines below.
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


def check_strict_scalars(path: Path) -> None:
    """Fail any governed-frontmatter plain scalar a STRICT YAML loader rejects.

    Claude Desktop's frontmatter loader is strict (js-yaml): an unquoted plain
    scalar whose value contains a colon+space (": ") is parsed as a nested
    mapping and the skill silently fails to register (issue #292). This check
    catches exactly that defect class across the governed frontmatter
    (skills/**/SKILL.md, agents/**/*.md, commands/**/*.md). It is stdlib-only,
    with no YAML parse. It walks the top-level `key: value` lines of the
    frontmatter block and flags any whose value is an unquoted plain scalar
    (does not start with |, >, ', or ") containing ": ". Block-scalar header
    lines (`key: >-`) carry no inline value and their indented continuation
    lines belong to the block, so both are exempt; a quoted value escapes the
    colon and is exempt too.

    The `collecting_block` state is load-bearing, not decorative: an indented line
    is exempt ONLY while inside a block scalar (its body). An indented line while
    NOT collecting a block is a plain-scalar CONTINUATION line (a multi-line
    plain value folded onto the next line), which js-yaml folds and rejects a
    ": " on exactly as it would on the header line (the #292 defect class,
    line-wrapped). So such a continuation line is flagged too, citing its own
    line number. The ": " test runs against the value with its TRAILING
    whitespace intact (only leading whitespace after the key's colon is stripped),
    so a value ending in a colon+space (e.g. `key: …drift: `) is not masked.

    Errors are recorded via err(); nothing is returned. Fence problems are not
    re-reported here (parse_frontmatter/require_keys already flag them).
    """
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    if not lines or lines[0].strip() != "---":
        return
    close_idx = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            close_idx = i
            break
    if close_idx is None:
        return

    _MSG = (
        "Claude Desktop's strict YAML loader (js-yaml) parses this as a nested "
        "mapping and the skill silently fails to register (issue #292); make the "
        "value a folded block scalar ('key: >-' with the text indented below) or "
        "quote it"
    )

    collecting_block = False  # inside a `key: >-`-style block scalar
    for i in range(1, close_idx):
        raw = lines[i]
        is_indented = raw[:1] in (" ", "\t")
        if collecting_block:
            if is_indented or raw.strip() == "":
                continue  # continuation of a block scalar, exempt.
            collecting_block = False  # unindented line ends the block; process it.
        if is_indented:
            # Not a block-scalar body (handled above) → a plain-scalar
            # continuation line. js-yaml folds it and rejects a ": " here just
            # as on the header line, so flag it (issue #292, line-wrapped).
            if ": " in raw:
                err(
                    path,
                    f"frontmatter line {i + 1} plain-scalar continuation "
                    f"'{raw.strip()}' contains a colon+space (': '). {_MSG}",
                )
            continue
        if ":" not in raw:
            continue
        # lstrip only: drop the leading space after the key's own colon so
        # `key: foo` never false-positives on its separator, but keep any TRAILING
        # whitespace so a value ending in ": " is still caught (fix: strip() here
        # masked a trailing colon+space).
        value = raw.partition(":")[2].lstrip()
        if value.strip() in _BLOCK_SCALAR_INDICATORS:
            collecting_block = True
            continue
        if not value.strip() or value[0] in ("|", ">", "'", '"'):
            continue  # block scalar / quoted value, exempt by construction.
        if ": " in value:
            err(
                path,
                f"frontmatter line {i + 1} value '{value.strip()}' is an "
                f"unquoted plain scalar containing a colon+space (': '). {_MSG}",
            )


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

# Skills: every skills/**/SKILL.md. Require name + description.
for skill_md in sorted((REPO_ROOT / "skills").rglob("SKILL.md")):
    checked += 1
    fm = parse_frontmatter(skill_md)
    if fm is not None:
        require_keys(skill_md, fm, ["name", "description"])
        check_strict_scalars(skill_md)

# Agents: every agents/**/*.md (recursive). Require name + description.
# Also collect each agent's `name` for the no-source-edit drift-guard below.
agent_names: list[str] = []
agents_dir = REPO_ROOT / "agents"
if agents_dir.is_dir():
    for agent_md in sorted(agents_dir.rglob("*.md")):
        checked += 1
        fm = parse_frontmatter(agent_md)
        if fm is not None:
            require_keys(agent_md, fm, ["name", "description"])
            check_strict_scalars(agent_md)
            name = str(fm.get("name", "")).strip()
            if name:
                agent_names.append(name)

# Commands: every commands/**/*.md (recursive). Require description only
# (a command's name is derived from its filename). None exist today.
commands_dir = REPO_ROOT / "commands"
if commands_dir.is_dir():
    for cmd_md in sorted(commands_dir.rglob("*.md")):
        checked += 1
        fm = parse_frontmatter(cmd_md)
        if fm is not None:
            require_keys(cmd_md, fm, ["description"])
            # Desktop's strict loader reads command frontmatter identically to
            # skills'/agents', so the #292 strict-scalar rule governs it too.
            check_strict_scalars(cmd_md)

# --- 4: no-source-edit actor-gate drift-guard -------------------------------
#
# Why this exists: hooks/no-source-edit.{sh,ps1} carry a HARDCODED set of the
# feeder's OWN agent names. That set is a security control: it must live inside
# the protected hooks/** boundary, NOT be read from feeder.json. So it cannot be
# auto-derived at runtime. This guard prevents the safety-relevant drift: if
# someone adds or renames an agents/*.md without updating the hooks, that agent
# would be MISSING from the hook set, so the gate would mis-classify it (treating
# a feeder subagent as an outside actor and letting it write source).
#
# Each hook carries the set TWICE and the two must agree:
#   1. A machine-parseable COMMENT literal:  # FEEDER_OWN_AGENTS: <name> <name>
#      (identical text in both scripts; one regex parses it for sh and ps1).
#   2. The RUNTIME literal the hook actually executes, language-specific:
#        sh:   FEEDER_OWN_AGENTS="architect issue-author"   (space-separated)
#        ps1:  $FeederOwnAgents = @('architect', 'issue-author')  (PS array)
# The guard verifies BOTH literals: it parses the runtime set the hook truly
# uses, asserts it equals the comment set (so neither a stale comment nor a stale
# runtime line can pass silently; a maintainer who updates one but not the other
# is caught), and coverage-checks the RUNTIME set against agents/*.md (the runtime
# set is the one the live gate executes, so it is the safety-relevant one to
# cover). The comment set is also coverage-checked as belt-and-suspenders.
#
# The coverage check is BIDIRECTIONAL: it asserts every agent name in
# agents/*.md appears in each hook's set (forward: a missing name would let the
# gate mis-classify a real feeder subagent as an outside actor), AND that every
# name in each hook's set has a matching agents/*.md file (reverse: a name with
# no matching agent is dead weight left behind by a deletion/rename, e.g. a
# deleted agent never trimmed from the allowlist). Neither direction is
# exempted: a missing name and an orphaned name both fail CI. The comment-vs-
# runtime check, separately, IS strict set equality, because a disagreement
# there is exactly the false-PASS this guard exists to catch. All parsing is
# stdlib `re` only. NO shell/pwsh execution.

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
        err(
            path,
            "missing the '# FEEDER_OWN_AGENTS: ...' set literal "
            "(required for the actor-gate drift-guard)",
        )
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
    can mis-classify actors). stdlib `re` only. The script is never executed.
    """
    text = path.read_text(encoding="utf-8-sig")
    if label == "sh":
        m = RUNTIME_SH_RE.search(text)
        names = {n for n in m.group(1).split() if n} if m else None
    elif label == "ps1":
        m = RUNTIME_PS1_RE.search(text)
        names = {t for t in PS1_TOKEN_RE.findall(m.group(1)) if t} if m else None
    else:  # pragma: no cover. Guard against an unknown script type.
        names = None
    if not names:
        err(
            path,
            "missing or empty RUNTIME FEEDER_OWN_AGENTS literal "
            "(the set the hook actually executes), required for the "
            "actor-gate drift-guard",
        )
        return None
    return names


hook_scripts = {
    "sh": REPO_ROOT / "hooks" / "no-source-edit.sh",
    "ps1": REPO_ROOT / "hooks" / "no-source-edit.ps1",
}
# Set form of agent_names for O(1) `in` checks in the reverse-coverage loops
# below (agent_names itself stays a list; order doesn't matter for membership,
# but no need to change its existing type/uses elsewhere in this script).
agent_names_set = set(agent_names)
for _label, hook_path in hook_scripts.items():
    checked += 1
    comment_set = parse_hook_agent_set(hook_path)
    runtime_set = (
        parse_hook_runtime_set(hook_path, _label) if hook_path.is_file() else None
    )
    if comment_set is None or runtime_set is None:
        continue
    # Comment-vs-runtime: strict equality. A disagreement is the false-PASS this
    # guard exists to catch (e.g. comment updated but runtime line left stale).
    if comment_set != runtime_set:
        err(
            hook_path,
            f"FEEDER_OWN_AGENTS comment literal "
            f"{sorted(comment_set)} disagrees with the runtime literal "
            f"{sorted(runtime_set)} the hook executes. Update both so "
            f"the live actor gate matches its documented set",
        )
    # Coverage: every declared agent must appear in BOTH sets. The runtime set is
    # the safety-relevant one (it is what the live gate executes); the comment set
    # is checked too as belt-and-suspenders.
    for agent_name in agent_names:
        if agent_name not in runtime_set:
            err(
                hook_path,
                f"runtime FEEDER_OWN_AGENTS set is missing agent "
                f"'{agent_name}' (declared in agents/*.md). The "
                f"no-source-edit actor gate the hook executes has "
                f"drifted from the real agent set; add it to keep the "
                f"safety gate correct",
            )
        if agent_name not in comment_set:
            err(
                hook_path,
                f"FEEDER_OWN_AGENTS comment literal is missing agent "
                f"'{agent_name}' (declared in agents/*.md). The "
                f"actor-gate drift-guard comment has drifted from the "
                f"real agent set; add it to keep the safety gate correct",
            )
    # Reverse coverage: every name the hook actually carries must map to a real
    # agents/*.md file. This is the NEW direction. An orphaned name (e.g. a
    # deleted agent left behind in the hook's allowlist) is dead weight that
    # silently masks drift forever without this check. No escape hatch: any
    # orphaned name fails CI, full stop.
    for name in runtime_set:
        if name not in agent_names_set:
            err(
                hook_path,
                f"runtime FEEDER_OWN_AGENTS set contains '{name}', "
                f"which has no matching agents/*.md. This is a stale "
                f"orphaned name (e.g. from a deleted agent); remove it "
                f"from the hook's allowlist",
            )
    for name in comment_set:
        if name not in agent_names_set:
            err(
                hook_path,
                f"FEEDER_OWN_AGENTS comment literal contains '{name}', "
                f"which has no matching agents/*.md. This is a stale "
                f"orphaned name (e.g. from a deleted agent); remove it "
                f"from the hook's comment literal",
            )

# --- 5: cross-file SKILL.md line-citation guard -----------------------------
#
# Why this exists: the skills cross-reference one another to ground their design
# decisions. When one skill cites another by ABSOLUTE LINE NUMBER (e.g.
# `skills/plan/SKILL.md:579-591`), any later insertion into the cited file shifts
# every line below it and SILENTLY invalidates the citation: it now points at
# unrelated text, with nothing to flag the drift (issue #154 alone drifted ~10
# such refs by ~67 lines). A STABLE NAMED ANCHOR names the cited target by its
# Step / section / § heading instead of a line number. It does not drift on
# insert, because the heading text moves together with the content it labels.
#
# This guard scans every skills/**/SKILL.md for a `…SKILL.md:NNN` (or `:NNN-MMM`)
# reference and flags it WHEN the cited path is a DIFFERENT file than the one the
# citation lives in (a cross-file line citation, the drift-prone kind). This
# covers in-repo cross-file refs AND cross-repo `<plugin>/skills/.../SKILL.md:NNN`
# refs (no exemptions). A SELF-REF is one where the cited path IS the containing
# file (e.g. `skills/plan/SKILL.md:336` written inside skills/plan/SKILL.md). It
# is ALLOWED: an intra-file line number is the author's own to keep current and
# is out of this guard's scope. The fix for a flagged citation is always the
# same: replace the `:NNN` with the target's stable heading name. stdlib `re`
# only; scoped to skills/**/SKILL.md (docs / SPEC prose is intentionally NOT
# scanned).

CROSS_FILE_LINE_CITATION_RE = re.compile(r"([A-Za-z0-9_./-]*SKILL\.md):\d+(?:-\d+)?")

for skill_md in sorted((REPO_ROOT / "skills").rglob("SKILL.md")):
    text = skill_md.read_text(encoding="utf-8-sig")
    for m in CROSS_FILE_LINE_CITATION_RE.finditer(text):
        cited_path = (REPO_ROOT / m.group(1)).resolve()
        if cited_path != skill_md.resolve():
            err(
                skill_md,
                f"cross-file line citation '{m.group(0)}'. Line numbers "
                f"drift when the cited file changes, silently invalidating "
                f"the reference; cite the target by its stable heading "
                f"(its Step / section / § name) instead of a line number",
            )

# --- 6: size budgets ---------------------------------------------------------
#
# Why this exists: a written size STANDARD with no enforcing GATE is exactly
# what let skills/plan/SKILL.md and its siblings regrow past their own stated
# targets before (issue #262's re-trim, issue #263's agent-description trim).
# This check is the gate that protects the standard going forward (issue #270).
#
# Ceiling discipline (documented rather than machine-enforced; mirrors the
# milestone-driver plugin's scripts/check-size-budgets.sh ratchet, issue #295):
#   - FILE_WORD_CEILINGS values ONLY GO DOWN, NEVER UP. A ceiling is the
#     governed file's actual `len(text.split())` count (when the ratchet was
#     introduced, or last tightened) times 1.05, rounded up to the next 50.
#     Where that product exceeds the ceiling already recorded, the recorded
#     ceiling stands: the never-up rule outranks the formula, which sets a
#     minimum headroom and never authorizes widening an existing ceiling.
#     Raising a ceiling requires a recorded decision on the issue that
#     grows the file.
#   - The agents/**/*.md description ceiling (AGENT_DESCRIPTION_WORD_CEILING)
#     is a flat policy ceiling, not ratcheted from any single file's count.
#   - A file not named in FILE_WORD_CEILINGS is not yet governed by this
#     check. It is silently unchecked until a ceiling is added for it
#     (a deliberate scope choice: an ungoverned file has no ceiling to violate).
#   - A path NAMED in FILE_WORD_CEILINGS but absent from disk (renamed or
#     deleted without updating this table) IS a failure, never a silent pass.
#     This mirrors both the driver twin's MISSING case and this same file's
#     "--- 4 ---" reverse-coverage check just above (a hook-listed agent name
#     with no matching agents/*.md file fails too). This is why the loop below
#     iterates FILE_WORD_CEILINGS itself, not a `skills/**/SKILL.md` glob.
#
# Measurement: whole-file word count (`len(text.split())`, confirmed identical
# to `wc -w`) for every file in the table below, uniformly, so fenced code
# blocks and <example> blocks count everywhere; the frontmatter `description`
# field's word count only (reusing parse_frontmatter()) for every
# agents/**/*.md. A file whose frontmatter doesn't parse, or that has no
# `description`, is skipped here. The structural check in "--- 3 ---" above
# already fails that file, so this check does not double-report or crash on it.
# An agent file is therefore checked twice, once whole-file against the table
# below and once description-only against the flat ceiling. That is deliberate.
# The two ceilings govern different things, so neither subsumes the other.
# (No analogous "listed but missing" guard is needed for agent descriptions:
# there is no per-file table to go stale; the ceiling is a flat number applied
# to whatever agents/*.md files are discovered, and a deleted/renamed agent
# already fails "--- 4 ---"'s reverse-coverage check above, so adding a second
# one here would only duplicate it.)

# The governed set is the 6 skills/**/SKILL.md, the 4 agents/**/*.md, SPEC.md,
# and the 12 docs/*.md that a file under skills/ or agents/ references. That
# reference is the criterion: a run loads a skill or an agent, and reaches a
# doc only through one of them. Deliberately ungoverned, and not to be added
# by a later sweep without a recorded decision:
#   - docs/specs/*.md are per-release design records. Three of the four are
#     referenced from skills/ or agents/, so the reference criterion alone
#     would pull them in. They are excluded anyway, because a ceiling there
#     would ratchet a record of what a past release designed rather than
#     protect a surface anyone is still authoring.
#   - docs/architecture.md, docs/consumer-setup.md, and
#     docs/never-claims-audit.md carry no skills/ or agents/ reference at all,
#     so no run loads them.
# Every value below was re-pinned to its governed file's actual
# `len(text.split())` count as of milestone v0.14.1, by the formula above
# (that count times 1.05, rounded up to the next 50). Entries carrying a
# per-entry note were set by that note's own recorded decision instead: two
# hold a previously recorded value the formula exceeds (the never-up rule
# outranks the formula), and the rest were raised or ratcheted by a decision
# recorded on the issue the note names.
FILE_WORD_CEILINGS: dict[str, int] = {
    # 4549 words times 1.05 is 4776.45, which rounds up to 4800. The recorded
    # 4650 stands instead, because the never-up rule outranks the formula.
    "skills/create/SKILL.md": 4650,
    "skills/update/SKILL.md": 6550,
    "skills/build-roadmap/SKILL.md": 2650,
    "skills/setup/SKILL.md": 2400,
    "skills/plan/SKILL.md": 9550,
    # New in issue #343, pinned by the formula on their as-authored counts:
    # 3260 words times 1.05 is 3423, rounding up to 3450; 1434 times 1.05 is
    # 1505.7, rounding up to 1550. Both go only down from here.
    "skills/remediate/SKILL.md": 3450,
    "agents/remediator.md": 1550,
    # Raised from 2950 by issue #486; the decision is recorded on that issue
    # and its PR, as the never-up rule requires. Clause 11 (shared-file
    # ordering) gained the `edits:` declaration sentence, the one-edge-per-pair
    # rule covering clause 9 as well as clause 3, and the acyclic direction
    # rule that derives every `after` edge from the clause 3 / clause 9 order;
    # the Rigor gate and the refusals now name the grounding each edge kind
    # carries. The previous round paid for new words by tightening existing
    # prose. That is NOT repeated here: it reworded the Read-scope bullet four
    # authoring agents must hold byte-identical, breaking that rule. 3087 words
    # times 1.05 is 3241.35, which rounds up to 3250.
    "agents/architect.md": 3250,
    # Raised from 2900 by issue #486, same recorded decision. The Rigor gate
    # gained the `Edits:` bullet: transcribe the architect's list verbatim,
    # confirm each path, and reconcile it against the clause 3 site search on
    # the `Sites searched:` line rather than editing the list. Tightening was
    # not used to pay for it, for the reason above. 2936 words times 1.05 is
    # 3082.8, which rounds up to 3100.
    "agents/issue-author.md": 3100,
    "agents/roadmap-splitter.md": 1850,
    # Raised from 6400 by issue #486 (issue #343 had ratcheted it down to that
    # from 6800 after an AI-prose pass cut 737 words); the decision is recorded
    # on #486 and its PR, as the never-up rule requires. §3.1's shared-file
    # ordering and layer-aware subsections were rewritten onto the corrected
    # clause 11: one edge per pair for any clause 3 or clause 9 edge already
    # relating it, direction derived from that order so the graph stays
    # acyclic, and an unlayered project ordered by clauses 3 and 11 rather than
    # promised an unchanged breakdown. Tightening was not used to pay for it,
    # for the reason recorded on agents/architect.md above. 6441 words times
    # 1.05 is 6763.05, which rounds up to 6800.
    "SPEC.md": 6800,
    "docs/create-deploy-sequence.md": 12100,
    "docs/file-map.md": 1450,
    "docs/implied-surfaces.md": 1250,
    # Raised from 2050 by issue #343; the decision is recorded on that issue's
    # PR, as the never-up rule requires. The new `remediate` verb owes existing
    # users a discovery notice (SPEC.md §3.1), and this doc carries one `##`
    # section per unit, each of which must fence that unit's printed text
    # verbatim ("Section fields" in the doc). An eighth such section does not
    # fit in the headroom the 2050 ceiling left, whatever its wording, because
    # the fenced copy is pinned line for line to BOTH scripts/emit-notice.json's
    # `writes.lines` array and .milestone-config/.gitignore by check 7 below,
    # and is not the author's to shorten independently. 2185 words times 1.05
    # is 2294.25, which rounds up to 2300.
    "docs/one-time-notices.md": 2300,
    "docs/plan-file-contract.md": 1600,
    "docs/profile-schema.md": 2400,
    "docs/roadmap-fan-out.md": 2450,
    "docs/roadmap-manifest-format.md": 1050,
    "docs/step-0-grounding.md": 2050,
    "docs/style-contracts.md": 800,
    # 2450 words times 1.05 is 2572.5, which rounds up to 2600. The recorded
    # 2450 stands instead, because the never-up rule outranks the formula.
    "docs/update-reconcile-parent.md": 2450,
    "docs/version-ladder.md": 1300,
}
AGENT_DESCRIPTION_WORD_CEILING = 150

for rel_path, ceiling in sorted(FILE_WORD_CEILINGS.items()):
    governed_md = REPO_ROOT / rel_path
    checked += 1
    if not governed_md.is_file():
        err(
            governed_md,
            f"is listed in FILE_WORD_CEILINGS ({ceiling}-word ceiling) "
            f"but is missing from disk. A renamed or deleted governed "
            f"file must update this table in the same change, not "
            f"silently drop out of the size-budget gate",
        )
        continue
    word_count = len(governed_md.read_text(encoding="utf-8-sig").split())
    if word_count > ceiling:
        err(
            governed_md,
            f"is {word_count} words, over its {ceiling}-word "
            f"size-budget ceiling (FILE_WORD_CEILINGS in this script). "
            f"Trim it, or if the growth is deliberate, record a "
            f"decision on the issue that grows it and raise the "
            f"ceiling in the same change",
        )

if agents_dir.is_dir():
    for agent_md in sorted(agents_dir.rglob("*.md")):
        fm = parse_frontmatter(agent_md)
        if fm is None:
            continue
        description = str(fm.get("description", "")).strip()
        if not description:
            continue
        checked += 1
        word_count = len(description.split())
        if word_count > AGENT_DESCRIPTION_WORD_CEILING:
            err(
                agent_md,
                f"frontmatter 'description' is {word_count} words, "
                f"over the flat {AGENT_DESCRIPTION_WORD_CEILING}-word "
                f"ceiling every agent description is held to. Trim it",
            )

# --- 7: nested .gitignore three-copy pin ------------------------------------
#
# Why this exists: the self-heal's ignore block is hand-synced across three
# files, and hand-syncing it has already failed twice (issues #333 and #366).
# Nothing reads one copy from another, so a divergence stays invisible until a
# consumer is handed a block no doc describes. `scripts/emit-notice.json`'s
# `writes.lines` array is what the self-heal actually WRITES; the fenced block
# in `docs/one-time-notices.md` is what a reader is told they will get; and
# `.milestone-config/.gitignore` is this repo's own copy of the result.
#
# Naming the drift: a single odd copy out of three is named against the two
# that agree. When all three differ there is no majority, so the JSON array is
# the reference (it is the writer) and every copy differing from it is named.
# A source absent ENTIRELY (the unit gone from the JSON, the fenced block gone
# from the doc, the committed .gitignore gone from disk) fails naming that
# source, never a silent pass, on the same rule as "--- 6 ---"'s named-but-
# missing case above.

SELF_HEAL_UNIT_ID = "self-heal-nested-gitignore"
SELF_HEAL_DOC_HEADING = "## Self-heal the nested .milestone-config/.gitignore"
SELF_HEAL_DOC_FENCE = "```gitignore"


def read_self_heal_json_lines(path: Path) -> list[str] | None:
    """Return the self-heal unit's `writes.lines` array, or None on any miss."""
    data = load_json(path)
    if data is None:
        return None
    units = data.get("units")
    unit = None
    if isinstance(units, list):
        for candidate in units:
            if (
                isinstance(candidate, dict)
                and candidate.get("id") == SELF_HEAL_UNIT_ID
            ):
                unit = candidate
                break
    if unit is None:
        err(
            path,
            f"has no unit with id '{SELF_HEAL_UNIT_ID}'. That unit is what "
            f"writes a consumer's .milestone-config/.gitignore, so without "
            f"it there is nothing for the other two copies to be pinned to",
        )
        return None
    writes = unit.get("writes")
    lines = writes.get("lines") if isinstance(writes, dict) else None
    if not isinstance(lines, list) or not all(isinstance(x, str) for x in lines):
        err(
            path,
            f"unit '{SELF_HEAL_UNIT_ID}' has no 'writes.lines' list of "
            f"strings. That array is the block the self-heal writes",
        )
        return None
    return lines


def read_self_heal_doc_lines(path: Path) -> list[str] | None:
    """Return the fenced gitignore block under the self-heal section heading."""
    if not path.is_file():
        # Silent on purpose: this path is in FILE_WORD_CEILINGS, so "--- 6 ---"
        # above already fails it as missing from disk, and that section states
        # this check does not double-report. Every other branch below names a
        # defect no other check can see.
        return None
    lines = path.read_text(encoding="utf-8-sig").splitlines()
    heading_idx = None
    for i, line in enumerate(lines):
        if line.strip() == SELF_HEAL_DOC_HEADING:
            heading_idx = i
            break
    if heading_idx is None:
        err(
            path,
            f"has no '{SELF_HEAL_DOC_HEADING}' heading, so the fenced copy "
            f"of the self-heal ignore block cannot be found to pin",
        )
        return None
    # Both scans stop at the next section. Unbounded, a LATER section's
    # ```gitignore fence stands in for a deleted one here (the block could go
    # missing and still PASS), an unrelated block gets reported as this one's
    # drift, and a deleted CLOSING fence is masked by the next section's.
    section_end = len(lines)
    for i in range(heading_idx + 1, len(lines)):
        if lines[i].startswith("## "):
            section_end = i
            break
    open_idx = None
    for i in range(heading_idx + 1, section_end):
        if lines[i].startswith(SELF_HEAL_DOC_FENCE):
            open_idx = i
            break
    if open_idx is None:
        err(
            path,
            f"'{SELF_HEAL_DOC_HEADING}' carries no '{SELF_HEAL_DOC_FENCE}' "
            f"fenced block. That block is the reader-facing copy of what "
            f"the self-heal writes",
        )
        return None
    for i in range(open_idx + 1, section_end):
        if lines[i].strip() == "```":
            return lines[open_idx + 1 : i]
    err(
        path,
        f"'{SELF_HEAL_DOC_FENCE}' block under '{SELF_HEAL_DOC_HEADING}' is "
        f"never closed",
    )
    return None


def read_committed_gitignore(path: Path) -> list[str] | None:
    """Return this repo's own committed nested .gitignore, line by line."""
    if not path.is_file():
        err(
            path,
            "is missing from disk. This repo's committed copy is one of the "
            "three the self-heal block is pinned across; deleting or "
            "renaming it fails here rather than dropping out of the pin",
        )
        return None
    return path.read_text(encoding="utf-8-sig").splitlines()


def first_line_difference(actual: list[str], expected: list[str]) -> str:
    """Describe the first line on which two copies of the block disagree."""
    for line_no, (got, want) in enumerate(zip(actual, expected), start=1):
        if got != want:
            return f"line {line_no} is {got!r} where {want!r} is expected"
    if len(actual) > len(expected):
        return (
            f"carries {len(actual)} lines to {len(expected)}: line "
            f"{len(expected) + 1}, {actual[len(expected)]!r}, is extra"
        )
    return (
        f"carries {len(actual)} lines to {len(expected)}: line "
        f"{len(actual) + 1}, {expected[len(actual)]!r}, is missing"
    )


emit_notice_json = REPO_ROOT / "scripts" / "emit-notice.json"
one_time_notices_md = REPO_ROOT / "docs" / "one-time-notices.md"
nested_gitignore = REPO_ROOT / ".milestone-config" / ".gitignore"

# JSON first: `present` keeps this order, so present[0] is the writer whenever
# the JSON parsed, and it is the reference wherever no majority names the drift.
self_heal_copies = [
    (emit_notice_json, read_self_heal_json_lines(emit_notice_json)),
    (one_time_notices_md, read_self_heal_doc_lines(one_time_notices_md)),
    (nested_gitignore, read_committed_gitignore(nested_gitignore)),
]
checked += len(self_heal_copies)
present = [(p, lines) for p, lines in self_heal_copies if lines is not None]

# Two present still compare: withholding the drift until the missing source is
# restored would hand a fixer one defect per run instead of both at once.
if len(present) >= 2:
    odd = [
        p
        for p, lines in present
        if all(lines != other for q, other in present if q != p)
    ]
    if len(odd) == 1:
        drifted = odd
        expected_path, expected_lines = next(
            (p, lines) for p, lines in present if p not in odd
        )
    else:
        expected_path, expected_lines = present[0]
        drifted = [p for p, lines in present if lines != expected_lines]
    for drifted_path in drifted:
        drifted_lines = next(lines for p, lines in present if p == drifted_path)
        err(
            drifted_path,
            f"has drifted from "
            f"{expected_path.relative_to(REPO_ROOT)}'s copy of the self-heal "
            f"ignore block: "
            f"{first_line_difference(drifted_lines, expected_lines)}. The "
            f"three copies are hand-synced and must stay equal line for "
            f"line; re-sync this one",
        )

# --- report -----------------------------------------------------------------

for w in warnings:
    print(f"WARN: {w}", file=sys.stderr)

if errors:
    print(
        f"FAIL: plugin structure invalid ({len(errors)} problem(s)):", file=sys.stderr
    )
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)

print(
    f"PASS: plugin structure valid ({checked} file(s) checked, "
    f"{len(warnings)} warning(s))."
)
sys.exit(0)
