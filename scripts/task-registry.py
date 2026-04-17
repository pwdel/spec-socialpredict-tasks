#!/usr/bin/env python3
"""Maintain UID-first task archives and registry state."""

from __future__ import annotations

import argparse
import copy
import json
import sys
import uuid
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise SystemExit(f"expected JSON object in {path}")
    return data


def save_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)
        handle.write("\n")


def new_registry() -> dict[str, Any]:
    return {
        "version": 2,
        "updated_at": utc_now_iso(),
        "archives": [],
        "uids": {},
        "task_ids": {},
    }


def resolve_registry_path(
    tasks_path: Path, args_registry: str | None, tasks_doc: dict[str, Any]
) -> Path | None:
    candidate = (
        args_registry
        or tasks_doc.get("task_registry")
        or tasks_doc.get("task_id_registry")
    )
    if not candidate:
        return None
    path = Path(candidate)
    if path.is_absolute():
        return path
    return (tasks_path.parent / path).resolve()


def load_registry(path: Path | None) -> tuple[Path | None, dict[str, Any]]:
    if path is None:
        return None, new_registry()
    if not path.exists():
        return path, new_registry()

    data = load_json(path)
    if data.get("version") == 2:
        archives = data.get("archives")
        uids = data.get("uids")
        task_ids = data.get("task_ids")
        if not isinstance(archives, list) or not isinstance(uids, dict) or not isinstance(task_ids, dict):
            raise SystemExit(f"invalid registry schema in {path}")
        return path, data

    # Legacy v1 registry support. Old entries cannot remain authoritative in a
    # UID-first world, so rebuild callers should regenerate from archives.
    legacy = new_registry()
    legacy["archives"] = data.get("archives", []) if isinstance(data.get("archives"), list) else []
    return path, legacy


def ensure_display_id(task: dict[str, Any]) -> str:
    value = task.get("id", "")
    if value is None:
        return ""
    if not isinstance(value, str):
        raise SystemExit("task id must be a string when present")
    return value.strip()


def ensure_uid(task: dict[str, Any], *, generate_missing: bool) -> str:
    value = task.get("uid")
    if value in (None, ""):
        if generate_missing:
            value = str(uuid.uuid7())
            task["uid"] = value
        else:
            raise SystemExit(f"task {task.get('id', '<unnamed>')} is missing required uid")
    if not isinstance(value, str) or not value.strip():
        raise SystemExit("task uid must be a non-empty string")
    return value.strip()


def normalize_depends_on(
    task: dict[str, Any],
    *,
    uid_set: set[str],
    id_to_uid: dict[str, str],
    ambiguous_ids: set[str],
) -> None:
    deps = task.get("depends_on", []) or []
    if not isinstance(deps, list):
        raise SystemExit(f"task {task.get('uid', '')} has non-list depends_on")
    normalized: list[str] = []
    for dep in deps:
        if not isinstance(dep, str) or not dep.strip():
            raise SystemExit(f"task {task.get('uid', '')} has invalid dependency entry")
        candidate = dep.strip()
        if candidate in uid_set:
            normalized.append(candidate)
            continue
        if candidate in ambiguous_ids:
            raise SystemExit(
                f"task {task.get('uid', '')} depends_on ambiguous display id: {candidate}"
            )
        if candidate in id_to_uid:
            normalized.append(id_to_uid[candidate])
            continue
        raise SystemExit(
            f"task {task.get('uid', '')} depends_on unknown task reference: {candidate}"
        )
    task["depends_on"] = normalized


def normalize_tasks_uid_first(
    tasks: list[dict[str, Any]], *, generate_missing_uids: bool
) -> list[dict[str, Any]]:
    normalized = [copy.deepcopy(task) for task in tasks]
    uid_counts: Counter[str] = Counter()
    id_to_uid: dict[str, str] = {}
    ambiguous_ids: set[str] = set()

    for task in normalized:
        uid = ensure_uid(task, generate_missing=generate_missing_uids)
        uid_counts[uid] += 1
        display_id = ensure_display_id(task)
        if display_id:
            if display_id in id_to_uid and id_to_uid[display_id] != uid:
                ambiguous_ids.add(display_id)
                id_to_uid.pop(display_id, None)
            elif display_id not in ambiguous_ids:
                id_to_uid[display_id] = uid

    duplicates = sorted(uid for uid, count in uid_counts.items() if count > 1)
    if duplicates:
        raise SystemExit(f"duplicate task uids in task set: {', '.join(duplicates)}")

    uid_set = set(uid_counts)
    for task in normalized:
        normalize_depends_on(
            task,
            uid_set=uid_set,
            id_to_uid=id_to_uid,
            ambiguous_ids=ambiguous_ids,
        )
    return normalized


def validate_active_tasks(
    tasks_path: Path, tasks_doc: dict[str, Any], registry_path: Path | None
) -> int:
    tasks = tasks_doc.get("tasks", [])
    if not isinstance(tasks, list):
        raise SystemExit(f"invalid tasks list in {tasks_path}")

    normalized = normalize_tasks_uid_first(tasks, generate_missing_uids=False)
    local_uids = {task["uid"] for task in normalized}
    _, registry = load_registry(registry_path)
    registry_uids = registry.get("uids", {})
    collisions = sorted(uid for uid in local_uids if uid in registry_uids)
    if collisions:
        registry_label = str(registry_path) if registry_path is not None else "registry"
        raise SystemExit(
            f"task uids already present in {registry_label}: {', '.join(collisions)}"
        )

    id_counts = Counter(ensure_display_id(task) for task in normalized if ensure_display_id(task))
    duplicate_ids = sorted(display_id for display_id, count in id_counts.items() if count > 1)
    if duplicate_ids:
        print(
            "WARNING: duplicate display ids in active queue: " + ", ".join(duplicate_ids),
            file=sys.stderr,
        )

    print(
        f"PASS: validated {len(normalized)} task uids in {tasks_path}"
        + (f" against {registry_path}" if registry_path is not None else "")
    )
    return 0


def register_archive(
    registry: dict[str, Any],
    archive_doc: dict[str, Any],
    *,
    archive_rel: str,
) -> None:
    archive_key = archive_doc.get("archive_key") or Path(archive_rel).stem
    project = archive_doc.get("project")
    archived_at = archive_doc.get("archived_at") or utc_now_iso()
    tasks = archive_doc.get("tasks", [])
    if not isinstance(tasks, list):
        raise SystemExit(f"archive {archive_rel} has invalid tasks list")

    archives = registry.setdefault("archives", [])
    archives = [entry for entry in archives if entry.get("key") != archive_key]
    archives.append(
        {
            "key": archive_key,
            "project": project,
            "file": archive_rel,
            "task_count": len(tasks),
            "archived_at": archived_at,
        }
    )
    registry["archives"] = sorted(archives, key=lambda item: item.get("archived_at", ""))

    uid_index = registry.setdefault("uids", {})
    id_index: defaultdict[str, list[dict[str, Any]]] = defaultdict(list)
    for display_id, entries in (registry.get("task_ids") or {}).items():
        if isinstance(entries, list):
            id_index[display_id].extend(entries)

    for task in tasks:
        uid = ensure_uid(task, generate_missing=False)
        display_id = ensure_display_id(task)
        uid_index[uid] = {
            "id": display_id or None,
            "project": project,
            "title": task.get("title"),
            "status": task.get("status"),
            "archive_key": archive_key,
            "archive_file": archive_rel,
            "archived_at": archived_at,
            "finished_at": task.get("finished_at"),
        }
        if display_id:
            id_index[display_id] = [
                entry for entry in id_index[display_id] if entry.get("uid") != uid
            ]
            id_index[display_id].append(
                {
                    "uid": uid,
                    "project": project,
                    "title": task.get("title"),
                    "status": task.get("status"),
                    "archive_key": archive_key,
                    "archive_file": archive_rel,
                    "archived_at": archived_at,
                }
            )

    registry["task_ids"] = {
        display_id: sorted(entries, key=lambda item: item.get("archived_at", ""))
        for display_id, entries in sorted(id_index.items())
    }
    registry["updated_at"] = utc_now_iso()
    registry["version"] = 2


def rewrite_archive_uid_first(archive_path: Path) -> dict[str, Any]:
    archive_doc = load_json(archive_path)
    tasks = archive_doc.get("tasks", [])
    if not isinstance(tasks, list):
        raise SystemExit(f"archive {archive_path} has invalid tasks list")

    normalized_tasks = normalize_tasks_uid_first(tasks, generate_missing_uids=True)
    archive_doc["version"] = 2
    archive_doc["identity_primary"] = "uid"
    archive_doc["task_count"] = len(normalized_tasks)
    archive_doc["tasks"] = normalized_tasks
    save_json(archive_path, archive_doc)
    return archive_doc


def command_validate(args: argparse.Namespace) -> int:
    tasks_path = Path(args.tasks).resolve()
    tasks_doc = load_json(tasks_path)
    registry_path = resolve_registry_path(tasks_path, args.registry, tasks_doc)
    return validate_active_tasks(tasks_path, tasks_doc, registry_path)


def command_archive(args: argparse.Namespace) -> int:
    tasks_path = Path(args.tasks).resolve()
    archive_path = Path(args.archive).resolve()
    registry_path = Path(args.registry).resolve()
    tasks_doc = load_json(tasks_path)
    tasks = tasks_doc.get("tasks", [])
    if not isinstance(tasks, list):
        raise SystemExit(f"invalid tasks list in {tasks_path}")
    if not tasks:
        raise SystemExit(f"no tasks to archive in {tasks_path}")

    normalized_tasks = normalize_tasks_uid_first(tasks, generate_missing_uids=True)

    if not args.allow_incomplete:
        incomplete = sorted(task.get("uid", "") for task in normalized_tasks if task.get("status") != "done")
        if incomplete:
            raise SystemExit(
                "refusing to archive incomplete tasks without --allow-incomplete: "
                + ", ".join(incomplete)
            )

    _, registry = load_registry(registry_path)
    registry_uids = registry.setdefault("uids", {})
    collisions = sorted(task["uid"] for task in normalized_tasks if task["uid"] in registry_uids)
    if collisions:
        raise SystemExit(
            "refusing to archive task uids already present in registry: "
            + ", ".join(collisions)
        )

    archived_at = utc_now_iso()
    project = tasks_doc.get("project")
    archive_key = args.archive_key or project or archive_path.stem
    archive_doc = {
        "version": 2,
        "identity_primary": "uid",
        "archive_key": archive_key,
        "project": project,
        "archived_at": archived_at,
        "source_tasks_file": tasks_path.name,
        "task_count": len(normalized_tasks),
        "tasks": normalized_tasks,
    }
    save_json(archive_path, archive_doc)

    archive_rel = archive_path.relative_to(tasks_path.parent).as_posix()
    register_archive(registry, archive_doc, archive_rel=archive_rel)
    save_json(registry_path, registry)

    if args.reset_tasks:
        task_archives = tasks_doc.get("task_archives", [])
        if not isinstance(task_archives, list):
            task_archives = []
        if archive_rel not in task_archives:
            task_archives.append(archive_rel)
        reset_doc = {
            "version": tasks_doc.get("version", 1),
            "project": args.new_project or "socialpredict",
            "task_registry": registry_path.relative_to(tasks_path.parent).as_posix(),
            "task_archives": task_archives,
            "tasks": [],
        }
        save_json(tasks_path, reset_doc)

    print(
        f"Archived {len(normalized_tasks)} tasks from {tasks_path} to {archive_path} "
        f"and updated {registry_path}"
    )
    return 0


def command_rebuild(args: argparse.Namespace) -> int:
    registry_path = Path(args.registry).resolve()
    registry = new_registry()
    archive_paths = [Path(value).resolve() for value in args.archive]
    repo_root_hint = registry_path.parent.parent
    for archive_path in archive_paths:
        archive_doc = rewrite_archive_uid_first(archive_path)
        try:
            archive_rel = archive_path.relative_to(repo_root_hint).as_posix()
        except ValueError:
            archive_rel = str(archive_path)
        register_archive(registry, archive_doc, archive_rel=archive_rel)
    save_json(registry_path, registry)
    print(
        f"Rebuilt {registry_path} from {len(archive_paths)} archive(s)"
    )
    return 0


def next_display_ids(
    *,
    used_ids: set[str],
    prefix: str,
    count: int,
    start: int,
    width: int,
) -> list[str]:
    minted: list[str] = []
    current = start
    while len(minted) < count:
        candidate = f"{prefix}-{current:0{width}d}"
        current += 1
        if candidate in used_ids:
            continue
        minted.append(candidate)
        used_ids.add(candidate)
    return minted


def load_tasks_for_mint(path_value: str | None) -> list[dict[str, Any]]:
    if not path_value:
        return []
    path = Path(path_value).resolve()
    doc = load_json(path)
    tasks = doc.get("tasks", [])
    if not isinstance(tasks, list):
        raise SystemExit(f"invalid tasks list in {path}")
    return normalize_tasks_uid_first(tasks, generate_missing_uids=False)


def command_mint(args: argparse.Namespace) -> int:
    registry_path = Path(args.registry).resolve()
    _, registry = load_registry(registry_path)
    active_tasks = load_tasks_for_mint(args.tasks)

    used_uids = set(registry.get("uids", {}).keys())
    used_uids.update(task["uid"] for task in active_tasks)

    used_ids = set(registry.get("task_ids", {}).keys())
    used_ids.update(
        ensure_display_id(task) for task in active_tasks if ensure_display_id(task)
    )

    minted_uids: list[str] = []
    while len(minted_uids) < args.count:
        candidate = str(uuid.uuid7())
        if candidate in used_uids:
            continue
        minted_uids.append(candidate)
        used_uids.add(candidate)

    display_ids: list[str] = []
    if args.id_prefix:
        display_ids = next_display_ids(
            used_ids=used_ids,
            prefix=args.id_prefix,
            count=args.count,
            start=args.start,
            width=args.width,
        )

    payload = []
    for index, uid in enumerate(minted_uids):
        row: dict[str, Any] = {"uid": uid}
        if display_ids:
            row["id"] = display_ids[index]
        payload.append(row)
    print(json.dumps(payload, indent=2))
    return 0


def command_lookup(args: argparse.Namespace) -> int:
    registry_path = Path(args.registry).resolve()
    _, registry = load_registry(registry_path)
    if args.uid:
        match = registry.get("uids", {}).get(args.uid)
        print(json.dumps(match or {}, indent=2))
        return 0 if match else 1
    if args.id:
        match = registry.get("task_ids", {}).get(args.id)
        print(json.dumps(match or [], indent=2))
        return 0 if match else 1
    raise SystemExit("lookup requires --uid or --id")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Maintain UID-first task registry state.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    validate = subparsers.add_parser("validate", help="Validate active task UIDs.")
    validate.add_argument("--tasks", required=True, help="Path to TASKS.json")
    validate.add_argument(
        "--registry",
        help="Override the task registry path. Defaults to TASKS.json task_registry.",
    )
    validate.set_defaults(func=command_validate)

    archive = subparsers.add_parser("archive", help="Archive a completed task queue.")
    archive.add_argument("--tasks", required=True, help="Path to TASKS.json")
    archive.add_argument("--archive", required=True, help="Archive output JSON path")
    archive.add_argument("--registry", required=True, help="Registry JSON path")
    archive.add_argument("--archive-key", help="Stable archive key.")
    archive.add_argument("--new-project", help="Project value for reset TASKS.json.")
    archive.add_argument(
        "--allow-incomplete",
        action="store_true",
        help="Allow archiving tasks whose status is not done.",
    )
    archive.add_argument(
        "--reset-tasks",
        action="store_true",
        help="Rewrite TASKS.json to an empty active queue after archiving.",
    )
    archive.set_defaults(func=command_archive)

    rebuild = subparsers.add_parser(
        "rebuild", help="Rewrite archives UID-first and rebuild the registry."
    )
    rebuild.add_argument("--registry", required=True, help="Registry JSON path")
    rebuild.add_argument(
        "--archive",
        required=True,
        action="append",
        help="Archive JSON path. Repeat for multiple archives.",
    )
    rebuild.set_defaults(func=command_rebuild)

    mint = subparsers.add_parser(
        "mint", help="Mint new UID/display-id pairs without mutating the registry."
    )
    mint.add_argument("--registry", required=True, help="Registry JSON path")
    mint.add_argument("--tasks", help="Optional TASKS.json to avoid active collisions")
    mint.add_argument("--count", type=int, default=1, help="How many identities to mint")
    mint.add_argument("--id-prefix", help="Optional display-id prefix, e.g. SP")
    mint.add_argument("--start", type=int, default=1, help="Starting numeric suffix")
    mint.add_argument("--width", type=int, default=3, help="Display-id zero-pad width")
    mint.set_defaults(func=command_mint)

    lookup = subparsers.add_parser("lookup", help="Lookup archived tasks by uid or id.")
    lookup.add_argument("--registry", required=True, help="Registry JSON path")
    lookup.add_argument("--uid")
    lookup.add_argument("--id")
    lookup.set_defaults(func=command_lookup)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
