#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" && pwd)"
# shellcheck source=../../lib/socialpredict_backend_common.sh
source "$SKILLS_LIB_DIR/socialpredict_backend_common.sh"

REPO_DIR="$(resolve_target_repo_dir "${1:-}")"

if ! command -v rg >/dev/null 2>&1; then
  echo "rg is required but not installed."
  exit 1
fi

BACKEND_DIR="$(require_backend_dir "$REPO_DIR")"
BASE_REF="$(resolve_base_ref "$REPO_DIR" "${2:-${BASE_REF:-}}")"

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
  cd "$BACKEND_DIR"
  go test ./... -run TestOpenAPISpecValidates -count=1
)

echo "PASS: API contract sync checks passed"
