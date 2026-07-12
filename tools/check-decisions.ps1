[CmdletBinding()]
param()

# Executable regression tests for the decisions recorded in .wip/adr/decisions-log.md.
# One check per structural decision. Add a new check here whenever maxime-plan adds a
# decision line, per the mA.xI.me rule: "toute decision doit avoir un test executable".

$ErrorActionPreference = 'Stop'
$repositoryRoot = Split-Path $PSScriptRoot -Parent
if (!(Test-Path (Join-Path $repositoryRoot 'core'))) {
    throw "Repository root not found from '$PSScriptRoot' (missing core/)."
}

$problems = New-Object System.Collections.Generic.List[string]
function Test-Decision {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Check
    )
    try {
        $result = & $Check
        if ($result -eq $false) {
            $problems.Add($Name)
            Write-Host "FAIL: $Name" -ForegroundColor Red
        }
        else {
            Write-Host "PASS: $Name" -ForegroundColor Green
        }
    }
    catch {
        $problems.Add("$Name (exception: $($_.Exception.Message))")
        Write-Host "FAIL: $Name -- $($_.Exception.Message)" -ForegroundColor Red
    }
}

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("maxime-decisions-check-" + [Guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot | Out-Null

try {
    # Decision: tools/ (root) contains only source-repo maintenance scripts, never
    # host-distributed tools like cleanup-wip.*.
    Test-Decision 'tools/ ne contient que les scripts de maintenance du repo source' {
        $expected = @(
            'check-adapter-sync.ps1', 'check-adapter-sync.sh',
            'check-codex-skills-sync.ps1', 'check-codex-skills-sync.sh',
            'check-decisions.ps1', 'check-decisions.sh',
            'generate-adapters.ps1', 'generate-adapters.sh'
        )
        $actual = Get-ChildItem -Path (Join-Path $repositoryRoot 'tools') -File | ForEach-Object { $_.Name }
        $unexpected = $actual | Where-Object { $_ -notin $expected }
        if ($unexpected) {
            throw "Fichiers inattendus sous tools/: $($unexpected -join ', ')"
        }
        $true
    }

    # Decision: cleanup-wip is distributed to target repos from core/tools/.
    Test-Decision 'core/tools/ contient cleanup-wip.ps1 et .sh (source canonique distribuee)' {
        (Test-Path (Join-Path $repositoryRoot 'core\tools\cleanup-wip.ps1')) -and
        (Test-Path (Join-Path $repositoryRoot 'core\tools\cleanup-wip.sh'))
    }

    # Decision: no dated spec filenames anywhere under core/ or .wip/specs/.
    Test-Decision 'aucune spec datee (YYYYMMDD-) sous core/ ou .wip/specs/' {
        $datedPattern = '^\d{8}-'
        $hits = @()
        foreach ($dir in @('core', '.wip\specs')) {
            $full = Join-Path $repositoryRoot $dir
            if (Test-Path $full) {
                $hits += Get-ChildItem -Path $full -Recurse -File -Filter '*.md' |
                    Where-Object { $_.Name -match $datedPattern }
            }
        }
        if ($hits) {
            throw "Specs datees trouvees: $($hits.FullName -join ', ')"
        }
        $true
    }

    # Decision: docs/SPECS.md removed, no dangling reference in product docs.
    Test-Decision 'docs/SPECS.md absent et non reference dans README/ARCHITECTURE' {
        if (Test-Path (Join-Path $repositoryRoot 'docs\SPECS.md')) {
            throw 'docs/SPECS.md existe encore.'
        }
        $refs = Select-String -Path (Join-Path $repositoryRoot 'README.md'), (Join-Path $repositoryRoot 'docs\ARCHITECTURE.md') -Pattern 'SPECS\.md' -ErrorAction SilentlyContinue
        if ($refs) {
            throw "Reference residuelle a SPECS.md: $($refs.Path -join ', ')"
        }
        $true
    }

    # Decision: no leftover .wip/maxime path or bare "maxime" agent identifier in
    # portable/generated source (excludes .wip/ local narrative and this checker's
    # own source, which legitimately mentions the old name/path as literal text).
    Test-Decision 'aucun residu .wip/maxime ou identifiant agent "maxime" nu dans le source portable' {
        $scanDirs = @('core', 'agents', 'skills', '.agents', '.copilot', '.codex', 'install')
        $scanFiles = @('CLAUDE.md', 'AGENTS.md', 'README.md')
        $targets = @()
        foreach ($dir in $scanDirs) {
            $full = Join-Path $repositoryRoot $dir
            if (Test-Path $full) {
                $targets += Get-ChildItem -Path $full -Recurse -File -Include '*.md', '*.ps1', '*.sh'
            }
        }
        foreach ($file in $scanFiles) {
            $full = Join-Path $repositoryRoot $file
            if (Test-Path $full) { $targets += Get-Item $full }
        }
        $hits = $targets | Select-String -Pattern '\.wip/maxime|agent:\s*maxime\b|name:\s*maxime\b(?!-)' -ErrorAction SilentlyContinue
        if ($hits) {
            throw "Residus trouves: $($hits.Path -join ', ')"
        }
        $true
    }

    # Decision: Copilot tool identifiers use VS Code's current names (read, grep,
    # search, execute, edit, agent), never the renamed/unknown legacy names that VS
    # Code's own agent-file linter flagged (read_file, grep_search, file_search,
    # run_in_terminal, apply_patch, create_file, runSubagent).
    Test-Decision 'aucun nom d''outil Copilot obsolete (read_file/grep_search/file_search/run_in_terminal/apply_patch/create_file/runSubagent)' {
        $legacyNames = 'read_file', 'grep_search', 'file_search', 'run_in_terminal', 'apply_patch', 'create_file', 'runSubagent'
        $pattern = ($legacyNames | ForEach-Object { [regex]::Escape($_) }) -join '|'
        $targets = Get-ChildItem -Path (Join-Path $repositoryRoot '.copilot') -Recurse -File -Include '*.md' -ErrorAction SilentlyContinue
        $targets += Get-Item (Join-Path $repositoryRoot 'tools\generate-adapters.ps1'), (Join-Path $repositoryRoot 'tools\generate-adapters.sh')
        $hits = $targets | Select-String -Pattern $pattern -ErrorAction SilentlyContinue
        if ($hits) {
            throw "Noms d'outils Copilot obsoletes trouves: $($hits.Path -join ', ')"
        }
        $true
    }

    # Decision: a fresh install produces the standardized .wip/ layout and distributes
    # cleanup-wip, and cleanup-wip runs safely even without .wip/tests/ present
    # (regression test for the set -e / bare `return` bug fixed 2026-07-11).
    Test-Decision 'installation fraiche: structure .wip/ standard + cleanup-wip fonctionnel' {
        $fixture = Join-Path $tempRoot 'fixture'
        New-Item -ItemType Directory -Path $fixture | Out-Null
        Push-Location $fixture
        try {
            git init -q
        }
        finally {
            Pop-Location
        }
        & (Join-Path $repositoryRoot 'install\install.ps1') -Target claude -WorkspaceRoot $fixture | Out-Null

        foreach ($dir in @('memory', 'specs', 'adr', 'results', 'tools')) {
            if (!(Test-Path (Join-Path $fixture ".wip\$dir"))) {
                throw "Repertoire .wip/$dir manquant apres installation."
            }
        }

        $installedCleanup = Join-Path $fixture '.wip\tools\cleanup-wip.ps1'
        if (!(Test-Path $installedCleanup)) {
            throw 'cleanup-wip.ps1 non distribue dans .wip/tools/ du repo cible.'
        }
        $sourceHash = (Get-FileHash -Algorithm SHA256 (Join-Path $repositoryRoot 'core\tools\cleanup-wip.ps1')).Hash
        $installedHash = (Get-FileHash -Algorithm SHA256 $installedCleanup).Hash
        if ($sourceHash -ne $installedHash) {
            throw 'cleanup-wip.ps1 distribue ne correspond pas a core/tools/cleanup-wip.ps1.'
        }

        # .wip/tests/ deliberately does not exist here: this is the exact condition
        # that used to crash cleanup-wip.sh under set -e before the 2026-07-11 fix.
        & $installedCleanup | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "cleanup-wip.ps1 a echoue (exit $LASTEXITCODE) sur une installation fraiche sans .wip/tests/."
        }
        $true
    }

    if ($problems.Count -gt 0) {
        Write-Host ''
        Write-Host 'mA.xI.me decision checks failed:' -ForegroundColor Red
        $problems | ForEach-Object { Write-Host "- $_" }
        exit 1
    }

    Write-Host ''
    Write-Host 'mA.xI.me decision checks passed.' -ForegroundColor Green
}
finally {
    Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
