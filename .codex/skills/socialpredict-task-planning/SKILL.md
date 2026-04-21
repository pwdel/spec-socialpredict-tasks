---
name: socialpredict-task-planning
description: Create or revise `TASKS.json` using the repo's uid-first task workflow, persistent registry under `lib/`, and existing task-registry tooling. Use when turning design artifacts into runnable task queues or when maintaining active task backlog state in this repo.
---

# SocialPredict Task Planning

## Workflow

1. Read `TASKS.example.json` to confirm the active queue shape before editing `TASKS.json`.
2. Read `lib/README.md` and inspect `lib/task-registry.json` or relevant `lib/task-archives/*.json` entries to understand prior task history, naming patterns, and archived display IDs.
3. Treat `uid` as canonical and `id` as human-facing only.
4. When creating new tasks, use `scripts/task-registry.py mint --registry lib/task-registry.json --tasks TASKS.json ...` to mint collision-safe identities before writing them into `TASKS.json`.
5. When planning from a design artifact, preserve the design intent but translate it into small, concrete, testable, reversible tasks rather than rewriting the architecture.
6. Keep `depends_on` references uid-first. If a human-facing display ID appears in source notes, normalize it to a UID before finalizing `TASKS.json`.
7. Use `scripts/task-registry.py validate --tasks TASKS.json` before concluding whenever the task file changes materially.

## Planning Rules

- Prefer small vertical slices over large horizontal bucket tasks.
- Sequence work to generate feedback early and preserve optionality.
- Put enabling cleanup or preparatory refactors ahead of dependent feature work when they materially reduce risk.
- Keep prompts concrete and execution-ready. Avoid vague subsystem-level tasks.
- Make dependencies explicit and minimal.
- Use notes for guardrails, migration cautions, and scope locks that the runner should preserve.
- Do not reuse archived task UIDs.
- Do not treat `id` collisions as primary risk. The UID registry is the collision boundary that matters most.

## TASKS.json Contract

Top-level fields:
- `version`
- `project`
- `task_registry`
- `task_archives`
- `tasks`

Each task should include:
- `uid`
- `id`
- `title`
- `status`
- `prompt`
- `acceptance_criteria`
- `verification`
- `out_of_scope`
- `touched_paths`
- `working_dir`
- `depends_on`
- `attempts`
- `max_attempts`
- `sandbox`
- `approval`
- `profile`
- `notes`

## Repo State Sources

- `TASKS.json`: active runnable queue.
- `TASKS.example.json`: compact schema example.
- `lib/task-registry.json`: persistent uid-first registry and historical display-ID lookup.
- `lib/task-archives/*.json`: archived queues and prior task phrasing.
- `scripts/task-registry.py`: validate, mint, lookup, archive, and rebuild workflow.

## Output Expectations

- If asked to update the runnable backlog, edit `TASKS.json` directly.
- If asked to sketch work before editing the queue, produce a plan that can be translated directly into `TASKS.json` entries.
- Whenever possible, explain task order in terms of feedback, reversibility, preparatory refactoring, and risk reduction.
