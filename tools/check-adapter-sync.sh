#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(dirname "$script_dir")"
temp_root="$(mktemp -d)"
trap 'rm -rf "$temp_root"' EXIT

cp -R "$repository_root/core" "$temp_root/core"
cp "$repository_root/tools/generate-adapters.sh" "$temp_root/generate-adapters.sh"
bash "$temp_root/generate-adapters.sh" "$temp_root" >/dev/null

relative_paths=(
  'CLAUDE.md'
  'AGENTS.md'
  '.codex/AGENTS.md'
  '.copilot/copilot-instructions.md'
  'agents/maxime.md'
  '.copilot/agents/maxime.agent.md'
)
while IFS= read -r workflow; do
  name="$(basename "$workflow" .md)"
  relative_paths+=(
    "skills/$name/SKILL.md"
    ".agents/skills/$name/SKILL.md"
    ".copilot/prompts/$name.prompt.md"
  )
done < <(find "$repository_root/core/workflows" -maxdepth 1 -type f -name 'maxime-*.md' -print | sort)

problems=0
for relative_path in "${relative_paths[@]}"; do
  expected="$temp_root/$relative_path"
  actual="$repository_root/$relative_path"
  if [ ! -f "$actual" ]; then
    echo "Missing generated projection: $relative_path" >&2
    problems=1
  elif ! cmp -s "$expected" "$actual"; then
    echo "Out-of-sync projection: $relative_path" >&2
    problems=1
  fi
done

if [ "$problems" -ne 0 ]; then
  echo 'mA.xI.me adapters are out of sync.' >&2
  exit 1
fi

echo 'mA.xI.me adapters are in sync.'
