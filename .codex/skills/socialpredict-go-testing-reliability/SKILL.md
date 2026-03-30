---
name: socialpredict-go-testing-reliability
description: Run deterministic Go reliability checks for SocialPredict PR #581 backend/API changes. Use when implementing or reviewing backend domain/service/repository/handler changes, diagnosing flaky test behavior, or preparing verification evidence.
---

# SocialPredict Go Testing Reliability

## Workflow

1. Keep execution limited to backend/API changes on PR #581 lineage.
2. Read `references/testing-reliability-guide.md` for deterministic test expectations.
3. Run `scripts/run_reliability_suite.sh [repo-dir] [pkg-pattern]`.
4. Repeat tests until results are deterministic or escalate as flaky-risk.
5. Log command outputs and failure triage notes in the task note.

## Current PR Execution Scope

- Prioritize service-level and integration-relevant backend tests for touched packages.
- Keep verification focused on changed backend/API behavior.
- Do not introduce unrelated test framework refactors.

## Future-State Kubernetes Design Context (Guidance Only)

- Preserve tests that remain valid when domains are extracted into separate services.
- Favor contract and integration checks that verify service boundaries, not in-process assumptions.
- Keep failure diagnostics actionable for later distributed tracing and observability workflows.

## Resources

- `references/testing-reliability-guide.md`: deterministic test policy and triage checklist.
- `scripts/run_reliability_suite.sh`: repeatable test, OpenAPI validation, and vet checks.
