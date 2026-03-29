# Workspace Purpose and Layout

## Purpose

This workspace exists as the control repo to operate and audit the SocialPredict PR #581 execution model:

- keep branch lineage anchored to PR #581 head SHA `94231f1d5f49c564d1a99c0135456d92101ed8f0`
- enforce scope lock and backend/API governance rules
- maintain reproducible verification for guardrails, skills, and task status

## Layout

```text
.
├── README.md                         # control-repo navigation entrypoint
├── .codex/                           # control-repo skills/hooks/config assets
│   └── skills/
├── README/                           # control-repo operator docs
│   ├── WORKSPACE.md
│   ├── VERIFICATION.md
│   ├── AGENTS.md
│   └── SKILLS-HOOKS.md
└── (sibling) ../socialpredict/       # target repo checkout for PR #581 code work
```

Repository responsibilities:

- control repo: task orchestration, docs, skills, and workspace governance.
- target repo: source changes, branch lineage, backend/API guardrails.

Useful references:

- `../socialpredict/backend/README/BACKEND/GUARDRAILS.md`
- `.codex/skills/*`
- `../socialpredict/README/PRODUCTION-NOTES/README.md`

## Execution Boundaries

Current execution boundary (active now):

- backend/API scope verification and governance only
- no frontend/UI changes
- no infrastructure rollout (Kubernetes/deployment work stays deferred)

Future expansion (not active in this workspace run):

- broader service extraction beyond PR #581
- infra rollout and runtime deployment automation
- cross-repo operational standardization

## Baseline Checks

Run these from workspace root to confirm expected baseline:

```bash
git -C ../socialpredict branch --show-current
git -C ../socialpredict rev-parse HEAD
git -C ../socialpredict ls-remote https://github.com/openpredictionmarkets/socialpredict.git refs/pull/581/head
```
