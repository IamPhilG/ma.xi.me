<#
.SYNOPSIS
Retire mA.xI.me d'un repository Git cible.

.DESCRIPTION
Wrapper fin autour des scripts specialises sous install/lib/ : miroir exact
de install.ps1. Ne touche jamais un fichier qui n'a pas ete identifie comme
provenant de mA.xI.me.

Par defaut, .wip/ et .bkp/ du repo cible sont conserves (l'historique de
travail peut avoir de la valeur independamment de mA.xI.me). Utilise
-RemoveState pour les supprimer aussi.

.PARAMETER Target
Selectionne les integrations a retirer : claude, copilot, codex, both
(Claude Code et Copilot) ou all (les trois, valeur par defaut).

.PARAMETER WorkspaceRoot
Chemin du repository Git cible. Si absent, le repository Git detecte depuis le
repertoire courant est utilise.

.PARAMETER RemoveState
Supprime aussi .wip/ et .bkp/ du repo cible.

.PARAMETER WhatIf
Affiche les operations qui seraient effectuees sans modifier le repository cible.

.EXAMPLE
.\install\uninstall.ps1 -Target all -WorkspaceRoot "C:\chemin\vers\repo-cible"
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('claude', 'copilot', 'codex', 'both', 'all')]
    [string]$Target = 'all',

    [string]$WorkspaceRoot,

    [switch]$RemoveState
)

$ErrorActionPreference = 'Stop'
$libRoot = Join-Path $PSScriptRoot 'lib'
. (Join-Path $libRoot 'common.ps1')

function Invoke-LibScript {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][hashtable]$LibParams
    )
    if ($WhatIfPreference) { $LibParams['WhatIf'] = $true }
    & (Join-Path $libRoot $Name) @LibParams
}

try {
    $workspaceRepoRoot = Resolve-WorkspaceRepoRoot -WorkspaceRoot $WorkspaceRoot

    if ($PSCmdlet.ShouldProcess($workspaceRepoRoot, "Retirer mA.xI.me pour la cible '$Target'")) {
        $uninstallParams = @{ RepoRoot = $workspaceRepoRoot }
        if ($RemoveState) { $uninstallParams['RemoveState'] = $true }

        switch ($Target) {
            'claude' { Invoke-LibScript -Name 'uninstall-claude.ps1' -LibParams $uninstallParams }
            'copilot' { Invoke-LibScript -Name 'uninstall-copilot.ps1' -LibParams $uninstallParams }
            'codex' { Invoke-LibScript -Name 'uninstall-codex.ps1' -LibParams $uninstallParams }
            'both' {
                Invoke-LibScript -Name 'uninstall-claude.ps1' -LibParams $uninstallParams
                Invoke-LibScript -Name 'uninstall-copilot.ps1' -LibParams $uninstallParams
            }
            'all' {
                Invoke-LibScript -Name 'uninstall-claude.ps1' -LibParams $uninstallParams
                Invoke-LibScript -Name 'uninstall-copilot.ps1' -LibParams $uninstallParams
                Invoke-LibScript -Name 'uninstall-codex.ps1' -LibParams $uninstallParams
            }
        }

        # Etat local retire en dernier: s'il contenait des backups du present
        # desinstalleur, ils doivent avoir eu le temps d'exister avant.
        if ($RemoveState) {
            foreach ($dir in @('.wip', '.bkp')) {
                $full = Join-Path $workspaceRepoRoot $dir
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
