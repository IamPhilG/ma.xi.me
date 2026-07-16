<#
.SYNOPSIS
Retire mA.xI.me pour GitHub Copilot d'un repository Git cible.

.DESCRIPTION
Script specialise, miroir de install-copilot.ps1. Ne touche jamais un fichier
qui n'a pas ete identifie comme provenant de mA.xI.me.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [switch]$RemoveState
)

$ErrorActionPreference = 'Stop'
$libRoot = $PSScriptRoot
. (Join-Path $libRoot 'common.ps1')

$stamp = Get-Date -Format yyyyMMdd-HHmmss

function Remove-IfExists {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$BackupDir
    )
    if (!(Test-Path $Path)) { return }
    if ($WhatIfPreference) {
        Write-Host "What if: remove $Path"
        return
    }
    if (-not $RemoveState) {
        if ((Get-Item $Path).PSIsContainer) {
            Backup-DirectoryIfExists -Path $Path -BackupDir $BackupDir
        }
        else {
            Backup-IfExists -Path $Path -BackupDir $BackupDir
        }
    }
    Remove-Item -Path $Path -Recurse -Force
}

function Remove-EmptyDirectory {
    param([Parameter(Mandatory = $true)][string]$Path)
    if ($WhatIfPreference) { return }
    if ((Test-Path $Path) -and ((Get-ChildItem -Path $Path -Force | Measure-Object).Count -eq 0)) {
        Remove-Item -Path $Path -Force
    }
}

$backupDir = Join-Path $RepoRoot ".bkp\copilot-uninstall\$stamp"
$ghRoot = Join-Path $RepoRoot '.github'

Remove-IfExists -Path (Join-Path $ghRoot 'copilot-instructions.md') -BackupDir $backupDir

$agentsTarget = Join-Path $ghRoot 'agents'
if (Test-Path $agentsTarget) {
    Get-ChildItem -Path $agentsTarget -Filter 'maxime*.agent.md' -File -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-IfExists -Path $_.FullName -BackupDir (Join-Path $backupDir 'agents')
    }
    Remove-EmptyDirectory -Path $agentsTarget
}

$promptsTarget = Join-Path $ghRoot 'prompts'
if (Test-Path $promptsTarget) {
    Get-ChildItem -Path $promptsTarget -Filter 'maxime-*.prompt.md' -File -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-IfExists -Path $_.FullName -BackupDir (Join-Path $backupDir 'prompts')
    }
    Remove-EmptyDirectory -Path $promptsTarget
}

Remove-EmptyDirectory -Path $ghRoot

$copilotEntries = @(
    '/.github/copilot-instructions.md',
    '/.github/agents/maxime*.agent.md'
)
Remove-GitExcludeEntries -RepoRoot $RepoRoot -Entries $copilotEntries
Remove-GitignoreEntries -RepoRoot $RepoRoot -Header '# mA.xI.me -- GitHub Copilot (outil installe, pas du code source)' -Entries $copilotEntries

if (-not $WhatIfPreference) {
    Write-Host "mA.xI.me retire pour Copilot (workspace)." -ForegroundColor Green
    if (-not $RemoveState) { Write-Host "Backups locaux: $backupDir" }
}
