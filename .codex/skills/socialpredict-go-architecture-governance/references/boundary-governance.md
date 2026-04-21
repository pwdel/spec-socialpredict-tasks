# SocialPredict Backend Boundary Governance

## Enforceable Rules (Current Execution Scope)

1. Handlers and `internal/service/auth` must call domain services/facades, not concrete repositories.
2. Domain packages (`backend/internal/domain/**`) must not import `backend/internal/repository/**` directly.
3. Repository packages must not import handlers.
4. Composition-root wiring belongs in `backend/server/server.go` and container/bootstrap code.

## Approved Legacy Exceptions (Do Not Expand)

- `backend/handlers/admin/adduser.go`
- `backend/handlers/stats/statshandler.go`
- `backend/internal/service/auth/loggin.go`
- `backend/handlers/cms/homepage/repo.go`
- `backend/server/server.go`

Policy: no new files may be added to this exception list.

## Escalate Immediately

- New cross-domain coupling that bypasses service interfaces.
- Any handler/auth direct DB use outside the exception list.
- Required change outside backend/API scope.

## Future-State Design Context (No Infra Changes Now)

Maintain boundaries so domains can become independently deployable services with their own readiness, configuration, and observability behavior in a later Kubernetes rollout phase.
