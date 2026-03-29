# Manual Verification Playbook

Run commands from workspace root unless noted.

## 1) Branch Lineage

Confirm the local branch is descended from PR #581 head:

```bash
git -C socialpredict branch --show-current
git -C socialpredict rev-parse HEAD
git -C socialpredict ls-remote https://github.com/openpredictionmarkets/socialpredict.git refs/pull/581/head
git -C socialpredict merge-base --is-ancestor 94231f1d5f49c564d1a99c0135456d92101ed8f0 HEAD && echo "lineage-ok"
```

## 2) Scope Lock

Use these checks before and after implementation waves.

```bash
# Full diff against PR #581 head
git -C socialpredict diff --name-only 94231f1d5f49c564d1a99c0135456d92101ed8f0...HEAD

# Flag potential out-of-scope paths for coding waves
git -C socialpredict diff --name-only 94231f1d5f49c564d1a99c0135456d92101ed8f0...HEAD | rg -n -v '^(backend/|\\.codex/skills/)'
```

For this docs-only workspace task, changed paths should be limited to:

```bash
git diff --name-only | rg -n -v '^(README\\.md|README/)'
```

## 3) Guardrails

```bash
bash socialpredict/backend/scripts/guardrails.sh pre-commit
bash socialpredict/backend/scripts/guardrails.sh pre-push
bash socialpredict/backend/scripts/guardrails.sh simulate-violation
```

Optional local git hook install:

```bash
bash socialpredict/backend/scripts/install-guardrail-hooks.sh
```

## 4) Skill Validation

Set up a deterministic validator environment first (no implicit global Python deps):

```bash
python3 -m venv .venv-skill-validate
./.venv-skill-validate/bin/python -m pip install --upgrade pip
./.venv-skill-validate/bin/python -m pip install pyyaml
```

Then validate all workspace skills with that interpreter:

```bash
VALIDATOR_PY=./.venv-skill-validate/bin/python
VALIDATOR_SCRIPT=/Users/patrick/.codex/skills/.system/skill-creator/scripts/quick_validate.py
for skill in socialpredict/.codex/skills/*; do
  "$VALIDATOR_PY" "$VALIDATOR_SCRIPT" "$skill"
done
```

Sanity check that skill metadata files are present:

```bash
find socialpredict/.codex/skills -maxdepth 2 -name 'SKILL.md' | sort
```

## 5) Task-Status Checks (Workspace MCP)

These are workspace-tool commands, not shell commands:

```text
list_note_tasks(noteId="spec")
list_note_tasks_workspace-mcp(noteId="spec")
read_note(noteId="spec")
read_note(noteId="527b7fb7-9551-4c7f-88e3-26a72e56a886")
```

Use these to verify:

- spec checklist state is synchronized
- the docs task status and acceptance criteria are complete
