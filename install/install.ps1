<#
.SYNOPSIS
Installe mA.xI.me dans un repository Git cible.

.DESCRIPTION
Wrapper fin autour des scripts specialises sous install/lib/ : chacun
(install-claude, install-copilot, install-codex, init-local-state) est
callable seul. Ce script orchestre la combinaison demandee par -Target,
inchange par rapport aux versions precedentes (retrocompatible).

L'installation est strictement locale au repository : aucun repertoire
global de Claude Code, Copilot ou Codex n'est modifie. Les fichiers existants
remplaces sont copies dans .bkp/<cible>-install/<horodatage> du repository
cible avant leur remplacement. L'etat partage de mA.xI.me est initialise sous
.wip/ (memory, specs, adr, results, kb, tools) et .bkp/ est ajoute au fichier
Git local info/exclude du repository cible.

Par defaut, les fichiers projetes (CLAUDE.md, .claude/, .github/*, AGENTS.md,
.agents/skills/) sont eux aussi ajoutes a .git/info/exclude et .gitignore :
l'installation reste strictement locale a la machine, jamais commitable par
erreur. Utilise -Shared pour revenir au comportement partage.

.PARAMETER Target
Selectionne les integrations a installer : claude, copilot, codex, both
(Claude Code et Copilot) ou all (les trois, valeur par defaut).

.PARAMETER CopilotScope
Doit etre workspace. La valeur user est conservee seulement afin de produire
une erreur explicite : les installations globales ne sont pas prises en charge.

.PARAMETER WorkspaceRoot
Chemin du repository Git cible. Si absent, le repository Git detecte depuis le
repertoire courant est utilise. Peut etre le repository source mA.xI.me
lui-meme (dogfooding) : les sources sous install/Packaged/ sont distinctes des
emplacements finaux.

.PARAMETER Shared
Rend les fichiers projetes commitables (comportement anterieur), au lieu du
comportement local par defaut.

.PARAMETER WhatIf
Affiche les operations qui seraient effectuees sans modifier le repository cible.

.PARAMETER Confirm
Demande confirmation avant les operations qui modifient le repository cible.

.EXAMPLE
.\install\install.ps1 -Target all -WorkspaceRoot "C:\chemin\vers\repo-cible"

.NOTES
Chaque etape est aussi callable seule : install\lib\install-claude.ps1
-RepoRoot <chemin>, etc. Utile pour un agent (ex. Maxime Init) qui veut
composer les etapes plutot que negocier -Target.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('claude', 'copilot', 'codex', 'both', 'all')]
    [string]$Target = 'all',

    [ValidateSet('user', 'workspace')]
    [string]$CopilotScope = 'workspace',

    [string]$WorkspaceRoot,

    [switch]$Shared
)

$ErrorActionPreference = 'Stop'
$libRoot = Join-Path $PSScriptRoot 'lib'
. (Join-Path $libRoot 'common.ps1')

function Assert-RepoOnlyMode {
    if ($CopilotScope -ne 'workspace') {
        throw "Installation globale retiree: -CopilotScope '$CopilotScope' n'est plus supporte. Utilise -CopilotScope workspace."
    }
}

function Invoke-LibScript {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][hashtable]$LibParams
    )
    if ($WhatIfPreference) { $LibParams['WhatIf'] = $true }
    & (Join-Path $libRoot $Name) @LibParams
}

try {
    Assert-RepoOnlyMode
    $workspaceRepoRoot = Resolve-WorkspaceRepoRoot -WorkspaceRoot $WorkspaceRoot

    if ($PSCmdlet.ShouldProcess($workspaceRepoRoot, "Installer mA.xI.me pour la cible '$Target'")) {
        Invoke-LibScript -Name 'init-local-state.ps1' -LibParams @{ RepoRoot = $workspaceRepoRoot }

        $installParams = @{ RepoRoot = $workspaceRepoRoot }
        if ($Shared) { $installParams['Shared'] = $true }

        switch ($Target) {
            'claude' { Invoke-LibScript -Name 'install-claude.ps1' -LibParams $installParams }
            'copilot' { Invoke-LibScript -Name 'install-copilot.ps1' -LibParams $installParams }
            'codex' { Invoke-LibScript -Name 'install-codex.ps1' -LibParams $installParams }
            'both' {
                Invoke-LibScript -Name 'install-claude.ps1' -LibParams $installParams
                Invoke-LibScript -Name 'install-copilot.ps1' -LibParams $installParams
            }
            'all' {
                Invoke-LibScript -Name 'install-claude.ps1' -LibParams $installParams
                Invoke-LibScript -Name 'install-copilot.ps1' -LibParams $installParams
                Invoke-LibScript -Name 'install-codex.ps1' -LibParams $installParams
            }
        }

        if (-not $WhatIfPreference) {
            if ($Shared) {
                Write-Host "Mode partage : les fichiers installes restent commitables (comme avant)." -ForegroundColor Cyan
            }
            else {
                Write-Host "Mode local (par defaut) : les fichiers installes sont exclus localement via .git/info/exclude, jamais commitables. Utilise -Shared pour les rendre commitables et partages avec l'equipe." -ForegroundColor Cyan
            }
        }
    }
}
catch {
    Write-Host "Echec de l'installation : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Les backups (si applicables) ont ete conserves." -ForegroundColor Yellow
    exit 1
}
