#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  codex-runner.sh [options]

Run queued `TASKS.json` work by repeatedly launching Codex in the selected
automation mode. The runner picks the next ready task, asks a dispatcher-led
Codex session to execute it end-to-end, writes run artifacts under
`.codex-runs/`, captures Codex output into per-task log files there, and can
checkpoint/resume long sessions before the active context window gets too full.

Options:
  --repo PATH            Repository root. Default: current directory
  --tasks PATH           Task file. Default: <repo>/TASKS.json
  --runs-dir PATH        Run artifact directory. Default: <repo>/.codex-runs
  --mode MODE            safe | full-access | yolo. Default: safe
  --sleep SECONDS        Poll interval when no task is ready. Default: 30
  --context-threshold PCT
                         Checkpoint and resume when active context usage
                         reaches this percent of the model window. Use 0 to
                         disable. Default: 70
                         This is percent used, not percent remaining. The
                         default keeps about 30% headroom for summaries,
                         TASKS.json checkpointing, and resume prompts in
                         long-running dispatcher sessions.
  --context-poll SECONDS Poll interval for context telemetry. Default: 15
  --context-soft-threshold PCT
                         Ask for a clean handoff once context usage reaches
                         this percent of the model window. Use 0 to disable.
                         Default: 60
  --quiet                Do not mirror live Codex stdout/stderr to the terminal
  --once                 Run at most one ready task, then exit
  --codex-bin PATH       Codex executable. Default: codex
  --dispatcher NAME      Custom dispatcher agent name. Default: dispatcher_agent
  --help                 Show this help

Task file:
  The runner expects TASKS.json, not TASKS.md. JSON is easier to validate,
  update, and consume from automation. A companion TASKS.md can still exist
  for humans, but TASKS.json should be the machine-readable source of truth.
  During execution the runner updates task status, attempts, summaries, and
  runner checkpoint metadata in TASKS.json.

Logs:
  The runner writes logs under --runs-dir (default: <repo>/.codex-runs)
  and, by default, also mirrors live Codex stdout/stderr to your terminal.
  Use --quiet to keep the previous fully silent terminal behavior.
  It also bootstraps canonical curated task reports under
  <target-repo>/.codex-reports/tasks/<task-id>/ for dispatcher/agent use.
  Per task segment it creates:
    events/<task>_<timestamp>_partNN.ndjson
      Raw `codex exec --json` event stream for that run segment.
    stderr/<task>_<timestamp>_partNN.stderr.log
      Codex stderr for that run segment.
    messages/<task>_<timestamp>_partNN.txt
      Final assistant message captured with `--output-last-message`.
    prompts/<task>_<timestamp>_partNN.txt
      Prompt sent to Codex for that run segment.
    context/<task>_<timestamp>_partNN.ndjson
      Context telemetry plus checkpoint/restart events.

  The runner also appends one summary record per completed task to
  <runs-dir>/RUNLOG.ndjson and keeps current runner state in
  <runs-dir>/STATE.json.
USAGE
}

REPO_ROOT="$(pwd)"
TASKS_FILE=""
RUNS_DIR=""
MODE="safe"
SLEEP_SECONDS="30"
# Default to 70% used so long-running coordinator/dispatcher sessions keep
# roughly 30% headroom for final summaries, checkpoint writes, and resumption.
CONTEXT_THRESHOLD_PCT="${CONTEXT_THRESHOLD_PCT:-70}"
CONTEXT_SOFT_THRESHOLD_PCT="${CONTEXT_SOFT_THRESHOLD_PCT:-60}"
CONTEXT_POLL_SECONDS="${CONTEXT_POLL_SECONDS:-15}"
VERBOSE_TERMINAL_OUTPUT="${VERBOSE_TERMINAL_OUTPUT:-1}"
RUN_ONCE="0"
CODEX_BIN="${CODEX_BIN:-codex}"
DISPATCHER_AGENT="${DISPATCHER_AGENT:-dispatcher_agent}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO_ROOT="$2"
      shift 2
      ;;
    --tasks)
      TASKS_FILE="$2"
      shift 2
      ;;
    --runs-dir)
      RUNS_DIR="$2"
      shift 2
      ;;
    --mode)
      MODE="$2"
      shift 2
      ;;
    --sleep)
      SLEEP_SECONDS="$2"
      shift 2
      ;;
    --context-threshold)
      CONTEXT_THRESHOLD_PCT="$2"
      shift 2
      ;;
    --context-poll)
      CONTEXT_POLL_SECONDS="$2"
      shift 2
      ;;
    --context-soft-threshold)
      CONTEXT_SOFT_THRESHOLD_PCT="$2"
      shift 2
      ;;
    --quiet)
      VERBOSE_TERMINAL_OUTPUT="0"
      shift
      ;;
    --once)
      RUN_ONCE="1"
      shift
      ;;
    --codex-bin)
      CODEX_BIN="$2"
      shift 2
      ;;
    --dispatcher)
      DISPATCHER_AGENT="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
TASKS_FILE="${TASKS_FILE:-$REPO_ROOT/TASKS.json}"
RUNS_DIR="${RUNS_DIR:-$REPO_ROOT/.codex-runs}"

command -v python3 >/dev/null 2>&1 || { echo "python3 is required" >&2; exit 1; }
command -v "$CODEX_BIN" >/dev/null 2>&1 || { echo "codex executable not found: $CODEX_BIN" >&2; exit 1; }
[[ -f "$TASKS_FILE" ]] || { echo "Task file not found: $TASKS_FILE" >&2; exit 1; }
python3 - "$CONTEXT_THRESHOLD_PCT" "$CONTEXT_SOFT_THRESHOLD_PCT" "$CONTEXT_POLL_SECONDS" <<'PY'
import sys

threshold = float(sys.argv[1])
soft_threshold = float(sys.argv[2])
poll = float(sys.argv[3])

if threshold < 0 or threshold > 100:
    raise SystemExit("context threshold must be between 0 and 100")
if soft_threshold < 0 or soft_threshold > 100:
    raise SystemExit("context soft threshold must be between 0 and 100")
if threshold > 0 and soft_threshold > threshold:
    raise SystemExit("context soft threshold cannot exceed hard threshold")
if poll <= 0:
    raise SystemExit("context poll interval must be greater than 0")
PY

mkdir -p "$RUNS_DIR/context" "$RUNS_DIR/events" "$RUNS_DIR/messages" "$RUNS_DIR/prompts" "$RUNS_DIR/stderr"
RUNLOG_FILE="$RUNS_DIR/RUNLOG.ndjson"
STATE_FILE="$RUNS_DIR/STATE.json"

run_codex_segment() {
  local event_file="$1"
  local stderr_file="$2"
  shift 2

  if [[ "$VERBOSE_TERMINAL_OUTPUT" == "1" ]]; then
    "$CODEX_BIN" "$@" \
      > >(tee "$event_file") \
      2> >(tee "$stderr_file" >&2)
  else
    "$CODEX_BIN" "$@" > "$event_file" 2> "$stderr_file"
  fi
}

resolve_target_repo_root() {
  local workdir="$1"

  if git -C "$workdir" rev-parse --show-toplevel >/dev/null 2>&1; then
    git -C "$workdir" rev-parse --show-toplevel
  else
    printf '%s\n' "$workdir"
  fi
}

initialize_task_reports() {
  local task_id="$1"
  local task_title="$2"
  local task_workdir_rel="$3"
  local task_workdir_abs="$4"
  local target_repo_root="$5"
  local report_dir="$6"

  python3 "$REPO_ROOT/scripts/codex-report.py" init \
    --report-dir "$report_dir" \
    --task-id "$task_id" \
    --title "$task_title" \
    --working-dir "$task_workdir_rel" \
    --dispatcher-agent "$DISPATCHER_AGENT" \
    --control-repo "$REPO_ROOT" \
    --target-repo "$target_repo_root" >/dev/null
}

pick_next_task() {
  python3 - "$TASKS_FILE" <<'PY'
import json
import os
import sys
from datetime import datetime, timezone

path = sys.argv[1]


def runner_pid_alive(value):
    if value in (None, ""):
        return False
    try:
        os.kill(int(value), 0)
    except (OSError, ValueError):
        return False
    return True

with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

tasks = data.get('tasks', [])
completed = {t['id'] for t in tasks if t.get('status') == 'done'}
now = datetime.now(timezone.utc).isoformat()

selected = None
for task in tasks:
    status = task.get('status', 'pending')
    runner_state = task.get('runner_state') or {}
    if status == 'running' and runner_state.get('resume_pending'):
        if runner_pid_alive(task.get('runner_pid')):
            continue
        task['runner_pid'] = os.getpid()
        task['last_resumed_at'] = now
        selected = task
        break
    deps = task.get('depends_on', []) or []
    max_attempts = int(task.get('max_attempts', 3))
    attempts = int(task.get('attempts', 0))
    if status not in ('pending', 'retry'):
        continue
    if attempts >= max_attempts:
        continue
    if any(dep not in completed for dep in deps):
        continue
    task['status'] = 'running'
    task['attempts'] = attempts + 1
    task['started_at'] = now
    task['runner_pid'] = os.getpid()
    selected = task
    break

with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2)
    f.write('\n')

if selected is None:
    print('')
else:
    print(json.dumps(selected))
PY
}

finalize_task() {
  local task_id="$1"
  local final_status="$2"
  local summary_file="$3"
  local exit_code="$4"
  python3 - "$TASKS_FILE" "$task_id" "$final_status" "$summary_file" "$exit_code" <<'PY'
import json
import sys
from datetime import datetime, timezone

path, task_id, final_status, summary_file, exit_code = sys.argv[1:]

with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

summary = ''
try:
    with open(summary_file, 'r', encoding='utf-8') as f:
        summary = f.read().strip()
except FileNotFoundError:
    summary = ''

now = datetime.now(timezone.utc).isoformat()
for task in data.get('tasks', []):
    if task.get('id') != task_id:
        continue
    task['status'] = final_status
    task['finished_at'] = now
    task['last_exit_code'] = int(exit_code)
    task.pop('runner_pid', None)
    runner_state = task.setdefault('runner_state', {})
    runner_state['resume_pending'] = False
    if summary:
        task['last_summary'] = summary
    break

with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PY
}

write_state() {
  local state_json="$1"
  printf '%s\n' "$state_json" > "$STATE_FILE"
}

write_running_state() {
  local task_id="$1"
  local task_title="$2"
  local event_file="$3"
  local stderr_file="$4"
  local message_file="$5"
  local prompt_file="$6"
  local context_file="$7"
  local segment_index="$8"
  local session_id="$9"
  local snapshot_json="${10:-null}"
  local state_json

  state_json=$(python3 - "$task_id" "$task_title" "$event_file" "$stderr_file" "$message_file" "$prompt_file" "$context_file" "$segment_index" "$session_id" "$CONTEXT_THRESHOLD_PCT" "$snapshot_json" <<'PY'
import json
import sys
from datetime import datetime, timezone

(task_id, task_title, event_file, stderr_file, message_file, prompt_file,
 context_file, segment_index, session_id, context_threshold_pct, snapshot_json) = sys.argv[1:]

state = {
    "status": "running",
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "task_id": task_id,
    "title": task_title,
    "segment": int(segment_index),
    "event_file": event_file,
    "stderr_file": stderr_file,
    "message_file": message_file,
    "prompt_file": prompt_file,
    "context_file": context_file,
    "context_threshold_pct": float(context_threshold_pct),
}

if session_id:
    state["session_id"] = session_id

snapshot = json.loads(snapshot_json)
if snapshot:
    state["context"] = snapshot

print(json.dumps(state))
PY
)
  write_state "$state_json"
}

update_task_runner_state() {
  local task_id="$1"
  local patch_json="$2"

  python3 - "$TASKS_FILE" "$task_id" "$patch_json" <<'PY'
import json
import sys

path, task_id, patch_json = sys.argv[1:]
patch = json.loads(patch_json)


def merge(dst, src):
    for key, value in src.items():
        if isinstance(value, dict) and isinstance(dst.get(key), dict):
            merge(dst[key], value)
        else:
            dst[key] = value


with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

for task in data.get('tasks', []):
    if task.get('id') != task_id:
        continue
    merge(task.setdefault('runner_state', {}), patch)
    break

with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
PY
}

read_task_json() {
  local task_id="$1"

  python3 - "$TASKS_FILE" "$task_id" <<'PY'
import json
import sys

path, task_id = sys.argv[1:]

with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

for task in data.get('tasks', []):
    if task.get('id') == task_id:
        print(json.dumps(task))
        break
else:
    print("")
PY
}

build_prompt() {
  local task_json="$1"
  local report_dir="$2"
  local meta_file="$3"
  local summary_file="$4"
  local conversation_file="$5"
  local decisions_file="$6"
  local helper_script="$7"
  python3 - "$REPO_ROOT" "$DISPATCHER_AGENT" "$report_dir" "$meta_file" "$summary_file" "$conversation_file" "$decisions_file" "$helper_script" "$task_json" <<'PY'
import json
import sys

repo_root = sys.argv[1]
dispatcher = sys.argv[2]
report_dir = sys.argv[3]
meta_file = sys.argv[4]
summary_file = sys.argv[5]
conversation_file = sys.argv[6]
decisions_file = sys.argv[7]
helper_script = sys.argv[8]
task = json.loads(sys.argv[9])

print(f"""You are executing a queued automation task for the SocialPredict repository at {repo_root}.

Start by explicitly spawning the custom agent named `{dispatcher}` to coordinate the task. The dispatcher should decide whether to spawn any specialist agents and should wait for them before concluding.

Reporting convention:
- The canonical curated report location is `{report_dir}`.
- Report files are already bootstrapped:
  - meta: `{meta_file}`
  - summary: `{summary_file}`
  - conversation log: `{conversation_file}`
  - decisions log: `{decisions_file}`
- Use helper script `{helper_script}` for deterministic report I/O when practical.
- Specialists should append facts and decisions; the dispatcher owns `summary.json`.
- Prefer incremental reads, for example `read-events --after-seq <last_event_seq>` instead of rereading the full conversation log.
- `summary.json.context` is runner-maintained. If `handoff_requested` becomes true, stop branching out, update the summary, record a handoff event, and converge toward a clean checkpoint.

Execution contract:
- Do the task end-to-end.
- Do not stop for clarifying questions unless blocked by a missing file, contradictory task instructions, or a safety issue.
- Prefer the smallest defensible change.
- Follow repository AGENTS.md guidance and nearby repo docs.
- Use machine-readable task metadata below as the source of truth.
- Finish with a concise summary that includes: task_id, status, files_changed, checks_run, and follow_ups.

Task metadata:
{json.dumps(task, indent=2, sort_keys=True)}
""")
PY
}

build_resume_prompt() {
  local task_json="$1"
  local report_dir="$2"
  local summary_file="$3"
  local conversation_file="$4"
  local decisions_file="$5"
  local helper_script="$6"
  python3 - "$report_dir" "$summary_file" "$conversation_file" "$decisions_file" "$helper_script" "$task_json" <<'PY'
import json
import sys

report_dir = sys.argv[1]
summary_file = sys.argv[2]
conversation_file = sys.argv[3]
decisions_file = sys.argv[4]
helper_script = sys.argv[5]
task = json.loads(sys.argv[6])
runner_state = task.get("runner_state") or {}
checkpoint = runner_state.get("last_context_checkpoint") or {}

print(f"""You are resuming queued automation task {task.get("id", "")} after codex-runner checkpointed the session because the active context window was getting full.

Continue from the existing session state and current repository contents.
- Reuse the canonical report directory `{report_dir}`.
- Continue appending to `{conversation_file}` and `{decisions_file}` rather than creating new report files.
- Keep `{summary_file}` current as the dispatcher-owned rollup.
- Use helper script `{helper_script}` for incremental reads and summary updates when practical.
- Check `summary.json.context` first. If `handoff_requested` is true, consolidate state before branching into more work.
- Do not restart the task from scratch.
- Avoid repeating work that is already complete.
- Re-read files or rerun checks only when needed to safely continue.
- Finish with the same concise summary contract as before.

Latest checkpoint:
{json.dumps(checkpoint, indent=2, sort_keys=True)}

Task metadata:
{json.dumps(task, indent=2, sort_keys=True)}
""")
PY
}

append_runlog() {
  local event_json="$1"
  printf '%s\n' "$event_json" >> "$RUNLOG_FILE"
}

append_context_log() {
  local context_file="$1"
  local event_json="$2"
  printf '%s\n' "$event_json" >> "$context_file"
}


update_report_context() {
  local report_dir="$1"
  local session_id="$2"
  local used_tokens="$3"
  local context_window="$4"
  local remaining_tokens="$5"
  local used_pct="$6"
  local reason="$7"
  local handoff_requested="$8"

  local -a args
  args=(
    update-context
    --report-dir "$report_dir"
    --session-id "$session_id"
    --used-tokens "$used_tokens"
    --context-window "$context_window"
    --remaining-tokens "$remaining_tokens"
    --used-pct "$used_pct"
    --soft-threshold-pct "$CONTEXT_SOFT_THRESHOLD_PCT"
    --threshold-pct "$CONTEXT_THRESHOLD_PCT"
  )

  if [[ "$handoff_requested" == "1" ]]; then
    args+=(--handoff-requested)
  fi
  if [[ -n "$reason" ]]; then
    args+=(--reason "$reason")
  fi

  python3 "$REPO_ROOT/scripts/codex-report.py" "${args[@]}" >/dev/null
}

append_report_event() {
  local report_dir="$1"
  local agent_name="$2"
  local agent_role="$3"
  local event_type="$4"
  local summary="$5"

  python3 "$REPO_ROOT/scripts/codex-report.py" append-event \
    --report-dir "$report_dir" \
    --agent-name "$agent_name" \
    --agent-role "$agent_role" \
    --event-type "$event_type" \
    --summary "$summary" >/dev/null
}

print_context_terminal_line() {
  local task_id="$1"
  local segment_index="$2"
  local level="$3"
  local used_pct="$4"
  local used_tokens="$5"
  local remaining_tokens="$6"
  local context_window="$7"
  local message="$8"

  printf '[codex-runner][%s][task=%s][segment=%s][context=%s%% used][used=%s][remaining=%s/%s] %s\n' \
    "$level" "$task_id" "$segment_index" "$used_pct" "$used_tokens" "$remaining_tokens" "$context_window" "$message" >&2
}

build_codex_exec_args() {
  local workdir="$1"
  local sandbox="$2"
  local approval="$3"
  local profile="$4"

  local -a args
  args=(--cd "$workdir")

  if [[ -n "$profile" ]]; then
    args+=(--profile "$profile")
  fi

  case "$MODE" in
    safe)
      args+=(--sandbox "$sandbox" --ask-for-approval "$approval")
      ;;
    full-access)
      args+=(--sandbox danger-full-access --ask-for-approval never)
      ;;
    yolo)
      args+=(--dangerously-bypass-approvals-and-sandbox)
      ;;
    *)
      echo "Unsupported mode: $MODE" >&2
      exit 1
      ;;
  esac

  args+=(exec --json)

  printf '%s\0' "${args[@]}"
}

build_codex_resume_args() {
  local workdir="$1"
  local sandbox="$2"
  local approval="$3"
  local profile="$4"

  local -a args
  args=(--cd "$workdir")

  if [[ -n "$profile" ]]; then
    args+=(--profile "$profile")
  fi

  case "$MODE" in
    safe)
      args+=(--sandbox "$sandbox" --ask-for-approval "$approval")
      ;;
    full-access)
      args+=(--sandbox danger-full-access --ask-for-approval never)
      ;;
    yolo)
      args+=(--dangerously-bypass-approvals-and-sandbox)
      ;;
    *)
      echo "Unsupported mode: $MODE" >&2
      exit 1
      ;;
  esac

  args+=(exec resume --json)

  printf '%s\0' "${args[@]}"
}

snapshot_context_usage() {
  local event_file="$1"
  python3 - "$event_file" <<'PY'
import json
import sys

path = sys.argv[1]
session_id = None
latest = None

try:
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        for raw in f:
            line = raw.strip()
            if not line:
                continue
            try:
                payload = json.loads(line)
            except json.JSONDecodeError:
                continue

            if payload.get('type') == 'thread.started' and not session_id:
                session_id = payload.get('thread_id') or payload.get('id')

            info = None
            if payload.get('type') == 'token_count':
                info = payload.get('info')
            elif isinstance(payload.get('payload'), dict) and payload['payload'].get('type') == 'token_count':
                info = payload['payload'].get('info')

            if not isinstance(info, dict):
                continue

            last_usage = info.get('last_token_usage') or {}
            used_tokens = last_usage.get('total_tokens')
            context_window = info.get('model_context_window')
            if not isinstance(used_tokens, int) or not isinstance(context_window, int):
                continue

            remaining_tokens = context_window - used_tokens
            latest = {
                "used_tokens": used_tokens,
                "context_window": context_window,
                "remaining_tokens": remaining_tokens,
                "used_pct": round((used_tokens / context_window) * 100, 2),
            }
except FileNotFoundError:
    pass

result = {
    "session_id": session_id,
    "has_snapshot": latest is not None,
}
if latest is not None:
    result.update(latest)

print(json.dumps(result))
PY
}

monitor_context_window() {
  local task_id="$1"
  local task_title="$2"
  local event_file="$3"
  local stderr_file="$4"
  local message_file="$5"
  local prompt_file="$6"
  local context_file="$7"
  local report_dir="$8"
  local codex_pid="$9"
  local segment_index="${10}"
  local restart_request_file="${11}"
  local next_restart_count="${12}"

  local known_session_id=""
  local last_logged_tokens=""
  local soft_handoff_requested="0"

  while kill -0 "$codex_pid" >/dev/null 2>&1; do
    sleep "$CONTEXT_POLL_SECONDS"

    local snapshot_json session_id has_snapshot used_tokens context_window remaining_tokens used_pct
    snapshot_json="$(snapshot_context_usage "$event_file")"
    IFS=$'\t' read -r session_id has_snapshot used_tokens context_window remaining_tokens used_pct < <(
      python3 - "$snapshot_json" <<'PY'
import json
import sys

snapshot = json.loads(sys.argv[1])
print(
    (snapshot.get("session_id") or ""),
    "1" if snapshot.get("has_snapshot") else "0",
    snapshot.get("used_tokens", ""),
    snapshot.get("context_window", ""),
    snapshot.get("remaining_tokens", ""),
    snapshot.get("used_pct", ""),
    sep="\t",
)
PY
    )

    if [[ -n "$session_id" && "$session_id" != "$known_session_id" ]]; then
      known_session_id="$session_id"

      local session_started_json task_patch_json
      session_started_json=$(python3 - "$task_id" "$segment_index" "$session_id" <<'PY'
import json
import sys
from datetime import datetime, timezone

task_id, segment_index, session_id = sys.argv[1:]
print(json.dumps({
    "record_type": "context_session_started",
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "task_id": task_id,
    "segment": int(segment_index),
    "session_id": session_id,
}))
PY
)
      append_context_log "$context_file" "$session_started_json"

      task_patch_json=$(python3 - "$segment_index" "$session_id" "$event_file" "$stderr_file" "$message_file" "$prompt_file" "$context_file" <<'PY'
import json
import sys

(segment_index, session_id, event_file, stderr_file, message_file,
 prompt_file, context_file) = sys.argv[1:]
print(json.dumps({
    "segment": int(segment_index),
    "session_id": session_id,
    "event_file": event_file,
    "stderr_file": stderr_file,
    "message_file": message_file,
    "prompt_file": prompt_file,
    "context_file": context_file,
}))
PY
)
      update_task_runner_state "$task_id" "$task_patch_json"
      write_running_state "$task_id" "$task_title" "$event_file" "$stderr_file" "$message_file" "$prompt_file" "$context_file" "$segment_index" "$session_id" "null"
    fi

    if [[ "$has_snapshot" != "1" || -z "$used_tokens" ]]; then
      continue
    fi

    if [[ "$used_tokens" != "$last_logged_tokens" ]]; then
      last_logged_tokens="$used_tokens"

      local progress_json
      progress_json=$(python3 - "$task_id" "$segment_index" "$session_id" "$used_tokens" "$context_window" "$remaining_tokens" "$used_pct" "$CONTEXT_THRESHOLD_PCT" <<'PY'
import json
import sys
from datetime import datetime, timezone

(task_id, segment_index, session_id, used_tokens, context_window,
 remaining_tokens, used_pct, threshold_pct) = sys.argv[1:]
print(json.dumps({
    "record_type": "context_progress",
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "task_id": task_id,
    "segment": int(segment_index),
    "session_id": session_id,
    "used_tokens": int(used_tokens),
    "context_window": int(context_window),
    "remaining_tokens": int(remaining_tokens),
    "used_pct": float(used_pct),
    "threshold_pct": float(threshold_pct),
}))
PY
)
      append_context_log "$context_file" "$progress_json"
      update_report_context "$report_dir" "$session_id" "$used_tokens" "$context_window" "$remaining_tokens" "$used_pct" "context_progress" "$soft_handoff_requested"
      print_context_terminal_line "$task_id" "$segment_index" "progress" "$used_pct" "$used_tokens" "$remaining_tokens" "$context_window" "Context usage updated."
      write_running_state "$task_id" "$task_title" "$event_file" "$stderr_file" "$message_file" "$prompt_file" "$context_file" "$segment_index" "$session_id" "$snapshot_json"
    fi

    if [[ "$soft_handoff_requested" != "1" && "$(python3 - "$used_pct" "$CONTEXT_SOFT_THRESHOLD_PCT" <<'PY'
import sys
soft = float(sys.argv[2])
print("1" if soft > 0 and float(sys.argv[1]) >= soft else "0")
PY
)" == "1" ]]; then
      soft_handoff_requested="1"

      local soft_warning_json
      soft_warning_json=$(python3 - "$task_id" "$segment_index" "$session_id" "$used_tokens" "$context_window" "$remaining_tokens" "$used_pct" "$CONTEXT_SOFT_THRESHOLD_PCT" "$CONTEXT_THRESHOLD_PCT" <<'PY'
import json
import sys
from datetime import datetime, timezone

(task_id, segment_index, session_id, used_tokens, context_window,
 remaining_tokens, used_pct, soft_threshold_pct, threshold_pct) = sys.argv[1:]
print(json.dumps({
    "record_type": "context_soft_limit_reached",
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "task_id": task_id,
    "segment": int(segment_index),
    "session_id": session_id,
    "used_tokens": int(used_tokens),
    "context_window": int(context_window),
    "remaining_tokens": int(remaining_tokens),
    "used_pct": float(used_pct),
    "soft_threshold_pct": float(soft_threshold_pct),
    "threshold_pct": float(threshold_pct),
}))
PY
)
      append_context_log "$context_file" "$soft_warning_json"
      append_report_event "$report_dir" "codex_runner" "runner" "context_soft_limit_reached" "Soft context threshold reached. Dispatcher should stop branching and write a clean handoff into summary.json and conversation.ndjson."
      update_report_context "$report_dir" "$session_id" "$used_tokens" "$context_window" "$remaining_tokens" "$used_pct" "soft_threshold_reached" "1"
      print_context_terminal_line "$task_id" "$segment_index" "soft-threshold" "$used_pct" "$used_tokens" "$remaining_tokens" "$context_window" "Soft threshold reached. Dispatcher should wrap up toward checkpoint."
    fi

    if [[ "$(python3 - "$used_pct" "$CONTEXT_THRESHOLD_PCT" <<'PY'
import sys
print("1" if float(sys.argv[1]) >= float(sys.argv[2]) else "0")
PY
)" != "1" ]]; then
      continue
    fi

    local checkpoint_patch_json checkpoint_log_json
    checkpoint_patch_json=$(python3 - "$segment_index" "$session_id" "$event_file" "$stderr_file" "$message_file" "$prompt_file" "$context_file" "$used_tokens" "$context_window" "$remaining_tokens" "$used_pct" "$CONTEXT_THRESHOLD_PCT" "$next_restart_count" <<'PY'
import json
import sys
from datetime import datetime, timezone

(segment_index, session_id, event_file, stderr_file, message_file,
 prompt_file, context_file, used_tokens, context_window,
 remaining_tokens, used_pct, threshold_pct, restart_count) = sys.argv[1:]
now = datetime.now(timezone.utc).isoformat()
snapshot = {
    "observed_at": now,
    "used_tokens": int(used_tokens),
    "context_window": int(context_window),
    "remaining_tokens": int(remaining_tokens),
    "used_pct": float(used_pct),
}
print(json.dumps({
    "segment": int(segment_index),
    "session_id": session_id,
    "event_file": event_file,
    "stderr_file": stderr_file,
    "message_file": message_file,
    "prompt_file": prompt_file,
    "context_file": context_file,
    "restart_count": int(restart_count),
    "resume_pending": True,
    "last_context_snapshot": snapshot,
    "last_context_checkpoint": {
        "reason": "context_threshold_reached",
        "checkpointed_at": now,
        "threshold_pct": float(threshold_pct),
        **snapshot,
    },
}))
PY
)
    checkpoint_log_json=$(python3 - "$task_id" "$segment_index" "$session_id" "$used_tokens" "$context_window" "$remaining_tokens" "$used_pct" "$CONTEXT_THRESHOLD_PCT" "$next_restart_count" <<'PY'
import json
import sys
from datetime import datetime, timezone

(task_id, segment_index, session_id, used_tokens, context_window,
 remaining_tokens, used_pct, threshold_pct, restart_count) = sys.argv[1:]
print(json.dumps({
    "record_type": "context_checkpoint_requested",
    "timestamp": datetime.now(timezone.utc).isoformat(),
    "task_id": task_id,
    "segment": int(segment_index),
    "session_id": session_id,
    "used_tokens": int(used_tokens),
    "context_window": int(context_window),
    "remaining_tokens": int(remaining_tokens),
    "used_pct": float(used_pct),
    "threshold_pct": float(threshold_pct),
    "restart_count": int(restart_count),
}))
PY
)

    update_task_runner_state "$task_id" "$checkpoint_patch_json"
    append_context_log "$context_file" "$checkpoint_log_json"
    append_report_event "$report_dir" "codex_runner" "runner" "context_checkpoint_requested" "Hard context threshold reached. Runner is checkpointing and will resume the same task session."
    update_report_context "$report_dir" "$session_id" "$used_tokens" "$context_window" "$remaining_tokens" "$used_pct" "hard_threshold_reached" "1"
    print_context_terminal_line "$task_id" "$segment_index" "hard-threshold" "$used_pct" "$used_tokens" "$remaining_tokens" "$context_window" "Hard threshold reached. Runner is checkpointing and resuming the session."
    write_running_state "$task_id" "$task_title" "$event_file" "$stderr_file" "$message_file" "$prompt_file" "$context_file" "$segment_index" "$session_id" "$snapshot_json"
    printf '%s\n' "$checkpoint_patch_json" > "$restart_request_file"
    kill -TERM "$codex_pid" >/dev/null 2>&1 || true
    return 0
  done
}

while true; do
  task_json="$(pick_next_task)"

  if [[ -z "$task_json" ]]; then
    state_json=$(python3 - <<'PY'
import json
from datetime import datetime, timezone
print(json.dumps({
  "status": "idle",
  "timestamp": datetime.now(timezone.utc).isoformat(),
  "message": "No ready tasks."
}))
PY
)
    write_state "$state_json"
    if [[ "$RUN_ONCE" == "1" ]]; then
      exit 0
    fi
    sleep "$SLEEP_SECONDS"
    continue
  fi

  task_id="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["id"])' <<< "$task_json")"
  task_title="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("title", ""))' <<< "$task_json")"
  task_workdir_rel="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("working_dir", "."))' <<< "$task_json")"
  task_workdir_abs="$(cd "$REPO_ROOT/$task_workdir_rel" && pwd)"
  task_sandbox="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("sandbox", "workspace-write"))' <<< "$task_json")"
  task_approval="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("approval", "never"))' <<< "$task_json")"
  task_profile="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("profile", ""))' <<< "$task_json")"
  target_repo_root="$(resolve_target_repo_root "$task_workdir_abs")"
  report_dir="$target_repo_root/.codex-reports/tasks/$task_id"
  meta_file="$report_dir/meta.json"
  summary_json_file="$report_dir/summary.json"
  conversation_file="$report_dir/conversation.ndjson"
  decisions_file="$report_dir/decisions.ndjson"
  report_helper="$REPO_ROOT/scripts/codex-report.py"
  start_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  resume_session_id="$(python3 -c 'import json,sys; print((json.loads(sys.stdin.read()).get("runner_state") or {}).get("session_id", ""))' <<< "$task_json")"
  resume_pending="$(python3 -c 'import json,sys; print("1" if ((json.loads(sys.stdin.read()).get("runner_state") or {}).get("resume_pending")) else "0")' <<< "$task_json")"
  stored_segment="$(python3 -c 'import json,sys; print(int((json.loads(sys.stdin.read()).get("runner_state") or {}).get("segment", 0)))' <<< "$task_json")"
  context_restart_count="$(python3 -c 'import json,sys; print(int((json.loads(sys.stdin.read()).get("runner_state") or {}).get("restart_count", 0)))' <<< "$task_json")"

  initialize_task_reports "$task_id" "$task_title" "$task_workdir_rel" "$task_workdir_abs" "$target_repo_root" "$report_dir"

  if [[ "$resume_pending" == "1" && -n "$resume_session_id" ]]; then
    segment_index=$((stored_segment + 1))
  else
    resume_session_id=""
    segment_index=1
  fi

  last_session_id="$resume_session_id"
  last_event_file=""
  last_stderr_file=""
  last_message_file=""
  last_prompt_file=""
  last_context_file=""
  event_files=()
  stderr_files=()
  message_files=()
  prompt_files=()
  context_files=()

  while true; do
    task_timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
    segment_label="$(printf '%02d' "$segment_index")"
    event_file="$RUNS_DIR/events/${task_id}_${task_timestamp}_part${segment_label}.ndjson"
    stderr_file="$RUNS_DIR/stderr/${task_id}_${task_timestamp}_part${segment_label}.stderr.log"
    message_file="$RUNS_DIR/messages/${task_id}_${task_timestamp}_part${segment_label}.txt"
    prompt_file="$RUNS_DIR/prompts/${task_id}_${task_timestamp}_part${segment_label}.txt"
    context_file="$RUNS_DIR/context/${task_id}_${task_timestamp}_part${segment_label}.ndjson"
    restart_request_file="${context_file%.ndjson}.restart.json"
    rm -f "$restart_request_file"

    if [[ -n "$resume_session_id" ]]; then
      build_resume_prompt "$task_json" "$report_dir" "$summary_json_file" "$conversation_file" "$decisions_file" "$report_helper" > "$prompt_file"
      mapfile -d '' codex_args < <(build_codex_resume_args "$task_workdir_abs" "$task_sandbox" "$task_approval" "$task_profile")
      codex_args+=(--output-last-message "$message_file" "$resume_session_id" -)
    else
      build_prompt "$task_json" "$report_dir" "$meta_file" "$summary_json_file" "$conversation_file" "$decisions_file" "$report_helper" > "$prompt_file"
      mapfile -d '' codex_args < <(build_codex_exec_args "$task_workdir_abs" "$task_sandbox" "$task_approval" "$task_profile")
      codex_args+=(--output-last-message "$message_file" -)
    fi

    event_files+=("$event_file")
    stderr_files+=("$stderr_file")
    message_files+=("$message_file")
    prompt_files+=("$prompt_file")
    context_files+=("$context_file")

    write_running_state "$task_id" "$task_title" "$event_file" "$stderr_file" "$message_file" "$prompt_file" "$context_file" "$segment_index" "$resume_session_id" "null"

    set +e
    run_codex_segment "$event_file" "$stderr_file" "${codex_args[@]}" < "$prompt_file" &
    codex_pid=$!

    monitor_pid=""
    if [[ "$(python3 - "$CONTEXT_THRESHOLD_PCT" <<'PY'
import sys
print("1" if float(sys.argv[1]) > 0 else "0")
PY
)" == "1" ]]; then
      next_restart_count=$((context_restart_count + 1))
      monitor_context_window "$task_id" "$task_title" "$event_file" "$stderr_file" "$message_file" "$prompt_file" "$context_file" "$report_dir" "$codex_pid" "$segment_index" "$restart_request_file" "$next_restart_count" &
      monitor_pid=$!
    fi

    wait "$codex_pid"
    exit_code=$?

    if [[ -n "$monitor_pid" ]]; then
      kill "$monitor_pid" >/dev/null 2>&1 || true
      wait "$monitor_pid" >/dev/null 2>&1 || true
    fi
    set -e

    if [[ -z "$last_session_id" ]]; then
      last_session_id="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("session_id", ""))' <<< "$(snapshot_context_usage "$event_file")")"
    fi

    last_event_file="$event_file"
    last_stderr_file="$stderr_file"
    last_message_file="$message_file"
    last_prompt_file="$prompt_file"
    last_context_file="$context_file"

    if [[ -f "$restart_request_file" ]]; then
      resume_session_id="$(python3 -c 'import json,sys; print(json.loads(sys.stdin.read()).get("session_id", ""))' < "$restart_request_file")"
      if [[ -z "$resume_session_id" ]]; then
        resume_session_id="$last_session_id"
      fi
      last_session_id="$resume_session_id"
      context_restart_count=$((context_restart_count + 1))
      segment_index=$((segment_index + 1))
      task_json="$(read_task_json "$task_id")"
      continue
    fi

    break
  done

  end_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if [[ $exit_code -eq 0 ]]; then
    task_status="done"
  else
    task_status="retry"
  fi

  finalize_task "$task_id" "$task_status" "$message_file" "$exit_code"

  files_changed_json="[]"
  if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    files_changed_json="$(git -C "$REPO_ROOT" status --porcelain | awk '{print $2}' | python3 -c 'import json,sys; print(json.dumps([line.strip() for line in sys.stdin if line.strip()]))')"
  fi

  event_files_json="$(printf '%s\n' "${event_files[@]}" | python3 -c 'import json,sys; print(json.dumps([line.strip() for line in sys.stdin if line.strip()]))')"
  stderr_files_json="$(printf '%s\n' "${stderr_files[@]}" | python3 -c 'import json,sys; print(json.dumps([line.strip() for line in sys.stdin if line.strip()]))')"
  message_files_json="$(printf '%s\n' "${message_files[@]}" | python3 -c 'import json,sys; print(json.dumps([line.strip() for line in sys.stdin if line.strip()]))')"
  prompt_files_json="$(printf '%s\n' "${prompt_files[@]}" | python3 -c 'import json,sys; print(json.dumps([line.strip() for line in sys.stdin if line.strip()]))')"
  context_files_json="$(printf '%s\n' "${context_files[@]}" | python3 -c 'import json,sys; print(json.dumps([line.strip() for line in sys.stdin if line.strip()]))')"

  runlog_json=$(python3 - "$task_id" "$task_title" "$start_ts" "$end_ts" "$task_status" "$exit_code" "$MODE" "$REPO_ROOT" "$task_workdir_rel" "$DISPATCHER_AGENT" "$last_event_file" "$last_stderr_file" "$last_message_file" "$last_prompt_file" "$last_context_file" "$last_session_id" "$segment_index" "$context_restart_count" "$CONTEXT_THRESHOLD_PCT" "$event_files_json" "$stderr_files_json" "$message_files_json" "$prompt_files_json" "$context_files_json" "$files_changed_json" <<'PY'
import json
import sys
(task_id, task_title, start_ts, end_ts, task_status, exit_code, mode, repo_root,
 task_workdir_rel, dispatcher_agent, event_file, stderr_file, message_file,
 prompt_file, context_file, session_id, segments, context_restarts,
 context_threshold_pct, event_files_json, stderr_files_json, message_files_json,
 prompt_files_json, context_files_json, files_changed_json) = sys.argv[1:]

def load_json_arg(raw, default):
    if raw is None or not raw.strip():
        return default
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return default

record = {
  "record_type": "run_summary",
  "task_id": task_id,
  "title": task_title,
  "started_at": start_ts,
  "finished_at": end_ts,
  "status": task_status,
  "exit_code": int(exit_code),
  "mode": mode,
  "repo_root": repo_root,
  "working_dir": task_workdir_rel,
  "dispatcher_agent": dispatcher_agent,
  "session_id": session_id,
  "segments": int(segments),
  "context_threshold_pct": float(context_threshold_pct),
  "context_restarts": int(context_restarts),
  "event_file": event_file,
  "stderr_file": stderr_file,
  "message_file": message_file,
  "prompt_file": prompt_file,
  "context_file": context_file,
  "event_files": load_json_arg(event_files_json, []),
  "stderr_files": load_json_arg(stderr_files_json, []),
  "message_files": load_json_arg(message_files_json, []),
  "prompt_files": load_json_arg(prompt_files_json, []),
  "context_files": load_json_arg(context_files_json, []),
  "files_changed": load_json_arg(files_changed_json, [])
}
print(json.dumps(record))
PY
)
  append_runlog "$runlog_json"

  if [[ "$RUN_ONCE" == "1" ]]; then
    exit $exit_code
  fi

done
