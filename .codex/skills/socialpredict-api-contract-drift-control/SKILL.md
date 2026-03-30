---
name: socialpredict-api-contract-drift-control
description: Keep SocialPredict backend route behavior and OpenAPI artifacts synchronized during PR #581 backend/API work. Use when modifying handlers, route wiring, middleware behavior, request or response shapes, or `backend/docs/openapi.yaml`.
---

# SocialPredict API Contract Drift Control

## Workflow

1. Confirm the task is backend/API scoped for PR #581 execution.
2. Read `references/api-contract-policy.md` to frame expected contract behavior.
3. Run `scripts/check_api_contract_sync.sh [repo-dir] [base-ref]`.
4. If route or handler behavior changes, require matching OpenAPI updates before merge.
5. Record endpoint and schema deltas in the task note or review output.

## Current PR Execution Scope

- Keep work in `socialpredict/backend/**` plus API contract artifacts.
- Focus on parity between implemented routes and `backend/docs/openapi.yaml`.
- Do not broaden into frontend client migration or deployment implementation.

## Future-State Kubernetes Design Context (Guidance Only)

- Treat API contracts as stable service boundaries.
- Preserve explicit error/response contracts so independent service deployments remain predictable.
- Keep auth and middleware behavior contract-documented for future split-service operation.

## Resources

- `references/api-contract-policy.md`: contract parity and drift rules.
- `scripts/check_api_contract_sync.sh`: route/OpenAPI sync checks and OpenAPI test command.
