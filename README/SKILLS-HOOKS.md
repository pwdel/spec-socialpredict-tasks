# Codex Skills and Hooks Customization

This document covers safe customization points for local skills and guardrail hooks in this workspace.

## Paths

- Skills root: `socialpredict/.codex/skills/`
- Skill examples:
  - `socialpredict-go-architecture-governance`
  - `socialpredict-go-testing-reliability`
  - `socialpredict-go-code-quality-guardrails`
  - `socialpredict-api-contract-drift-control`
- Hook scripts:
  - `socialpredict/backend/scripts/guardrails.sh`
  - `socialpredict/backend/scripts/install-guardrail-hooks.sh`
- Hook policy reference:
  - `socialpredict/backend/README/BACKEND/GUARDRAILS.md`

## Skill Customization Workflow

1. Duplicate an existing skill directory as the template.
2. Update `SKILL.md`, `agents/openai.yaml`, and any local `references/*` or `scripts/*`.
3. Validate each edited skill:

```bash
python /Users/patrick/.codex/skills/.system/skill-creator/scripts/quick_validate.py socialpredict/.codex/skills/<skill-name>
```

4. Repeat validation for all skills before handoff:

```bash
for skill in socialpredict/.codex/skills/*; do
  python /Users/patrick/.codex/skills/.system/skill-creator/scripts/quick_validate.py "$skill"
done
```

## Hook Customization Workflow

1. Keep boundary and contract checks in `guardrails.sh` intact.
2. Add stricter checks only if they are deterministic and reproducible.
3. Validate behavior:

```bash
bash socialpredict/backend/scripts/guardrails.sh pre-commit
bash socialpredict/backend/scripts/guardrails.sh simulate-violation
```

4. Install hooks locally if needed:

```bash
bash socialpredict/backend/scripts/install-guardrail-hooks.sh
```

## Guardrails for Customization

- Do not use skills or hooks to bypass scope lock or verifier policy.
- Any bypass path must require explicit reason logging.
- Keep changes in docs/config/scripts; application logic changes need a separate scoped task.
