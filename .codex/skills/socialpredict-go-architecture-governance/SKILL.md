---
name: socialpredict-go-architecture-governance
description: Enforce SocialPredict Go service-boundary governance for PR #581 backend/API work. Use when implementing or reviewing changes in backend handlers, domain services, repositories, auth service, or route wiring to prevent layer violations, direct DB leakage, and cross-domain coupling.
---

# SocialPredict Go Architecture Governance

## Workflow

1. Confirm scope is limited to `socialpredict/backend/**` and API contract artifacts.
2. Read `references/boundary-governance.md` before editing boundaries or wiring.
3. Run `scripts/run_boundary_checks.sh [repo-dir]`.
4. Treat any new boundary violation as a blocker and stop implementation until fixed.
5. Report command output and violating file paths in the task note or review.

## Current PR Execution Scope

- Keep execution on PR #581 lineage and backend/API-only paths.
- Block new direct DB access in handlers/auth outside the approved exception list.
- Avoid frontend work and infrastructure rollout in this execution wave.

## Future-State Kubernetes Design Context (Guidance Only)

- Keep domains extractable into independently deployable services.
- Keep concrete wiring centralized so service extraction remains straightforward.
- Preserve interface-first boundaries so health/readiness and observability evolve cleanly later.

## Resources

- `references/boundary-governance.md`: rules, exceptions, escalation expectations.
- `scripts/run_boundary_checks.sh`: deterministic boundary and import checks.
