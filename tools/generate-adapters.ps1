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

- mA.xI.me skills are available under `.claude/skills/`.
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
"@
$copilotAdapter = @"
---
applyTo: "**"
---

# mA.xI.me - adapter for GitHub Copilot

Generated from `core/socle.md`. Do not edit directly.

$socle

## GitHub Copilot extension

- The `maxi-copilot` agent is available under `.github/agents/`.
- Workflows are available under `.github/prompts/`.
- Capabilities and permissions depend on VS Code and the Copilot extension; do not claim a Claude hook or a host capability that is unavailable.
"@

Write-Utf8File (Join-Path $root 'CLAUDE.md') $claudeAdapter
Write-Utf8File (Join-Path $root 'AGENTS.md') $codexAdapter
Write-Utf8File (Join-Path $root '.codex/AGENTS.md') $codexAdapter
Write-Utf8File (Join-Path $root '.copilot/copilot-instructions.md') $copilotAdapter

$orchestratorBody = @"
# mA.xI.me - Orchestrator

mA.xI.me is the single orchestrator for structured work. It applies the common core and orchestrates `maxime-start`, `maxime-plan`, `maxime-handoff`, `maxime-setup`, `maxime-retrofit`, `maxime-review`, and `maxime-kb`.

For significant work, start with `maxime-start`, create a specification with `maxime-plan`, wait for approval before writes, then conclude with verification and a handoff when needed.

The shared state is always `.wip/`. Host-specific extensions are additions and do not replace the common core.
"@
$claudeAgent = @"
---
name: maxi-claude
description: mA.xI.me orchestrator for structured work, planning, verification, and handoff.
tools: Read, Glob, Grep, Bash, Write, Edit
---

$orchestratorBody
"@
$copilotAgent = @"
---
name: maxi-copilot
description: mA.xI.me orchestrator for structured work, planning, verification, and handoff.
tools: [read, search, execute, edit, agent]
agents: [maxi-copilot-reviewer, maxi-copilot-reviewer-shell]
user-invocable: true
---

$orchestratorBody
"@
Write-Utf8File (Join-Path $root 'agents/maxime.md') $claudeAgent
Write-Utf8File (Join-Path $root '.copilot/agents/maxime.agent.md') $copilotAgent

$workflowFiles = Get-ChildItem -Path $workflowRoot -Filter 'maxime-*.md' -File | Sort-Object Name
if ($workflowFiles.Count -ne 7) { throw "Expected seven canonical workflows; found $($workflowFiles.Count)." }
foreach ($workflowFile in $workflowFiles) {
    $name = [System.IO.Path]::GetFileNameWithoutExtension($workflowFile.Name)
    $body = Read-CoreFile $workflowFile.FullName
    $isReview = $name -eq 'maxime-review'
    $claudeTools = if ($isReview) { 'Read, Glob, Grep, Bash' } else { 'Read, Glob, Grep, Bash, Write, Edit' }
    $copilotTools = if ($isReview) { '[read, search]' } else { '[read, search, execute, edit]' }
    $claudeSkill = @"
---
name: $name
description: mA.xI.me workflow generated from the canonical source.
allowed-tools: $claudeTools
---

$body
"@
    $codexSkill = @"
---
name: $name
description: mA.xI.me workflow generated from the canonical source.
---

$body
"@
    $prompt = @"
---
name: $name
description: mA.xI.me workflow generated from the canonical source.
agent: maxi-copilot
tools: $copilotTools
---

$body
"@
    Write-Utf8File (Join-Path $root "skills/$name/SKILL.md") $claudeSkill
    Write-Utf8File (Join-Path $root ".agents/skills/$name/SKILL.md") $codexSkill
    Write-Utf8File (Join-Path $root ".copilot/prompts/$name.prompt.md") $prompt
}

Write-Host 'mA.xI.me adapters generated from core.' -ForegroundColor Green
