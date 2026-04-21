# Task Library

This directory keeps persistent task history outside the active `TASKS.json`
queue.

- `design/`
  Canonical design-plan artifacts and schema shared by software-designer agents
  and downstream architecture review.
- `backlog-drafts/*.md`
  Decision-oriented backlog drafts that are not yet ready to load into the
  active runner queue.
- `task-registry.json`
  UID-first task registry plus the historical display-ID index.
- `task-archives/*.json`
  Archived task queues moved out of `TASKS.json` once they are complete.

Use `scripts/task-registry.py` to archive a completed queue and update the
registry.

To mint a fresh batch of task identities without reusing archived display IDs:

```bash
python3 scripts/task-registry.py mint \
  --registry lib/task-registry.json \
  --tasks TASKS.json \
  --count 5 \
  --id-prefix SP
```
