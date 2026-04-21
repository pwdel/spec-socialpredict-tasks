#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" && pwd)"
# shellcheck source=../../lib/socialpredict_backend_common.sh
source "$SKILLS_LIB_DIR/socialpredict_backend_common.sh"

REPO_DIR="$(resolve_target_repo_dir "${1:-}")"
MODE="${2:-check}"
if [[ $# -ge 3 ]]; then
  TARGETS=("${@:3}")
else
  TARGETS=(.)
fi

if ! command -v gofmt >/dev/null 2>&1; then
  echo "gofmt is required but not installed." >&2
  exit 1
fi

BACKEND_DIR="$(require_backend_dir "$REPO_DIR")"

case "$MODE" in
  check)
    echo "Running: (cd $BACKEND_DIR && gofmt -l ${TARGETS[*]})"
    OUTPUT="$(cd "$BACKEND_DIR" && gofmt -l "${TARGETS[@]}")"
    if [[ -z "$OUTPUT" ]]; then
      echo "PASS: gofmt reports no formatting drift."
      exit 0
    fi
    printf '%s\n' "$OUTPUT"
    echo "FAIL: gofmt reported formatting drift." >&2
    exit 1
    ;;
  write)
    echo "Running: (cd $BACKEND_DIR && gofmt -l ${TARGETS[*]})"
    BEFORE="$(cd "$BACKEND_DIR" && gofmt -l "${TARGETS[@]}")"
    if [[ -z "$BEFORE" ]]; then
      echo "No files required formatting."
      exit 0
    fi
    echo "Running: (cd $BACKEND_DIR && gofmt -w ${TARGETS[*]})"
    (cd "$BACKEND_DIR" && gofmt -w "${TARGETS[@]}")
    printf '%s\n' "$BEFORE"
    ;;
  *)
    echo "Unsupported mode: $MODE. Use 'check' or 'write'." >&2
    exit 1
    ;;
esac
