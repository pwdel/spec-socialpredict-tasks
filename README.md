# SocialPredict PR #581 Operator Workspace

This workspace is the control repo for SocialPredict PR #581 governance and verification.
As of 2026-03-29, PR #581 head is `94231f1d5f49c564d1a99c0135456d92101ed8f0`
and local target-repo work tracks `../socialpredict` branch `pilot/pr581-backend-api-20260329`.

## Repo Topology

- control repo: `spec-socialpredict-tasks` (this workspace) for orchestration notes, docs, and `.codex` assets.
- target repo: `../socialpredict` for PR #581 code, branch lineage checks, and backend guardrails.

## Documentation Map

- [Workspace Purpose and Layout](README/WORKSPACE.md)
- [Manual Verification Playbook](README/VERIFICATION.md)
- [Agent Customization Guide](README/AGENTS.md)
- [Codex Skills and Hook Customization Guide](README/SKILLS-HOOKS.md)

## Current Scope

- In scope: operator documentation, branch/scope verification workflow, and governance guidance for agents/skills/hooks.
- Out of scope for this docs PR: application/business logic changes under `../socialpredict/backend` and any frontend/infrastructure implementation.

## Quick Start

Run from workspace root:

```bash
git -C ../socialpredict branch --show-current
git -C ../socialpredict merge-base --is-ancestor 94231f1d5f49c564d1a99c0135456d92101ed8f0 HEAD && echo "lineage-ok"
bash ../socialpredict/backend/scripts/guardrails.sh pre-commit
```

Then use the playbook:

- [Manual Verification Playbook](README/VERIFICATION.md)
