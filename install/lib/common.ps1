# Helpers partages par les scripts install/lib/*.ps1. Dot-source uniquement,
# jamais execute directement.

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
    param(
        [string]$WorkspaceRoot
    )

    if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) {
        $autoRepoRoot = Resolve-GitRepoRoot -StartPath (Get-Location).Path
        if ([string]::IsNullOrWhiteSpace($autoRepoRoot)) {
            throw "Aucun repo git detecte dans le repertoire courant. Fournis -WorkspaceRoot <chemin-du-repo-cible>."
        }
        return $autoRepoRoot
    }

    $resolvedWorkspace = (Resolve-Path -Path $WorkspaceRoot).Path
    $repoRoot = Resolve-GitRepoRoot -StartPath $resolvedWorkspace
    if ([string]::IsNullOrWhiteSpace($repoRoot)) {
        throw "Le chemin -WorkspaceRoot '$resolvedWorkspace' ne pointe pas vers un repo git valide."
    }

    return $repoRoot
}

function Add-GitExcludeEntries {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [Parameter(Mandatory = $true)]
        [string[]]$Entries
    )

    if ($WhatIfPreference) {
        $Entries | ForEach-Object { Write-Host "What if: add $_ to the target repo's Git local exclude file" }
        return
    }

    $excludePath = (& git -C $RepoRoot rev-parse --git-path info/exclude).Trim()
    if (![System.IO.Path]::IsPathRooted($excludePath)) {
        $excludePath = Join-Path $RepoRoot $excludePath
    }
    $excludeDirectory = Split-Path $excludePath -Parent
    New-Item -ItemType Directory -Force -Path $excludeDirectory | Out-Null
    $existing = if (Test-Path $excludePath) { Get-Content -Path $excludePath } else { @() }
    foreach ($entry in $Entries) {
        if ($existing -notcontains $entry) {
            Add-Content -Path $excludePath -Value $entry -Encoding UTF8
        }
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

function Add-GitignoreEntries {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [Parameter(Mandatory = $true)]
        [string]$Header,
        [Parameter(Mandatory = $true)]
        [string[]]$Entries
    )

    if ($WhatIfPreference) {
        Write-Host "What if: add '$Header' block to the target repo's .gitignore"
        return
    }

    $gitignorePath = Join-Path $RepoRoot '.gitignore'
    $existing = if (Test-Path $gitignorePath) { @(Get-Content -Path $gitignorePath) } else { @() }
    $wanted = @($Header) + $Entries
    $missing = $wanted | Where-Object { $existing -notcontains $_ }
    if (@($missing).Count -eq 0) { return }

    if (($existing.Count -gt 0) -and ($existing[-1] -ne '')) {
        Add-Content -Path $gitignorePath -Value '' -Encoding UTF8
    }
    if ($existing -notcontains $Header) {
        Add-Content -Path $gitignorePath -Value $Header -Encoding UTF8
    }
    foreach ($entry in $Entries) {
        if ($existing -notcontains $entry) {
            Add-Content -Path $gitignorePath -Value $entry -Encoding UTF8
        }
    }
}

function Remove-GitignoreEntries {
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$Header,
        [Parameter(Mandatory = $true)][string[]]$Entries
    )
    if ($WhatIfPreference) {
        Write-Host "What if: remove '$Header' block from the target repo's .gitignore"
        return
    }
    $gitignorePath = Join-Path $RepoRoot '.gitignore'
    if (!(Test-Path $gitignorePath)) { return }
    $existing = Get-Content -Path $gitignorePath
    $toRemove = @($Header) + $Entries
    $filtered = $existing | Where-Object { $_ -notin $toRemove }
    if (@($filtered).Count -ne @($existing).Count) {
        Set-Content -Path $gitignorePath -Value $filtered -Encoding UTF8
    }
}
