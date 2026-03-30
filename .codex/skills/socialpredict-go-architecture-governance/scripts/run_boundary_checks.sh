#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${1:-socialpredict}"

if ! command -v rg >/dev/null 2>&1; then
  echo "rg is required but not installed."
  exit 1
fi

if [ ! -d "$REPO_DIR/backend" ]; then
  echo "Expected backend directory at $REPO_DIR/backend"
  exit 1
fi

ALLOWED="backend/handlers/admin/adduser.go|backend/handlers/stats/statshandler.go|backend/internal/service/auth/loggin.go|backend/handlers/cms/homepage/repo.go|backend/server/server.go"

echo "[1/4] Check for direct DB usage outside approved exceptions"
violations=$(rg -n --glob '!**/*_test.go' 'util.GetDB\(|gorm\.io/gorm' \
  "$REPO_DIR/backend/handlers" "$REPO_DIR/backend/internal/service" "$REPO_DIR/backend/server" \
  | rg -v "$ALLOWED" || true)
if [ -n "$violations" ]; then
  echo "$violations"
  echo "FAIL: direct DB usage detected outside exception list"
  exit 1
fi

echo "[2/4] Check handler/auth imports of concrete repositories"
if rg -n --glob '!**/*_test.go' 'internal/repository/' \
  "$REPO_DIR/backend/handlers" "$REPO_DIR/backend/internal/service"; then
  echo "FAIL: handler/auth imports concrete repository package"
  exit 1
fi

echo "[3/4] Check domain imports of concrete repositories"
if rg -n --glob '!**/*_test.go' 'internal/repository/' "$REPO_DIR/backend/internal/domain"; then
  echo "FAIL: domain layer imports concrete repository package"
  exit 1
fi

echo "[4/4] Check repository imports of handlers"
if rg -n --glob '!**/*_test.go' 'handlers/' "$REPO_DIR/backend/internal/repository"; then
  echo "FAIL: repository layer imports handler package"
  exit 1
fi

echo "PASS: all architecture boundary checks passed"
