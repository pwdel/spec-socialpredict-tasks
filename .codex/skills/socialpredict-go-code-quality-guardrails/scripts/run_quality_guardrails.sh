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

changed_go=$(git -C "$REPO_DIR" diff --name-only "$BASE_REF"...HEAD | rg '^backend/.*\.go$' || true)

echo "[1/3] gofmt check on changed backend files"
if [ -z "$changed_go" ]; then
  echo "No backend Go file changes detected since $BASE_REF; skipping gofmt gate."
else
  unformatted=$(printf '%s\n' "$changed_go" | sed "s#^#$REPO_DIR/#" | xargs gofmt -l)
  if [ -n "$unformatted" ]; then
    echo "$unformatted"
    echo "FAIL: gofmt reported unformatted changed files"
    exit 1
  fi
fi

echo "[2/3] go vet ./..."
(
  cd "$REPO_DIR/backend"
  go vet ./...
)

echo "[3/3] boundary hygiene spot-check"
ALLOWED="backend/handlers/admin/adduser.go|backend/handlers/stats/statshandler.go|backend/internal/service/auth/loggin.go|backend/handlers/cms/homepage/repo.go|backend/server/server.go"
violations=$(rg -n --glob '!**/*_test.go' 'util.GetDB\(|gorm\.io/gorm' \
  "$REPO_DIR/backend/handlers" "$REPO_DIR/backend/internal/service" "$REPO_DIR/backend/server" \
  | rg -v "$ALLOWED" || true)
if [ -n "$violations" ]; then
  echo "$violations"
  echo "FAIL: boundary hygiene violation detected"
  exit 1
fi

echo "PASS: quality guardrails passed"
