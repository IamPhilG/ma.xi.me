<#
.SYNOPSIS
Detecte et retire les artefacts globaux (hors repo) laisses par d'anciennes
versions de mA.xI.me qui installaient globalement, avant le mode repo-only.

.DESCRIPTION
mA.xI.me est desormais strictement repo-only : aucune installation ne doit
toucher les repertoires globaux de l'utilisateur. Les toutes premieres
versions (avant "Enforce repo-only installer mode") ecrivaient cependant
dans :
  - ~/.claude       (CLAUDE.md, agents/maxime*, skills/maxime-*)
  - ~/.copilot      (agents/maxime*.agent.md, instructions/maxime-global.instructions.md)
  - ~/.codex        (AGENTS.md)
  - ~/.agents       (skills/maxime-*)

Ce script scanne ces emplacements. Les fichiers/dossiers identifiables sans
ambiguite comme provenant de mA.xI.me (motif maxime*/maxi-*) peuvent etre
retires avec -Apply. Les fichiers partages ambigus (~/.claude/CLAUDE.md,
~/.codex/AGENTS.md) ne sont jamais supprimes automatiquement : ils peuvent
tout autant etre le fichier personnel de l'utilisateur qu'un reliquat
mA.xI.me, et une suppression a tort serait couteuse. Ils sont seulement
signales pour decision manuelle.

Mode dry-run par defaut (aucune suppression). -Apply supprime reellement les
elements non ambigus.

.PARAMETER Apply
Supprime reellement les elements non ambigus detectes. Sans cette option,
le script se contente de lister ce qu'il trouve.

.EXAMPLE
.\tools\cleanup-global.ps1

Liste les artefacts globaux mA.xI.me trouves, ne supprime rien.

.EXAMPLE
.\tools\cleanup-global.ps1 -Apply

Supprime les artefacts non ambigus trouves (agents/skills nommes maxime*).
#>
[CmdletBinding()]
param(
    [switch]$Apply,

    # Reserve aux tests (tools/check-decisions.ps1) : simule un autre repertoire home
    # sans toucher au vrai profil utilisateur.
    [string]$HomeOverride
)

$ErrorActionPreference = 'Stop'
$homeDir = if ($HomeOverride) { $HomeOverride } else { [Environment]::GetFolderPath('UserProfile') }

$unambiguous = New-Object System.Collections.Generic.List[string]
$ambiguous = New-Object System.Collections.Generic.List[string]
$informational = New-Object System.Collections.Generic.List[string]

function Add-UnambiguousTarget {
    param([string]$Path)
    if (Test-Path $Path) { $unambiguous.Add($Path) }
}

function Add-UnambiguousGlob {
    param([string]$Directory, [string]$Filter, [string]$ItemType)
    if (!(Test-Path $Directory)) { return }
    $items = if ($ItemType -eq 'Directory') {
        Get-ChildItem -Path $Directory -Filter $Filter -Directory -ErrorAction SilentlyContinue
    }
    else {
        Get-ChildItem -Path $Directory -Filter $Filter -File -ErrorAction SilentlyContinue
    }
    $items | ForEach-Object { $unambiguous.Add($_.FullName) }
}

function Add-AmbiguousIfExists {
    param([string]$Path, [string]$Reason)
    if (Test-Path $Path) { $ambiguous.Add("$Path -- $Reason") }
}

function Add-InformationalIfExists {
    param([string]$Path, [string]$Reason)
    if (Test-Path $Path) { $informational.Add("$Path -- $Reason") }
}

# --- ~/.claude (generation 1 : install global historique) ---
Add-UnambiguousGlob -Directory (Join-Path $homeDir '.claude\agents') -Filter 'maxime*.md' -ItemType File
Add-UnambiguousGlob -Directory (Join-Path $homeDir '.claude\skills') -Filter 'maxime-*' -ItemType Directory
Add-AmbiguousIfExists -Path (Join-Path $homeDir '.claude\CLAUDE.md') `
    -Reason 'peut etre ton CLAUDE.md personnel ou un reliquat mA.xI.me -- verifie le contenu avant toute action'
Add-InformationalIfExists -Path (Join-Path $homeDir '.claude\backups') `
    -Reason 'backups locaux Claude Code (peuvent contenir ton contenu pre-mA.xI.me original si un install global a deja ecrase quelque chose)'

# --- ~/.copilot (generation 2 : install global Copilot) ---
Add-UnambiguousGlob -Directory (Join-Path $homeDir '.copilot\agents') -Filter 'maxime*.agent.md' -ItemType File
Add-UnambiguousTarget -Path (Join-Path $homeDir '.copilot\instructions\maxime-global.instructions.md')
Add-InformationalIfExists -Path (Join-Path $homeDir '.copilot\backups') -Reason 'backups locaux Copilot'

# --- ~/.codex + ~/.agents (generation 3 : install global Codex) ---
Add-AmbiguousIfExists -Path (Join-Path $homeDir '.codex\AGENTS.md') `
    -Reason 'peut etre ta config Codex globale personnelle ou un reliquat mA.xI.me -- verifie le contenu avant toute action'
Add-InformationalIfExists -Path (Join-Path $homeDir '.codex\backups') -Reason 'backups locaux Codex'
Add-UnambiguousGlob -Directory (Join-Path $homeDir '.agents\skills') -Filter 'maxime-*' -ItemType Directory

Write-Host 'mA.xI.me est repo-only depuis la refonte de phase 1 -- ce script cherche des reliquats de versions plus anciennes.' -ForegroundColor Cyan
Write-Host ''

if ($unambiguous.Count -eq 0) {
    Write-Host 'Aucun artefact global non ambigu trouve.' -ForegroundColor Green
}
else {
    Write-Host "Artefacts mA.xI.me non ambigus trouves ($($unambiguous.Count)) :" -ForegroundColor Yellow
    $unambiguous | ForEach-Object { Write-Host "  - $_" }
}

if ($ambiguous.Count -gt 0) {
    Write-Host ''
    Write-Host 'Fichiers ambigus (jamais supprimes automatiquement, decision manuelle requise) :' -ForegroundColor Yellow
    $ambiguous | ForEach-Object { Write-Host "  - $_" }
}

if ($informational.Count -gt 0) {
    Write-Host ''
    Write-Host 'Informatif (non supprime, juste signale) :' -ForegroundColor DarkGray
    $informational | ForEach-Object { Write-Host "  - $_" }
}

if ($Apply -and $unambiguous.Count -gt 0) {
    Write-Host ''
    Write-Host 'Suppression des artefacts non ambigus...' -ForegroundColor Yellow
    foreach ($item in $unambiguous) {
        Remove-Item -Path $item -Recurse -Force
        Write-Host "  supprime: $item"
    }
    Write-Host 'Termine.' -ForegroundColor Green
}
elseif ($unambiguous.Count -gt 0) {
    Write-Host ''
    Write-Host "Mode lecture seule (dry-run). Relance avec -Apply pour supprimer les $($unambiguous.Count) element(s) non ambigu(s) ci-dessus." -ForegroundColor Cyan
}
