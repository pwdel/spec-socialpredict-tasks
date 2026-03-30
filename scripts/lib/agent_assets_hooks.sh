#!/usr/bin/env bash

aa_hooks_runner_rel_path() {
  local installer_id="$1"
  printf '.git-hooks/.managed/%s/bin/socialpredict-guardrails\n' "$installer_id"
}

aa_hooks_repo_source_ids() {
  local installer_id="$1"
  printf '.git-hooks/pre-commit\n'
  printf '.git-hooks/pre-push\n'
  aa_hooks_runner_rel_path "$installer_id"
}

aa_hooks_source_abs_path() {
  local repo_root="$1"
  local source_id="$2"
  printf '%s/%s\n' "$repo_root" "$source_id"
}

aa_hooks_collect_entries() {
  local repo_root="$1"
  local _home_dir="$2"
  local installer_id="$3"
  local output_tsv="$4"

  local source_id source_abs digest
  while IFS= read -r source_id; do
    source_abs="$(aa_hooks_source_abs_path "$repo_root" "$source_id")"
    if [[ ! -f "$source_abs" ]]; then
      printf 'Hook source file is missing: %s\n' "$source_abs" >&2
      return 3
    fi
    digest="$(aa_sha256_file "$source_abs")"
    printf 'hook\t%s\t%s\t%s\n' "$source_id" "$source_id" "$digest" >>"$output_tsv"
  done < <(aa_hooks_repo_source_ids "$installer_id")
}

aa_hooks_write_target() {
  local repo_root="$1"
  local _home_dir="$2"
  local _installer_id="$3"
  local source_id="$4"
  local target_abs="$5"
  local source_abs

  source_abs="$(aa_hooks_source_abs_path "$repo_root" "$source_id")"
  if [[ ! -f "$source_abs" ]]; then
    printf 'Unknown managed hook source id: %s\n' "$source_id" >&2
    return 2
  fi

  mkdir -p "$(dirname "$target_abs")"
  cp -f "$source_abs" "$target_abs"
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

  if [[ "$hooks_path" == "~" ]]; then
    printf '%s\n' "$home_dir"
    return
  fi

  if [[ "${hooks_path:0:2}" == "~/" ]]; then
    printf '%s/%s\n' "$home_dir" "${hooks_path:2}"
    return
  fi

  case "$hooks_path" in
  /*)
    printf '%s\n' "$hooks_path"
    ;;
  *)
    printf '%s/%s\n' "$home_dir" "$hooks_path"
    ;;
  esac
}

aa_state_read_field() {
  local state_path="$1"
  local field_path="$2"

  aa_manifest_read_field "$state_path" "$field_path"
}

aa_state_write() {
  local state_path="$1"
  local installer_id="$2"
  local hooks_path="$3"
  local previous_hooks_path="$4"
  local set_by_installer="$5"
  local timestamp="$6"

  mkdir -p "$(dirname "$state_path")"

  python3 - \
    "$state_path" \
    "$installer_id" \
    "$hooks_path" \
    "$previous_hooks_path" \
    "$set_by_installer" \
    "$timestamp" <<'PY'
import json
import sys

state_path, installer_id, hooks_path, previous_hooks_path, set_by_installer, timestamp = sys.argv[1:7]

payload = {
    "schemaVersion": 1,
    "installerId": installer_id,
    "updatedAt": timestamp,
    "hooksPath": {
        "current": hooks_path,
        "previous": previous_hooks_path,
        "setByInstaller": set_by_installer == "true",
    },
}

with open(state_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}
