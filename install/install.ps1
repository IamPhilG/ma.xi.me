[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('claude', 'copilot', 'codex', 'both', 'all')]
    [string]$Target = 'copilot',

    [ValidateSet('user', 'workspace')]
    [string]$CopilotScope = 'workspace',

    [string]$WorkspaceRoot
)

# Installe mA.xI.me en mode repo-only pour GitHub Copilot.
# Les modes d'installation globaux ont ete retires.
# Supporte -WhatIf (simulation) et -Confirm.
$ErrorActionPreference = 'Stop'

$srcRepoRoot = Split-Path $PSScriptRoot -Parent
$stamp = Get-Date -Format yyyyMMdd-HHmmss
$dayStamp = Get-Date -Format yyyyMMdd

function Backup-IfExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$BackupDir
    )
    if (Test-Path $Path) {
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
        $name = Split-Path $Path -Leaf
        Copy-Item $Path (Join-Path $BackupDir $name) -Force
    }
}

function Resolve-GitRepoRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StartPath
    )

    $resolvedStart = (Resolve-Path -Path $StartPath).Path
    $detected = & git -C $resolvedStart rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($detected)) {
        return (Resolve-Path -Path $detected.Trim()).Path
    }

    return $null
}

function Resolve-WorkspaceRepoRoot {
    if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
        $autoRepoRoot = Resolve-GitRepoRoot -StartPath (Get-Location).Path
        if ([string]::IsNullOrWhiteSpace($autoRepoRoot)) {
            throw "Aucun repo git detecte dans le repertoire courant. Fournis -WorkspaceRoot <chemin-du-repo-cible>."
        }

        return $autoRepoRoot
    }

    $resolvedWorkspace = (Resolve-Path -Path $WorkspaceRoot).Path
    $repoRoot = Resolve-GitRepoRoot -StartPath $resolvedWorkspace
    if ([string]::IsNullOrWhiteSpace($repoRoot)) {
        throw "Le chemin -WorkspaceRoot '$resolvedWorkspace' ne pointe pas vers un repo git valide."
    }

    return $repoRoot
}

function Assert-RepoOnlyMode {
    if ($Target -ne 'copilot') {
        throw "Installation globale retiree: -Target '$Target' n'est plus supporte. Utilise -Target copilot -CopilotScope workspace."
    }

    if ($CopilotScope -ne 'workspace') {
        throw "Installation globale retiree: -CopilotScope '$CopilotScope' n'est plus supporte. Utilise -CopilotScope workspace."
    }
}

function Install-CopilotWorkspace {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $copilotSrc = Join-Path $srcRepoRoot '.copilot'
    if (!(Test-Path $copilotSrc)) {
        throw "Le dossier source .copilot est introuvable dans le repo."
    }

    $ghRoot = Join-Path $RepoRoot '.github'
    $agentsTarget = Join-Path $ghRoot 'agents'
    $promptsTarget = Join-Path $ghRoot 'prompts'
    $instructionsTarget = Join-Path $ghRoot 'copilot-instructions.md'
    $memoryTarget = Join-Path $RepoRoot ".copilot\memory\$dayStamp.session-handoff.md"
    $backupDir = Join-Path $RepoRoot ".bkp\copilot-install\$stamp"

    New-Item -ItemType Directory -Force -Path $agentsTarget, $promptsTarget | Out-Null
    Backup-IfExists -Path $instructionsTarget -BackupDir $backupDir

    $srcAgents = Join-Path $copilotSrc 'agents'
    Get-ChildItem -Path $srcAgents -Filter '*.agent.md' -File | ForEach-Object {
        $dest = Join-Path $agentsTarget $_.Name
        Backup-IfExists -Path $dest -BackupDir $backupDir
        Copy-Item $_.FullName $dest -Force
    }

    $srcPrompts = Join-Path $copilotSrc 'prompts'
    Get-ChildItem -Path $srcPrompts -Filter '*.prompt.md' -File | ForEach-Object {
        $dest = Join-Path $promptsTarget $_.Name
        Backup-IfExists -Path $dest -BackupDir $backupDir
        Copy-Item $_.FullName $dest -Force
    }

    Copy-Item (Join-Path $copilotSrc 'copilot-instructions.md') $instructionsTarget -Force

    $memoryDir = Split-Path $memoryTarget -Parent
    New-Item -ItemType Directory -Force -Path $memoryDir | Out-Null
    if (!(Test-Path $memoryTarget)) {
        $defaultHandoff = @"
# Session Handoff

## Date
- $dayStamp

## Etat courant
- Aucun handoff initialise.

## Prochaines actions
- Definir la tache active.
- Confirmer les criteres d'acceptation.
- Executer puis verifier.
"@
        Set-Content -Path $memoryTarget -Value $defaultHandoff -Encoding UTF8
    }

    if (-not $WhatIfPreference) {
        Write-Host "mA.xI.me installe pour Copilot (workspace)." -ForegroundColor Green
        Write-Host "Repo cible: $RepoRoot"
        Write-Host "Instructions: $instructionsTarget"
        Write-Host "Agents: $agentsTarget"
        Write-Host "Prompts: $promptsTarget"
        Write-Host "Backups locaux: $backupDir"
    }
}

try {
    Assert-RepoOnlyMode
    $workspaceRepoRoot = Resolve-WorkspaceRepoRoot
    Install-CopilotWorkspace -RepoRoot $workspaceRepoRoot
}
catch {
    Write-Host "Echec de l'installation : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Les backups (si applicables) ont ete conserves." -ForegroundColor Yellow
    exit 1
}
