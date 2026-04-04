# SocialPredict OpenAPI Rules

## Source of Truth Order

1. `backend/server/server.go` route wiring
2. touched handlers under `backend/handlers/**`
3. touched DTOs under `backend/handlers/<service>/dto`
4. tests that lock request, response, auth, or error behavior
5. `backend/docs/openapi.yaml`
6. supporting docs such as `backend/docs/README.md` and `backend/docs/API-ISSUES.md`

If the documentation disagrees with implemented behavior, align the spec to the code unless the task explicitly changes the code too.

## Official OpenAPI Editing Rules

From `backend/docs/README.md`:

- `backend/docs/openapi.yaml` is the master monolith contract.
- Paths stay grouped by tag so service slices can later split into separate specs.
- Shared shapes live under `components/schemas`.
- DTO changes in `backend/handlers/<service>/dto` should be mirrored into `components/schemas`.
- Keep response shapes consistent with handlers.

## Hard Constraints from `backend/docs/API-ISSUES.md`

Treat these as actionable now:

- Keep the API aligned with actual backend logic above all.
- Reconstruct uncertain contract behavior from source code rather than stale documentation.
- Treat the following handlers as error-contract hotspot areas whenever their endpoints are touched:
  - `backend/handlers/stats/statshandler.go`
  - `backend/handlers/cms/homepage/http/handler.go`
  - `backend/handlers/bets/buying/buypositionhandler.go`
  - `backend/handlers/bets/selling/sellpositionhandler.go`
  - `backend/handlers/positions/positionshandler.go`
  - `backend/handlers/users/changedisplayname.go`
  - `backend/handlers/users/userpositiononmarkethandler.go`
  - `backend/handlers/users/profile_helpers.go`
- For those routes, verify whether the code returns generic strings, sanitized messages, or raw error text before writing or changing the spec.

## Explicit Non-Goals Unless Asked

Do not treat these as default contract work:

- login-flow redesign
- forcing an `ok/result/reason` envelope across the API
- broad REST route reorganization such as rewriting Users or Markets into new CRUD path schemes

Those ideas may inform future work, but they are not the default source of truth for the current spec.

## Query Helper Usage

Use the bundled script instead of reading the full YAML when you only need a slice:

```bash
.codex/skills/socialpredict-openapi-navigation/scripts/query_openapi.sh ../socialpredict summary
.codex/skills/socialpredict-openapi-navigation/scripts/query_openapi.sh ../socialpredict tag Users
.codex/skills/socialpredict-openapi-navigation/scripts/query_openapi.sh ../socialpredict operation /v0/markets post
.codex/skills/socialpredict-openapi-navigation/scripts/query_openapi.sh ../socialpredict refs ErrorResponse
```

