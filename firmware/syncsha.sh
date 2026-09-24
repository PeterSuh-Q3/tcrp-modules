#!/usr/bin/env bash
set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
raw_base='https://raw.githubusercontent.com/PeterSuh-Q3/tcrp-modules/main'

sync_checksum() {
  local relative_path=$1
  local checksum
  local url
  local recipe
  local temporary

  checksum=$(sha256sum "$repo_root/$relative_path" | awk '{print $1}')
  url="$raw_base/$relative_path"
  printf '%s  %s\n' "$checksum" "$relative_path"

  while IFS= read -r -d '' recipe; do
    temporary=$(mktemp)
    jq --arg url "$url" --arg checksum "$checksum" '
      if (.files | type) == "array" then
        .files |= map(
          if .url == $url then .sha256 = $checksum else . end
        )
      else
        .
      end
    ' "$recipe" > "$temporary"

    if ! cmp -s "$recipe" "$temporary"; then
      mv "$temporary" "$recipe"
      printf 'updated %s\n' "${recipe#$repo_root/}"
    else
      rm "$temporary"
    fi
  done < <(rg -l -0 -F "$url" "$repo_root" -g '*.json')
}

sync_checksum 'firmware/common/firmware.tgz'
sync_checksum 'firmware/common/firmwarei915.tgz'
sync_checksum 'firmware/common/firmwareamdgpu.tgz'
sync_checksum 'firmware/custom-modules/firmware.tgz'
