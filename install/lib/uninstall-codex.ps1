<#
.SYNOPSIS
Retire mA.xI.me pour Codex d'un repository Git cible.

.DESCRIPTION
Script specialise, miroir de install-codex.ps1. Ne touche jamais un fichier
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

$backupDir = Join-Path $RepoRoot ".bkp\codex-uninstall\$stamp"

# AGENTS.md may now mix project content merged in by install-codex.ps1
# (issue #27): strip only the managed block if one is present, never delete
# the whole file outright -- mirrors Merge-MaximeManagedBlock at install
# time. Falls back to full removal for pre-fix installs (no block to find).
$agentsTarget = Join-Path $RepoRoot 'AGENTS.md'
if (Test-Path $agentsTarget) {
    if ($WhatIfPreference) {
        Write-Host "What if: remove or strip managed block from $agentsTarget"
    }
    else {
        if (-not $RemoveState) {
            Backup-IfExists -Path $agentsTarget -BackupDir $backupDir
        }
        if (-not (Remove-MaximeManagedBlock -TargetPath $agentsTarget)) {
            Remove-Item -Path $agentsTarget -Force
        }
    }
}

$skillsTargetRoot = Join-Path $RepoRoot '.agents\skills'
if (Test-Path $skillsTargetRoot) {
    Get-ChildItem -Path $skillsTargetRoot -Filter 'maxime-*' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-IfExists -Path $_.FullName -BackupDir (Join-Path $backupDir 'skills')
    }
    Remove-EmptyDirectory -Path $skillsTargetRoot
}

Remove-IfExists -Path (Join-Path $RepoRoot '.agents\MAXIME_VERSION') -BackupDir $backupDir
Remove-EmptyDirectory -Path (Join-Path $RepoRoot '.agents')

$codexEntries = @(
    '/AGENTS.md',
    '/.agents/skills/maxime-*/',
    '/.agents/MAXIME_VERSION'
)
Remove-GitExcludeEntries -RepoRoot $RepoRoot -Entries $codexEntries
Remove-GitignoreEntries -RepoRoot $RepoRoot -Header '# mA.xI.me -- Codex (outil installe, pas du code source)' -Entries $codexEntries

if (-not $WhatIfPreference) {
    Write-Host "mA.xI.me retire pour Codex (workspace)." -ForegroundColor Green
    if (-not $RemoveState) { Write-Host "Backups locaux: $backupDir" }
}
