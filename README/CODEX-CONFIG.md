# Codex Config Layering (Control Repo + User Global)

This document defines a portable config pattern for the two-repo model:

- control repo: `spec-socialpredict-tasks` (orchestration/docs/.codex assets)
- target repo: `../socialpredict` (application code)

## Layering Order

When running Codex from this control repo, use this precedence model:

1. User-global base: `~/.codex/config.toml`
2. Project-scoped overrides: `<control-repo>/.codex/config.toml`
3. One-off runtime overrides: CLI flags (for example `-c`, `-a`, `-s`, `--enable`)

Operational intent:

- `~/.codex/config.toml` carries personal and machine-local settings.
- `.codex/config.toml` carries shared team defaults for this control repo.
- CLI flags handle temporary run-specific changes without editing committed files.

## What Is Project-Scoped (Commit to Control Repo)

Use `.codex/config.toml` for team-portable defaults that should be identical for all operators in this workspace, for example:

- default model selection
- reasoning effort defaults
- stable persona/behavior defaults for this project

Current committed example: [`../.codex/config.toml`](../.codex/config.toml)

## What Stays User-Global (Do Not Commit)

Keep these in `~/.codex/config.toml` because they are user-specific or machine-specific:

- path-based trust declarations (`[projects."/absolute/path"]`)
- local MCP server endpoints (`[mcp_servers.*]`)
- local authentication/session state (`codex login`)
- personal risk posture defaults that are not team policy

## Approval/Sandbox/Feature-Flag Controls

To keep delegated-agent operations compatible across environments:

- do not hardcode aggressive risk settings as project defaults unless explicitly approved by the team
- prefer runtime controls for temporary policy changes:

```bash
codex -C /path/to/spec-socialpredict-tasks -a on-request -s workspace-write --enable search
```

If the team later standardizes a shared policy, add only the approved keys to `.codex/config.toml` and record the decision in the task/spec notes.

## Two-Repo Usage

- Run orchestration and docs workflows from the control repo (`spec-socialpredict-tasks`), where this project-scoped config lives.
- Run source changes and guardrails in the target repo (`../socialpredict`).
- Do not copy control-repo project config into the target repo unless the team explicitly adopts that as a separate policy.
