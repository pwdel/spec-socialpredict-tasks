#!/usr/bin/env bash

aa_codex_collect_entries() {
  local repo_root="$1"
  local output_tsv="$2"
  local source_root="${repo_root}/.codex/skills"

  if [[ ! -d "$source_root" ]]; then
    printf 'Codex skills source directory is missing: %s\n' "$source_root" >&2
    return 3
  fi

  local rel_path source_rel target_rel digest
  while IFS= read -r rel_path; do
    source_rel=".codex/skills/${rel_path}"
    target_rel=".codex/skills/${rel_path}"
    digest="$(aa_sha256_file "${repo_root}/${source_rel}")"
    printf 'codex\t%s\t%s\t%s\n' "$source_rel" "$target_rel" "$digest" >>"$output_tsv"
  done < <(
    cd "$source_root"
    find . -type f | sed 's#^\./##' | LC_ALL=C sort
  )
}

aa_codex_write_target() {
  local repo_root="$1"
  local source_rel="$2"
  local target_abs="$3"

  if [[ "$source_rel" != .codex/skills/* ]]; then
    printf 'Refusing to copy unexpected codex source: %s\n' "$source_rel" >&2
    return 2
  fi

  mkdir -p "$(dirname "$target_abs")"
  cp -f "${repo_root}/${source_rel}" "$target_abs"
}
