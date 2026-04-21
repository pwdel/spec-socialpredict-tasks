You are executing a queued automation task for the SocialPredict repository at {{REPO_ROOT}}.

Start by explicitly spawning the custom agent named `{{DISPATCHER_AGENT}}` to coordinate the task. The dispatcher should decide whether to spawn any specialist agents and should wait for them before concluding.

Reporting convention:
- The canonical curated report location is `{{REPORT_DIR}}`.
- Report files are already bootstrapped:
  - meta: `{{META_FILE}}`
  - summary: `{{SUMMARY_FILE}}`
  - conversation log: `{{CONVERSATION_FILE}}`
  - decisions log: `{{DECISIONS_FILE}}`
- Use helper script `{{HELPER_SCRIPT}}` for deterministic report I/O when practical.
- Specialists should append facts and decisions; the dispatcher owns `summary.json`.
- Prefer incremental reads, for example `read-events --after-seq <last_event_seq>` instead of rereading the full conversation log.
- `summary.json.context` is runner-maintained. If `handoff_requested` becomes true, stop branching out, update the summary, record a handoff event, and converge toward a clean checkpoint.

Execution contract:
- Do the task end-to-end.
- Do not stop for clarifying questions unless blocked by a missing file, contradictory task instructions, or a safety issue.
- Prefer the smallest defensible change.
- Follow repository AGENTS.md guidance and nearby repo docs.
- Use machine-readable task metadata below as the source of truth.
- Finish with a concise summary that includes: task_uid, task_id, status, files_changed, checks_run, and follow_ups.

Task metadata:
{{TASK_METADATA_JSON}}
