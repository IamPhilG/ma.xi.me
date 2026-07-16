<#
.SYNOPSIS
Installe mA.xI.me pour GitHub Copilot dans un repository Git cible.

.DESCRIPTION
Script specialise, callable seul ou depuis install.ps1. Projette
copilot-instructions.md, .github/agents/ et .github/prompts/ depuis
install/Packaged/.copilot/ vers le repository cible. Par defaut (sans
-Shared), ajoute aussi les motifs projetes a .git/info/exclude et .gitignore
du repo cible.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [switch]$Shared
)

$ErrorActionPreference = 'Stop'
$libRoot = $PSScriptRoot
$srcRepoRoot = Split-Path (Split-Path $libRoot -Parent) -Parent
. (Join-Path $libRoot 'common.ps1')

$stamp = Get-Date -Format yyyyMMdd-HHmmss

function Install-CopilotWorkspace {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $copilotSrc = Join-Path $srcRepoRoot 'install\Packaged\.copilot'
    if (!(Test-Path $copilotSrc)) {
        throw "Le dossier source .copilot est introuvable dans le repo."
    }

    $ghRoot = Join-Path $RepoRoot '.github'
    $agentsTarget = Join-Path $ghRoot 'agents'
    $promptsTarget = Join-Path $ghRoot 'prompts'
    $instructionsTarget = Join-Path $ghRoot 'copilot-instructions.md'
    $backupDir = Join-Path $RepoRoot ".bkp\copilot-install\$stamp"

    New-Item -ItemType Directory -Force -Path $agentsTarget | Out-Null
    Backup-IfExists -Path $instructionsTarget -BackupDir $backupDir

    $srcAgents = Join-Path $copilotSrc 'agents'
    Get-ChildItem -Path $srcAgents -Filter '*.agent.md' -File | ForEach-Object {
        $dest = Join-Path $agentsTarget $_.Name
        Backup-IfExists -Path $dest -BackupDir $backupDir
        Copy-Item $_.FullName $dest -Force
    }

    $srcPrompts = Join-Path $copilotSrc 'prompts'
    if ((Test-Path $srcPrompts) -and (Get-ChildItem -Path $srcPrompts -Filter '*.prompt.md' -File -ErrorAction SilentlyContinue)) {
        New-Item -ItemType Directory -Force -Path $promptsTarget | Out-Null
        Get-ChildItem -Path $srcPrompts -Filter '*.prompt.md' -File | ForEach-Object {
            $dest = Join-Path $promptsTarget $_.Name
            Backup-IfExists -Path $dest -BackupDir $backupDir
            Copy-Item $_.FullName $dest -Force
        }
    }

    Copy-Item (Join-Path $copilotSrc 'copilot-instructions.md') $instructionsTarget -Force

    Write-MaximeVersionMarker -SrcRepoRoot $srcRepoRoot -TargetPath (Join-Path $ghRoot 'MAXIME_VERSION') -BackupDir $backupDir

    if (-not $WhatIfPreference) {
        Write-Host "mA.xI.me installe pour Copilot (workspace)." -ForegroundColor Green
        Write-Host "Repo cible: $RepoRoot"
        Write-Host "Instructions: $instructionsTarget"
        Write-Host "Agents: $agentsTarget"
        Write-Host "Backups locaux: $backupDir"
    }
}

$copilotExcludeEntries = @(
    '/.github/copilot-instructions.md',
    '/.github/agents/maxime*.agent.md',
    '/.github/MAXIME_VERSION'
)

Install-CopilotWorkspace -RepoRoot $RepoRoot
if (-not $Shared) {
    Add-GitExcludeEntries -RepoRoot $RepoRoot -Entries $copilotExcludeEntries
    Add-GitignoreEntries -RepoRoot $RepoRoot -Header '# mA.xI.me -- GitHub Copilot (outil installe, pas du code source)' -Entries $copilotExcludeEntries
}
