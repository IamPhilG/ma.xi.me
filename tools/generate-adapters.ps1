[CmdletBinding()]
param(
    [string]$RepositoryRoot
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) {
    $RepositoryRoot = Split-Path $PSScriptRoot -Parent
}
$resolvedRoot = (Resolve-Path $RepositoryRoot).Path
if (!(Test-Path (Join-Path $resolvedRoot 'core'))) {
    $parentRoot = Split-Path $resolvedRoot -Parent
    if (Test-Path (Join-Path $parentRoot 'core')) {
        $resolvedRoot = $parentRoot
    }
    else {
        throw "Repository root not found from '$RepositoryRoot' (missing core/)."
    }
}
$root = $resolvedRoot
$coreRoot = Join-Path $root 'core'
$workflowRoot = Join-Path $coreRoot 'workflows'
$packagedRoot = Join-Path $root 'install/Packaged'
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Utf8File {
    param([string]$Path, [string]$Content)
    $directory = Split-Path $Path -Parent
    [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    $normalized = ($Content -replace "`r`n", "`n" -replace "`r", "`n").TrimEnd() + "`n"
    [System.IO.File]::WriteAllText($Path, $normalized, $utf8NoBom)
}

function Read-CoreFile {
    param([string]$Path)
    if (!(Test-Path $Path)) { throw "Missing canonical source: $Path" }
    return [System.IO.File]::ReadAllText($Path).Trim()
}

$socle = Read-CoreFile (Join-Path $coreRoot 'socle.md')
$claudeAdapter = @"
# CLAUDE.md - mA.xI.me adapter for Claude Code

Generated from `core/socle.md`. Do not edit directly.

$socle

## Claude Code extension

- mA.xI.me workflows are available as dedicated sub-agents under `.claude/agents/`.
- The `maxi-claude` orchestrator is available under `.claude/agents/`.
- The hook configured in `.claude/settings.json`, when present, is Claude-specific protection and is not a portable guarantee.
"@
$codexAdapter = @"
# AGENTS.md - mA.xI.me adapter for Codex

Generated from `core/socle.md`. Do not edit directly.

$socle

## Codex extension

- mA.xI.me workflows are available under `.agents/skills/`.
- The logical Codex orchestrator identity is `maxi-codex` (workflow-based, no picker agent).
- Use these workflows for structured work; do not claim an agent mechanism that the host does not provide.
- Codex skill files carry no tool-restriction frontmatter (unlike Claude's allowed-tools or
  Copilot's tools:): VS Code's Codex extension does not support one. Read-only workflows
  (e.g. maxime-review) rely on their own text instruction, not a mechanical guarantee. For
  an enforced read-only guarantee, run the Codex session itself in a read-only sandbox
  (e.g. codex exec --sandbox read-only) rather than expecting the skill file to restrict it.
"@
$copilotAdapter = @"
---
applyTo: "**"
---

# mA.xI.me - adapter for GitHub Copilot

Generated from `core/socle.md`. Do not edit directly.

$socle

## GitHub Copilot extension

- The `maxi-copilot` agent is available under `.github/agents/`, along with a dedicated sub-agent per workflow.
- Capabilities and permissions depend on VS Code and the Copilot extension; do not claim a Claude hook or a host capability that is unavailable.
"@

Write-Utf8File (Join-Path $packagedRoot 'CLAUDE.md') $claudeAdapter
Write-Utf8File (Join-Path $packagedRoot 'AGENTS.md') $codexAdapter
Write-Utf8File (Join-Path $packagedRoot '.codex/AGENTS.md') $codexAdapter
Write-Utf8File (Join-Path $packagedRoot '.copilot/copilot-instructions.md') $copilotAdapter

# Bootstrap guard: prepended to every generated workflow agent/skill except
# maxime-init itself, which is the one thing allowed to run before .wip/
# exists. See decisions-log 2026-07-14 (workflows -> dedicated agents).
$bootstrapGuard = @'
> Prerequis : verifier que ce repository a deja ete initialise avec mA.xI.me
> (presence de .wip/ et .wip/adr/decisions-log.md). Si absent, s'arreter
> immediatement, l'expliquer, et demander l'autorisation explicite de lancer
> Maxime Init avant de continuer. Ne jamais lancer Maxime Init automatiquement
> sans confirmation.
'@

$orchestratorBody = @"
# mA.xI.me - Orchestrator

mA.xI.me is the single orchestrator for structured work. It applies the common core and delegates to a dedicated sub-agent per workflow: `maxime-start`, `maxime-plan`, `maxime-handoff`, `maxime-init`, `maxime-retrofit`, `maxime-review`, and `maxime-kb`. Each sub-agent covers a small part of the workflow; talking to mA.xI.me directly always applies the method below, never a bare skill lookup.

$bootstrapGuard

For significant work, delegate to `maxime-start`, create a specification via `maxime-plan`, wait for approval before writes, then conclude with verification and a handoff when needed.

The shared state is always `.wip/`. Host-specific extensions are additions and do not replace the common core.
"@
$claudeAgent = @"
---
name: maxi-claude
description: mA.xI.me orchestrator for structured work, planning, verification, and handoff.
tools: Read, Glob, Grep, Bash, Write, Edit
---

$orchestratorBody

Delegate to the matching sub-agent (via the Task tool) for each phase: `maxi-claude-start`, `maxi-claude-plan`, `maxi-claude-handoff`, `maxi-claude-init`, `maxi-claude-retrofit`, `maxi-claude-review`, `maxi-claude-kb`.
"@
$copilotAgent = @"
---
name: maxi-copilot
description: mA.xI.me orchestrator for structured work, planning, verification, and handoff.
tools: [read, search, execute, edit, agent, vscode, web]
agents: [maxi-copilot-start, maxi-copilot-plan, maxi-copilot-handoff, maxi-copilot-init, maxi-copilot-retrofit, maxi-copilot-review, maxi-copilot-kb]
user-invocable: true
---

$orchestratorBody
"@
Write-Utf8File (Join-Path $packagedRoot 'agents/maxime.md') $claudeAgent
Write-Utf8File (Join-Path $packagedRoot '.copilot/agents/maxime.agent.md') $copilotAgent

# Tool-scoping per workflow: derived from what each workflow's own text
# actually does (see decisions-log 2026-07-14). Codex has no agent/tools
# mechanism, so it gets no equivalent -- its skill carries the bootstrap
# guard as text only, same as maxime-review already relied on text alone.
$claudeToolsByWorkflow = @{
    'maxime-start'    = 'Read, Glob, Grep, Bash'
    'maxime-plan'     = 'Read, Glob, Grep, Bash, Write'
    'maxime-handoff'  = 'Read, Glob, Grep, Bash, Write'
    'maxime-init'     = 'Read, Glob, Grep, Bash'
    'maxime-retrofit' = 'Read, Glob, Grep, Bash, Write'
    'maxime-review'   = 'Read, Glob, Grep, Bash'
    'maxime-kb'       = 'Read, Glob, Grep, Bash, Write'
}
$copilotToolsByWorkflow = @{
    'maxime-start'    = '[read, search, execute]'
    'maxime-plan'     = '[read, search, execute, edit]'
    'maxime-handoff'  = '[read, search, execute, edit]'
    'maxime-init'     = '[read, search, execute]'
    'maxime-retrofit' = '[read, search, execute, edit]'
    'maxime-review'   = '[read, search]'
    'maxime-kb'       = '[read, search, execute, edit]'
}

$workflowFiles = Get-ChildItem -Path $workflowRoot -Filter 'maxime-*.md' -File | Sort-Object Name
if ($workflowFiles.Count -ne 7) { throw "Expected seven canonical workflows; found $($workflowFiles.Count)." }
foreach ($workflowFile in $workflowFiles) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($workflowFile.Name)
    $body = Read-CoreFile $workflowFile.FullName
    $isInit = $name -eq 'maxime-init'
    $bodyWithGuard = if ($isInit) { $body } else { "$bootstrapGuard`n`n$body" }
    $claudeTools = $claudeToolsByWorkflow[$name]
    $copilotTools = $copilotToolsByWorkflow[$name]

    $claudeAgentBody = @"
---
name: maxi-claude-$($name -replace '^maxime-', '')
description: mA.xI.me workflow generated from the canonical source.
tools: $claudeTools
---

$bodyWithGuard
"@
    $codexSkill = @"
---
name: $name
description: mA.xI.me workflow generated from the canonical source.
---

$bodyWithGuard
"@
    $copilotAgentBody = @"
---
name: maxi-copilot-$($name -replace '^maxime-', '')
description: mA.xI.me workflow generated from the canonical source.
tools: $copilotTools
user-invocable: true
handoffs:
  - label: Retour a maxime
    agent: maxi-copilot
    prompt: Integre ce retour et decide des actions suivantes.
    send: false
---

$bodyWithGuard
"@
    Write-Utf8File (Join-Path $packagedRoot "agents/$name.md") $claudeAgentBody
    Write-Utf8File (Join-Path $packagedRoot ".agents/skills/$name/SKILL.md") $codexSkill
    Write-Utf8File (Join-Path $packagedRoot ".copilot/agents/$name.agent.md") $copilotAgentBody
}

Write-Host 'mA.xI.me adapters generated from core.' -ForegroundColor Green
