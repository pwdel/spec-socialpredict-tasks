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

ALLOWED="$(allowed_direct_db_exceptions_regex)"

echo "[1/4] Check for direct DB usage outside approved exceptions"
violations=$(rg -n --glob '!**/*_test.go' 'util.GetDB\(|gorm\.io/gorm' \
  "$BACKEND_DIR/handlers" "$BACKEND_DIR/internal/service" "$BACKEND_DIR/server" \
  | rg -v "$ALLOWED" || true)
if [ -n "$violations" ]; then
  echo "$violations"
  echo "FAIL: direct DB usage detected outside exception list"
  exit 1
fi

echo "[2/4] Check handler/auth imports of concrete repositories"
if rg -n --glob '!**/*_test.go' 'internal/repository/' \
  "$BACKEND_DIR/handlers" "$BACKEND_DIR/internal/service"; then
  echo "FAIL: handler/auth imports concrete repository package"
  exit 1
fi

echo "[3/4] Check domain imports of concrete repositories"
if rg -n --glob '!**/*_test.go' 'internal/repository/' "$BACKEND_DIR/internal/domain"; then
  echo "FAIL: domain layer imports concrete repository package"
  exit 1
fi

echo "[4/4] Check repository imports of handlers"
if rg -n --glob '!**/*_test.go' 'handlers/' "$BACKEND_DIR/internal/repository"; then
  echo "FAIL: repository layer imports handler package"
  exit 1
fi

echo "PASS: all architecture boundary checks passed"
