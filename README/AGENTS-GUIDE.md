# Agent Customization Guide

This guide defines where to customize agent behavior for the PR #581 workspace and what boundaries must remain enforced across control and target repos.

Topology reminder:

- control repo: this workspace for spec/task orchestration and `.codex` assets.
- target repo: `../socialpredict` for backend/API code changes and branch checks.

Concrete repo-local team definitions now live under `.codex/agents/` as
committed `.toml` files:

- `.codex/agents/architecture-agent.toml`
- `.codex/agents/coding-best-practices-agent.toml`
- `.codex/agents/db-migration-agent.toml`
- `.codex/agents/dispatcher-agent.toml`
- `.codex/agents/error-handling-agent.toml`
- `.codex/agents/go-style-agent.toml`
- `.codex/agents/logging-agent.toml`
- `.codex/agents/openapi-contract-agent.toml`
- `.codex/agents/test-reliability-agent.toml`
- `.codex/agents/verifier-agent.toml`

Skill-local helper prompts still live under each skill directory at
`.codex/skills/*/agents/openai.yaml`.

## Customization Surfaces

1. Spec note role charter sections (`spec` note):
   - agent role missions
   - verifier gate policy
   - escalation criteria
2. Task notes (`intent://local/task/...`):
   - task-specific acceptance criteria
   - verification commands
   - turn-by-turn progress logging
3. Per-agent messages from coordinator:
   - task-focused constraints
   - handoff and evidence expectations

## Boundary Rules (Do Not Relax)

- Keep coding scope locked to `../socialpredict/backend/**` and API contract artifacts unless explicitly re-scoped.
- Preserve verifier gates for lineage, scope, guardrails, and quality checks.
- Do not bypass guardrails without an auditable reason.
- Do not assign frontend/infrastructure implementation to PR #581 backend/API waves.

## Practical Update Workflow

1. Inspect current task and spec state:

```text
list_note_tasks(noteId="spec")
read_note(noteId="spec")
```

2. Edit role/task instructions in notes (not source code) so constraints are explicit.
3. Re-check that delegated tasks and statuses still match the spec checklist.
4. Run verification commands from [VERIFICATION.md](VERIFICATION.md) before closing a wave.

## Scope Split: Current vs Future

Current execution:

- backend/API refactor governance and verification only

Future expansion (separate approval required):

- frontend/UI migration
- infrastructure rollout and deployment automation
- cross-service production hardening programs
