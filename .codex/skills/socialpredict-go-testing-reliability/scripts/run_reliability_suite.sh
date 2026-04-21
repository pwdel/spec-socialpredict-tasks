#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" && pwd)"
# shellcheck source=../../lib/socialpredict_backend_common.sh
source "$SKILLS_LIB_DIR/socialpredict_backend_common.sh"

REPO_DIR="$(resolve_target_repo_dir "${1:-}")"
PKG_PATTERN="${2:-${PKG_PATTERN:-./...}}"
RUNS="${RUNS:-2}"
ENABLE_RACE="${ENABLE_RACE:-0}"

BACKEND_DIR="$(require_backend_dir "$REPO_DIR")"

cd "$BACKEND_DIR"

echo "[1/3] Deterministic go test loop for $PKG_PATTERN (runs=$RUNS, race=$ENABLE_RACE)"
for run in $(seq 1 "$RUNS"); do
  echo "run $run/$RUNS"
  if [ "$ENABLE_RACE" = "1" ]; then
    go test "$PKG_PATTERN" -race -count=1
  else
    go test "$PKG_PATTERN" -count=1
  fi
done

echo "[2/3] OpenAPI validation test"
go test ./... -run TestOpenAPISpecValidates -count=1

echo "[3/3] go vet on $PKG_PATTERN"
go vet "$PKG_PATTERN"

echo "PASS: reliability suite completed"
