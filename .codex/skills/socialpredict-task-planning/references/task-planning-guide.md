# Task Planning Guide

Use this guide when translating a design artifact into executable queue items.

## Goals

- Produce tasks that are small enough to execute safely.
- Preserve the architectural intent from the design artifact.
- Front-load learning, feedback, and risk reduction.
- Keep the active queue consistent with repo tooling and archived task history.

## Sequence Heuristics

- Start with the smallest useful end-to-end slice.
- Add preparatory refactors before dependent feature work when they clearly reduce complexity.
- Prefer reversible tasks over broad lock-in moves.
- Put uncertainty into spikes or narrow investigation tasks instead of hiding it inside a large feature task.
- Keep the system runnable between tasks where practical.

## Task Prompt Guidance

- State the concrete objective.
- Name the code areas or assets that matter when that improves execution clarity.
- Call out what must remain stable.
- Include test or verification expectations when known.
- Avoid implementation micromanagement unless the constraint is necessary to preserve architecture or scope.

## Identity Guidance

- `uid` is canonical.
- `id` is a human-facing label and may be wave-oriented or project-oriented.
- Use `scripts/task-registry.py mint` to avoid collisions with active or archived tasks.
- Use `scripts/task-registry.py lookup` when checking whether a past task already covered similar ground.

## Validation

- Validate `TASKS.json` structure and uid uniqueness before concluding.
- Check that every dependency points to a valid UID in the active task set.
- Make sure the task order matches the intended review points and stop points from the planning logic.
