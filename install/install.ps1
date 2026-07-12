<#
.SYNOPSIS
Installe mA.xI.me dans un repository Git cible.

.DESCRIPTION
Projette les fichiers mA.xI.me pour Claude Code, GitHub Copilot et/ou Codex
dans un repository Git. L'installation est strictement locale au repository :
aucun repertoire global de Claude Code, Copilot ou Codex n'est modifie.

Si WorkspaceRoot est omis, le repository Git contenant le repertoire courant
est utilise comme cible. Sinon, WorkspaceRoot designe le repository cible.
Les fichiers existants remplaces sont copies dans .bkp/<cible>-install/<horodatage>
du repository cible avant leur remplacement.
L'etat partage de mA.xI.me est initialise sous .wip/ (memory, specs, adr,
results, tools) et .bkp/ est ajoute au fichier Git local info/exclude du
repository cible.

.PARAMETER Target
Selectionne les integrations a installer : claude, copilot, codex, both
(Claude Code et Copilot) ou all (les trois, valeur par defaut).

.PARAMETER CopilotScope
Doit etre workspace. La valeur user est conservee seulement afin de produire
une erreur explicite : les installations globales ne sont pas prises en charge.

.PARAMETER WorkspaceRoot
Chemin du repository Git cible. Si absent, le repository Git detecte depuis le
repertoire courant est utilise.

.PARAMETER WhatIf
Affiche les operations qui seraient effectuees sans modifier le repository cible.

.PARAMETER Confirm
Demande confirmation avant les operations qui modifient le repository cible.

.EXAMPLE
Get-Help .\install\install.ps1 -Detailed

Affiche cette aide detaillee depuis la racine du repository mA.xI.me.

.EXAMPLE
.\install\install.ps1 -Target all -WorkspaceRoot "C:\chemin\vers\repo-cible"

Installe Claude Code, Copilot et Codex dans le repository cible, depuis la
racine du repository mA.xI.me. Mets le chemin entre guillemets s'il contient
des espaces.

.EXAMPLE
powershell -ExecutionPolicy Bypass -File "C:\chemin\vers\ma.xi.me\install\install.ps1" -Target copilot -WorkspaceRoot "C:\chemin\vers\repo-cible" -WhatIf

Previsualise l'installation Copilot depuis n'importe quel repertoire, sans ecrire.
Guillemets obligatoires si l'un des deux chemins contient un espace (ex. sous
OneDrive ou un profil "Prenom Nom").

.NOTES
Utilise `Get-Help <chemin-vers-install.ps1> -Full` pour afficher l'aide complete.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('claude', 'copilot', 'codex', 'both', 'all')]
    [string]$Target = 'all',

    [ValidateSet('user', 'workspace')]
    [string]$CopilotScope = 'workspace',

    [string]$WorkspaceRoot
)

# Installe mA.xI.me en mode repo-only pour Claude Code, GitHub Copilot et/ou Codex.
# Les modes d'installation globaux ont ete retires.
# Supporte -WhatIf (simulation) et -Confirm.
$ErrorActionPreference = 'Stop'

$srcRepoRoot = Split-Path $PSScriptRoot -Parent
$stamp = Get-Date -Format yyyyMMdd-HHmmss
$dayStamp = Get-Date -Format yyyyMMdd

function Backup-IfExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$BackupDir
    )
    if (Test-Path $Path) {
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
        $name = Split-Path $Path -Leaf
        Copy-Item $Path (Join-Path $BackupDir $name) -Force
    }
}

function Backup-DirectoryIfExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$BackupDir
    )
    if (Test-Path $Path) {
        New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
        $name = Split-Path $Path -Leaf
        Copy-Item $Path (Join-Path $BackupDir $name) -Recurse -Force
    }
}

function Resolve-GitRepoRoot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$StartPath
    )

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
            throw "Le repo cible ne peut pas etre le repo source mA.xI.me. Fournis -WorkspaceRoot <chemin-du-repo-cible>."
        }

        return $autoRepoRoot
    }

    $resolvedWorkspace = (Resolve-Path -Path $WorkspaceRoot).Path
    $repoRoot = Resolve-GitRepoRoot -StartPath $resolvedWorkspace
    if ([string]::IsNullOrWhiteSpace($repoRoot)) {
        throw "Le chemin -WorkspaceRoot '$resolvedWorkspace' ne pointe pas vers un repo git valide."
    }

    if ([System.IO.Path]::GetFullPath($repoRoot) -eq [System.IO.Path]::GetFullPath($srcRepoRoot)) {
        throw "Le repo cible ne peut pas etre le repo source mA.xI.me. Fournis -WorkspaceRoot <chemin-du-repo-cible>."
    }

    return $repoRoot
}

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

    $toolsRoot = Join-Path $stateRoot 'tools'
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

    $excludePath = (& git -C $RepoRoot rev-parse --git-path info/exclude).Trim()
    if (![System.IO.Path]::IsPathRooted($excludePath)) {
        $excludePath = Join-Path $RepoRoot $excludePath
    }
    $excludeDirectory = Split-Path $excludePath -Parent
    New-Item -ItemType Directory -Force -Path $excludeDirectory | Out-Null
    $existing = if (Test-Path $excludePath) { Get-Content -Path $excludePath } else { @() }
    foreach ($entry in @('/.wip/', '/.bkp/')) {
        if ($existing -notcontains $entry) {
            Add-Content -Path $excludePath -Value $entry -Encoding UTF8
        }
    }
}

function Target-IncludesCopilot {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SelectedTarget
    )

    return $SelectedTarget -in @('copilot', 'both', 'all')
}

function Assert-RepoOnlyMode {
    if ($CopilotScope -ne 'workspace') {
        throw "Installation globale retiree: -CopilotScope '$CopilotScope' n'est plus supporte. Utilise -CopilotScope workspace."
    }
}

function Install-ClaudeWorkspace {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $srcClaudeMd = Join-Path $srcRepoRoot 'CLAUDE.md'
    $srcAgents = Join-Path $srcRepoRoot 'agents'
    $srcSkills = Join-Path $srcRepoRoot 'skills'
    if (!(Test-Path $srcClaudeMd)) {
        throw "Le fichier source CLAUDE.md est introuvable dans le repo."
    }
    if (!(Test-Path $srcAgents)) {
        throw "Le dossier source agents est introuvable dans le repo."
    }
    if (!(Test-Path $srcSkills)) {
        throw "Le dossier source skills est introuvable dans le repo."
    }

    $backupDir = Join-Path $RepoRoot ".bkp\claude-install\$stamp"
    $claudeMdTarget = Join-Path $RepoRoot 'CLAUDE.md'
    $claudeRootTarget = Join-Path $RepoRoot '.claude'
    $agentsTarget = Join-Path $claudeRootTarget 'agents'
    $skillsTarget = Join-Path $claudeRootTarget 'skills'
    $hooksTarget = Join-Path $claudeRootTarget 'hooks'
    $settingsTarget = Join-Path $claudeRootTarget 'settings.json'

    New-Item -ItemType Directory -Force -Path $agentsTarget, $skillsTarget, $hooksTarget | Out-Null

    Backup-IfExists -Path $claudeMdTarget -BackupDir $backupDir
    Copy-Item $srcClaudeMd $claudeMdTarget -Force

    $srcSettings = Join-Path $srcRepoRoot '.claude\settings.json'
    if (Test-Path $srcSettings) {
        Backup-IfExists -Path $settingsTarget -BackupDir $backupDir
        Copy-Item $srcSettings $settingsTarget -Force
    }

    $srcHooks = Join-Path $srcRepoRoot '.claude\hooks'
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

    $skillDirs = Get-ChildItem -Path $srcSkills -Filter 'maxime*' -Directory
    if ($skillDirs.Count -eq 0) {
        throw "Aucun skill maxime* trouve dans le dossier source skills."
    }
    $skillDirs | ForEach-Object {
        $dest = Join-Path $skillsTarget $_.Name
        Backup-DirectoryIfExists -Path $dest -BackupDir (Join-Path $backupDir 'skills')
        Copy-Item $_.FullName $skillsTarget -Recurse -Force
    }

    if (-not $WhatIfPreference) {
        Write-Host "mA.xI.me installe pour Claude (workspace)." -ForegroundColor Green
        Write-Host "Repo cible: $RepoRoot"
        Write-Host "CLAUDE.md: $claudeMdTarget"
        Write-Host "Agents: $agentsTarget"
        Write-Host "Skills: $skillsTarget"
        Write-Host "Backups locaux: $backupDir"
    }
}

function Install-CopilotWorkspace {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $copilotSrc = Join-Path $srcRepoRoot '.copilot'
    if (!(Test-Path $copilotSrc)) {
        throw "Le dossier source .copilot est introuvable dans le repo."
    }

    $ghRoot = Join-Path $RepoRoot '.github'
    $agentsTarget = Join-Path $ghRoot 'agents'
    $promptsTarget = Join-Path $ghRoot 'prompts'
    $instructionsTarget = Join-Path $ghRoot 'copilot-instructions.md'
    $backupDir = Join-Path $RepoRoot ".bkp\copilot-install\$stamp"

    New-Item -ItemType Directory -Force -Path $agentsTarget, $promptsTarget | Out-Null
    Backup-IfExists -Path $instructionsTarget -BackupDir $backupDir

    $srcAgents = Join-Path $copilotSrc 'agents'
    Get-ChildItem -Path $srcAgents -Filter '*.agent.md' -File | ForEach-Object {
        $dest = Join-Path $agentsTarget $_.Name
        Backup-IfExists -Path $dest -BackupDir $backupDir
        Copy-Item $_.FullName $dest -Force
    }

    $srcPrompts = Join-Path $copilotSrc 'prompts'
    Get-ChildItem -Path $srcPrompts -Filter '*.prompt.md' -File | ForEach-Object {
        $dest = Join-Path $promptsTarget $_.Name
        Backup-IfExists -Path $dest -BackupDir $backupDir
        Copy-Item $_.FullName $dest -Force
    }

    Copy-Item (Join-Path $copilotSrc 'copilot-instructions.md') $instructionsTarget -Force

    if (-not $WhatIfPreference) {
        Write-Host "mA.xI.me installe pour Copilot (workspace)." -ForegroundColor Green
        Write-Host "Repo cible: $RepoRoot"
        Write-Host "Instructions: $instructionsTarget"
        Write-Host "Agents: $agentsTarget"
        Write-Host "Prompts: $promptsTarget"
        Write-Host "Backups locaux: $backupDir"
    }
}

function Install-CodexWorkspace {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $codexSource = Join-Path $srcRepoRoot '.codex\AGENTS.md'
    $skillsSourceRoot = Join-Path $srcRepoRoot '.agents\skills'
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

    Backup-IfExists -Path $agentsTarget -BackupDir $backupDir
    Copy-Item $codexSource $agentsTarget -Force

    $skillDirs = Get-ChildItem -Path $skillsSourceRoot -Filter 'maxime*' -Directory
    if ($skillDirs.Count -eq 0) {
        throw "Aucun skill maxime* trouve dans le dossier source .agents/skills."
    }

    $skillDirs | ForEach-Object {
        $dest = Join-Path $skillsTargetRoot $_.Name
        Backup-DirectoryIfExists -Path $dest -BackupDir (Join-Path $backupDir 'skills')
        Copy-Item $_.FullName $skillsTargetRoot -Recurse -Force
    }

    if (-not $WhatIfPreference) {
        Write-Host "mA.xI.me installe pour Codex (workspace)." -ForegroundColor Green
        Write-Host "Repo cible: $RepoRoot"
        Write-Host "Instructions: $agentsTarget"
        Write-Host "Skills: $skillsTargetRoot"
        Write-Host "Backups locaux: $backupDir"
    }
}

try {
    Assert-RepoOnlyMode
    $workspaceRepoRoot = Resolve-WorkspaceRepoRoot

    if ($PSCmdlet.ShouldProcess($workspaceRepoRoot, "Installer mA.xI.me pour la cible '$Target'")) {
        Initialize-MaximeLocalState -RepoRoot $workspaceRepoRoot

        switch ($Target) {
            'claude' { Install-ClaudeWorkspace -RepoRoot $workspaceRepoRoot }
            'copilot' { Install-CopilotWorkspace -RepoRoot $workspaceRepoRoot }
            'codex' { Install-CodexWorkspace -RepoRoot $workspaceRepoRoot }
            'both' {
                Install-ClaudeWorkspace -RepoRoot $workspaceRepoRoot
                Install-CopilotWorkspace -RepoRoot $workspaceRepoRoot
            }
            'all' {
                Install-ClaudeWorkspace -RepoRoot $workspaceRepoRoot
                Install-CopilotWorkspace -RepoRoot $workspaceRepoRoot
                Install-CodexWorkspace -RepoRoot $workspaceRepoRoot
            }
        }
    }
}
catch {
    Write-Host "Echec de l'installation : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Les backups (si applicables) ont ete conserves." -ForegroundColor Yellow
    exit 1
}
