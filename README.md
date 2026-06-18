# milestone-feeder

A Claude Code plugin that turns a feature brief into a **GitHub milestone + small, well-formed issues** ready for [`milestone-driver`](https://github.com/kenmulford/milestone-driver) to build. The feeder is the driver's direct predecessor: it produces the input the driver assumes already exists.

Its quality bar is concrete — every issue it emits passes the driver's own triage clean (`GAPS: none`), because the feeder reuses the driver's actual reviewer agents as a pre-creation self-check.

Status: **spec-stage, implementation starting.** The full design is in [SPEC.md](SPEC.md). Part of the [dev-tools](../dev-tools) suite.

## At a glance

- **Input:** a feature brief (file, inline, or a GitHub epic issue) + the project substrate (`.project/`).
- **Output:** a milestone whose description encodes the Wave/dependency order, and small issues each carrying complete acceptance criteria, recorded consistent design, declared dependencies, and UI/logic + risk classification.
- **Safety:** previews a reviewable plan by default; `--apply` creates the milestone/issues. Authors no code, opens no PRs. Parks product decisions rather than inventing scope.

See [SPEC.md](SPEC.md) for the procedure, output contract, config schema, and build order.
