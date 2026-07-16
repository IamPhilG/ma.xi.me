<#
.SYNOPSIS
Retire mA.xI.me pour Claude Code d'un repository Git cible.

.DESCRIPTION
Script specialise, miroir de install-claude.ps1. Ne touche jamais un fichier
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
$srcRepoRoot = Split-Path (Split-Path $libRoot -Parent) -Parent
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
    # No point backing up into .bkp/ if -RemoveState is about to delete .bkp/ anyway.
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

$backupDir = Join-Path $RepoRoot ".bkp\claude-uninstall\$stamp"
$claudeRoot = Join-Path $RepoRoot '.claude'

Remove-IfExists -Path (Join-Path $RepoRoot 'CLAUDE.md') -BackupDir $backupDir

$agentsTarget = Join-Path $claudeRoot 'agents'
if (Test-Path $agentsTarget) {
    Get-ChildItem -Path $agentsTarget -Filter 'maxime*.md' -File -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-IfExists -Path $_.FullName -BackupDir (Join-Path $backupDir 'agents')
    }
    Remove-EmptyDirectory -Path $agentsTarget
}

$skillsTarget = Join-Path $claudeRoot 'skills'
if (Test-Path $skillsTarget) {
    Get-ChildItem -Path $skillsTarget -Filter 'maxime-*' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-IfExists -Path $_.FullName -BackupDir (Join-Path $backupDir 'skills')
    }
    Remove-EmptyDirectory -Path $skillsTarget
}

$srcHooks = Join-Path $srcRepoRoot 'install\Packaged\.claude\hooks'
$hooksTarget = Join-Path $claudeRoot 'hooks'
if ((Test-Path $srcHooks) -and (Test-Path $hooksTarget)) {
    Get-ChildItem -Path $srcHooks -File | ForEach-Object {
        $dest = Join-Path $hooksTarget $_.Name
        Remove-IfExists -Path $dest -BackupDir (Join-Path $backupDir 'hooks')
    }
    Remove-EmptyDirectory -Path $hooksTarget
}

Remove-IfExists -Path (Join-Path $claudeRoot 'settings.json') -BackupDir $backupDir
Remove-IfExists -Path (Join-Path $claudeRoot 'MAXIME_VERSION') -BackupDir $backupDir
Remove-EmptyDirectory -Path $claudeRoot

$claudeEntries = @(
    '/CLAUDE.md',
    '/.claude/agents/maxime*.md',
    '/.claude/skills/maxime-*/',
    '/.claude/hooks/block-destructive-bash.sh',
    '/.claude/hooks/block-destructive-powershell.sh',
    '/.claude/hooks/block-outside-repo-write.sh',
    '/.claude/hooks/lib-path-guard.sh',
    '/.claude/settings.json',
    '/.claude/MAXIME_VERSION'
)
Remove-GitExcludeEntries -RepoRoot $RepoRoot -Entries $claudeEntries
Remove-GitignoreEntries -RepoRoot $RepoRoot -Header '# mA.xI.me -- Claude Code (outil installe, pas du code source)' -Entries $claudeEntries

if (-not $WhatIfPreference) {
    Write-Host "mA.xI.me retire pour Claude (workspace)." -ForegroundColor Green
    if (-not $RemoveState) { Write-Host "Backups locaux: $backupDir" }
}
