#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(dirname "$script_dir")"
if [ ! -d "$repository_root/core" ] && [ -d "$(dirname "$repository_root")/core" ]; then
  repository_root="$(dirname "$repository_root")"
fi
repository_root="$(cd "$repository_root" && pwd)"
[ -d "$repository_root/core" ] || { echo "Repository root not found from '$script_dir' (missing core/)." >&2; exit 1; }
temp_root="$(mktemp -d)"
trap 'rm -rf "$temp_root"' EXIT

cp -R "$repository_root/core" "$temp_root/core"
generator_path="$repository_root/tools/generate-adapters.sh"
if [ ! -f "$generator_path" ]; then
  generator_path="$repository_root/.wip/tools/generate-adapters.sh"
fi
[ -f "$generator_path" ] || { echo "Unable to find generate-adapters.sh under tools/ or .wip/tools/." >&2; exit 1; }
cp "$generator_path" "$temp_root/generate-adapters.sh"
bash "$temp_root/generate-adapters.sh" "$temp_root" >/dev/null

relative_paths=(
  'install/Packaged/CLAUDE.md'
  'install/Packaged/AGENTS.md'
  'install/Packaged/.codex/AGENTS.md'
  'install/Packaged/.copilot/copilot-instructions.md'
  'install/Packaged/agents/maxime.md'
  'install/Packaged/.copilot/agents/maxime.agent.md'
)
while IFS= read -r workflow; do
  name="$(basename "$workflow" .md)"
  relative_paths+=(
    "install/Packaged/agents/$name.md"
    "install/Packaged/.agents/skills/$name/SKILL.md"
    "install/Packaged/.copilot/agents/$name.agent.md"
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
