# SocialPredict API Contract Policy

## Contract Drift Controls (Current Execution Scope)

1. Any route wiring change in `backend/server/server.go` must be reflected in `backend/docs/openapi.yaml`.
2. Any handler response/request shape change must update the OpenAPI schema and examples.
3. Any auth/middleware behavior change affecting endpoint access or error codes must be documented in the contract artifacts.
4. OpenAPI validation tests must pass after every contract-relevant change.

## Minimal Delta Log Template

| Endpoint | Change Type | Backward Compatibility | OpenAPI Updated | Notes |
| --- | --- | --- | --- | --- |

## Future-State Design Context (No Deployment Work in This Task)

Contract-first behavior now reduces risk when backend domains become independently deployable Kubernetes services later.
