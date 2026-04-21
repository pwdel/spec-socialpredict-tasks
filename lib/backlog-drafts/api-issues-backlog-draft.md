# API Platform Wave Roadmap

This roadmap started from `../socialpredict/backend/docs/API-ISSUES.md`, but the
current read of the codebase shows that the API/auth/docs issues are not the
true phase-1 work. They sit behind two platform prerequisites:

- `backend/setup` is still a global package instead of a service-backed slice
  wired through the internal application structure.
- the internal domain/math layer is still widely coupled to the legacy
  `socialpredict/models` package.

Because of that, the practical sequencing is:

- WAVE01: `util` breakup into proper infrastructure/bootstrap and domain-owned boundaries
- WAVE02: configuration service extraction and consumer migration
- WAVE03: remaining legacy model/domain decoupling
- WAVE04: API/auth/OpenAPI/API-ISSUES alignment

## Inputs Reviewed

- `../socialpredict/backend/docs/API-ISSUES.md`
- `../socialpredict/backend/docs/openapi.yaml`
- `../socialpredict/backend/server/server.go`
- `../socialpredict/backend/internal/service/auth/auth.go`
- `../socialpredict/backend/internal/service/auth/auth_service.go`
- `../socialpredict/backend/internal/service/auth/loggin.go`
- `../socialpredict/backend/handlers/users/changepassword.go`
- `../socialpredict/backend/setup/setup.go`
- `../socialpredict/backend/handlers/setup/setuphandler.go`
- archived tasks in `lib/task-archives/socialpredict-pr-581-service-boundary-refactor.json`

## Architectural Read

### What the archived work already completed

- The prior task wave already completed the main handler-to-domain-to-repository
  migration baseline for markets, users, bets, math, analytics, and auth.
- The archived work also completed large SRP/OCP/ISP/DIP passes inside the
  internal domain packages.
- That means the next platform work should not restart the architecture program
  from zero. It should finish the obvious remaining slices that were left
  outside the internal service/domain boundary model.

### What is still structurally unfinished

- `backend/util` is still a mixed package containing DB bootstrap/global DB
  access, dotenv loading, API key generation, and user/model-specific helper
  logic that belong to different layers.
- `backend/setup/setup.go` is still a global singleton package with embedded
  YAML, global accessors, and direct consumers across server startup, handlers,
  seed, and internal packages.
- `backend/handlers/setup/setuphandler.go` is still a function-wrapper around
  direct config loading rather than a service-backed slice.
- The remaining direct `setup` coupling is large enough to justify its own
  wave: `20` files across `internal`, `handlers`, `server`, and `seed` still
  import `socialpredict/setup`.
- The remaining direct legacy-model coupling is also large enough to justify
  its own wave: `44` files under `backend/internal/**` still import
  `socialpredict/models`.
- The remaining `util` coupling is smaller in raw count but high-impact because
  it hides global runtime boundaries (`GetDB`, env loading, bootstrap) and also
  contains user-specific helper logic that should not live in a generic
  package.

### Why the API backlog moves to WAVE04

- The current API/auth/OpenAPI work assumes a cleaner application boundary than
  the code actually has.
- Stats already mixes config loading, DB access, and response writing in one
  handler.
- Auth/login still mixes direct model access with contract shaping.
- OpenAPI alignment should follow the prerequisite platform changes, not freeze
  the contract too early around unfinished internals.

## Locked Product Decisions

- WAVE04 should pursue the `{ ok, result, reason }` response envelope.
- WAVE02 should make configuration look and behave like the other internal
  service-backed slices as closely as practical, because the long-term goal is
  extraction-ready services that can later live in their own containers.
- Prefer moving touched callers directly onto the new internal config slice
  rather than preserving `backend/setup` as a long-lived compatibility layer.
  A very thin temporary shim is acceptable only if it materially reduces
  migration risk.
- For wave-4 operational outcomes, when the backend processes the request
  correctly, communicate success or business-rule failure through
  `{ ok, result, reason }`, and reserve transport-level 4xx/5xx for malformed,
  unauthorized, or actual server failures where practical.
- Before a required password change is completed, keep login and
  `/v0/changepassword` usable and block other authenticated user actions.
- `/v0/changepassword` should return JSON on success.
- The limited-scope/no-normal-JWT login redesign is deferred to a later task.
- When `API-ISSUES.md` and current code disagree, the implementation direction
  should follow `API-ISSUES.md` unless that conflicts with the explicitly
  deferred items above.
- Route-organization work in this program is limited to doc/tag cleanup, not
  public path migration.
- `Bets` -> `Trades` is deferred to a later scope-cleanup wave.

## Wave Plan

### WAVE01: Util Breakup

1. Split `backend/util` into proper homes:
   bootstrap/runtime env loading, DB/bootstrap wiring, and domain-owned helper
   logic.
2. Remove direct runtime dependence on `util.GetDB()` and similar hidden global
   boundaries from touched code where practical.
3. Push API key generation and user-specific uniqueness helpers toward the
   users/account boundary instead of keeping them in a generic helper package.

### WAVE02: Configuration Service Baseline

1. Extract a service-backed configuration slice from `backend/setup` into the
   internal application architecture.
2. Migrate handlers, server wiring, seed flows, and other direct config
   consumers to the new service while keeping `/v0/setup` and
   `/v0/setup/frontend` path semantics stable.

### WAVE03: Legacy Model / Domain Decoupling

1. Establish explicit boundary types and adapters so internal domain/math code
   no longer needs to treat `socialpredict/models` as its native data model.
2. Move markets, bets, and math packages off direct legacy-model usage where
   practical by pushing translation toward repositories and boundary helpers.
3. Finish the remaining internal/boundary cleanup in analytics, auth login, and
   adjacent consumers so any unavoidable legacy-model usage is isolated and
   obvious.

### WAVE04: API/Auth/OpenAPI Alignment

1. Introduce shared sanitized `{ ok, result, reason }` helpers and migrate the
   hotspot handlers called out in `API-ISSUES.md`.
2. Tighten `mustChangePassword` enforcement and normalize login/change-password
   response contracts while deferring the limited-scope-token redesign.
3. Align OpenAPI and targeted tag ownership metadata to the implemented
   wave-4 behavior.
4. Refresh `API-ISSUES.md` so it reflects the post-wave-4 code rather than a
   mixture of fixed issues, stale assumptions, and deferred redesign ideas.

## Deferred Beyond WAVE04

- Redesigning login so initial password-change users never receive a normal
  access token.
- Rewriting Users and Markets routes into a new CRUD/REST layout.
- Renaming Bets to Trades across the API surface.

## WAVE02 Stance

- Keep `backend/setup/setup.yaml` as the source configuration asset for now.
- Model configuration as a normal internal service-backed slice, consistent
  with the broader backend architecture rather than as a permanent special
  package.
- Move touched callers onto the new internal config slice directly where
  practical.
- Only retain a thin compatibility shim if it clearly helps the migration
  without becoming the new permanent runtime boundary.
