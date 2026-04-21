#!/usr/bin/env python3
"""Render codex-runner prompt templates from task metadata."""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


PLACEHOLDER_RE = re.compile(r"\{\{([A-Z0-9_]+)\}\}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Render codex-runner prompt templates from task JSON read on stdin."
    )
    subparsers = parser.add_subparsers(dest="mode", required=True)

    initial = subparsers.add_parser(
        "initial", help="Render the initial task-execution prompt."
    )
    add_common_args(initial)
    initial.add_argument("--repo-root", required=True)
    initial.add_argument("--dispatcher", required=True)
    initial.add_argument("--report-dir", required=True)
    initial.add_argument("--meta-file", required=True)
    initial.add_argument("--summary-file", required=True)
    initial.add_argument("--conversation-file", required=True)
    initial.add_argument("--decisions-file", required=True)
    initial.add_argument("--helper-script", required=True)

    resume = subparsers.add_parser(
        "resume", help="Render the checkpoint-resume prompt."
    )
    add_common_args(resume)
    resume.add_argument("--report-dir", required=True)
    resume.add_argument("--summary-file", required=True)
    resume.add_argument("--conversation-file", required=True)
    resume.add_argument("--decisions-file", required=True)
    resume.add_argument("--helper-script", required=True)

    return parser


def add_common_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--template", required=True)


def load_task_from_stdin() -> dict:
    raw = sys.stdin.read()
    if not raw.strip():
        raise SystemExit("task JSON is required on stdin")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise SystemExit(f"invalid task JSON on stdin: {exc}") from exc
    if not isinstance(data, dict):
        raise SystemExit("task JSON must decode to an object")
    return data


def render_template(template_path: Path, replacements: dict[str, str]) -> str:
    text = template_path.read_text(encoding="utf-8")
    for key, value in replacements.items():
        text = text.replace(f"{{{{{key}}}}}", value)

    unresolved = sorted(set(PLACEHOLDER_RE.findall(text)))
    if unresolved:
        unresolved_list = ", ".join(unresolved)
        raise SystemExit(
            f"unresolved placeholders in {template_path}: {unresolved_list}"
        )
    return text


def task_json_block(task: dict) -> str:
    return json.dumps(task, indent=2, sort_keys=True)


def checkpoint_json_block(task: dict) -> str:
    runner_state = task.get("runner_state") or {}
    checkpoint = runner_state.get("last_context_checkpoint") or {}
    return json.dumps(checkpoint, indent=2, sort_keys=True)


def build_initial_replacements(args: argparse.Namespace, task: dict) -> dict[str, str]:
    return {
        "REPO_ROOT": args.repo_root,
        "DISPATCHER_AGENT": args.dispatcher,
        "REPORT_DIR": args.report_dir,
        "META_FILE": args.meta_file,
        "SUMMARY_FILE": args.summary_file,
        "CONVERSATION_FILE": args.conversation_file,
        "DECISIONS_FILE": args.decisions_file,
        "HELPER_SCRIPT": args.helper_script,
        "TASK_METADATA_JSON": task_json_block(task),
    }


def build_resume_replacements(args: argparse.Namespace, task: dict) -> dict[str, str]:
    task_uid = str(task.get("uid", ""))
    task_id = str(task.get("id", ""))
    task_ref = task_uid
    if task_id:
        task_ref = f"{task_id} ({task_uid})"
    return {
        "TASK_UID": task_uid,
        "TASK_ID": task_id,
        "TASK_REF": task_ref,
        "REPORT_DIR": args.report_dir,
        "SUMMARY_FILE": args.summary_file,
        "CONVERSATION_FILE": args.conversation_file,
        "DECISIONS_FILE": args.decisions_file,
        "HELPER_SCRIPT": args.helper_script,
        "CHECKPOINT_JSON": checkpoint_json_block(task),
        "TASK_METADATA_JSON": task_json_block(task),
    }


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    task = load_task_from_stdin()
    template_path = Path(args.template)

    if args.mode == "initial":
        replacements = build_initial_replacements(args, task)
    else:
        replacements = build_resume_replacements(args, task)

    sys.stdout.write(render_template(template_path, replacements))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
