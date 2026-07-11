[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
if (!(Test-Path (Join-Path $repoRoot 'skills'))) {
    $parentRoot = Split-Path $repoRoot -Parent
    if (Test-Path (Join-Path $parentRoot 'skills')) {
        $repoRoot = $parentRoot
    }
    else {
        throw "Repository root not found from '$PSScriptRoot' (missing skills/)."
    }
}
$sourceRoot = Join-Path $repoRoot 'skills'
$targetRoot = Join-Path $repoRoot '.agents\skills'
$problems = New-Object System.Collections.Generic.List[string]

function Get-RelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $pathFull = [System.IO.Path]::GetFullPath($Path)
    return $pathFull.Substring($rootFull.Length).Replace('\', '/')
}

if (!(Test-Path $sourceRoot)) {
    throw "Source skills directory not found: $sourceRoot"
}
if (!(Test-Path $targetRoot)) {
    throw "Codex skills directory not found: $targetRoot"
}

$sourceFiles = Get-ChildItem -Path (Join-Path $sourceRoot 'maxime*') -Recurse -File
$targetFiles = Get-ChildItem -Path (Join-Path $targetRoot 'maxime*') -Recurse -File

$sourceMap = @{}
foreach ($file in $sourceFiles) {
    $relative = Get-RelativePath -Root $sourceRoot -Path $file.FullName
    $sourceMap[$relative] = $file.FullName
}

$targetMap = @{}
foreach ($file in $targetFiles) {
    $relative = Get-RelativePath -Root $targetRoot -Path $file.FullName
    $targetMap[$relative] = $file.FullName
}

foreach ($relative in ($sourceMap.Keys | Sort-Object)) {
    if (!$targetMap.ContainsKey($relative)) {
        $problems.Add("Missing in .agents/skills: $relative")
        continue
    }

    $sourceHash = (Get-FileHash -Algorithm SHA256 -Path $sourceMap[$relative]).Hash
    $targetHash = (Get-FileHash -Algorithm SHA256 -Path $targetMap[$relative]).Hash
    if ($sourceHash -ne $targetHash) {
        $problems.Add("Different content: $relative")
    }
}

foreach ($relative in ($targetMap.Keys | Sort-Object)) {
    if (!$sourceMap.ContainsKey($relative)) {
        $problems.Add("Extra in .agents/skills: $relative")
    }
}

if ($problems.Count -gt 0) {
    Write-Host "Codex skills are out of sync:" -ForegroundColor Red
    $problems | ForEach-Object { Write-Host "- $_" }
    exit 1
}

Write-Host "Codex skills are in sync." -ForegroundColor Green
