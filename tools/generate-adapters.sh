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
packaged_root="$root/install/Packaged"

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
write_file "$packaged_root/CLAUDE.md" <<EOF
# CLAUDE.md - mA.xI.me adapter for Claude Code

Generated from core/socle.md. Do not edit directly.

$socle

## Claude Code extension

- mA.xI.me workflows are available as dedicated sub-agents under .claude/agents/.
- The maxi-claude orchestrator is available under .claude/agents/.
- The hook configured in .claude/settings.json, when present, is Claude-specific protection and is not a portable guarantee.
EOF
write_file "$packaged_root/AGENTS.md" <<EOF
# AGENTS.md - mA.xI.me adapter for Codex

Generated from core/socle.md. Do not edit directly.

$socle

## Codex extension

- mA.xI.me workflows are available under .agents/skills/.
- The logical Codex orchestrator identity is maxi-codex (workflow-based, no picker agent).
- Use these workflows for structured work; do not claim an agent mechanism that the host does not provide.
- Codex skill files carry no tool-restriction frontmatter (unlike Claude's allowed-tools or
  Copilot's tools:): VS Code's Codex extension does not support one. Read-only workflows
  (e.g. maxime-review) rely on their own text instruction, not a mechanical guarantee. For
  an enforced read-only guarantee, run the Codex session itself in a read-only sandbox
  (e.g. codex exec --sandbox read-only) rather than expecting the skill file to restrict it.
EOF
write_file "$packaged_root/.codex/AGENTS.md" <<EOF
# AGENTS.md - mA.xI.me adapter for Codex

Generated from core/socle.md. Do not edit directly.

$socle

## Codex extension

- mA.xI.me workflows are available under .agents/skills/.
- The logical Codex orchestrator identity is maxi-codex (workflow-based, no picker agent).
- Use these workflows for structured work; do not claim an agent mechanism that the host does not provide.
- Codex skill files carry no tool-restriction frontmatter (unlike Claude's allowed-tools or
  Copilot's tools:): VS Code's Codex extension does not support one. Read-only workflows
  (e.g. maxime-review) rely on their own text instruction, not a mechanical guarantee. For
  an enforced read-only guarantee, run the Codex session itself in a read-only sandbox
  (e.g. codex exec --sandbox read-only) rather than expecting the skill file to restrict it.
EOF
write_file "$packaged_root/.copilot/copilot-instructions.md" <<EOF
---
applyTo: "**"
---

# mA.xI.me - adapter for GitHub Copilot

Generated from core/socle.md. Do not edit directly.

$socle

## GitHub Copilot extension

- The maxi-copilot agent is available under .github/agents/, along with a dedicated sub-agent per workflow.
- Capabilities and permissions depend on VS Code and the Copilot extension; do not claim a Claude hook or a host capability that is unavailable.
EOF

# Bootstrap guard: prepended to every generated workflow agent/skill except
# maxime-init itself, which is the one thing allowed to run before .wip/
# exists. See decisions-log 2026-07-14 (workflows -> dedicated agents).
bootstrap_guard='> Prerequis : verifier que ce repository a deja ete initialise avec mA.xI.me
> (presence de .wip/ et .wip/adr/decisions-log.md). Si absent, s'"'"'arreter
> immediatement, l'"'"'expliquer, et demander l'"'"'autorisation explicite de lancer
> Maxime Init avant de continuer. Ne jamais lancer Maxime Init automatiquement
> sans confirmation.'

orchestrator_body="# mA.xI.me - Orchestrator

mA.xI.me is the single orchestrator for structured work. It applies the common core and delegates to a dedicated sub-agent per workflow: maxime-start, maxime-plan, maxime-handoff, maxime-init, maxime-retrofit, maxime-review, and maxime-kb. Each sub-agent covers a small part of the workflow; talking to mA.xI.me directly always applies the method below, never a bare skill lookup.

$bootstrap_guard

For significant work, delegate to maxime-start, create a specification via maxime-plan, wait for approval before writes, then conclude with verification and a handoff when needed.

The shared state is always .wip/. Host-specific extensions are additions and do not replace the common core."

write_file "$packaged_root/agents/maxime.md" <<EOF
---
name: maxi-claude
description: mA.xI.me orchestrator for structured work, planning, verification, and handoff.
tools: Read, Glob, Grep, Bash, Write, Edit
---

$orchestrator_body

Delegate to the matching sub-agent (via the Task tool) for each phase: maxi-claude-start, maxi-claude-plan, maxi-claude-handoff, maxi-claude-init, maxi-claude-retrofit, maxi-claude-review, maxi-claude-kb.
EOF
write_file "$packaged_root/.copilot/agents/maxime.agent.md" <<EOF
---
name: maxi-copilot
description: mA.xI.me orchestrator for structured work, planning, verification, and handoff.
tools: [read, search, execute, edit, agent, vscode, web]
agents: [maxi-copilot-start, maxi-copilot-plan, maxi-copilot-handoff, maxi-copilot-init, maxi-copilot-retrofit, maxi-copilot-review, maxi-copilot-kb]
user-invocable: true
---

$orchestrator_body
EOF

# Tool-scoping per workflow: derived from what each workflow's own text
# actually does (see decisions-log 2026-07-14). Codex has no agent/tools
# mechanism, so it gets no equivalent -- its skill carries the bootstrap
# guard as text only, same as maxime-review already relied on text alone.
declare -A claude_tools_by_workflow=(
  [maxime-start]='Read, Glob, Grep, Bash'
  [maxime-plan]='Read, Glob, Grep, Bash, Write'
  [maxime-handoff]='Read, Glob, Grep, Bash, Write'
  [maxime-init]='Read, Glob, Grep, Bash'
  [maxime-retrofit]='Read, Glob, Grep, Bash, Write'
  [maxime-review]='Read, Glob, Grep, Bash'
  [maxime-kb]='Read, Glob, Grep, Bash, Write'
)
declare -A copilot_tools_by_workflow=(
  [maxime-start]='[read, search, execute]'
  [maxime-plan]='[read, search, execute, edit]'
  [maxime-handoff]='[read, search, execute, edit]'
  [maxime-init]='[read, search, execute]'
  [maxime-retrofit]='[read, search, execute, edit]'
  [maxime-review]='[read, search]'
  [maxime-kb]='[read, search, execute, edit]'
)

workflow_count=0
while IFS= read -r workflow; do
  workflow_count=$((workflow_count + 1))
  name="$(basename "$workflow" .md)"
  short_name="${name#maxime-}"
  body="$(read_core "$workflow")"
  if [ "$name" = "maxime-init" ]; then
    body_with_guard="$body"
  else
    body_with_guard="$bootstrap_guard

$body"
  fi
  claude_tools="${claude_tools_by_workflow[$name]}"
  copilot_tools="${copilot_tools_by_workflow[$name]}"

  write_file "$packaged_root/agents/$name.md" <<EOF
---
name: maxi-claude-$short_name
description: mA.xI.me workflow generated from the canonical source.
tools: $claude_tools
---

$body_with_guard
EOF
  write_file "$packaged_root/.agents/skills/$name/SKILL.md" <<EOF
---
name: $name
description: mA.xI.me workflow generated from the canonical source.
---

$body_with_guard
EOF
  write_file "$packaged_root/.copilot/agents/$name.agent.md" <<EOF
---
name: maxi-copilot-$short_name
description: mA.xI.me workflow generated from the canonical source.
tools: $copilot_tools
user-invocable: true
handoffs:
  - label: Retour a maxime
    agent: maxi-copilot
    prompt: Integre ce retour et decide des actions suivantes.
    send: false
---

$body_with_guard
EOF
done < <(find "$workflow_root" -maxdepth 1 -type f -name 'maxime-*.md' -print | sort)
[ "$workflow_count" -eq 7 ] || { echo "Expected seven canonical workflows; found $workflow_count." >&2; exit 1; }

echo 'mA.xI.me adapters generated from core.'
