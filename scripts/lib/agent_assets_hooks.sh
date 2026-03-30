#!/usr/bin/env bash

aa_hooks_runner_rel_path() {
  local installer_id="$1"
  printf '.git-hooks/.managed/%s/bin/socialpredict-guardrails\n' "$installer_id"
}

aa_hooks_runner_abs_path() {
  local home_dir="$1"
  local installer_id="$2"
  printf '%s/%s\n' "$home_dir" "$(aa_hooks_runner_rel_path "$installer_id")"
}

aa_hooks_render_pre_commit() {
  local runner_abs="$1"
  local installer_id="$2"

  cat <<__PAYLOAD__
#!/usr/bin/env bash
set -euo pipefail
# Managed by ${installer_id}. Do not edit manually.
"${runner_abs}" pre-commit
__PAYLOAD__
}

aa_hooks_render_pre_push() {
  local runner_abs="$1"
  local installer_id="$2"

  cat <<__PAYLOAD__
#!/usr/bin/env bash
set -euo pipefail
# Managed by ${installer_id}. Do not edit manually.
"${runner_abs}" pre-push
__PAYLOAD__
}

aa_hooks_render_runner() {
  local home_dir="$1"
  local installer_id="$2"
  local audit_log_default="${home_dir}/.git-hooks/.managed/${installer_id}/logs/guardrail-bypass.log"

  cat <<'__RUNNER__' | sed "s|__AUDIT_LOG_DEFAULT__|${audit_log_default}|g; s|__INSTALLER_ID__|${installer_id}|g"
#!/usr/bin/env bash
set -euo pipefail

INSTALLER_ID="__INSTALLER_ID__"
BYPASS_AUDIT_LOG_DEFAULT="__AUDIT_LOG_DEFAULT__"

ALLOWED_DB_ACCESS_FILES=(
  "backend/handlers/admin/adduser.go"
  "backend/handlers/stats/statshandler.go"
  "backend/internal/service/auth/loggin.go"
  "backend/handlers/cms/homepage/repo.go"
  "backend/server/server.go"
)

log() {
  printf '[socialpredict-guardrails] %s\n' "$*"
}

usage() {
  cat <<'USAGE'
Usage: socialpredict-guardrails <command>

Commands:
  pre-commit          Fast local gates (boundary + gofmt)
  pre-push            Full gates (boundary + OpenAPI drift + quality)
  boundary            Run boundary policy checks
  openapi-drift       Run route/handler drift check + OpenAPI validation test
  quality             Run gofmt/go vet/go test checks
  all                 Run boundary + openapi-drift + quality (default)
  help                Show this message

Environment:
  BASE_REF                            Optional base ref for openapi-drift check
  GUARDRAIL_TEST_PACKAGES             Space-separated go test package list
  GUARDRAIL_GOFMT_SCOPE               "changed" (default) or "all"
  SOCIALPREDICT_GUARDRAIL_BYPASS      Set non-empty to bypass all gates
  SOCIALPREDICT_GUARDRAIL_BYPASS_REASON
                                      Required when bypassing; written to audit log
  SOCIALPREDICT_GUARDRAIL_BYPASS_AUDIT_LOG
                                      Optional custom bypass audit log file
USAGE
}

require_cmd() {
  local command="$1"
  if ! command -v "${command}" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "${command}" >&2
    exit 2
  fi
}

resolve_repo_root() {
  if ! git rev-parse --show-toplevel 2>/dev/null; then
    printf 'Unable to resolve git repository root for guardrails\n' >&2
    exit 1
  fi
}

REPO_ROOT="$(resolve_repo_root)"
BACKEND_DIR="${REPO_ROOT}/backend"

if [[ ! -d "${BACKEND_DIR}" ]]; then
  printf 'Expected backend directory at %s\n' "${BACKEND_DIR}" >&2
  exit 1
fi

resolve_base_ref() {
  if [[ -n "${BASE_REF:-}" ]]; then
    printf '%s\n' "${BASE_REF}"
    return
  fi

  local candidate
  for candidate in \
    "origin/fix/checkpoint20251020-80" \
    "fix/checkpoint20251020-80" \
    "94231f1d5f49c564d1a99c0135456d92101ed8f0" \
    "HEAD~1"; do
    if git -C "${REPO_ROOT}" rev-parse --verify --quiet "${candidate}^{commit}" >/dev/null 2>&1; then
      printf '%s\n' "${candidate}"
      return
    fi
  done

  printf 'HEAD\n'
}

maybe_bypass() {
  local mode="$1"

  if [[ -z "${SOCIALPREDICT_GUARDRAIL_BYPASS:-}" ]]; then
    return
  fi

  local reason="${SOCIALPREDICT_GUARDRAIL_BYPASS_REASON:-}"
  if [[ -z "${reason}" ]]; then
    printf 'SOCIALPREDICT_GUARDRAIL_BYPASS is set but SOCIALPREDICT_GUARDRAIL_BYPASS_REASON is empty.\n' >&2
    exit 2
  fi

  local audit_log="${SOCIALPREDICT_GUARDRAIL_BYPASS_AUDIT_LOG:-${BYPASS_AUDIT_LOG_DEFAULT}}"
  mkdir -p "$(dirname "${audit_log}")"

  local branch
  branch="$(git -C "${REPO_ROOT}" branch --show-current 2>/dev/null || printf 'unknown')"

  printf '%s\tuser=%s\tbranch=%s\tmode=%s\treason=%s\n' \
    "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    "${USER:-unknown}" \
    "${branch}" \
    "${mode}" \
    "${reason}" >>"${audit_log}"

  log "Bypass enabled for '${mode}'. Audit recorded in ${audit_log}."
  exit 0
}

check_boundary_db_access_allowlist() {
  local allowed_regex
  allowed_regex="$(printf '%s|' "${ALLOWED_DB_ACCESS_FILES[@]}")"
  allowed_regex="${allowed_regex%|}"

  local violations
  violations="$({
    cd "${REPO_ROOT}"
    rg -n --glob '!**/*_test.go' 'util.GetDB\(|gorm\.io/gorm' backend/handlers backend/internal/service backend/server | rg -v "${allowed_regex}" || true
  })"

  if [[ -n "${violations}" ]]; then
    log "Boundary violation: direct DB access outside allowlist."
    printf '%s\n' "${violations}" >&2
    return 1
  fi

  log "Boundary check passed: direct DB access allowlist."
}

check_no_handler_or_service_repo_imports() {
  local matches
  matches="$({
    cd "${REPO_ROOT}"
    rg -n --glob '!**/*_test.go' 'socialpredict/internal/repository/' backend/handlers backend/internal/service || true
  })"

  if [[ -n "${matches}" ]]; then
    log "Boundary violation: handlers/internal service importing concrete repositories."
    printf '%s\n' "${matches}" >&2
    return 1
  fi

  log "Boundary check passed: handlers/internal service repository import rule."
}

check_no_domain_repo_imports() {
  local matches
  matches="$({
    cd "${REPO_ROOT}"
    rg -n --glob '!**/*_test.go' 'socialpredict/internal/repository/' backend/internal/domain || true
  })"

  if [[ -n "${matches}" ]]; then
    log "Boundary violation: domain layer importing concrete repositories."
    printf '%s\n' "${matches}" >&2
    return 1
  fi

  log "Boundary check passed: domain repository import rule."
}

check_no_repository_handler_imports() {
  local matches
  matches="$({
    cd "${REPO_ROOT}"
    rg -n --glob '!**/*_test.go' 'socialpredict/handlers/' backend/internal/repository || true
  })"

  if [[ -n "${matches}" ]]; then
    log "Boundary violation: repository layer importing handlers."
    printf '%s\n' "${matches}" >&2
    return 1
  fi

  log "Boundary check passed: repository->handler import rule."
}

run_boundary_gates() {
  log "Running boundary policy gates..."
  local rc=0
  check_boundary_db_access_allowlist || rc=1
  check_no_handler_or_service_repo_imports || rc=1
  check_no_domain_repo_imports || rc=1
  check_no_repository_handler_imports || rc=1
  return "${rc}"
}

check_openapi_drift() {
  local base_ref changed_files
  base_ref="$(resolve_base_ref)"
  changed_files="$(git -C "${REPO_ROOT}" diff --name-only "${base_ref}"...HEAD || true)"

  if [[ -n "${changed_files}" ]] && printf '%s\n' "${changed_files}" | rg -q '^backend/server/server\.go$|^backend/handlers/.*\.go$'; then
    if ! printf '%s\n' "${changed_files}" | rg -q '^backend/docs/openapi\.yaml$'; then
      log "OpenAPI drift violation: handlers/server changed without backend/docs/openapi.yaml update."
      printf '%s\n' "${changed_files}" >&2
      return 1
    fi
  fi

  log "OpenAPI drift path rule passed against ${base_ref}."
  log "Running OpenAPI validation test..."
  (cd "${BACKEND_DIR}" && go test ./... -run TestOpenAPISpecValidates -count=1)
}

check_gofmt() {
  local scope="${GUARDRAIL_GOFMT_SCOPE:-changed}"
  local -a go_files

  if [[ "${scope}" == "all" ]]; then
    mapfile -t go_files < <(find "${BACKEND_DIR}" -type f -name '*.go' | sort)
  else
    local base_ref
    base_ref="$(resolve_base_ref)"
    mapfile -t go_files < <(
      {
        git -C "${REPO_ROOT}" diff --name-only --diff-filter=ACMRTUXB -- backend
        git -C "${REPO_ROOT}" diff --cached --name-only --diff-filter=ACMRTUXB -- backend
        git -C "${REPO_ROOT}" diff --name-only --diff-filter=ACMRTUXB "${base_ref}"...HEAD -- backend
      } | rg '\.go$' | sort -u | sed "s#^#${REPO_ROOT}/#"
    )
  fi

  if [[ "${#go_files[@]}" -eq 0 ]]; then
    log "No Go files selected for gofmt check (scope=${scope})."
    return
  fi

  local unformatted
  unformatted="$(gofmt -l "${go_files[@]}")"
  if [[ -n "${unformatted}" ]]; then
    log "Go quality violation: gofmt found unformatted files."
    printf '%s\n' "${unformatted}" >&2
    return 1
  fi

  log "Go quality check passed: gofmt -l (scope=${scope})."
}

check_go_vet() {
  log "Running go vet ./..."
  (cd "${BACKEND_DIR}" && go vet ./...)
}

check_go_test() {
  local packages_raw="${GUARDRAIL_TEST_PACKAGES:-./...}"
  local -a packages
  read -r -a packages <<<"${packages_raw}"

  log "Running go test ${packages_raw} -count=1"
  (cd "${BACKEND_DIR}" && go test "${packages[@]}" -count=1)
}

run_quality_gates() {
  log "Running Go quality gates..."
  check_gofmt
  check_go_vet
  check_go_test
}

run_all_gates() {
  run_boundary_gates
  check_openapi_drift
  run_quality_gates
}

run_pre_commit() {
  run_boundary_gates
  check_gofmt
}

run_pre_push() {
  run_all_gates
}

main() {
  require_cmd git
  require_cmd rg
  require_cmd go
  require_cmd gofmt

  local command="${1:-all}"
  maybe_bypass "${command}"

  case "${command}" in
  pre-commit)
    run_pre_commit
    ;;
  pre-push)
    run_pre_push
    ;;
  boundary)
    run_boundary_gates
    ;;
  openapi-drift)
    check_openapi_drift
    ;;
  quality)
    run_quality_gates
    ;;
  all)
    run_all_gates
    ;;
  help | --help | -h)
    usage
    ;;
  *)
    usage
    exit 2
    ;;
  esac
}

main "$@"
__RUNNER__
}

aa_hooks_collect_entries() {
  local home_dir="$1"
  local installer_id="$2"
  local output_tsv="$3"

  local tmp_dir
  tmp_dir="$(mktemp -d)"

  local runner_rel
  runner_rel="$(aa_hooks_runner_rel_path "$installer_id")"

  local runner_abs
  runner_abs="${home_dir}/${runner_rel}"

  aa_hooks_render_runner "$home_dir" "$installer_id" >"${tmp_dir}/runner"
  aa_hooks_render_pre_commit "$runner_abs" "$installer_id" >"${tmp_dir}/pre-commit"
  aa_hooks_render_pre_push "$runner_abs" "$installer_id" >"${tmp_dir}/pre-push"

  printf 'hook\tinternal:hook/pre-commit\t.git-hooks/pre-commit\t%s\n' "$(aa_sha256_file "${tmp_dir}/pre-commit")" >>"$output_tsv"
  printf 'hook\tinternal:hook/pre-push\t.git-hooks/pre-push\t%s\n' "$(aa_sha256_file "${tmp_dir}/pre-push")" >>"$output_tsv"
  printf 'hook\tinternal:hook/runner\t%s\t%s\n' "$runner_rel" "$(aa_sha256_file "${tmp_dir}/runner")" >>"$output_tsv"

  rm -rf "${tmp_dir}"
}

aa_hooks_write_target() {
  local home_dir="$1"
  local installer_id="$2"
  local source_id="$3"
  local target_abs="$4"
  local runner_abs

  runner_abs="$(aa_hooks_runner_abs_path "$home_dir" "$installer_id")"

  mkdir -p "$(dirname "$target_abs")"

  case "$source_id" in
  internal:hook/pre-commit)
    aa_hooks_render_pre_commit "$runner_abs" "$installer_id" >"$target_abs"
    ;;
  internal:hook/pre-push)
    aa_hooks_render_pre_push "$runner_abs" "$installer_id" >"$target_abs"
    ;;
  internal:hook/runner)
    aa_hooks_render_runner "$home_dir" "$installer_id" >"$target_abs"
    ;;
  *)
    printf 'Unknown managed hook source id: %s\n' "$source_id" >&2
    return 2
    ;;
  esac

  chmod 0755 "$target_abs"
}

aa_git_config_cmd() {
  local home_dir="$1"
  local git_config_file="$2"
  shift 2

  if [[ -n "$git_config_file" ]]; then
    HOME="$home_dir" GIT_CONFIG_GLOBAL="$git_config_file" git config --global "$@"
  else
    HOME="$home_dir" git config --global "$@"
  fi
}

aa_git_config_get_hooks_path() {
  local home_dir="$1"
  local git_config_file="$2"

  aa_git_config_cmd "$home_dir" "$git_config_file" --get core.hooksPath 2>/dev/null || true
}

aa_git_config_set_hooks_path() {
  local home_dir="$1"
  local git_config_file="$2"
  local hooks_path="$3"

  aa_git_config_cmd "$home_dir" "$git_config_file" core.hooksPath "$hooks_path"
}

aa_git_config_unset_hooks_path() {
  local home_dir="$1"
  local git_config_file="$2"

  aa_git_config_cmd "$home_dir" "$git_config_file" --unset-all core.hooksPath 2>/dev/null || true
}

aa_normalize_hooks_path() {
  local home_dir="$1"
  local hooks_path="$2"

  if [[ -z "$hooks_path" ]]; then
    printf '\n'
    return
  fi

  case "$hooks_path" in
  '~')
    printf '%s\n' "$home_dir"
    ;;
  '~/'*)
    printf '%s/%s\n' "$home_dir" "${hooks_path#\~/}"
    ;;
  *)
    printf '%s\n' "$hooks_path"
    ;;
  esac
}

aa_state_write() {
  local state_path="$1"
  local installer_id="$2"
  local target_hooks_path="$3"
  local previous_hooks_path="$4"
  local set_by_installer="$5"
  local timestamp="$6"

  mkdir -p "$(dirname "$state_path")"

  python3 - \
    "$state_path" \
    "$installer_id" \
    "$target_hooks_path" \
    "$previous_hooks_path" \
    "$set_by_installer" \
    "$timestamp" <<'__PY__'
import json
import sys

state_path, installer_id, target_hooks_path, previous_hooks_path, set_by_installer, timestamp = sys.argv[1:7]

payload = {
    "schemaVersion": 1,
    "installerId": installer_id,
    "hooksPath": {
        "target": target_hooks_path,
        "previous": previous_hooks_path,
        "setByInstaller": set_by_installer.lower() == "true",
        "recordedAt": timestamp,
    },
}

with open(state_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2, sort_keys=True)
    handle.write("\n")
__PY__
}

aa_state_read_field() {
  local state_path="$1"
  local field_path="$2"

  if [[ ! -f "$state_path" ]]; then
    return 1
  fi

  python3 - "$state_path" "$field_path" <<'__PY__'
import json
import sys

state_path, field_path = sys.argv[1:3]
with open(state_path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

value = data
for part in field_path.split('.'):
    if isinstance(value, dict) and part in value:
        value = value[part]
    else:
        sys.exit(1)

if isinstance(value, bool):
    print("true" if value else "false")
elif value is None:
    print("")
else:
    print(value)
__PY__
}
