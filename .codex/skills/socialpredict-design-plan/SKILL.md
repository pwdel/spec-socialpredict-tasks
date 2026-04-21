---
name: socialpredict-design-plan
description: Create or refine the canonical repo-level design plan at `lib/design/design-plan.json` using the shared schema in `lib/design/design-plan.schema.json`. Use when producing architecture or design documents that must later drive task planning or architecture review.
---

# SocialPredict Design Plan

## Workflow

1. Read `lib/design/design-plan.schema.json` before drafting or revising the design plan.
2. Treat `lib/design/design-plan.json` as the canonical writable artifact.
3. Preserve the shared schema shape even when working from different design postures such as Evans, Fowler, or Martin.
4. Capture uncertainty explicitly in `open_questions`, `risks`, and `decision_log` rather than hiding it in prose.
5. Keep the plan strategic. Do not collapse directly into implementation tickets unless explicitly asked for a later task document.
6. When source material is weak or contradictory, record the gap in the plan instead of guessing past it.

## Output Contract

- The required output is `lib/design/design-plan.json`.
- The file must satisfy `lib/design/design-plan.schema.json`.
- `authors` must identify the contributing agent and its design posture.
- `decision_log` should contain durable architectural or modeling decisions, not transient implementation notes.
- `workstreams` may exist at a design level, but they should remain objective-oriented and avoid ticket decomposition.

## Canonical Location Rule

- Put design-plan state in `lib/design/`, not in `.codex/skills/` and not in ad hoc root files.
- Skills define how agents work.
- `lib/design/design-plan.json` defines the design output they share.

## Resources

- `lib/design/design-plan.schema.json`: canonical JSON Schema for the design plan.
- `lib/design/design-plan.json`: canonical writable design-plan artifact.
- `lib/design/README.md`: rationale for why the plan lives in `lib/`.
