[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
if (!(Test-Path (Join-Path $repositoryRoot 'core'))) {
    $parentRoot = Split-Path $repositoryRoot -Parent
    if (Test-Path (Join-Path $parentRoot 'core')) {
        $repositoryRoot = $parentRoot
    }
    else {
        throw "Repository root not found from '$PSScriptRoot' (missing core/)."
    }
}
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("maxime-adapter-check-" + [Guid]::NewGuid())

try {
    New-Item -ItemType Directory -Path $tempRoot | Out-Null
    Copy-Item -Path (Join-Path $repositoryRoot 'core') -Destination (Join-Path $tempRoot 'core') -Recurse
    $generatorPath = Join-Path $repositoryRoot 'tools\generate-adapters.ps1'
    if (!(Test-Path $generatorPath)) {
        $generatorPath = Join-Path $repositoryRoot '.wip\tools\generate-adapters.ps1'
    }
    if (!(Test-Path $generatorPath)) {
        throw "Unable to find generate-adapters.ps1 under tools/ or .wip/tools/."
    }
    Copy-Item -Path $generatorPath -Destination (Join-Path $tempRoot 'generate-adapters.ps1')
    & (Join-Path $tempRoot 'generate-adapters.ps1') -RepositoryRoot $tempRoot

    $relativePaths = @(
        'install/Packaged/CLAUDE.md',
        'install/Packaged/AGENTS.md',
        'install/Packaged/.codex/AGENTS.md',
        'install/Packaged/.copilot/copilot-instructions.md',
        'install/Packaged/agents/maxime.md',
        'install/Packaged/.copilot/agents/maxime.agent.md'
    )
    $workflows = Get-ChildItem -Path (Join-Path $repositoryRoot 'core\workflows') -Filter 'maxime-*.md' -File
    foreach ($workflow in $workflows) {
        $name = [System.IO.Path]::GetFileNameWithoutExtension($workflow.Name)
        $relativePaths += "install/Packaged/agents/$name.md", "install/Packaged/.agents/skills/$name/SKILL.md", "install/Packaged/.copilot/agents/$name.agent.md"
    }

    $problems = New-Object System.Collections.Generic.List[string]
    foreach ($relativePath in $relativePaths) {
        $expected = Join-Path $tempRoot $relativePath
        $actual = Join-Path $repositoryRoot $relativePath
        if (!(Test-Path $actual)) {
            $problems.Add("Missing generated projection: $relativePath")
            continue
        }
        if ((Get-FileHash -Algorithm SHA256 $expected).Hash -ne (Get-FileHash -Algorithm SHA256 $actual).Hash) {
            $problems.Add("Out-of-sync projection: $relativePath")
        }
    }

    if ($problems.Count -gt 0) {
        Write-Host 'mA.xI.me adapters are out of sync:' -ForegroundColor Red
        $problems | ForEach-Object { Write-Host "- $_" }
        exit 1
    }

    Write-Host 'mA.xI.me adapters are in sync.' -ForegroundColor Green
}
finally {
    Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
exit 0
