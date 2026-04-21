---
name: socialpredict-go-code-quality-guardrails
description: Apply Go quality guardrails for SocialPredict backend/API work. Use when touching backend Go files to enforce formatting, vet hygiene, and backend boundary-safe coding practices before review or verifier handoff.
---

# SocialPredict Go Code Quality Guardrails

## Workflow

1. Confirm changed paths stay in backend/API scope.
2. Read `references/code-quality-checklist.md` for required quality gates.
3. Run `scripts/run_quality_guardrails.sh [repo-dir] [base-ref]`.
4. Resolve all blocking findings before handoff.
5. Include command output and touched-file list in the verification notes.

## Current Execution Scope

- Apply quality checks to backend/API files changed in the current task wave.
- Enforce `gofmt` and `go vet` as non-optional gates.
- Avoid broad stylistic refactors unrelated to the current change set.

## Future-State Kubernetes Design Context (Guidance Only)

- Preserve configuration hygiene and observability-friendly error handling for eventual service extraction.
- Keep code changes diagnosable under distributed service operation.
- Maintain quality standards that support future independent service rollout.

## Resources

- `references/code-quality-checklist.md`: required gates and escalation criteria.
- `scripts/run_quality_guardrails.sh`: changed-file gofmt, go vet, and boundary hygiene checks.
- Companion tool skills for deeper or tool-specific passes:
  - `socialpredict-go-gofmt`
  - `socialpredict-go-vet`
  - `socialpredict-go-staticcheck`
  - `socialpredict-go-golangci-lint`
  - `socialpredict-go-cyclomatic-complexity`
