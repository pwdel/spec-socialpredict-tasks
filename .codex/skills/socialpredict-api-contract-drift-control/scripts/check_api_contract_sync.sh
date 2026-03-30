#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${1:-socialpredict}"
BASE_REF="${2:-${BASE_REF:-origin/fix/checkpoint20251020-80}}"

if ! command -v rg >/dev/null 2>&1; then
  echo "rg is required but not installed."
  exit 1
fi

if [ ! -d "$REPO_DIR/backend" ]; then
  echo "Expected backend directory at $REPO_DIR/backend"
  exit 1
fi

if ! git -C "$REPO_DIR" rev-parse --verify "$BASE_REF" >/dev/null 2>&1; then
  BASE_REF="$(git -C "$REPO_DIR" rev-parse HEAD~1)"
  echo "BASE_REF not found locally; falling back to $BASE_REF"
fi

changed=$(git -C "$REPO_DIR" diff --name-only "$BASE_REF"...HEAD || true)

echo "[1/3] Changed files since $BASE_REF"
if [ -n "$changed" ]; then
  echo "$changed"
else
  echo "(none)"
fi

echo "[2/3] Enforce route/handler to OpenAPI sync"
if echo "$changed" | rg -q '^backend/server/server\.go$|^backend/handlers/.*\.go$'; then
  if ! echo "$changed" | rg -q '^backend/docs/openapi\.yaml$'; then
    echo "FAIL: route/handler change detected without backend/docs/openapi.yaml update"
    exit 1
  fi
  echo "PASS: OpenAPI file changed with route/handler updates"
else
  echo "PASS: no route/handler file changes detected"
fi

echo "[3/3] Run OpenAPI validation test"
(
  cd "$REPO_DIR/backend"
  go test ./... -run TestOpenAPISpecValidates -count=1
)

echo "PASS: API contract sync checks passed"
