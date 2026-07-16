<#
.SYNOPSIS
Installe mA.xI.me pour Codex dans un repository Git cible.

.DESCRIPTION
Script specialise, callable seul ou depuis install.ps1. Projette AGENTS.md et
.agents/skills/ depuis install/Packaged/ vers le repository cible. Verifie au
prealable que generate-adapters.ps1/.sh produisent la meme projection
(tools/check-adapter-sync.ps1). Par defaut (sans -Shared), ajoute aussi les
motifs projetes a .git/info/exclude et .gitignore du repo cible.
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

function Install-CodexWorkspace {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $codexSource = Join-Path $srcRepoRoot 'install\Packaged\.codex\AGENTS.md'
    $skillsSourceRoot = Join-Path $srcRepoRoot 'install\Packaged\.agents\skills'
    if (!(Test-Path $codexSource)) {
        throw "Le fichier source .codex/AGENTS.md est introuvable dans le repo."
    }
    if (!(Test-Path $skillsSourceRoot)) {
        throw "Le dossier source .agents/skills est introuvable dans le repo."
    }

    $checkScript = Join-Path $srcRepoRoot 'tools\check-adapter-sync.ps1'
    if (Test-Path $checkScript) {
        $previousWhatIfPreference = $WhatIfPreference
        try {
            $WhatIfPreference = $false
            & $checkScript
        }
        finally {
            $WhatIfPreference = $previousWhatIfPreference
        }
    }

    $backupDir = Join-Path $RepoRoot ".bkp\codex-install\$stamp"
    $agentsTarget = Join-Path $RepoRoot 'AGENTS.md'
    $skillsTargetRoot = Join-Path $RepoRoot '.agents\skills'

    New-Item -ItemType Directory -Force -Path $skillsTargetRoot | Out-Null

    # No confirmed native import/merge mechanism for AGENTS.md (issue #27):
    # the override-file semantics found in research were ambiguous ("at most
    # one file used per directory" suggests replace, not merge). Instead of
    # overwriting AGENTS.md wholesale, splice the generated content into an
    # explicit marker block, preserving any pre-existing project content
    # around it.
    Backup-IfExists -Path $agentsTarget -BackupDir $backupDir
    $script:codexAgentsMixed = Merge-MaximeManagedBlock -TargetPath $agentsTarget -GeneratedContent (Get-Content -Raw -Path $codexSource)
    if ($script:codexAgentsMixed -and -not $WhatIfPreference) {
        Write-Host "AGENTS.md contient du contenu projet pre-existant -- fusionne avec le contenu genere via un bloc delimite, jamais ecrase entierement." -ForegroundColor Yellow
    }

    $skillDirs = Get-ChildItem -Path $skillsSourceRoot -Filter 'maxime*' -Directory
    if ($skillDirs.Count -eq 0) {
        throw "Aucun skill maxime* trouve dans le dossier source .agents/skills."
    }

    $skillDirs | ForEach-Object {
        $dest = Join-Path $skillsTargetRoot $_.Name
        Backup-DirectoryIfExists -Path $dest -BackupDir (Join-Path $backupDir 'skills')
        Copy-Item $_.FullName $skillsTargetRoot -Recurse -Force
    }

    Write-MaximeVersionMarker -SrcRepoRoot $srcRepoRoot -TargetPath (Join-Path $RepoRoot '.agents\MAXIME_VERSION') -BackupDir $backupDir

    if (-not $WhatIfPreference) {
        Write-Host "mA.xI.me installe pour Codex (workspace)." -ForegroundColor Green
        Write-Host "Repo cible: $RepoRoot"
        Write-Host "Instructions: $agentsTarget"
        Write-Host "Skills: $skillsTargetRoot"
        Write-Host "Backups locaux: $backupDir"
    }
}

Install-CodexWorkspace -RepoRoot $RepoRoot
if (-not $Shared) {
    # AGENTS.md is excluded by default only when it's purely tool-owned. Once
    # it mixes in real project content (issue #27 merge), it is no longer
    # ours alone to exclude -- the project content it now carries deserves
    # the same git treatment it would have had before mA.xI.me touched it.
    $codexExcludeEntries = @(
        '/.agents/skills/maxime-*/',
        '/.agents/MAXIME_VERSION'
    )
    if (-not $script:codexAgentsMixed) {
        $codexExcludeEntries = @('/AGENTS.md') + $codexExcludeEntries
    }
    Add-GitExcludeEntries -RepoRoot $RepoRoot -Entries $codexExcludeEntries
    Add-GitignoreEntries -RepoRoot $RepoRoot -Header '# mA.xI.me -- Codex (outil installe, pas du code source)' -Entries $codexExcludeEntries
}
