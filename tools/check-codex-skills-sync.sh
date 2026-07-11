#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(dirname "$script_dir")"
if [ ! -d "$repo_root/skills" ] && [ -d "$(dirname "$repo_root")/skills" ]; then
  repo_root="$(dirname "$repo_root")"
fi
repo_root="$(cd "$repo_root" && pwd)"
[ -d "$repo_root/skills" ] || { echo "Repository root not found from '$script_dir' (missing skills/)." >&2; exit 1; }
source_root="$repo_root/skills"
target_root="$repo_root/.agents/skills"
problems=0

if [ ! -d "$source_root" ]; then
  echo "Source skills directory not found: $source_root" >&2
  exit 1
fi
if [ ! -d "$target_root" ]; then
  echo "Codex skills directory not found: $target_root" >&2
  exit 1
fi

while IFS= read -r -d '' source_file; do
  relative="${source_file#$source_root/}"
  target_file="$target_root/$relative"
  if [ ! -f "$target_file" ]; then
    echo "Missing in .agents/skills: $relative"
    problems=1
  elif ! cmp -s "$source_file" "$target_file"; then
    echo "Different content: $relative"
    problems=1
  fi
done < <(find "$source_root" -path "$source_root/maxime*" -type f -print0 | sort -z)

while IFS= read -r -d '' target_file; do
  relative="${target_file#$target_root/}"
  source_file="$source_root/$relative"
  if [ ! -f "$source_file" ]; then
    echo "Extra in .agents/skills: $relative"
    problems=1
  fi
done < <(find "$target_root" -path "$target_root/maxime*" -type f -print0 | sort -z)

if [ "$problems" -ne 0 ]; then
  echo "Codex skills are out of sync." >&2
  exit 1
fi

echo "Codex skills are in sync."
