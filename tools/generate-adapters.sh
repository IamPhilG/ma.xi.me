#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="${1:-$(dirname "$script_dir")}"
root="$(cd "$root" && pwd)"
if [ ! -d "$root/core" ] && [ -d "$(dirname "$root")/core" ]; then
  root="$(cd "$(dirname "$root")" && pwd)"
fi
[ -d "$root/core" ] || { echo "Repository root not found from '$root' (missing core/)." >&2; exit 1; }
core_root="$root/core"
workflow_root="$core_root/workflows"

read_core() {
  local path="$1"
  [ -f "$path" ] || { echo "Missing canonical source: $path" >&2; exit 1; }
  tr -d '\r' < "$path"
}

write_file() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path"
}

socle="$(read_core "$core_root/socle.md")"
write_file "$root/CLAUDE.md" <<EOF
# CLAUDE.md - mA.xI.me adapter for Claude Code

Generated from core/socle.md. Do not edit directly.

$socle

## Claude Code extension

- mA.xI.me skills are available under .claude/skills/.
- The maxi-claude orchestrator is available under .claude/agents/.
- The hook configured in .claude/settings.json, when present, is Claude-specific protection and is not a portable guarantee.
EOF
write_file "$root/AGENTS.md" <<EOF
# AGENTS.md - mA.xI.me adapter for Codex

Generated from core/socle.md. Do not edit directly.

$socle

## Codex extension

- mA.xI.me workflows are available under .agents/skills/.
- The logical Codex orchestrator identity is maxi-codex (workflow-based, no picker agent).
- Use these workflows for structured work; do not claim an agent mechanism that the host does not provide.
EOF
write_file "$root/.codex/AGENTS.md" <<EOF
# AGENTS.md - mA.xI.me adapter for Codex

Generated from core/socle.md. Do not edit directly.

$socle

## Codex extension

- mA.xI.me workflows are available under .agents/skills/.
- The logical Codex orchestrator identity is maxi-codex (workflow-based, no picker agent).
- Use these workflows for structured work; do not claim an agent mechanism that the host does not provide.
EOF
write_file "$root/.copilot/copilot-instructions.md" <<EOF
---
applyTo: "**"
---

# mA.xI.me - adapter for GitHub Copilot

Generated from core/socle.md. Do not edit directly.

$socle

## GitHub Copilot extension

- The maxi-copilot agent is available under .github/agents/.
- Workflows are available under .github/prompts/.
- Capabilities and permissions depend on VS Code and the Copilot extension; do not claim a Claude hook or a host capability that is unavailable.
EOF

orchestrator_body='# mA.xI.me - Orchestrator

mA.xI.me is the single orchestrator for structured work. It applies the common core and orchestrates maxime-start, maxime-plan, maxime-handoff, maxime-setup, maxime-retrofit, maxime-review, and maxime-kb.

For significant work, start with maxime-start, create a specification with maxime-plan, wait for approval before writes, then conclude with verification and a handoff when needed.

The shared state is always .wip/. Host-specific extensions are additions and do not replace the common core.'
write_file "$root/agents/maxime.md" <<EOF
---
name: maxi-claude
description: mA.xI.me orchestrator for structured work, planning, verification, and handoff.
tools: Read, Glob, Grep, Bash, Write, Edit
---

$orchestrator_body
EOF
write_file "$root/.copilot/agents/maxime.agent.md" <<EOF
---
name: maxi-copilot
description: mA.xI.me orchestrator for structured work, planning, verification, and handoff.
tools: [read_file, grep_search, file_search, run_in_terminal, apply_patch, create_file, runSubagent]
agents: [maxi-copilot-reviewer, maxi-copilot-reviewer-shell]
user-invocable: true
---

$orchestrator_body
EOF

workflow_count=0
while IFS= read -r workflow; do
  workflow_count=$((workflow_count + 1))
  name="$(basename "$workflow" .md)"
  body="$(read_core "$workflow")"
  if [ "$name" = "maxime-review" ]; then
    claude_tools='Read, Glob, Grep, Bash'
    copilot_tools='[read_file, grep_search, file_search]'
  else
    claude_tools='Read, Glob, Grep, Bash, Write, Edit'
    copilot_tools='[read_file, grep_search, file_search, run_in_terminal, apply_patch, create_file]'
  fi
  write_file "$root/skills/$name/SKILL.md" <<EOF
---
name: $name
description: mA.xI.me workflow generated from the canonical source.
allowed-tools: $claude_tools
---

$body
EOF
  mkdir -p "$root/.agents/skills/$name"
  cp "$root/skills/$name/SKILL.md" "$root/.agents/skills/$name/SKILL.md"
  write_file "$root/.copilot/prompts/$name.prompt.md" <<EOF
---
name: $name
description: mA.xI.me workflow generated from the canonical source.
agent: maxi-copilot
tools: $copilot_tools
---

$body
EOF
done < <(find "$workflow_root" -maxdepth 1 -type f -name 'maxime-*.md' -print | sort)
[ "$workflow_count" -eq 7 ] || { echo "Expected seven canonical workflows; found $workflow_count." >&2; exit 1; }

echo 'mA.xI.me adapters generated from core.'
