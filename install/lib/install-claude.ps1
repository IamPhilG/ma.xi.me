<#
.SYNOPSIS
Installe mA.xI.me pour Claude Code dans un repository Git cible.

.DESCRIPTION
Script specialise, callable seul ou depuis install.ps1. Projette CLAUDE.md,
.claude/agents/, .claude/skills/, .claude/hooks/ et .claude/settings.json
depuis install/Packaged/ vers le repository cible. Par defaut (sans -Shared),
ajoute aussi les motifs projetes a .git/info/exclude et .gitignore du repo
cible.
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

function Install-ClaudeWorkspace {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $srcClaudeMd = Join-Path $srcRepoRoot 'install\Packaged\CLAUDE.md'
    $srcAgents = Join-Path $srcRepoRoot 'install\Packaged\agents'
    $srcSkills = Join-Path $srcRepoRoot 'install\Packaged\skills'
    if (!(Test-Path $srcClaudeMd)) {
        throw "Le fichier source CLAUDE.md est introuvable dans le repo."
    }
    if (!(Test-Path $srcAgents)) {
        throw "Le dossier source agents est introuvable dans le repo."
    }

    $backupDir = Join-Path $RepoRoot ".bkp\claude-install\$stamp"
    $claudeMdTarget = Join-Path $RepoRoot 'CLAUDE.md'
    $claudeRootTarget = Join-Path $RepoRoot '.claude'
    $agentsTarget = Join-Path $claudeRootTarget 'agents'
    $skillsTarget = Join-Path $claudeRootTarget 'skills'
    $hooksTarget = Join-Path $claudeRootTarget 'hooks'
    $settingsTarget = Join-Path $claudeRootTarget 'settings.json'

    New-Item -ItemType Directory -Force -Path $agentsTarget, $hooksTarget | Out-Null

    # Preserve pre-existing project-specific CLAUDE.md content instead of
    # silently overwriting it (issue #27): move it once into .claude/rules/,
    # which Claude Code loads automatically without any import line needed.
    $projectConventionsTarget = Join-Path $claudeRootTarget 'rules\project-conventions.md'
    $preservedClaude = Save-PreExistingProjectContent -TargetPath $claudeMdTarget -PreserveDestination $projectConventionsTarget
    if ($preservedClaude -and -not $WhatIfPreference) {
        Write-Host "Contenu CLAUDE.md pre-existant preserve dans $projectConventionsTarget (charge automatiquement par Claude Code via .claude/rules/, jamais touche par mA.xI.me a l'avenir)." -ForegroundColor Yellow
    }

    Backup-IfExists -Path $claudeMdTarget -BackupDir $backupDir
    Copy-Item $srcClaudeMd $claudeMdTarget -Force

    Write-MaximeVersionMarker -SrcRepoRoot $srcRepoRoot -TargetPath (Join-Path $claudeRootTarget 'MAXIME_VERSION') -BackupDir $backupDir

    $srcSettings = Join-Path $srcRepoRoot 'install\Packaged\.claude\settings.json'
    if (Test-Path $srcSettings) {
        Backup-IfExists -Path $settingsTarget -BackupDir $backupDir
        Copy-Item $srcSettings $settingsTarget -Force
    }

    $srcHooks = Join-Path $srcRepoRoot 'install\Packaged\.claude\hooks'
    if (Test-Path $srcHooks) {
        Get-ChildItem -Path $srcHooks -File | ForEach-Object {
            $dest = Join-Path $hooksTarget $_.Name
            Backup-IfExists -Path $dest -BackupDir (Join-Path $backupDir 'hooks')
            Copy-Item $_.FullName $dest -Force
        }
    }

    $agentFiles = Get-ChildItem -Path $srcAgents -Filter 'maxime*.md' -File
    if ($agentFiles.Count -eq 0) {
        throw "Aucun agent maxime*.md trouve dans le dossier source agents."
    }
    $agentFiles | ForEach-Object {
        $dest = Join-Path $agentsTarget $_.Name
        Backup-IfExists -Path $dest -BackupDir (Join-Path $backupDir 'agents')
        Copy-Item $_.FullName $dest -Force
    }

    if ((Test-Path $srcSkills) -and (Get-ChildItem -Path $srcSkills -Filter 'maxime*' -Directory -ErrorAction SilentlyContinue)) {
        New-Item -ItemType Directory -Force -Path $skillsTarget | Out-Null
        Get-ChildItem -Path $srcSkills -Filter 'maxime*' -Directory | ForEach-Object {
            $dest = Join-Path $skillsTarget $_.Name
            Backup-DirectoryIfExists -Path $dest -BackupDir (Join-Path $backupDir 'skills')
            Copy-Item $_.FullName $skillsTarget -Recurse -Force
        }
    }

    if (-not $WhatIfPreference) {
        Write-Host "mA.xI.me installe pour Claude (workspace)." -ForegroundColor Green
        Write-Host "Repo cible: $RepoRoot"
        Write-Host "CLAUDE.md: $claudeMdTarget"
        Write-Host "Agents: $agentsTarget"
        Write-Host "Backups locaux: $backupDir"
    }
}

$claudeExcludeEntries = @(
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

Install-ClaudeWorkspace -RepoRoot $RepoRoot
if (-not $Shared) {
    Add-GitExcludeEntries -RepoRoot $RepoRoot -Entries $claudeExcludeEntries
    Add-GitignoreEntries -RepoRoot $RepoRoot -Header '# mA.xI.me -- Claude Code (outil installe, pas du code source)' -Entries $claudeExcludeEntries
}
