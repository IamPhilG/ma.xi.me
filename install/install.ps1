[CmdletBinding(SupportsShouldProcess)]
param(
    [ValidateSet('claude', 'copilot', 'both')]
    [string]$Target = 'claude',

    [ValidateSet('user', 'workspace')]
    [string]$CopilotScope = 'user'
)

# Installe mA.xI.me pour Claude et/ou GitHub Copilot.
# - Claude: ~/.claude (CLAUDE.md + agents/skills maxime*)
# - Copilot user: ~/.copilot/agents + dossier prompts VS Code
# - Copilot workspace: ./.github (copilot-instructions + agents + prompts)
# Supporte -WhatIf (simulation) et -Confirm.
$ErrorActionPreference = 'Stop'

$src   = Split-Path $PSScriptRoot -Parent
$stamp = Get-Date -Format yyyyMMdd-HHmmss

function Install-Claude {
    $target  = "$HOME\.claude"
    $backups = "$target\backups"

    if (!(Test-Path $target)) {
        New-Item -ItemType Directory -Force -Path $target | Out-Null
    }
    else {
        if (!(Test-Path $backups)) {
            New-Item -ItemType Directory -Force -Path $backups | Out-Null
        }
        foreach ($d in @('agents', 'skills')) {
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

    Copy-Item "$src\CLAUDE.md" "$target\CLAUDE.md" -Force
    New-Item -ItemType Directory -Force -Path "$target\agents", "$target\skills" | Out-Null
    Copy-Item "$src\agents\maxime*" "$target\agents\" -Recurse -Force
    Copy-Item "$src\skills\maxime*" "$target\skills\" -Recurse -Force

    if (-not $WhatIfPreference) {
        Write-Host "mA.xI.me installe pour Claude dans $target." -ForegroundColor Green
    }
}

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

function Install-Copilot {
    $copilotSrc = Join-Path $src '.copilot'
    if (!(Test-Path $copilotSrc)) {
        throw "Le dossier source .copilot est introuvable dans le repo."
    }

    if ($CopilotScope -eq 'workspace') {
        $ghRoot = Join-Path $src '.github'
        $agentsTarget = Join-Path $ghRoot 'agents'
        $promptsTarget = Join-Path $ghRoot 'prompts'
        $instructionsTarget = Join-Path $ghRoot 'copilot-instructions.md'
        $memoryTarget = Join-Path $src '.copilot\memory\session-handoff.md'
        $backupDir = "$HOME\.copilot\backups\$stamp"
    }
    else {
        $agentsTarget = "$HOME\.copilot\agents"
        if ([string]::IsNullOrWhiteSpace($env:APPDATA)) {
            throw "APPDATA est introuvable. Impossible de determiner le dossier prompts VS Code."
        }
        $promptsTarget = Join-Path $env:APPDATA 'Code\User\prompts'
        $instructionsTarget = Join-Path $promptsTarget 'maxime-global.instructions.md'
        $memoryTarget = $null
        $backupDir = "$HOME\.copilot\backups\$stamp"
    }

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

    if ($CopilotScope -eq 'workspace') {
        $memoryDir = Split-Path $memoryTarget -Parent
        New-Item -ItemType Directory -Force -Path $memoryDir | Out-Null
        $memorySource = Join-Path $copilotSrc 'memory\session-handoff.md'
        $sameMemoryPath = ([System.IO.Path]::GetFullPath($memorySource) -eq [System.IO.Path]::GetFullPath($memoryTarget))
        if (-not $sameMemoryPath) {
            Backup-IfExists -Path $memoryTarget -BackupDir $backupDir
            Copy-Item $memorySource $memoryTarget -Force
        }
    }

    if (-not $WhatIfPreference) {
        Write-Host "mA.xI.me installe pour Copilot ($CopilotScope)." -ForegroundColor Green
        Write-Host "Instructions: $instructionsTarget"
        Write-Host "Agents: $agentsTarget"
        Write-Host "Prompts: $promptsTarget"
    }
}

try {
    switch ($Target) {
        'claude' { Install-Claude }
        'copilot' { Install-Copilot }
        'both' {
            Install-Claude
            Install-Copilot
        }
    }
}
catch {
    Write-Host "Echec de l'installation : $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Les backups (si applicables) ont ete conserves." -ForegroundColor Yellow
    exit 1
}