# SocialPredict Testing Reliability Guide

## Deterministic Verification Policy

1. Run backend tests with `-count=1` to avoid cached pass artifacts.
2. Re-run the same suite at least twice for changed packages.
3. Treat non-reproducible failures as flaky-risk and document environment assumptions.
4. Include OpenAPI validation whenever API behavior may be affected.

## Reliability Triage Checklist

- Confirm the failing test maps to changed backend/API behavior.
- Separate deterministic code defects from environment-dependent failures.
- Note exact package, command, and failing assertion.
- Escalate unresolved flakes before marking a wave complete.

## Future-State Design Context (No Infra Rollout in This Task)

Prefer tests that remain meaningful after domain extraction to independently deployable Kubernetes services.
