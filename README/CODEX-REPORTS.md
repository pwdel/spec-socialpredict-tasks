# Codex Report Convention

This workspace keeps orchestration state in the control repo and writes curated
task journals into the target repo.

## Ownership Split

- Control repo (`spec-socialpredict-tasks`):
  - `TASKS.json`
- Log repo (`../log-socialpredict-tasks`):
  - `.codex-runs/` raw event streams, stderr, prompt captures, runner state
- Target repo (`../socialpredict`):
  - `.codex-reports/tasks/<task-uid>/` curated task journal and summary

## Canonical Target-Repo Layout

```text
../socialpredict/.codex-reports/tasks/<task-uid>/
├── meta.json
├── summary.json
├── conversation.ndjson
└── decisions.ndjson
```

## File Roles

- `meta.json`: stable metadata for the task, repos, dispatcher, and file paths
- `summary.json`: dispatcher-owned rolled-up current state
- `conversation.ndjson`: append-only event journal across dispatcher and specialists; each row carries `task_uid` and `task_id`
- `decisions.ndjson`: append-only architectural/process decisions; each row carries `task_uid` and `task_id`

## Why NDJSON

- append-friendly for long-running tasks
- easy to slice with `tail`, `rg`, `jq`, or helper scripts
- agents do not need to re-read the full conversation to process new entries

## Helper Script

Use [`scripts/codex-report.py`](/workspace/spec-socialpredict-tasks/scripts/codex-report.py) to
interact with the report files deterministically.

Examples:

```bash
python3 scripts/codex-report.py read-summary \
  --report-dir ../socialpredict/.codex-reports/tasks/019d9935-ace6-7305-bbc5-9e35238350cc

python3 scripts/codex-report.py read-events \
  --report-dir ../socialpredict/.codex-reports/tasks/019d9935-ace6-7305-bbc5-9e35238350cc \
  --after-seq 12

python3 scripts/codex-report.py append-event \
  --report-dir ../socialpredict/.codex-reports/tasks/019d9935-ace6-7305-bbc5-9e35238350cc \
  --agent-name software_action_dispatcher_agent \
  --agent-role dispatcher \
  --event-type plan_updated \
  --summary "Narrowed scope to the two remaining markets handlers."
```

## Summary Ownership

- Specialists should append facts and decisions.
- The dispatcher owns `summary.json`.
- `summary.json.last_event_seq` tracks the last rolled-up conversation event so
  dispatcher-led summarization can operate incrementally.
