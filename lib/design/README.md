# Design Plan Library

This directory is the canonical home for repository-level design-plan state.

- `design-plan.json`
  The active canonical design artifact used by software-designer agents and by
  downstream architecture review.
- `design-plan.schema.json`
  The contract that all generated design plans must satisfy.

Design plans belong in `lib/` instead of under `.codex/skills/` because they
are persistent workspace state, not reusable prompt logic. Skills should teach
agents how to produce and consume the plan, but the plan itself should remain a
first-class repo artifact that can be reviewed, versioned, diffed, and handed
off independently of any single agent implementation.
