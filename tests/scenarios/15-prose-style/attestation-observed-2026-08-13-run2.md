# Attestation: `/milestone-feeder:plan` preview run against `/private/tmp/app-repo-4b8e13`

## Dispatch count

**3**

That number counts this orchestrator as dispatch **0** plus **2** subagent dispatches, numbered **1** and **2**. So the numbered subagent blocks run `1` through `N` where **N = 2**, and block `0` below is this orchestrator's own. There were **no retries and no re-dispatches**: the architect was dispatched exactly once (Step 3) and the issue-author exactly once (Step 4, one surviving candidate), and both returns passed the Step-4 per-dispatch verify on the first attempt.

| Dispatch | Role | Candidate | Retry? |
|---|---|---|---|
| 0 | `plan` orchestrator (this agent) | n/a | n/a |
| 1 | architect (proxied as `general-purpose`) | n/a (dispatched once per run) | no |
| 2 | issue-author (proxied as `general-purpose`) | `#A` | no |

---

## Block 0: the `plan` orchestrator (this agent)

**Role:** `plan` orchestrator, Step 0 through Step 5.1 plus the preview emit and Step 7's plan-file render.
**Candidate handled:** none directly; it dispatched the two agents below and assembled their returns.

### Paths read

Read tool, file contents:

```
/private/tmp/app-repo-4b8e13/feeder-env.md
/private/tmp/app-repo-4b8e13/brief.md
/private/tmp/app-repo-4b8e13/project/conventions.md
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/SPEC.md
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/skills/plan/SKILL.md
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/agents/architect.md
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/agents/issue-author.md
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/plan-file-contract.md
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/step-0-grounding.md
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/one-time-notices.md
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/version-ladder.md
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/file-map.md
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/implied-surfaces.md
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/style-contracts.md
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/profile-schema.md
```

Write tool, files I authored (listed because I wrote them, and because I later read two of them back):

```
/private/tmp/app-repo-4b8e13/.milestone-feeder/plan-add-a-paginated-activity-log-list-to-the-account-area.md
/private/tmp/app-run-out-4b8e13/emit-head.md
/private/tmp/app-run-out-4b8e13/emit-tail.md
/private/tmp/app-run-out-4b8e13/attestation.md
```

`find . -type f | head -200` and `find . -type d | head -50`, cwd `/private/tmp/app-repo-4b8e13`. Directory traversal, entry names only, no file contents:

```
/private/tmp/app-repo-4b8e13
/private/tmp/app-repo-4b8e13/project
```

`ls docs/ && ls skills/ && ls agents/`, cwd `/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392`. Directory entry names only, no file contents:

```
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/skills
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/agents
```

The Step-0 one-time-notice emitter block (sections 1, 2, 3, 4, 5, 7 bash twins run verbatim), cwd `/private/tmp/app-repo-4b8e13`. Every read here is an existence test, a directory traversal, or an attempted read of an absent file. No file contents were read: section 2's `grep` on the root `.gitignore` never executed, because the `[ -f ".gitignore" ]` guard ahead of it was false.

```
/private/tmp/app-repo-4b8e13/.milestone-config/.gitignore                       (existence test, then written)
/private/tmp/app-repo-4b8e13/.gitignore                                         (existence test; absent)
/private/tmp/app-repo-4b8e13/.milestone-config/feeder.json                      (jq attempted to read it; absent, fell back to the default)
/private/tmp/app-repo-4b8e13/.project                                           (find -L traversal; absent)
/private/tmp/app-repo-4b8e13/.milestone-config/driver.json                      (existence test; absent)
/private/tmp/app-repo-4b8e13/.milestone-config/implied-surfaces.md              (existence test; absent)
/private/tmp/app-repo-4b8e13/.milestone-config/.runtime/legacy-blanket-notice   (existence test; absent, notice did not fire)
/private/tmp/app-repo-4b8e13/.milestone-config/.runtime/bootstrap-nudge-notice  (existence test, then written)
/private/tmp/app-repo-4b8e13/.milestone-config/.runtime/roadmap-routing-notice  (existence test, then written)
/private/tmp/app-repo-4b8e13/.milestone-config/.runtime/implied-surfaces-notice (existence test, then written)
/private/tmp/app-repo-4b8e13/.milestone-config/.runtime/issue-template-notice-v2 (existence test, then written)
```

Step-0 resolution probes: `ls -la .github/ISSUE_TEMPLATE/`, `ls -la .milestone-config/driver.json`, `ls -la milestone-driver.json`, `ls -la .milestone-config/feeder.json`, `ls -la .milestone-config/implied-surfaces.md`, `ls -la src`, `find . -type f | sort`, cwd `/private/tmp/app-repo-4b8e13`. Stats and entry names only, no file contents:

```
/private/tmp/app-repo-4b8e13/.github/ISSUE_TEMPLATE        (absent)
/private/tmp/app-repo-4b8e13/.milestone-config/driver.json (absent)
/private/tmp/app-repo-4b8e13/milestone-driver.json         (absent)
/private/tmp/app-repo-4b8e13/.milestone-config/feeder.json (absent)
/private/tmp/app-repo-4b8e13/.milestone-config/implied-surfaces.md (absent)
/private/tmp/app-repo-4b8e13/src                           (absent)
/private/tmp/app-repo-4b8e13                               (traversal, names only)
```

Step-5.1 version-ladder probes, cwd `/private/tmp/app-repo-4b8e13`:

- `git tag --list 'v*'` and `git remote -v`: git searched for a `.git` directory in the cwd and then in its **parent directories**, and found none. These are `.git` existence probes outside the consumer root, no contents read. See the out-of-scope disclosure below.
- `gh api repos/{owner}/{repo}/milestones --jq '.[] | .title'`: gh shelled out to git for the repo context, which made the same parent-directory `.git` probes and failed. **No network request was made and no GitHub state was read or written.**
- `command -v gh`: a PATH lookup that resolved to `/opt/homebrew/bin/gh`. A name resolution, not a file read. See the out-of-scope disclosure below.

Step-7 write, verification, and emit assembly:

```
/private/tmp/app-repo-4b8e13/.milestone-feeder                                  (mkdir; ls of its entries)
/private/tmp/app-repo-4b8e13/.milestone-feeder/.gitignore                       (existence test, written, then read by `cat`)
/private/tmp/app-repo-4b8e13/.milestone-feeder/plan-add-a-paginated-activity-log-list-to-the-account-area.md
      (read by `grep -m1 '^Milestone number (GitHub):'` for the prior-receipt probe, absent at that point;
       then written; then read by `awk` for the brief extraction, by `grep -c` for the em-dash scan,
       and by `cp` and `cmp` for the copy to the output directory)
/private/tmp/app-repo-4b8e13/brief.md                                           (read again by `diff` and `cat` during the verbatim-brief check)
```

### Paths read outside the two permitted roots

**Not none.** Three disclosures, all of them mine, none of them a read of another project's content:

1. **The output directory `/private/tmp/app-run-out-4b8e13/`.** My instructions describe it as "outside both read roots and is write-only for you". I both wrote and **read back** files there, in order to verify my own writes and to assemble `emit.md`. The reads:
   - `tee /private/tmp/app-run-out-4b8e13/step0-notices.txt` (write), later read by `cat` and by `diff`.
   - `cat emit-head.md step0-notices.txt emit-tail.md > emit.md` read all three.
   - `awk` read `emit.md`; `diff emit-notice-block.txt step0-notices.txt` read both.
   - `diff extracted-brief.txt brief.md` read `extracted-brief.txt`; `cmp` read `plan-file.md`.
   Every one of those files was authored by me in this run, in the directory I was told to write to. No file that pre-existed this run was read there.
2. **Parent-directory `.git` probes.** `git tag`, `git remote -v`, and `gh api` (which shells out to git) each searched upward from `/private/tmp/app-repo-4b8e13` for a `.git` directory, so they stat'd `/private/tmp` and its ancestors up to `/`. Existence probes only. No directory was listed and no file content was read. These probes are intrinsic to running the version ladder's rung-3 read-only signals, which the procedure requires.
3. **`command -v gh` resolved `/opt/homebrew/bin/gh` on `PATH`,** and running `gh` executed that binary. A name resolution plus an execution, not a read of any file's content.

Beyond those three: **no path outside the two permitted roots was Read, Globbed, Grepped, listed, or opened.** Nothing was written to any session scratchpad directory. No repository-wide search was run. `agents/architect.md`, `agents/issue-author.md`, and `docs/file-map.md` all cite `milestone-driver/skills/citation-format.md`, which lies outside both roots; the citation was noted and the file was not opened. Disclosure for completeness, matching what both subagents reported: the harness itself initializes each Bash shell from the user's profile, which lives outside both roots. That is the Bash tool's own documented behavior, not a command any of us wrote, and its contents were never inspected.

---

## Block 1: architect

**Role:** milestone-feeder architect, dispatched once at Step 3 as a `general-purpose` subagent briefed to read and follow `/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/agents/architect.md` in full.
**Candidate handled:** none (the architect produces the candidate set; it does not handle one).
**Returned an itemized path list:** yes. Transcribed verbatim below.

### Paths read

Read tool, file contents:

```
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/agents/architect.md
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/implied-surfaces.md
/private/tmp/app-repo-4b8e13/brief.md
/private/tmp/app-repo-4b8e13/project/conventions.md
/private/tmp/app-repo-4b8e13/feeder-env.md
```

`cat docs/style-contracts.md`, cwd `/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392`, file contents:

```
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/style-contracts.md
```

`awk '/^## Prose style/,/^## [^P]/' agents/issue-author.md`, cwd `/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392`. The architect recorded that awk read the file in full and printed the section:

```
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/agents/issue-author.md
```

`ls -la`, cwd `/private/tmp/app-repo-4b8e13`. Directory entries; the architect recorded that it also stats the `..` entry without listing its contents:

```
/private/tmp/app-repo-4b8e13
/private/tmp   (stat of the `..` entry only; contents not listed or read)
```

`find . -type f -not -path './.git/*'`, cwd `/private/tmp/app-repo-4b8e13`. Directory traversal, names only:

```
/private/tmp/app-repo-4b8e13
/private/tmp/app-repo-4b8e13/.milestone-config
/private/tmp/app-repo-4b8e13/.milestone-config/.runtime
/private/tmp/app-repo-4b8e13/project
```

`ls -d src` and `find . -type d -name src`, cwd `/private/tmp/app-repo-4b8e13`. Directory traversal, names only; `src` does not exist:

```
/private/tmp/app-repo-4b8e13
/private/tmp/app-repo-4b8e13/.milestone-config
/private/tmp/app-repo-4b8e13/.milestone-config/.runtime
/private/tmp/app-repo-4b8e13/project
```

`grep -rn "ActivityListService" . --exclude-dir=.git` and `grep -rni "activity" . --exclude-dir=.git`, cwd `/private/tmp/app-repo-4b8e13`. The architect recorded that both read the full contents of every file below:

```
/private/tmp/app-repo-4b8e13/.milestone-config/.gitignore
/private/tmp/app-repo-4b8e13/.milestone-config/.runtime/bootstrap-nudge-notice
/private/tmp/app-repo-4b8e13/.milestone-config/.runtime/implied-surfaces-notice
/private/tmp/app-repo-4b8e13/.milestone-config/.runtime/issue-template-notice-v2
/private/tmp/app-repo-4b8e13/.milestone-config/.runtime/roadmap-routing-notice
/private/tmp/app-repo-4b8e13/brief.md
/private/tmp/app-repo-4b8e13/feeder-env.md
/private/tmp/app-repo-4b8e13/project/conventions.md
```

### Paths read outside the two permitted roots, as the architect reported them

The architect reported that it opened no file outside the two permitted roots. It noted that `agents/architect.md` cites `milestone-driver/skills/citation-format.md`, which is outside its read scope, and that it noted the citation without opening the file. It disclosed for completeness that the harness initializes each Bash invocation from the user's shell profile, which lives outside both roots, that this is the Bash tool's own contract rather than a command it wrote, and that it did not author, inspect, or read that profile's contents. Its `ls -la` disclosure of the stat'd `/private/tmp` `..` entry is transcribed above.

---

## Block 2: issue-author

**Role:** milestone-feeder issue-author, dispatched once at Step 4 as a `general-purpose` subagent briefed to read and follow `/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/agents/issue-author.md` in full.
**Candidate handled:** `#A`, "Add the paginated activity-log list to the account area". Returned `STATUS: AUTHORED`.
**Returned an itemized path list:** yes. Transcribed verbatim below.

### Paths read

```
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/agents/issue-author.md (Read tool)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/style-contracts.md (Read tool)
/private/tmp/app-repo-4b8e13/brief.md (Read tool; also read by `grep -rn "ActivityListService" .` and `grep -n '30 rows per page' project/conventions.md brief.md`)
/private/tmp/app-repo-4b8e13/project/conventions.md (Read tool; also read by `grep -rn "ActivityListService" .`, `grep -n '^## ' project/conventions.md`, `grep -n '30 rows per page' project/conventions.md brief.md`)
/private/tmp/app-repo-4b8e13/feeder-env.md (Read tool; also read by `grep -rn "ActivityListService" .`)
/private/tmp/app-repo-4b8e13/.milestone-config/.gitignore (read by `grep -rn "ActivityListService" .` and by `cat .milestone-config/.gitignore`)
/private/tmp/app-repo-4b8e13/.milestone-config/.runtime/bootstrap-nudge-notice (read by `grep -rn "ActivityListService" .`)
/private/tmp/app-repo-4b8e13/.milestone-config/.runtime/implied-surfaces-notice (read by `grep -rn "ActivityListService" .`)
/private/tmp/app-repo-4b8e13/.milestone-config/.runtime/issue-template-notice-v2 (read by `grep -rn "ActivityListService" .`)
/private/tmp/app-repo-4b8e13/.milestone-config/.runtime/roadmap-routing-notice (read by `grep -rn "ActivityListService" .`)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/SPEC.md (read by `grep -rn "citation-format" docs/ skills/ agents/ SPEC.md`, `grep -rn "## Dependencies" docs/ skills/ agents/ SPEC.md`, and `sed -n '170,240p' SPEC.md`)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/agents/architect.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/agents/roadmap-splitter.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/architecture.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/consumer-setup.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/create-deploy-sequence.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/file-map.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/implied-surfaces.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/never-claims-audit.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/one-time-notices.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/plan-file-contract.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/profile-schema.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/roadmap-fan-out.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/roadmap-manifest-format.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/specs/v0.11.0-md-epic-parent-issue.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/specs/v0.3.0-humanize-the-surface.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/specs/v0.3.1-driver-handoff.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/specs/v0.7.0-implied-surfaces.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/step-0-grounding.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/update-reconcile-parent.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/docs/version-ladder.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/skills/build-roadmap/SKILL.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/skills/create/SKILL.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/skills/plan/SKILL.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/skills/setup/SKILL.md (read by both recursive greps above)
/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392/skills/update/SKILL.md (read by both recursive greps above)
```

Directory-name-only enumerations the issue-author reported (no file contents read), all inside the two permitted roots:

- `ls -la` and `find . -type f -not -path './.git/*'` in `/private/tmp/app-repo-4b8e13`
- `ls -d src`, `ls -d .github`, `ls -d .project`, `ls -la project/`, `find . -name '*.ts'`, `find . -iname 'tokens*' -o -iname 'design-system*' -o -iname 'environment*'`, `find .milestone-config -type f`, `ls -la .milestone-config/` in `/private/tmp/app-repo-4b8e13`
- `ls -la docs/ skills/ agents/` and `find docs skills agents -type f` in `/Users/ken/repos/milestone-feeder/.milestone-config/worktrees/issue-392`

### Paths read outside the two permitted roots, as the issue-author reported them

The issue-author reported that no path outside the two permitted roots was read, globbed, grepped, or listed. It noted that `milestone-driver/skills/citation-format.md` is cited by its own contract and by `docs/file-map.md`, that the path lies outside both roots, and that it was not opened.

---

## Consolidated out-of-scope statement

Across all three dispatches, the only reads outside the two permitted roots are the three this orchestrator discloses in block 0: my own read-backs of files I authored in the designated output directory `/private/tmp/app-run-out-4b8e13/`, the parent-directory `.git` existence probes that `git` and `gh` make intrinsically when run inside a non-git directory, and the `PATH` resolution and execution of `/opt/homebrew/bin/gh`. Neither subagent read outside the roots. No other project's files, no user configuration, no lesson or vault file, and no session scratchpad file was read or written by any dispatch in this run.
