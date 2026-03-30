# SocialPredict Go Quality Checklist

## Blocking Gates (Current PR #581 Scope)

1. `gofmt -l` must return no files for changed backend Go files.
2. `go vet ./...` must pass in `backend/`.
3. No new direct DB usage in handlers/auth outside the approved legacy exception list.
4. Verification output must be captured with exact commands and results.

## Escalation Triggers

- `go vet` failure indicating correctness or concurrency risk.
- Newly introduced direct DB usage outside approved files.
- Required remediation that exceeds backend/API scope.

## Future-State Design Context (No Deployment Execution Here)

Bias changes toward clean configuration boundaries and diagnosable behavior so services can be split and operated in Kubernetes later without rewrites.
