# SocialPredict Task Workspace

This repository is a reusable control workspace for running Codex against a
SocialPredict checkout. It keeps task state, operator docs, repo-local Codex
config, specialist agents, skills, and guardrail payloads outside the main
application repo so the same execution model can be reused across multiple
tasks, branches, and pull requests.

The intended topology is:

- control repo: this workspace, used for orchestration, task state, docs, and
  `.codex` assets
- target repo: a sibling `../socialpredict` checkout where Codex reads, edits,
  and validates code

## What Lives Here

- `TASKS.json`
  Machine-readable task queue and runner state.
  Active tasks are `uid`-first: `uid` is the canonical identity, while `id` is
  an optional human-readable label.
- `TASKS.example.json`
  Minimal schema example for defining new task waves.
- `lib/task-registry.json`
  Persistent UID-first registry plus historical display-ID lookup.
- `lib/task-archives/`
  Historical task-queue archives moved out of the active `TASKS.json`.
- `codex-runner.sh`
  Queue runner that launches Codex, captures logs, and maintains canonical task
  reports.
- `AGENTS.md`
  Workspace table of contents plus the current target-repo map and active scope.
- `README/`
  Operator-facing docs for workspace usage, verification, reports, and config.
- `prompts/`
  Human-readable prompt templates used by `codex-runner.sh`.
- `.codex/`
  Repo-local Codex config, specialist agents, and reusable skills.
- `.git-hooks/`
  Guardrail entrypoints and managed hook payloads for boundary checks.

## Documentation Map

- [Workspace Purpose and Layout](README/WORKSPACE.md)
- [Manual Verification Playbook](README/VERIFICATION.md)
- [Agent Customization Guide](README/AGENTS-GUIDE.md)
- [Codex Config Notes](README/CODEX-CONFIG.md)
- [Codex Report Convention](README/CODEX-REPORTS.md)
- [Codex Skills and Hook Customization Guide](README/SKILLS-HOOKS.md)

## Retargeting Checklist

When reusing this repo for a different task wave or PR, update these first:

1. `AGENTS.md`
   Replace the current target-branch, target-focus, and repo-map details with
   the new active workspace context.
2. `TASKS.json`
   Replace the existing queue with the current task set. Use
   `TASKS.example.json` as the schema reference, not as a policy source.
   Keep historical completed queues in `lib/task-archives/` and reserve their
   UIDs in `lib/task-registry.json`. The same registry also keeps the old
   human-readable `id` values for lookup and optional collision avoidance.
3. `.codex/agents/` and `.codex/skills/`
   Review any scope assumptions before reuse. Several bundled assets still
   assume backend/API work, Go validation flows, OpenAPI checks, or specific
   SocialPredict package locations.
4. `README/` docs
   Keep the operator docs aligned with the actual current scope, target repo,
   and verification process.
5. `defaults.env` and publication metadata
   Update repo description, PR/release text, and any other bootstrap metadata if
   this control repo is being published or renamed.

## Current Snapshot: What Is Already Generic vs Specific

Already reusable:

- the two-repo control-repo/target-repo operating model
- the `TASKS.json` queue format and runner flow
- the persistent task-ID registry and archive pattern
- the `.codex` asset layout for project-scoped config, agents, and skills
- the canonical report layout under the target repo

Still specialized in this snapshot:

- `AGENTS.md` currently documents a specific backend-oriented target map
- `README/WORKSPACE.md`, `README/VERIFICATION.md`, and
  `README/AGENTS-GUIDE.md` still describe the current backend/API execution
  model rather than a fully generic template
- multiple `.codex/agents/*.toml` files are written specifically for
  SocialPredict backend governance
- multiple `.codex/skills/*` prompts, references, and helper scripts assume Go
  backend paths, OpenAPI validation, and checkpoint/base-ref defaults
- `defaults.env` still uses PR- and repo-bootstrap text from the original
  single-PR setup

That means the repo can already serve as a general control workspace, but the
bundled policy layer is still optimized for SocialPredict backend work. The
next generalization pass should focus on those policy files rather than the
runner or task schema.

## Quick Start

Review the current workspace state:

```bash
sed -n '1,220p' AGENTS.md
sed -n '1,220p' TASKS.example.json
./codex-runner.sh --help
```

Then retarget the workspace for the current task wave and run the queue:

```bash
./codex-runner.sh --once
```
