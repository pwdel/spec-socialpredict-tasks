---
name: socialpredict-openapi-navigation
description: Navigate, query, and make precise edits to SocialPredict's large `backend/docs/openapi.yaml` without loading the whole file. Use when inspecting tags, paths, operations, schemas, or `$ref` usage; reconciling the spec with backend handlers and routes; or applying the hard OpenAPI constraints from `backend/docs/API-ISSUES.md` while ignoring aspirational redesign ideas.
---

# SocialPredict OpenAPI Navigation

## When to Use

- Tasks that touch `backend/docs/openapi.yaml`, `backend/openapi_embed.go`, or `backend/openapi_test.go`.
- Questions about specific tags, paths, operations, schemas, or `$ref` usage in the large OpenAPI document.
- Precision edits where the source of truth is `backend/server/server.go`, relevant handlers, DTOs, and tests.
- Reviews of contract drift or error-response mismatches in known hotspot handlers.

## Workflow

1. Read `references/openapi-rules.md`.
2. Use `scripts/query_openapi.sh [repo-dir] ...` for targeted inspection instead of loading the whole spec into context.
3. Cross-check the touched route or schema against:
   - `backend/server/server.go`
   - relevant handlers under `backend/handlers/**`
   - relevant DTOs under `backend/handlers/<service>/dto`
   - `backend/openapi_test.go`
4. Edit only the affected `paths` and `components/schemas` blocks.
5. If route or handler behavior changed, also use `socialpredict-api-contract-drift-control`.

## Query Helper

Run from the TASK repo root and point at the TARGET repo root:

```bash
.codex/skills/socialpredict-openapi-navigation/scripts/query_openapi.sh ../socialpredict summary
.codex/skills/socialpredict-openapi-navigation/scripts/query_openapi.sh ../socialpredict tags
.codex/skills/socialpredict-openapi-navigation/scripts/query_openapi.sh ../socialpredict tag Markets
.codex/skills/socialpredict-openapi-navigation/scripts/query_openapi.sh ../socialpredict path /v0/markets
.codex/skills/socialpredict-openapi-navigation/scripts/query_openapi.sh ../socialpredict operation /v0/markets post
.codex/skills/socialpredict-openapi-navigation/scripts/query_openapi.sh ../socialpredict schema ErrorResponse
.codex/skills/socialpredict-openapi-navigation/scripts/query_openapi.sh ../socialpredict refs ErrorResponse
```

## Working Rules

- Treat the implemented backend behavior as the source of truth over stale documentation.
- Keep `backend/docs/openapi.yaml` as the master monolith contract.
- Keep paths grouped by service tag.
- Keep shared response and DTO shapes under `components/schemas`.
- Mirror handler DTO changes into `components/schemas` and touched path entries.
- Ignore aspirational login redesign, response-envelope redesign, and REST route reorganization unless the task explicitly asks for them.
- When `backend/docs/API-ISSUES.md` conflicts with current code, document the actual code behavior and record the mismatch as follow-up rather than inventing future behavior in the spec.

## Resources

- `references/openapi-rules.md`: source-of-truth order, hard constraints, and current hotspot guidance.
- `scripts/query_openapi.sh`: targeted parser-backed queries for tags, paths, operations, schemas, and `$ref` usage.

