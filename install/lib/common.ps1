# Helpers partages par les scripts install/lib/*.ps1. Dot-source uniquement,
# jamais execute directement.

# Present in the header of every file generate-adapters.* produces -- used to
# tell "this is our own prior output" apart from "the target repo already had
# its own project-specific file before mA.xI.me was installed" (issue #27).
$script:MaximeGeneratedMarker = 'Generated from `core/socle.md`. Do not edit directly.'

function Save-PreExistingProjectContent {
    <#
    Before a generated file overwrites TargetPath, checks whether TargetPath
    already exists and is NOT one of mA.xI.me's own prior outputs (no
    generated-marker). If so, moves its content to PreserveDestination
    (created once, never touched again on later installs) so it survives the
    overwrite -- instead of only living in a timestamped .bkp/ folder. Returns
    $true if content was preserved this way.
    #>
    param(
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$PreserveDestination,
        [string]$PreserveHeader
    )
    if (!(Test-Path $TargetPath)) { return $false }
    if (Test-Path $PreserveDestination) { return $false }
    $content = Get-Content -Raw -Path $TargetPath
    if ($content.Contains($script:MaximeGeneratedMarker)) { return $false }

    $preserveDir = Split-Path $PreserveDestination -Parent
    New-Item -ItemType Directory -Force -Path $preserveDir | Out-Null
    if ($PreserveHeader) {
        Set-Content -Path $PreserveDestination -Value ($PreserveHeader + $content) -Encoding UTF8 -NoNewline
    }
    else {
        Copy-Item $TargetPath $PreserveDestination -Force
    }
    return $true
}

function Merge-MaximeManagedBlock {
    <#
    For hosts with no confirmed native import/merge mechanism (Codex/AGENTS.md
    -- the override-file semantics found in research were ambiguous, "at most
    one file used per directory" suggests replace, not merge). Writes
    GeneratedContent inside an explicit marker block instead of overwriting
    TargetPath wholesale:
    - No pre-existing file: write the block alone.
    - Pre-existing file with a managed block already: replace ONLY that
      block, leave everything else in the file untouched.
    - Pre-existing file that's an old-style fully-generated mA.xI.me output
      (has the generated-marker, no block yet): replace wholesale with the
      block -- there was never any project content to lose.
    - Pre-existing file with real project content, never touched before:
      append the block, preserve everything that was there.
    Returns $true if the resulting file mixes managed and non-managed content
    (caller should then skip default git-exclude for that file -- it is no
    longer purely tool-owned).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$GeneratedContent
    )
    $beginMarker = '<!-- BEGIN mA.xI.me generated -->'
    $endMarker = '<!-- END mA.xI.me generated -->'
    $block = "$beginMarker`n$GeneratedContent`n$endMarker"

    if (!(Test-Path $TargetPath)) {
        Set-Content -Path $TargetPath -Value $block -Encoding UTF8 -NoNewline
        return $false
    }

    $existing = Get-Content -Raw -Path $TargetPath
    $beginIdx = $existing.IndexOf($beginMarker)
    $endIdx = $existing.IndexOf($endMarker)

    if ($beginIdx -ge 0 -and $endIdx -ge 0) {
        $before = $existing.Substring(0, $beginIdx)
        $after = $existing.Substring($endIdx + $endMarker.Length)
        Set-Content -Path $TargetPath -Value ($before + $block + $after) -Encoding UTF8 -NoNewline
        return (($before.Trim() + $after.Trim()).Length -gt 0)
    }
    elseif ($existing.Contains($script:MaximeGeneratedMarker)) {
        Set-Content -Path $TargetPath -Value $block -Encoding UTF8 -NoNewline
        return $false
    }
    else {
        Set-Content -Path $TargetPath -Value ($existing.TrimEnd() + "`n`n" + $block) -Encoding UTF8 -NoNewline
        return $true
    }
}

function Remove-MaximeManagedBlock {
    <#
    Mirror of Merge-MaximeManagedBlock for uninstall. If TargetPath contains
    an explicit marker block, removes ONLY that block, leaving any
    surrounding project content untouched (deletes the file entirely if
    nothing remains), and returns $true. If no marker block is found, does
    nothing and returns $false -- caller falls back to its normal whole-file
    removal (pre-fix installs never had a block to begin with).
    #>
    param(
        [Parameter(Mandatory = $true)][string]$TargetPath
    )
    if (!(Test-Path $TargetPath)) { return $false }
    $beginMarker = '<!-- BEGIN mA.xI.me generated -->'
    $endMarker = '<!-- END mA.xI.me generated -->'
    $existing = Get-Content -Raw -Path $TargetPath
    $beginIdx = $existing.IndexOf($beginMarker)
    $endIdx = $existing.IndexOf($endMarker)
    if ($beginIdx -lt 0 -or $endIdx -lt 0) { return $false }

    $before = $existing.Substring(0, $beginIdx)
    $after = $existing.Substring($endIdx + $endMarker.Length)
    $remaining = ($before.TrimEnd() + "`n" + $after.TrimStart()).Trim()
    if ($remaining.Length -eq 0) {
        Remove-Item -Path $TargetPath -Force
    }
    else {
        Set-Content -Path $TargetPath -Value $remaining -Encoding UTF8 -NoNewline
    }
    return $true
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

function Write-MaximeVersionMarker {
    param(
        [Parameter(Mandatory = $true)][string]$SrcRepoRoot,
        [Parameter(Mandatory = $true)][string]$TargetPath,
        [Parameter(Mandatory = $true)][string]$BackupDir
    )
    # Computed live at install time, never copied from a committed file: a
    # SHA baked into a generated file is always at least one commit stale
    # (it can't know the commit that carries it). See decisions-log
    # 2026-07-16. Wrapped in try/catch: under $ErrorActionPreference =
    # 'Stop', a native command writing to stderr (e.g. git outside a git
    # repo) raises a terminating error even with 2>$null.
    try {
        $sha = (& git -C $SrcRepoRoot rev-parse HEAD 2>$null)
        if ($LASTEXITCODE -eq 0 -and $sha) {
            Backup-IfExists -Path $TargetPath -BackupDir $BackupDir
            Set-Content -Path $TargetPath -Value $sha.Trim() -Encoding UTF8 -NoNewline
        }
    }
    catch {
        # Not a git repository -- no version marker, not fatal.
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
