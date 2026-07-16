[CmdletBinding()]
param(
    [string]$WorkspaceRoot,
    [switch]$Apply,
    [int]$KeepHandoffs = 5,
    [int]$RetainSpecsDays = 30,
    [int]$RetainResultsDays = 30,
    [int]$RetainToolsDays = 14,
    [int]$RetainTestsDays = 30,
    [int]$RetainKbArchivedDays = 90,
    [int]$RetainTmpDays = 1,
    [switch]$NoReport
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    param([string]$InputRoot)

    if ([string]::IsNullOrWhiteSpace($InputRoot)) {
        return (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
    }

    $resolved = (Resolve-Path $InputRoot).Path
    if ([System.IO.Path]::GetFileName($resolved) -eq '.wip') {
        return (Resolve-Path (Join-Path $resolved '..')).Path
    }

    return $resolved
}

function Ensure-UnderWip {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$WipRoot
    )

    $full = [System.IO.Path]::GetFullPath($Path)
    $root = [System.IO.Path]::GetFullPath($WipRoot).TrimEnd('\') + '\'
    return $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)
}

function Add-Candidate {
    param(
        [Parameter(Mandatory = $true)] $List,
        [Parameter(Mandatory = $true)] [string]$Path,
        [Parameter(Mandatory = $true)] [string]$Reason,
        [Parameter(Mandatory = $true)] [string]$WipRoot
    )

    if (Ensure-UnderWip -Path $Path -WipRoot $WipRoot) {
        $List.Add([pscustomobject]@{ Path = $Path; Reason = $Reason })
    }
}

function Get-AgeCandidates {
    param(
        [Parameter(Mandatory = $true)] [string]$Directory,
        [Parameter(Mandatory = $true)] [int]$RetainDays,
        [Parameter(Mandatory = $true)] [string]$WipRoot,
        [Parameter(Mandatory = $true)] $List,
        [string[]]$ExcludeNames = @()
    )

    if (!(Test-Path $Directory)) {
        return
    }

    $limit = (Get-Date).AddDays(-$RetainDays)
    Get-ChildItem -Path $Directory -File -Recurse | ForEach-Object {
        if ($ExcludeNames -contains $_.Name) {
            return
        }
        if ($_.LastWriteTime -lt $limit) {
            Add-Candidate -List $List -Path $_.FullName -Reason "older-than-$RetainDays-days" -WipRoot $WipRoot
        }
    }
}

$repoRoot = Resolve-RepoRoot -InputRoot $WorkspaceRoot
$wipRoot = Join-Path $repoRoot '.wip'
if (!(Test-Path $wipRoot)) {
    throw "Missing .wip directory at '$wipRoot'."
}

$memoryRoot = Join-Path $wipRoot 'memory'
$specsRoot = Join-Path $wipRoot 'specs'
$adrRoot = Join-Path $wipRoot 'adr'
$resultsRoot = Join-Path $wipRoot 'results'
$toolsRoot = Join-Path $wipRoot 'tools'
$testsRoot = Join-Path $wipRoot 'tests'
$kbArchivedRoot = Join-Path $wipRoot 'kb\archived'
$kbIndexPath = Join-Path $wipRoot 'kb\index.json'
$tmpRoot = Join-Path $wipRoot 'tmp'

$candidates = New-Object 'System.Collections.Generic.List[object]'

if (Test-Path $memoryRoot) {
    $handoffs = Get-ChildItem -Path $memoryRoot -File -Filter '*.session-handoff.md' |
        Sort-Object LastWriteTime -Descending
    if ($handoffs.Count -gt $KeepHandoffs) {
        $handoffs | Select-Object -Skip $KeepHandoffs | ForEach-Object {
            Add-Candidate -List $candidates -Path $_.FullName -Reason 'old-handoff' -WipRoot $wipRoot
        }
    }
}

Get-AgeCandidates -Directory $specsRoot -RetainDays $RetainSpecsDays -WipRoot $wipRoot -List $candidates
Get-AgeCandidates -Directory $resultsRoot -RetainDays $RetainResultsDays -WipRoot $wipRoot -List $candidates
Get-AgeCandidates -Directory $testsRoot -RetainDays $RetainTestsDays -WipRoot $wipRoot -List $candidates
# Only kb/archived/ is age-purged (issue #20, point 3): kb/active/ fiches are
# never auto-deleted by age, only flagged for revalidation via ttl_days
# (maxime-kb rule 9). A fiche must be explicitly archived first.
Get-AgeCandidates -Directory $kbArchivedRoot -RetainDays $RetainKbArchivedDays -WipRoot $wipRoot -List $candidates
# .wip/tmp/ is for genuinely ephemeral work only (see core/socle.md: never
# write outside the target repo, use .wip/tmp/ instead) -- short default
# retention, nothing there is meant to survive long.
Get-AgeCandidates -Directory $tmpRoot -RetainDays $RetainTmpDays -WipRoot $wipRoot -List $candidates
Get-AgeCandidates -Directory $toolsRoot -RetainDays $RetainToolsDays -WipRoot $wipRoot -List $candidates -ExcludeNames @(
    'cleanup-wip.ps1',
    'cleanup-wip.sh',
    'generate-adapters.ps1',
    'generate-adapters.sh',
    'check-adapter-sync.ps1',
    'check-adapter-sync.sh',
    'check-codex-skills-sync.ps1',
    'check-codex-skills-sync.sh'
)

$uniqueCandidates = $candidates |
    Group-Object Path |
    ForEach-Object { $_.Group | Select-Object -First 1 } |
    Sort-Object Path

$deleted = New-Object 'System.Collections.Generic.List[string]'
$failed = New-Object 'System.Collections.Generic.List[string]'

$deletedKbPaths = New-Object 'System.Collections.Generic.List[string]'

if ($Apply.IsPresent) {
    foreach ($item in $uniqueCandidates) {
        try {
            Remove-Item -Path $item.Path -Force
            $deleted.Add($item.Path)
            if ($item.Path.StartsWith($kbArchivedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                $relativeToKb = [System.IO.Path]::GetRelativePath((Join-Path $wipRoot 'kb'), $item.Path).Replace('\', '/')
                $deletedKbPaths.Add($relativeToKb)
            }
        }
        catch {
            $failed.Add("$($item.Path) :: $($_.Exception.Message)")
        }
    }

    # index.json never holds `content` (only short metadata), so ConvertTo-Json
    # is safe here -- unlike large fiche content, which must use manual string
    # escaping (see .wip/kb/ migration notes, 2026-07-16: ConvertTo-Json hangs
    # on long strings in this PowerShell version).
    if ($deletedKbPaths.Count -gt 0 -and (Test-Path $kbIndexPath)) {
        try {
            $index = Get-Content -Raw -Path $kbIndexPath | ConvertFrom-Json
            $remaining = @($index | Where-Object { $deletedKbPaths -notcontains $_.path })
            $json = if ($remaining.Count -eq 0) { '[]' } else { $remaining | ConvertTo-Json -Depth 5 }
            Set-Content -Path $kbIndexPath -Value $json -Encoding UTF8
        }
        catch {
            $failed.Add("$kbIndexPath :: $($_.Exception.Message)")
        }
    }

    foreach ($dir in @($specsRoot, $resultsRoot, $testsRoot, $toolsRoot, $memoryRoot, $kbArchivedRoot, $tmpRoot)) {
        if (!(Test-Path $dir)) { continue }
        Get-ChildItem -Path $dir -Directory -Recurse |
            Sort-Object FullName -Descending |
            ForEach-Object {
                if ((Get-ChildItem -Path $_.FullName -Force | Measure-Object).Count -eq 0) {
                    try {
                        Remove-Item -Path $_.FullName -Force
                    }
                    catch {
                        $failed.Add("$($_.FullName) :: $($_.Exception.Message)")
                    }
                }
            }
    }
}

if (-not $NoReport.IsPresent) {
    $reportDir = Join-Path $wipRoot 'results'
    New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $reportPath = Join-Path $reportDir "$stamp.wip-cleanup-report.md"

    $mode = if ($Apply.IsPresent) { 'APPLY' } else { 'DRY-RUN' }
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add('# WIP Cleanup Report')
    $lines.Add('')
    $lines.Add("- Mode: $mode")
    $lines.Add("- Repo root: $repoRoot")
    $lines.Add("- WIP root: $wipRoot")
    $lines.Add("- Keep handoffs: $KeepHandoffs")
    $lines.Add("- Retention days: specs=$RetainSpecsDays results=$RetainResultsDays tools=$RetainToolsDays tests=$RetainTestsDays kb-archived=$RetainKbArchivedDays tmp=$RetainTmpDays")
    $lines.Add('')
    $lines.Add('## Candidates')

    if ($uniqueCandidates.Count -eq 0) {
        $lines.Add('- none')
    }
    else {
        foreach ($item in $uniqueCandidates) {
            $rel = [System.IO.Path]::GetRelativePath($repoRoot, $item.Path).Replace('\', '/')
            $lines.Add("- $rel ($($item.Reason))")
        }
    }

    if ($Apply.IsPresent) {
        $lines.Add('')
        $lines.Add('## Deleted')
        if ($deleted.Count -eq 0) {
            $lines.Add('- none')
        }
        else {
            foreach ($path in $deleted) {
                $rel = [System.IO.Path]::GetRelativePath($repoRoot, $path).Replace('\\', '/')
                $lines.Add("- $rel")
            }
        }

        $lines.Add('')
        $lines.Add('## Failures')
        if ($failed.Count -eq 0) {
            $lines.Add('- none')
        }
        else {
            foreach ($entry in $failed) {
                $lines.Add("- $entry")
            }
        }
    }

    Set-Content -Path $reportPath -Value ($lines -join "`n") -Encoding UTF8
    Write-Host "WIP cleanup report: $reportPath"
}

if ($Apply.IsPresent) {
    Write-Host "WIP cleanup applied. Deleted: $($deleted.Count). Failures: $($failed.Count)."
    if ($failed.Count -gt 0) { exit 1 }
}
else {
    Write-Host "WIP cleanup dry-run complete. Candidates: $($uniqueCandidates.Count)."
}
