<#
.SYNOPSIS
Retire mA.xI.me d'un repository Git cible.

.DESCRIPTION
Miroir de install.ps1 : retire exactement les fichiers que l'installateur
projette pour Claude Code, GitHub Copilot et/ou Codex dans un repository Git.
Ne touche jamais un fichier qui n'a pas ete identifie comme provenant de
mA.xI.me (ex. ne supprime pas tout .claude/hooks/, seulement les fichiers
mA.xI.me qu'il contient).

Par defaut, .wip/ et .bkp/ du repo cible sont conserves (l'historique de
travail peut avoir de la valeur independamment de mA.xI.me). Utilise
-RemoveState pour les supprimer aussi.

Les fichiers retires sont sauvegardes dans .bkp/<cible>-uninstall/<horodatage>
avant suppression, sauf si -RemoveState est utilise (auquel cas .bkp/ est
lui-meme supprime en fin d'operation, la sauvegarde serait donc immediatement
perdue).

.PARAMETER Target
Selectionne les integrations a retirer : claude, copilot, codex, both
(Claude Code et Copilot) ou all (les trois, valeur par defaut).

.PARAMETER WorkspaceRoot
Chemin du repository Git cible. Si absent, le repository Git detecte depuis le
repertoire courant est utilise.

.PARAMETER RemoveState
Supprime aussi .wip/ et .bkp/ du repo cible. Sans cette option, ils sont
conserves.

.PARAMETER WhatIf
Affiche les operations qui seraient effectuees sans modifier le repository cible.

.PARAMETER Confirm
Demande confirmation avant les operations qui modifient le repository cible.

.EXAMPLE
.\install\uninstall.ps1 -Target all -WorkspaceRoot "C:\chemin\vers\repo-cible"

Retire Claude Code, Copilot et Codex du repository cible. Conserve .wip/ et .bkp/.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File "C:\chemin\vers\ma.xi.me\install\uninstall.ps1" -Target all -WorkspaceRoot "C:\chemin\vers\repo-cible" -RemoveState -WhatIf

Previsualise un retrait complet (y compris .wip/ et .bkp/) sans rien ecrire.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('claude', 'copilot', 'codex', 'both', 'all')]
    [string]$Target = 'all',

    [string]$WorkspaceRoot,

    [switch]$RemoveState
)

$ErrorActionPreference = 'Stop'

$srcRepoRoot = Split-Path $PSScriptRoot -Parent
$stamp = Get-Date -Format yyyyMMdd-HHmmss

function Backup-IfExists {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$BackupDir
    )
    if (Test-Path $Path) {
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
        $name = Split-Path $Path -Leaf
        Copy-Item $Path (Join-Path $BackupDir $name) -Force
    }
}

function Backup-DirectoryIfExists {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$BackupDir
    )
    if (Test-Path $Path) {
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
        $name = Split-Path $Path -Leaf
        Copy-Item $Path (Join-Path $BackupDir $name) -Recurse -Force
    }
}

function Remove-IfExists {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$BackupDir,
        [switch]$SkipBackup
    )
    if (!(Test-Path $Path)) { return }
    if ($WhatIfPreference) {
        Write-Host "What if: remove $Path"
        return
    }
    # No point backing up into .bkp/ if -RemoveState is about to delete .bkp/ anyway.
    if (-not $SkipBackup -and -not $RemoveState) {
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

function Remove-GitExcludeEntries {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string[]]$Entries
    )
    if ($WhatIfPreference) {
        $Entries | ForEach-Object { Write-Host "What if: remove $_ from the target repo's Git local exclude file" }
        return
    }
    $excludePath = (& git -C $RepoRoot rev-parse --git-path info/exclude).Trim()
    if (![System.IO.Path]::IsPathRooted($excludePath)) {
        $excludePath = Join-Path $RepoRoot $excludePath
    }
    if (!(Test-Path $excludePath)) { return }
    $existing = Get-Content -Path $excludePath
    $filtered = $existing | Where-Object { $_ -notin $Entries }
    if (@($filtered).Count -ne @($existing).Count) {
        Set-Content -Path $excludePath -Value $filtered -Encoding UTF8
    }
}

function Resolve-GitRepoRoot {
    param([Parameter(Mandatory = $true)][string]$StartPath)
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
        if ([System.IO.Path]::GetFullPath($autoRepoRoot) -eq [System.IO.Path]::GetFullPath($srcRepoRoot)) {
            throw "Le repo cible ne peut pas etre le repo source mA.xI.me."
        }
        return $autoRepoRoot
    }

    $resolvedWorkspace = (Resolve-Path -Path $WorkspaceRoot).Path
    $repoRoot = Resolve-GitRepoRoot -StartPath $resolvedWorkspace
    if ([string]::IsNullOrWhiteSpace($repoRoot)) {
        throw "Le chemin -WorkspaceRoot '$resolvedWorkspace' ne pointe pas vers un repo git valide."
    }
    if ([System.IO.Path]::GetFullPath($repoRoot) -eq [System.IO.Path]::GetFullPath($srcRepoRoot)) {
        throw "Le repo cible ne peut pas etre le repo source mA.xI.me."
    }
    return $repoRoot
}

function Uninstall-ClaudeWorkspace {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

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

    $srcHooks = Join-Path $srcRepoRoot '.claude\hooks'
    $hooksTarget = Join-Path $claudeRoot 'hooks'
    if ((Test-Path $srcHooks) -and (Test-Path $hooksTarget)) {
        Get-ChildItem -Path $srcHooks -File | ForEach-Object {
            $dest = Join-Path $hooksTarget $_.Name
            Remove-IfExists -Path $dest -BackupDir (Join-Path $backupDir 'hooks')
        }
        Remove-EmptyDirectory -Path $hooksTarget
    }

    Remove-IfExists -Path (Join-Path $claudeRoot 'settings.json') -BackupDir $backupDir
    Remove-EmptyDirectory -Path $claudeRoot

    Remove-GitExcludeEntries -RepoRoot $RepoRoot -Entries @(
        '/CLAUDE.md',
        '/.claude/agents/maxime*.md',
        '/.claude/skills/maxime-*/',
        '/.claude/hooks/block-destructive-bash.sh',
        '/.claude/settings.json'
    )

    if (-not $WhatIfPreference) {
        Write-Host "mA.xI.me retire pour Claude (workspace)." -ForegroundColor Green
        if (-not $RemoveState) { Write-Host "Backups locaux: $backupDir" }
    }
}

function Uninstall-CopilotWorkspace {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

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

    Remove-GitExcludeEntries -RepoRoot $RepoRoot -Entries @(
        '/.github/copilot-instructions.md',
        '/.github/agents/maxime*.agent.md',
        '/.github/prompts/maxime-*.prompt.md'
    )

    if (-not $WhatIfPreference) {
        Write-Host "mA.xI.me retire pour Copilot (workspace)." -ForegroundColor Green
        if (-not $RemoveState) { Write-Host "Backups locaux: $backupDir" }
    }
}

function Uninstall-CodexWorkspace {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $backupDir = Join-Path $RepoRoot ".bkp\codex-uninstall\$stamp"

    Remove-IfExists -Path (Join-Path $RepoRoot 'AGENTS.md') -BackupDir $backupDir

    $skillsTargetRoot = Join-Path $RepoRoot '.agents\skills'
    if (Test-Path $skillsTargetRoot) {
        Get-ChildItem -Path $skillsTargetRoot -Filter 'maxime-*' -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-IfExists -Path $_.FullName -BackupDir (Join-Path $backupDir 'skills')
        }
        Remove-EmptyDirectory -Path $skillsTargetRoot
        Remove-EmptyDirectory -Path (Join-Path $RepoRoot '.agents')
    }

    Remove-GitExcludeEntries -RepoRoot $RepoRoot -Entries @(
        '/AGENTS.md',
        '/.agents/skills/maxime-*/'
    )

    if (-not $WhatIfPreference) {
        Write-Host "mA.xI.me retire pour Codex (workspace)." -ForegroundColor Green
        if (-not $RemoveState) { Write-Host "Backups locaux: $backupDir" }
    }
}

function Remove-MaximeLocalState {
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    if (-not $RemoveState) {
        return
    }

    foreach ($dir in @('.wip', '.bkp')) {
        $full = Join-Path $RepoRoot $dir
        if (Test-Path $full) {
            if ($WhatIfPreference) {
                Write-Host "What if: remove $full"
            }
            else {
                Remove-Item -Path $full -Recurse -Force
            }
        }
    }
}

try {
    $workspaceRepoRoot = Resolve-WorkspaceRepoRoot

    if ($PSCmdlet.ShouldProcess($workspaceRepoRoot, "Retirer mA.xI.me pour la cible '$Target'")) {
        switch ($Target) {
            'claude' { Uninstall-ClaudeWorkspace -RepoRoot $workspaceRepoRoot }
            'copilot' { Uninstall-CopilotWorkspace -RepoRoot $workspaceRepoRoot }
            'codex' { Uninstall-CodexWorkspace -RepoRoot $workspaceRepoRoot }
            'both' {
                Uninstall-ClaudeWorkspace -RepoRoot $workspaceRepoRoot
                Uninstall-CopilotWorkspace -RepoRoot $workspaceRepoRoot
            }
            'all' {
                Uninstall-ClaudeWorkspace -RepoRoot $workspaceRepoRoot
                Uninstall-CopilotWorkspace -RepoRoot $workspaceRepoRoot
                Uninstall-CodexWorkspace -RepoRoot $workspaceRepoRoot
            }
        }

        # Etat local retire en dernier: s'il contenait des backups du present
        # desinstalleur, ils doivent avoir eu le temps d'exister avant.
        Remove-MaximeLocalState -RepoRoot $workspaceRepoRoot

        if (-not $WhatIfPreference) {
            if ($RemoveState) {
                Write-Host "Etat local (.wip/, .bkp/) supprime." -ForegroundColor Yellow
            }
            else {
                Write-Host "Etat local (.wip/, .bkp/) conserve. Utilise -RemoveState pour le supprimer aussi." -ForegroundColor Cyan
            }
        }
    }
}
catch {
    Write-Host "Echec du retrait : $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
