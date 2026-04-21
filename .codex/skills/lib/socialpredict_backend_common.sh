#!/usr/bin/env bash

# Shared helpers for skill scripts that operate on the SocialPredict target repo.

SKILLS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SKILLS_LIB_DIR/../../.." && pwd)"

default_target_repo_dir() {
  if [[ -n "${TARGET_REPO_DIR:-}" ]]; then
    printf '%s\n' "$TARGET_REPO_DIR"
    return 0
  fi
  if [[ -n "${SOCIALPREDICT_REPO_DIR:-}" ]]; then
    printf '%s\n' "$SOCIALPREDICT_REPO_DIR"
    return 0
  fi
  printf '%s\n' "$WORKSPACE_ROOT/../socialpredict"
}

resolve_target_repo_dir() {
  local candidate="${1:-}"
  if [[ -n "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi
  default_target_repo_dir
}

require_backend_dir() {
  local repo_dir="$1"
  local backend_dir="$repo_dir/backend"
  if [[ ! -d "$backend_dir" ]]; then
    echo "Expected backend directory at: $backend_dir" >&2
    exit 1
  fi
  printf '%s\n' "$backend_dir"
}

resolve_base_ref() {
  local repo_dir="$1"
  local requested="${2:-${BASE_REF:-}}"
  local fallback=""

  if [[ -n "$requested" ]] && git -C "$repo_dir" rev-parse --verify "$requested" >/dev/null 2>&1; then
    printf '%s\n' "$requested"
    return 0
  fi

  fallback="$(git -C "$repo_dir" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [[ -n "$fallback" ]] && git -C "$repo_dir" rev-parse --verify "$fallback" >/dev/null 2>&1; then
    if [[ -n "$requested" ]]; then
      echo "BASE_REF not found locally; falling back to $fallback" >&2
    fi
    printf '%s\n' "$fallback"
    return 0
  fi

  fallback="$(git -C "$repo_dir" rev-parse HEAD~1 2>/dev/null || true)"
  if [[ -n "$fallback" ]]; then
    if [[ -n "$requested" ]]; then
      echo "BASE_REF not found locally; falling back to $fallback" >&2
    else
      echo "BASE_REF not provided; falling back to $fallback" >&2
    fi
    printf '%s\n' "$fallback"
    return 0
  fi

  echo "Unable to resolve BASE_REF for repo: $repo_dir" >&2
  exit 1
}

allowed_direct_db_exceptions_regex() {
  printf '%s\n' \
    'backend/handlers/admin/adduser.go|backend/handlers/stats/statshandler.go|backend/internal/service/auth/loggin.go|backend/handlers/cms/homepage/repo.go|backend/server/server.go'
}
