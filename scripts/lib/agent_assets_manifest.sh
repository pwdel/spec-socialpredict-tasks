#!/usr/bin/env bash

aa_now_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

aa_sha256_file() {
  local path="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
    return
  fi

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
    return
  fi

  if command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$path" | awk '{print $2}'
    return
  fi

  printf 'Unable to compute sha256: no supported hashing command found\n' >&2
  return 2
}

aa_manifest_exists() {
  local manifest_path="$1"
  [[ -f "$manifest_path" ]]
}

aa_manifest_list_files() {
  local manifest_path="$1"

  if [[ ! -f "$manifest_path" ]]; then
    return 0
  fi

  python3 - "$manifest_path" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

for item in data.get("managedFiles", []):
    kind = item.get("kind", "")
    source = item.get("source", "")
    target = item.get("target", "")
    digest = item.get("sha256", "")
    print(f"{kind}\t{source}\t{target}\t{digest}")
PY
}

aa_manifest_list_directories() {
  local manifest_path="$1"

  if [[ ! -f "$manifest_path" ]]; then
    return 0
  fi

  python3 - "$manifest_path" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

for directory in data.get("managedDirectories", []):
    print(directory)
PY
}

aa_manifest_read_field() {
  local manifest_path="$1"
  local field_path="$2"

  if [[ ! -f "$manifest_path" ]]; then
    return 1
  fi

  python3 - "$manifest_path" "$field_path" <<'PY'
import json
import sys

path = sys.argv[1]
field_path = sys.argv[2]

with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle)

value = data
for part in field_path.split("."):
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
PY
}

aa_manifest_write() {
  local manifest_path="$1"
  local installer_id="$2"
  local tool="$3"
  local install_mode="$4"
  local source_repo_path="$5"
  local source_commit="$6"
  local home_dir="$7"
  local codex_root="$8"
  local hooks_root="$9"
  local timestamp="${10}"
  local entries_tsv="${11}"
  local directories_list="${12}"

  mkdir -p "$(dirname "$manifest_path")"

  python3 - \
    "$manifest_path" \
    "$installer_id" \
    "$tool" \
    "$install_mode" \
    "$source_repo_path" \
    "$source_commit" \
    "$home_dir" \
    "$codex_root" \
    "$hooks_root" \
    "$timestamp" \
    "$entries_tsv" \
    "$directories_list" <<'PY'
import json
import os
import sys

(
    manifest_path,
    installer_id,
    tool,
    install_mode,
    source_repo_path,
    source_commit,
    home_dir,
    codex_root,
    hooks_root,
    timestamp,
    entries_tsv,
    directories_list,
) = sys.argv[1:13]

managed_files = []
if os.path.isfile(entries_tsv):
    with open(entries_tsv, "r", encoding="utf-8") as handle:
        for raw in handle:
            line = raw.rstrip("\n")
            if not line:
                continue
            parts = line.split("\t")
            if len(parts) != 4:
                continue
            kind, source, target, digest = parts
            managed_files.append(
                {
                    "kind": kind,
                    "source": source,
                    "target": target,
                    "sha256": digest,
                    "type": "file",
                }
            )

managed_files.sort(key=lambda item: item["target"])

managed_directories = []
if os.path.isfile(directories_list):
    with open(directories_list, "r", encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if line:
                managed_directories.append(line)
managed_directories = sorted(set(managed_directories))

payload = {
    "schemaVersion": 1,
    "installerId": installer_id,
    "tool": tool,
    "installMode": install_mode,
    "sourceRepo": {
        "path": source_repo_path,
        "commit": source_commit,
    },
    "installedAt": timestamp,
    "updatedAt": timestamp,
    "home": home_dir,
    "codexRoot": codex_root,
    "hooksRoot": hooks_root,
    "managedFiles": managed_files,
    "managedDirectories": managed_directories,
}

with open(manifest_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, indent=2, sort_keys=True)
    handle.write("\n")
PY
}
