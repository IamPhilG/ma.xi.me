[CmdletBinding(SupportsShouldProcess)]
param()

# Installe mA.xI.me dans ~/.claude (CLAUDE.md + agents/skills maxime*).
# Ne touche pas aux dossiers locaux (sessions, cache, credentials).
# Supporte -WhatIf (simulation) et -Confirm.
$ErrorActionPreference = 'Stop'

$target  = "$HOME\.claude"
$src     = Split-Path $PSScriptRoot -Parent
$stamp   = Get-Date -Format yyyyMMdd-HHmmss
$backups = "$target\backups"

try {
    if (!(Test-Path $target)) {
        New-Item -ItemType Directory -Force -Path $target | Out-Null
    } else {
        # Backup horodaté de l'existant AVANT toute écriture.
        # En cas d'échec du backup -> on s'arrête, on n'écrase rien.
        if (!(Test-Path $backups)) {
          New-Item -ItemType Directory -Force -Path $backups | Out-Null
        }
        foreach ($d in @("agents","skills")) {
            if (Test-Path "$target\$d") {
                $bk = "$backups\$d-pre-maxime-$stamp"
                New-Item -ItemType Directory -Force -Path $bk | Out-Null
                Copy-Item "$target\$d\*" $bk -Recurse -Force
            }
        }
        if (Test-Path "$target\CLAUDE.md") {
            Copy-Item "$target\CLAUDE.md" "$backups\CLAUDE-pre-maxime-$stamp.md" -Force
        }
    }

    # Installation : seulement les fichiers maxime*.
    Copy-Item "$src\CLAUDE.md" "$target\CLAUDE.md" -Force
    New-Item -ItemType Directory -Force -Path "$target\agents","$target\skills" | Out-Null
    Copy-Item "$src\agents\maxime*" "$target\agents\" -Recurse -Force
    Copy-Item "$src\skills\maxime*" "$target\skills\" -Recurse -Force

    if (-not $WhatIfPreference) {
        Write-Host "mA.xI.me installe dans $target. Verifie avec /memory, /agents dans Claude Code." -ForegroundColor Green
    }
}
catch {
    Write-Host "Echec de l'installation : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Rien n'a ete valide au-dela de ce point. Backups dans $backups." -ForegroundColor Yellow
    exit 1
}