You are resuming queued automation task {{TASK_REF}} after codex-runner checkpointed the session because the active context window was getting full.

Continue from the existing session state and current repository contents.
- Reuse the canonical report directory `{{REPORT_DIR}}`.
- Continue appending to `{{CONVERSATION_FILE}}` and `{{DECISIONS_FILE}}` rather than creating new report files.
- Keep `{{SUMMARY_FILE}}` current as the dispatcher-owned rollup.
- Use helper script `{{HELPER_SCRIPT}}` for incremental reads and summary updates when practical.
- Check `summary.json.context` first. If `handoff_requested` is true, consolidate state before branching into more work.
- Do not restart the task from scratch.
- Avoid repeating work that is already complete.
- Re-read files or rerun checks only when needed to safely continue.
- Finish with the same concise summary contract as before, including task_uid and task_id.

Latest checkpoint:
{{CHECKPOINT_JSON}}

Task metadata:
{{TASK_METADATA_JSON}}
