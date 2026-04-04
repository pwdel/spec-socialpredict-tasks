# AGENTS.md

Use this file as the startup table of contents for the two-repo execution model
used in this workspace.

## Two-Repo Model

- TASK repo (`/workspace/spec-socialpredict-tasks`)
  Stable control workspace for orchestration, task state, documentation,
  guardrail payloads, and repo-local Codex assets.
- TARGET repo (`../socialpredict`)
  Sibling application checkout where Codex reads, edits, and validates code.
- Execution flow
  `codex-runner.sh` reads `TASKS.json`, launches Codex from the TASK repo, and
  Codex uses TASK repo guidance while operating on the TARGET repo.
- Current TARGET branch for structural reference
  `fix/checkpoint20251020-80`

## Current TARGET Repo Context

- Target repo root
  `../socialpredict`
- Current target focus
  `./backend/`
- Path convention below
  TARGET paths are written relative to the TARGET repo root, so `./backend/...`
  means `../socialpredict/backend/...`.
- Update rule
  When the active TARGET branch or focus area changes, refresh the TARGET map
  first. The TASK repo map below should change only when this control repo
  layout changes.

## Current TARGET Repo Map

### Backend root

- `./backend/`
  Current backend/API scope for this workspace.
- `./backend/.env.dev`
  Local development environment overrides for backend runs.
- `./backend/.gitignore`
  Backend-local ignore rules.
- `./backend/go.mod`
  Go module definition for the backend service.
- `./backend/go.sum`
  Dependency checksum lockfile for the backend module.
- `./backend/main.go`
  Backend process entrypoint that loads env, initializes DB, runs seed and
  migration startup work, and starts the server.
- `./backend/openapi_embed.go`
  Embeds the OpenAPI spec and Swagger UI assets into the backend binary.
- `./backend/openapi_test.go`
  Validates the OpenAPI document during tests.

### Backend reference docs

- `./backend/README/`
  Older backend reference subtree kept under the target repo.
- `./backend/README/BACKEND/API/API-DESIGN-REPORT.md`
  Narrative API design notes for the backend.
- `./backend/README/BACKEND/API/API-DOCS.md`
  Older API documentation notes.
- `./backend/README/BACKEND/API/openapi.yaml`
  Older OpenAPI artifact under the README tree.
- `./backend/docs/`
  Current backend API documentation directory.
- `./backend/docs/README.md`
  Explains how the current OpenAPI contract is organized and maintained.
- `./backend/docs/API-ISSUES.md`
  Known API documentation gaps or issues.
- `./backend/docs/openapi.yaml`
  Current OpenAPI contract for the backend.

### Error and transport packages

- `./backend/errors/`
  Shared backend error types used by handlers and supporting packages.
- `./backend/errors/httperror.go`
  HTTP-facing error wrapper and serialization helpers.
- `./backend/errors/httperror_test.go`
  Tests for HTTP error behavior.
- `./backend/errors/normalerror.go`
  General non-HTTP error helper type.
- `./backend/handlers/`
  Request-boundary HTTP handlers and handler-scoped helper packages.
- `./backend/handlers/admin/`
  Admin-only HTTP handlers.
- `./backend/handlers/bets/`
  Bet endpoints and supporting buy/sell/DTO helpers.
- `./backend/handlers/cms/`
  CMS/content handlers.
- `./backend/handlers/home.go`
  Home/root handler entrypoint.
- `./backend/handlers/marketpublicresponse/`
  Helpers for shaping public market API responses.
- `./backend/handlers/markets/`
  Market creation, listing, search, projection, leaderboard, and resolution
  handlers.
- `./backend/handlers/math/`
  Market and betting math helper packages used near the handler boundary.
- `./backend/handlers/metrics/`
  System metrics and leaderboard handlers.
- `./backend/handlers/positions/`
  Position lookup and response-shaping handlers.
- `./backend/handlers/setup/`
  HTTP handlers exposing setup/config values.
- `./backend/handlers/stats/`
  Stats/reporting handlers.
- `./backend/handlers/users/`
  User profile, financial, credit, and user-market handlers.

### Internal application structure

- `./backend/internal/`
  Newer internal application layers for dependency wiring, domain logic,
  repositories, and auth services.
- `./backend/internal/app/`
  Dependency container and application wiring.
- `./backend/internal/app/container.go`
  Builds repositories, services, and handler dependencies around the DB and
  economics config.
- `./backend/internal/domain/`
  Core domain logic separated from HTTP handlers.
- `./backend/internal/domain/analytics/`
  Analytics, leaderboard, positions, and system-metrics domain logic.
- `./backend/internal/domain/bets/`
  Bet placement, selling, and bet-domain policies.
- `./backend/internal/domain/markets/`
  Market creation, overview, search, projection, status, volume, and
  resolution domain logic.
- `./backend/internal/domain/math/`
  Internal math support used by domain services.
- `./backend/internal/domain/users/`
  User profile, account, and transaction domain logic.
- `./backend/internal/repository/`
  Persistence adapters for domain services.
- `./backend/internal/repository/bets/`
  Bet repository implementations and tests.
- `./backend/internal/repository/markets/`
  Market repository implementations and tests.
- `./backend/internal/repository/users/`
  User repository implementations and tests.
- `./backend/internal/service/`
  Internal service-layer helpers that do not fit the domain packages.
- `./backend/internal/service/auth/`
  Login/auth middleware and auth service logic extracted from the older
  middleware package.

### Logging, middleware, and serving

- `./backend/logger/`
  Simple logging package plus local notes and tests.
- `./backend/logger/README_SIMPLELOGGING.md`
  Notes for the simple logging package.
- `./backend/logger/simplelogging.go`
  Concrete simple logging implementation.
- `./backend/logger/simplelogging_test.go`
  Tests for the simple logging package.
- `./backend/logging/`
  Shared logging helpers and mocks.
- `./backend/logging/loggingutils.go`
  Logging helper utilities.
- `./backend/logging/mocklogging.go`
  Mock logging helpers for tests and isolated package use.
- `./backend/server/`
  HTTP server package.
- `./backend/server/server.go`
  Route wiring, middleware application, health/docs endpoints, and HTTP server
  startup.
- `./backend/server/server_test.go`
  Tests for server wiring behavior.

### Schema, models, and persistence support

- `./backend/migration/`
  Migration runner, migration registry, and migration tests.
- `./backend/migration/migrate.go`
  Migration registry and startup runner.
- `./backend/migration/migrate_test.go`
  Tests for migration registration and application behavior.
- `./backend/migration/migrations/`
  Timestamped migration files registered via package init side effects.
- `./backend/models/`
  Core data models and model-testing helpers used by the monolith and newer
  domain layers.
- `./backend/models/README.md`
  Notes for the model layer.
- `./backend/models/bets.go`
  Bet-related core data models.
- `./backend/models/bets_test.go`
  Tests for bet model behavior.
- `./backend/models/homepage.go`
  Homepage content model definitions.
- `./backend/models/market.go`
  Market-related core data models.
- `./backend/models/modelstesting/`
  Model-layer test helpers and fixtures.
- `./backend/models/user.go`
  User-related core data models.

### Security, seed, and runtime config

- `./backend/security/`
  Security helpers for headers, rate limits, sanitization, validation, and
  middleware composition.
- `./backend/security/headers.go`
  Security header helpers.
- `./backend/security/ratelimit.go`
  Rate-limiting logic.
- `./backend/security/ratelimit_test.go`
  Tests for rate-limiting behavior.
- `./backend/security/sanitizer.go`
  Input sanitization helpers.
- `./backend/security/sanitizer_test.go`
  Tests for sanitization behavior.
- `./backend/security/security.go`
  Security service and middleware composition.
- `./backend/security/security_test.go`
  Tests for security service behavior.
- `./backend/security/validator.go`
  Input validation helpers.
- `./backend/security/validator_test.go`
  Tests for validation behavior.
- `./backend/seed/`
  Seed content and startup data/bootstrap helpers.
- `./backend/seed/home.md`
  Seed markdown content for homepage initialization.
- `./backend/seed/home_embed.go`
  Embedded access to seed homepage content.
- `./backend/seed/integration_test.go`
  Integration coverage for seed/bootstrap behavior.
- `./backend/seed/seed.go`
  Seed helpers used during backend startup.
- `./backend/seed/seed_test.go`
  Tests for seed helpers.
- `./backend/setup/`
  Embedded economics/setup configuration and related test helpers.
- `./backend/setup/setup.go`
  Embedded YAML configuration loader for economics and frontend setup values.
- `./backend/setup/setup.yaml`
  Source configuration data loaded by the setup package.
- `./backend/setup/setup_test.go`
  Tests for setup/config loading behavior.
- `./backend/setup/setuptesting/`
  Setup-focused test helpers.

### Embedded docs UI and shared utilities

- `./backend/swagger-ui/`
  Static Swagger UI assets embedded into the backend binary and served by the
  server package.
- `./backend/util/`
  Cross-cutting helpers such as env loading, DB bootstrap, model checks, and
  API key utilities.
- `./backend/util/apikeys.go`
  API key helper utilities.
- `./backend/util/getenv.go`
  Environment loading helpers.
- `./backend/util/modelchecks.go`
  Shared model validation/check helpers.
- `./backend/util/postgres.go`
  PostgreSQL and DB initialization helpers.
- `./backend/util/util_test.go`
  Tests for utility-layer helpers.

This repository is the SocialPredict PR #581 TASK repo. Use the sections below
as the navigation point for the committed workspace contents.

## Scope

- Include the committed workspace layout, including repo-local `.codex/`.
- Exclude `.git/` internals and user-global `~/.codex` state.
- Prefer the files below over older narrative docs when they disagree about
  current paths.

## TASK Repo Map

### Root files

- `README.md`
  Main entrypoint for this control repo. Explains purpose, topology, quick
  start commands, and links into the `README/` docs set.

- `AGENTS.md`
  This workspace table of contents.

- `TASKS.json`
  Live machine-readable task backlog and runner state for the workspace.

- `TASKS.example.json`
  Small example showing the expected task schema.

- `TASKS.json.backup`
  Backup snapshot of the task file.

- `codex-runner.sh`
  Task runner that polls `TASKS.json`, launches Codex for ready tasks, and
  writes run artifacts under `.codex-runs/`.

- `agent-assets`
  Repo-root wrapper for installing or inspecting this repo's managed Codex
  assets and git-hook payload.

- `defaults.env`
  Default environment values used by `bin/publish-repo`.

- `.gitignore`
  Minimal local ignore rules for this repo.

### Documentation

- `README/WORKSPACE.md`
  Workspace purpose, layout, and execution boundaries.

- `README/VERIFICATION.md`
  Manual verification playbook for lineage, scope lock, guardrails, skill
  validation, and task-status checks.

- `README/AGENTS-GUIDE.md`
  Agent customization guidance for this workspace.

- `README/CODEX-CONFIG.md`
  Explains how user-global Codex config and repo-local `.codex/config.toml`
  are meant to layer.

- `README/CODEX-REPORTS.md`
  Defines the canonical report layout under `../socialpredict/.codex-reports/`
  and the ownership split between runner, dispatcher, and specialists.

- `README/SKILLS-HOOKS.md`
  Customization guidance for repo-local skills and git-hook guardrails.

### Automation and helper scripts

- `bin/publish-repo`
  GitHub bootstrap and publication helper for the control repo.

- `scripts/agent-assets`
  Implementation behind `./agent-assets install|update|status|uninstall`.

- `scripts/codex-report.py`
  Deterministic helper for initializing and updating canonical task reports in
  the target repo.

- `scripts/lib/agent_assets_manifest.sh`
  Manifest, hashing, and JSON helper functions for managed installs.

- `scripts/lib/agent_assets_codex.sh`
  Defines which repo Codex files are copied into user scope and how they are
  written there.

- `scripts/lib/agent_assets_hooks.sh`
  Hook-installation helpers, including managed hook paths and `core.hooksPath`
  handling.

### Repo-local Codex assets

- `.codex/config.toml`
  Shared project-scoped Codex defaults for this workspace, including model,
  reasoning effort, and persona defaults.

- `.codex/agents/`
  Repo-local specialist agent definitions. Current files:
  - `architecture-agent.toml`
  - `coding-best-practices-agent.toml`
  - `db-migration-agent.toml`
  - `dispatcher-agent.toml`
  - `error-handling-agent.toml`
  - `go-style-agent.toml`
  - `logging-agent.toml`
  - `openapi-contract-agent.toml`
  - `test-reliability-agent.toml`
  - `verifier-agent.toml`

- `.codex/skills/`
  Repo-local skills used by this workspace. Current skill directories:
  - `socialpredict-api-contract-drift-control`
  - `socialpredict-go-architecture-governance`
  - `socialpredict-go-code-quality-guardrails`
  - `socialpredict-go-cyclomatic-complexity`
  - `socialpredict-go-gofmt`
  - `socialpredict-go-golangci-lint`
  - `socialpredict-go-staticcheck`
  - `socialpredict-go-testing-reliability`
  - `socialpredict-go-vet`
  - `socialpredict-google-go-style-guide`
  - `socialpredict-openapi-navigation`

  Each skill directory contains:
  - `SKILL.md` as the entrypoint
  - `agents/openai.yaml` for skill-specific agent guidance
  - `references/*.md` for policy or reference material
  - `scripts/*.sh` for deterministic helper commands

### Repo-local git-hook payload

- `.git-hooks/pre-commit`
  Thin wrapper that forwards to the managed guardrail runner in this repo.

- `.git-hooks/pre-push`
  Thin wrapper that forwards to the managed guardrail runner in this repo.

- `.git-hooks/.managed/spec-socialpredict-tasks/bin/socialpredict-guardrails`
  Actual guardrail implementation for boundary checks, OpenAPI drift checks,
  and quality gates.

### Other directories

- `agent-reports/templates/`
  Currently an empty placeholder for future report templates.

## Current Layout Notes

- `.codex/` is part of this committed workspace and should be treated as
  first-class repo content.
- Older docs may still mention prior agent path conventions. The current
  committed agent definitions are the `.toml` files under `.codex/agents/`.
- Backend and API code changes belong in `../socialpredict`, not in this
  control repo.
