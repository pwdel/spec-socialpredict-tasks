#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" && pwd)"
# shellcheck source=../../lib/socialpredict_backend_common.sh
source "$SKILLS_LIB_DIR/socialpredict_backend_common.sh"

REPO_DIR="$(resolve_target_repo_dir "${1:-}")"
if [[ $# -ge 2 ]]; then
  PACKAGES=("${@:2}")
else
  PACKAGES=(./...)
fi

if ! command -v golangci-lint >/dev/null 2>&1; then
  echo "golangci-lint is required but not installed." >&2
  echo "Install with: go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest" >&2
  exit 1
fi

BACKEND_DIR="$(require_backend_dir "$REPO_DIR")"

echo "Running: (cd $BACKEND_DIR && golangci-lint run ${PACKAGES[*]})"
(cd "$BACKEND_DIR" && golangci-lint run "${PACKAGES[@]}")
echo "PASS: golangci-lint completed without findings."
