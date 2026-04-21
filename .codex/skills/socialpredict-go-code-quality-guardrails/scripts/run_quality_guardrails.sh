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
  cd "$BACKEND_DIR"
  go vet ./...
)

echo "[3/3] boundary hygiene spot-check"
ALLOWED="$(allowed_direct_db_exceptions_regex)"
violations=$(rg -n --glob '!**/*_test.go' 'util.GetDB\(|gorm\.io/gorm' \
  "$BACKEND_DIR/handlers" "$BACKEND_DIR/internal/service" "$BACKEND_DIR/server" \
  | rg -v "$ALLOWED" || true)
if [ -n "$violations" ]; then
  echo "$violations"
  echo "FAIL: boundary hygiene violation detected"
  exit 1
fi

echo "PASS: quality guardrails passed"
