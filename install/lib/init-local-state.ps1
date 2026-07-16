<#
.SYNOPSIS
Initialise l'etat local mA.xI.me (.wip/, .bkp/) dans un repository Git cible.

.DESCRIPTION
Script specialise, callable seul ou depuis install.ps1. Cree .wip/{memory,
specs,adr,results,tools} et .bkp/, distribue cleanup-wip.ps1/.sh depuis
core/tools/, et ajoute /.wip/ et /.bkp/ au fichier Git local info/exclude du
repository cible (jamais un .gitignore : etat de travail local a la machine).
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'
$libRoot = $PSScriptRoot
$srcRepoRoot = Split-Path (Split-Path $libRoot -Parent) -Parent
. (Join-Path $libRoot 'common.ps1')

$stamp = Get-Date -Format yyyyMMdd-HHmmss
$dayStamp = Get-Date -Format yyyyMMdd

function Initialize-MaximeLocalState {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $stateRoot = Join-Path $RepoRoot '.wip'
    $stateDirectories = @(
        (Join-Path $stateRoot 'memory'),
        (Join-Path $stateRoot 'specs'),
        (Join-Path $stateRoot 'adr'),
        (Join-Path $stateRoot 'results'),
        (Join-Path $stateRoot 'kb'),
        (Join-Path $stateRoot 'kb\active'),
        (Join-Path $stateRoot 'kb\archived'),
        (Join-Path $stateRoot 'tools'),
        (Join-Path $RepoRoot '.bkp')
    )

    if ($WhatIfPreference) {
        $stateDirectories | ForEach-Object { Write-Host "What if: create local state directory $_" }
        Write-Host "What if: copy cleanup-wip.ps1 and cleanup-wip.sh into $(Join-Path $stateRoot 'tools')"
        Write-Host "What if: add .wip/ and .bkp/ to the target repo's Git local exclude file"
        return
    }

    New-Item -ItemType Directory -Force -Path $stateDirectories | Out-Null

    $handoffPath = Join-Path $stateRoot "memory\$dayStamp.session-handoff.md"
    $decisionsPath = Join-Path $stateRoot 'adr\decisions-log.md'
    $deadEndsPath = Join-Path $stateRoot 'results\dead-ends.md'
    $kbIndexPath = Join-Path $stateRoot 'kb\index.json'

    if (!(Test-Path $handoffPath)) {
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
        Set-Content -Path $handoffPath -Value $defaultHandoff -Encoding UTF8
    }

    if (!(Test-Path $decisionsPath)) {
        Set-Content -Path $decisionsPath -Value "# Decisions Log`n" -Encoding UTF8
    }

    if (!(Test-Path $deadEndsPath)) {
        Set-Content -Path $deadEndsPath -Value "# Dead Ends`n" -Encoding UTF8
    }

    if (!(Test-Path $kbIndexPath)) {
        Set-Content -Path $kbIndexPath -Value '[]' -Encoding UTF8
    }

    $toolsRoot = Join-Path $stateRoot 'tools'
    $networkPolicyPath = Join-Path $toolsRoot 'kb-network-policy.json'
    if (!(Test-Path $networkPolicyPath)) {
        # Fail-safe default: never assume network write access. Read defaults
        # to true (most environments have outbound read access; air-gapped is
        # the exception, not the norm) -- maxime-init overwrites both once
        # the question is actually asked. See decisions-log 2026-07-16.
        $defaultPolicy = '{"network_read": true, "network_write": false}'
        Set-Content -Path $networkPolicyPath -Value $defaultPolicy -Encoding UTF8
    }

    $toolsBackupDir = Join-Path $RepoRoot ".bkp\maxime-tools\$stamp"
    $wipToolsSource = Join-Path $srcRepoRoot 'core\tools'
    foreach ($toolName in @('cleanup-wip.ps1', 'cleanup-wip.sh')) {
        $toolSource = Join-Path $wipToolsSource $toolName
        $toolTarget = Join-Path $toolsRoot $toolName
        if (Test-Path $toolSource) {
            Backup-IfExists -Path $toolTarget -BackupDir $toolsBackupDir
            Copy-Item $toolSource $toolTarget -Force
        }
    }

    Add-GitExcludeEntries -RepoRoot $RepoRoot -Entries @('/.wip/', '/.bkp/')
}

Initialize-MaximeLocalState -RepoRoot $RepoRoot
