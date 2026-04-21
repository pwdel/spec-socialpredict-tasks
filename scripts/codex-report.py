#!/usr/bin/env python3
"""Manage canonical Codex task reports in the target repository."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def report_paths(report_dir: Path) -> dict[str, Path]:
    return {
        "report_dir": report_dir,
        "meta": report_dir / "meta.json",
        "summary": report_dir / "summary.json",
        "conversation": report_dir / "conversation.ndjson",
        "decisions": report_dir / "decisions.ndjson",
    }


def ensure_report_dir(report_dir: Path) -> dict[str, Path]:
    paths = report_paths(report_dir)
    report_dir.mkdir(parents=True, exist_ok=True)
    return paths


def read_json(path: Path, default: dict) -> dict:
    if not path.exists():
        return default.copy()
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, payload: dict) -> None:
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def read_last_seq(path: Path) -> int:
    if not path.exists():
        return 0
    last_seq = 0
    with path.open("r", encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if not line:
                continue
            payload = json.loads(line)
            last_seq = max(last_seq, int(payload.get("seq", 0)))
    return last_seq


def append_ndjson(path: Path, payload: dict) -> None:
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, separators=(",", ":")) + "\n")


def read_ndjson(path: Path) -> Iterable[dict]:
    if not path.exists():
        return []
    rows = []
    with path.open("r", encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if not line:
                continue
            rows.append(json.loads(line))
    return rows


def load_task_identity(paths: dict[str, Path]) -> tuple[str, str]:
    summary = read_json(paths["summary"], {})
    task_uid = summary.get("task_uid", "")
    task_id = summary.get("task_id", "")
    if task_uid:
        return task_uid, task_id

    meta = read_json(paths["meta"], {})
    task = meta.get("task", {}) if isinstance(meta.get("task"), dict) else {}
    task_uid = task.get("uid", "") or ""
    task_id = task.get("id", "") or ""
    return task_uid, task_id


def command_init(args: argparse.Namespace) -> int:
    report_dir = Path(args.report_dir).resolve()
    paths = ensure_report_dir(report_dir)
    created_at = utc_now()

    meta = read_json(paths["meta"], {})
    if not meta:
        meta = {
            "schema_version": 1,
            "task": {
                "uid": args.task_uid,
                "id": args.task_id,
                "title": args.title,
                "working_dir": args.working_dir,
            },
            "dispatcher_agent": args.dispatcher_agent,
            "control_repo": args.control_repo,
            "target_repo": args.target_repo,
            "report_dir": str(report_dir),
            "created_at": created_at,
        }
    meta["updated_at"] = created_at
    meta["files"] = {
        "summary": str(paths["summary"]),
        "conversation": str(paths["conversation"]),
        "decisions": str(paths["decisions"]),
    }
    write_json(paths["meta"], meta)

    if not paths["conversation"].exists():
        paths["conversation"].touch()
    if not paths["decisions"].exists():
        paths["decisions"].touch()

    summary = read_json(paths["summary"], {})
    if not summary:
        summary = {
            "task_uid": args.task_uid,
            "task_id": args.task_id,
            "status": "pending",
            "updated_at": created_at,
            "owner": args.dispatcher_agent,
            "headline": "",
            "current_focus": "",
            "files_changed": [],
            "checks_run": [],
            "open_questions": [],
            "follow_ups": [],
            "last_event_seq": 0,
            "context": {
                "handoff_requested": False,
            },
        }
    else:
        summary.setdefault("task_uid", args.task_uid)
        summary.setdefault("task_id", args.task_id)
        summary.setdefault("owner", args.dispatcher_agent)
        summary.setdefault("files_changed", [])
        summary.setdefault("checks_run", [])
        summary.setdefault("open_questions", [])
        summary.setdefault("follow_ups", [])
        summary.setdefault("last_event_seq", 0)
        summary.setdefault("context", {"handoff_requested": False})
        summary["updated_at"] = created_at
    write_json(paths["summary"], summary)

    if read_last_seq(paths["conversation"]) == 0:
        append_ndjson(
            paths["conversation"],
            {
                "seq": 1,
                "ts": created_at,
                "task_uid": args.task_uid,
                "task_id": args.task_id,
                "agent": "codex_runner",
                "role": "runner",
                "type": "task_bootstrapped",
                "summary": "Bootstrapped canonical target-repo report files for this task.",
                "files_considered": [],
                "files_changed": [],
                "checks": [],
                "refs": [
                    str(paths["meta"]),
                    str(paths["summary"]),
                    str(paths["conversation"]),
                    str(paths["decisions"]),
                ],
            },
        )
        summary["last_event_seq"] = 1
        summary["updated_at"] = created_at
        write_json(paths["summary"], summary)

    print(json.dumps({"report_dir": str(report_dir), "summary": str(paths["summary"])}))
    return 0


def command_append_event(args: argparse.Namespace) -> int:
    report_dir = Path(args.report_dir).resolve()
    paths = ensure_report_dir(report_dir)
    task_uid, task_id = load_task_identity(paths)
    seq = read_last_seq(paths["conversation"]) + 1
    payload = {
        "seq": seq,
        "ts": utc_now(),
        "task_uid": task_uid,
        "task_id": task_id,
        "agent": args.agent_name,
        "role": args.agent_role,
        "type": args.event_type,
        "summary": args.summary,
        "status": args.status or "",
        "files_considered": args.files_considered or [],
        "files_changed": args.files_changed or [],
        "checks": args.checks_run or [],
        "refs": args.refs or [],
    }
    append_ndjson(paths["conversation"], payload)
    print(json.dumps(payload))
    return 0


def command_append_decision(args: argparse.Namespace) -> int:
    report_dir = Path(args.report_dir).resolve()
    paths = ensure_report_dir(report_dir)
    task_uid, task_id = load_task_identity(paths)
    seq = read_last_seq(paths["decisions"]) + 1
    payload = {
        "seq": seq,
        "ts": utc_now(),
        "task_uid": task_uid,
        "task_id": task_id,
        "agent": args.agent_name,
        "decision": args.decision,
        "reason": args.reason,
        "impact": args.impact or "",
    }
    append_ndjson(paths["decisions"], payload)
    print(json.dumps(payload))
    return 0


def command_update_summary(args: argparse.Namespace) -> int:
    report_dir = Path(args.report_dir).resolve()
    paths = ensure_report_dir(report_dir)
    summary = read_json(paths["summary"], {})
    summary.update(
        {
            "updated_at": utc_now(),
            "task_uid": summary.get("task_uid") or args.task_uid or "",
            "task_id": summary.get("task_id") or args.task_id or "",
            "owner": args.owner or summary.get("owner", ""),
            "status": args.status or summary.get("status", "pending"),
            "headline": args.headline if args.headline is not None else summary.get("headline", ""),
            "current_focus": (
                args.current_focus
                if args.current_focus is not None
                else summary.get("current_focus", "")
            ),
            "files_changed": args.files_changed if args.files_changed is not None else summary.get("files_changed", []),
            "checks_run": args.checks_run if args.checks_run is not None else summary.get("checks_run", []),
            "open_questions": (
                args.open_questions if args.open_questions is not None else summary.get("open_questions", [])
            ),
            "follow_ups": args.follow_ups if args.follow_ups is not None else summary.get("follow_ups", []),
            "last_event_seq": (
                args.last_event_seq
                if args.last_event_seq is not None
                else summary.get("last_event_seq", 0)
            ),
            "context": summary.get("context", {"handoff_requested": False}),
        }
    )
    write_json(paths["summary"], summary)
    print(json.dumps(summary))
    return 0


def command_update_context(args: argparse.Namespace) -> int:
    report_dir = Path(args.report_dir).resolve()
    paths = ensure_report_dir(report_dir)
    summary = read_json(paths["summary"], {})
    context = summary.get("context", {"handoff_requested": False})
    context.update(
        {
            "updated_at": utc_now(),
            "session_id": args.session_id or context.get("session_id", ""),
            "used_tokens": args.used_tokens,
            "context_window": args.context_window,
            "remaining_tokens": args.remaining_tokens,
            "used_pct": args.used_pct,
            "soft_threshold_pct": args.soft_threshold_pct,
            "threshold_pct": args.threshold_pct,
            "handoff_requested": args.handoff_requested,
            "reason": args.reason or context.get("reason", ""),
        }
    )
    summary["context"] = context
    summary["updated_at"] = utc_now()
    write_json(paths["summary"], summary)
    print(json.dumps(summary))
    return 0


def command_read_ndjson(args: argparse.Namespace, key: str) -> int:
    report_dir = Path(args.report_dir).resolve()
    paths = report_paths(report_dir)
    rows = [
        row
        for row in read_ndjson(paths[key])
        if int(row.get("seq", 0)) > args.after_seq
    ]
    if args.limit is not None:
        rows = rows[-args.limit :]
    for row in rows:
        print(json.dumps(row, separators=(",", ":")))
    return 0


def command_read_summary(args: argparse.Namespace) -> int:
    report_dir = Path(args.report_dir).resolve()
    paths = report_paths(report_dir)
    summary = read_json(paths["summary"], {})
    print(json.dumps(summary, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser("init")
    init_parser.add_argument("--report-dir", required=True)
    init_parser.add_argument("--task-uid", required=True)
    init_parser.add_argument("--task-id", default="")
    init_parser.add_argument("--title", required=True)
    init_parser.add_argument("--working-dir", required=True)
    init_parser.add_argument("--dispatcher-agent", required=True)
    init_parser.add_argument("--control-repo", required=True)
    init_parser.add_argument("--target-repo", required=True)
    init_parser.set_defaults(func=command_init)

    event_parser = subparsers.add_parser("append-event")
    event_parser.add_argument("--report-dir", required=True)
    event_parser.add_argument("--agent-name", required=True)
    event_parser.add_argument("--agent-role", required=True)
    event_parser.add_argument("--event-type", required=True)
    event_parser.add_argument("--summary", required=True)
    event_parser.add_argument("--status")
    event_parser.add_argument("--files-considered", action="append")
    event_parser.add_argument("--files-changed", action="append")
    event_parser.add_argument("--checks-run", action="append")
    event_parser.add_argument("--refs", action="append")
    event_parser.set_defaults(func=command_append_event)

    decision_parser = subparsers.add_parser("append-decision")
    decision_parser.add_argument("--report-dir", required=True)
    decision_parser.add_argument("--agent-name", required=True)
    decision_parser.add_argument("--decision", required=True)
    decision_parser.add_argument("--reason", required=True)
    decision_parser.add_argument("--impact")
    decision_parser.set_defaults(func=command_append_decision)

    summary_parser = subparsers.add_parser("update-summary")
    summary_parser.add_argument("--report-dir", required=True)
    summary_parser.add_argument("--task-uid")
    summary_parser.add_argument("--task-id")
    summary_parser.add_argument("--owner")
    summary_parser.add_argument("--status")
    summary_parser.add_argument("--headline")
    summary_parser.add_argument("--current-focus")
    summary_parser.add_argument("--last-event-seq", type=int)
    summary_parser.add_argument("--files-changed", action="append")
    summary_parser.add_argument("--checks-run", action="append")
    summary_parser.add_argument("--open-questions", action="append")
    summary_parser.add_argument("--follow-ups", action="append")
    summary_parser.set_defaults(func=command_update_summary)

    context_parser = subparsers.add_parser("update-context")
    context_parser.add_argument("--report-dir", required=True)
    context_parser.add_argument("--session-id")
    context_parser.add_argument("--used-tokens", required=True, type=int)
    context_parser.add_argument("--context-window", required=True, type=int)
    context_parser.add_argument("--remaining-tokens", required=True, type=int)
    context_parser.add_argument("--used-pct", required=True, type=float)
    context_parser.add_argument("--soft-threshold-pct", required=True, type=float)
    context_parser.add_argument("--threshold-pct", required=True, type=float)
    context_parser.add_argument("--handoff-requested", action="store_true")
    context_parser.add_argument("--reason")
    context_parser.set_defaults(func=command_update_context)

    read_events = subparsers.add_parser("read-events")
    read_events.add_argument("--report-dir", required=True)
    read_events.add_argument("--after-seq", type=int, default=0)
    read_events.add_argument("--limit", type=int)
    read_events.set_defaults(func=lambda args: command_read_ndjson(args, "conversation"))

    read_decisions = subparsers.add_parser("read-decisions")
    read_decisions.add_argument("--report-dir", required=True)
    read_decisions.add_argument("--after-seq", type=int, default=0)
    read_decisions.add_argument("--limit", type=int)
    read_decisions.set_defaults(func=lambda args: command_read_ndjson(args, "decisions"))

    read_summary = subparsers.add_parser("read-summary")
    read_summary.add_argument("--report-dir", required=True)
    read_summary.set_defaults(func=command_read_summary)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
