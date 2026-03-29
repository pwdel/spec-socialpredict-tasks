# Codex Skills and Hooks Customization

This document covers safe customization points for local skills and guardrail hooks in the two-repo topology.

Topology reminder:

- control repo: this workspace, including `.codex/skills`.
- target repo: `../socialpredict`, including backend guardrail scripts.

## Paths

- Skills root: `.codex/skills/`
- Skill examples:
  - `socialpredict-go-architecture-governance`
  - `socialpredict-go-testing-reliability`
  - `socialpredict-go-code-quality-guardrails`
  - `socialpredict-api-contract-drift-control`
- Hook scripts:
  - `../socialpredict/backend/scripts/guardrails.sh`
  - `../socialpredict/backend/scripts/install-guardrail-hooks.sh`
- Hook policy reference:
  - `../socialpredict/backend/README/BACKEND/GUARDRAILS.md`

## Skill Customization Workflow

1. Duplicate an existing skill directory as the template.
2. Update `SKILL.md`, `agents/openai.yaml`, and any local `references/*` or `scripts/*`.
3. Create a deterministic validator environment and install required dependency:

```bash
python3 -m venv .venv-skill-validate
./.venv-skill-validate/bin/python -m pip install --upgrade pip
./.venv-skill-validate/bin/python -m pip install pyyaml
```

4. Validate each edited skill with the venv interpreter:

```bash
./.venv-skill-validate/bin/python /Users/patrick/.codex/skills/.system/skill-creator/scripts/quick_validate.py .codex/skills/<skill-name>
```

5. Repeat validation for all skills before handoff:

```bash
VALIDATOR_PY=./.venv-skill-validate/bin/python
VALIDATOR_SCRIPT=/Users/patrick/.codex/skills/.system/skill-creator/scripts/quick_validate.py
for skill in .codex/skills/*; do
  "$VALIDATOR_PY" "$VALIDATOR_SCRIPT" "$skill"
done
```

## Hook Customization Workflow

1. Keep boundary and contract checks in `guardrails.sh` intact.
2. Add stricter checks only if they are deterministic and reproducible.
3. Validate behavior:

```bash
bash ../socialpredict/backend/scripts/guardrails.sh pre-commit
bash ../socialpredict/backend/scripts/guardrails.sh simulate-violation
```

4. Install hooks locally if needed:

```bash
bash ../socialpredict/backend/scripts/install-guardrail-hooks.sh
```

## Guardrails for Customization

- Do not use skills or hooks to bypass scope lock or verifier policy.
- Any bypass path must require explicit reason logging.
- Keep changes in docs/config/scripts; application logic changes need a separate scoped task.
