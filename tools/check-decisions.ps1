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
            'check-decisions.ps1', 'check-decisions.sh',
            'cleanup-global.ps1', 'cleanup-global.sh',
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
        $scanDirs = @('core', 'install')
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

    # Decision: Copilot tool identifiers use VS Code's current names (read, search,
    # execute, edit, agent -- no standalone 'grep', folded into 'search'), never the
    # renamed/unknown legacy names that VS Code's own agent-file linter flagged
    # (read_file, grep_search, file_search, run_in_terminal, apply_patch, create_file,
    # runSubagent).
    Test-Decision 'aucun nom d''outil Copilot obsolete (read_file/grep_search/file_search/run_in_terminal/apply_patch/create_file/runSubagent/grep)' {
        $legacyNames = 'read_file', 'grep_search', 'file_search', 'run_in_terminal', 'apply_patch', 'create_file', 'runSubagent'
        $pattern = ($legacyNames | ForEach-Object { [regex]::Escape($_) }) -join '|'
        $targets = Get-ChildItem -Path (Join-Path $repositoryRoot 'install\Packaged\.copilot') -Recurse -File -Include '*.md' -ErrorAction SilentlyContinue
        $targets += Get-Item (Join-Path $repositoryRoot 'tools\generate-adapters.ps1'), (Join-Path $repositoryRoot 'tools\generate-adapters.sh')
        $hits = $targets | Select-String -Pattern $pattern -ErrorAction SilentlyContinue
        if ($hits) {
            throw "Noms d'outils Copilot obsoletes trouves: $($hits.Path -join ', ')"
        }
        $copilotTargets = Get-ChildItem -Path (Join-Path $repositoryRoot 'install\Packaged\.copilot') -Recurse -File -Include '*.md' -ErrorAction SilentlyContinue
        $toolsLineHits = $copilotTargets | Select-String -Pattern '^tools:.*\bgrep\b' -ErrorAction SilentlyContinue
        if ($toolsLineHits) {
            throw "'grep' n'est pas un outil Copilot valide (utiliser 'search'): $($toolsLineHits.Path -join ', ')"
        }
        $true
    }

    # Decision: Codex-facing SKILL.md (.agents/skills/) must not declare
    # 'allowed-tools' -- VS Code's Codex extension rejects it (supported frontmatter:
    # argument-hint, compatibility, context, description, disable-model-invocation,
    # license, metadata, name, user-invocable). Claude-facing skills/*/SKILL.md keeps
    # it; the two are generated as distinct bodies, not copies of each other.
    Test-Decision 'aucun allowed-tools dans .agents/skills/*/SKILL.md (Codex)' {
        $hits = Get-ChildItem -Path (Join-Path $repositoryRoot 'install\Packaged\.agents\skills') -Recurse -File -Filter 'SKILL.md' -ErrorAction SilentlyContinue |
            Select-String -Pattern '^allowed-tools:' -ErrorAction SilentlyContinue
        if ($hits) {
            throw "allowed-tools trouve dans une SKILL.md Codex: $($hits.Path -join ', ')"
        }
        $true
    }

    # Decision: generate-adapters.ps1 and generate-adapters.sh must produce byte-identical
    # projections from the same core/ source. Running only one language's
    # check-adapter-sync is not enough -- it only compares that language's generator
    # against the committed files, so it can pass even if the two generators disagree
    # with each other (regression: a PowerShell here-string backtick escape sequence
    # silently corrupted generated text on 2026-07-12, undetected by check-adapter-sync.ps1
    # alone because it was comparing the bug against itself).
    Test-Decision 'generate-adapters.ps1 et .sh produisent une projection identique' {
        & (Join-Path $repositoryRoot 'tools\check-adapter-sync.ps1') | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw 'check-adapter-sync.ps1 echoue.'
        }
        $bash = Get-Command bash -ErrorAction SilentlyContinue
        if (-not $bash) {
            throw 'bash introuvable -- impossible de verifier check-adapter-sync.sh depuis ce checker.'
        }
        # Two conventions coexist on Windows depending on which 'bash' resolves first:
        # git-bash/MSYS uses /c/..., WSL uses /mnt/c/.... Try both.
        $driveLetter = $repositoryRoot.Substring(0, 1).ToLower()
        $tail = $repositoryRoot.Substring(2) -replace '\\', '/'
        $candidates = @("/$driveLetter$tail", "/mnt/$driveLetter$tail")
        $success = $false
        $previousEap = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            foreach ($candidate in $candidates) {
                try {
                    & bash -c "cd '$candidate' && bash tools/check-adapter-sync.sh" *>$null
                }
                catch {
                    continue
                }
                if ($LASTEXITCODE -eq 0) {
                    $success = $true
                    break
                }
            }
        }
        finally {
            $ErrorActionPreference = $previousEap
        }
        if (-not $success) {
            throw 'check-adapter-sync.sh echoue (les deux generateurs divergent), ou le chemin repo n''a pas pu etre resolu depuis bash.'
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

        foreach ($dir in @('memory', 'specs', 'adr', 'results', 'kb', 'tools')) {
            if (!(Test-Path (Join-Path $fixture ".wip\$dir"))) {
                throw "Repertoire .wip/$dir manquant apres installation."
            }
        }

        $excludePath = (& git -C $fixture rev-parse --git-path info/exclude).Trim()
        if (![System.IO.Path]::IsPathRooted($excludePath)) {
            $excludePath = Join-Path $fixture $excludePath
        }
        $excludeContent = if (Test-Path $excludePath) { Get-Content -Path $excludePath } else { @() }
        if (($excludeContent -notcontains '/.wip/') -or ($excludeContent -notcontains '/.bkp/')) {
            throw ".git/info/exclude ne contient pas /.wip/ et /.bkp/ apres installation (exclusion locale attendue, pas de .gitignore)."
        }
        $gitignorePath = Join-Path $fixture '.gitignore'
        if (Test-Path $gitignorePath) {
            $gitignoreContent = Get-Content -Path $gitignorePath
            if (($gitignoreContent -contains '/.wip/') -or ($gitignoreContent -contains '/.bkp/')) {
                throw "/.wip/ ou /.bkp/ trouve dans .gitignore -- cette exclusion doit rester locale via .git/info/exclude uniquement."
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

    # Decision: KB fiches under .wip/kb/ are JSON (id/type/theme/tags/scope/status/
    # confidence/audience/source/validated/created/ttl_days/links/content), not
    # Markdown+frontmatter. A fresh install creates .wip/kb/index.json (empty array),
    # .wip/kb/active/ and .wip/kb/archived/ -- never .wip/kb/INDEX.md. The generated
    # maxime-kb agent documents the JSON schema, not the old ".new" filename convention.
    Test-Decision 'KB au format JSON (index.json + active/archived), pas Markdown+INDEX.md' {
        $fixture = Join-Path $tempRoot 'fixture-kb-json'
        New-Item -ItemType Directory -Path $fixture | Out-Null
        Push-Location $fixture
        try { git init -q } finally { Pop-Location }
        & (Join-Path $repositoryRoot 'install\install.ps1') -Target claude -WorkspaceRoot $fixture | Out-Null

        $indexPath = Join-Path $fixture '.wip\kb\index.json'
        if (!(Test-Path $indexPath)) {
            throw '.wip/kb/index.json manquant apres installation fraiche.'
        }
        if (Test-Path (Join-Path $fixture '.wip\kb\INDEX.md')) {
            throw '.wip/kb/INDEX.md ne devrait plus etre cree (remplace par index.json).'
        }
        try {
            $parsed = Get-Content -Raw -Path $indexPath | ConvertFrom-Json
        }
        catch {
            throw ".wip/kb/index.json n'est pas un JSON valide: $($_.Exception.Message)"
        }
        if ($parsed.Count -ne 0) {
            throw ".wip/kb/index.json d'une installation fraiche devrait etre un tableau vide."
        }
        foreach ($dir in @('active', 'archived')) {
            if (!(Test-Path (Join-Path $fixture ".wip\kb\$dir"))) {
                throw "Repertoire .wip/kb/$dir manquant apres installation."
            }
        }

        $maximeKbAgent = Get-Content -Raw -Path (Join-Path $repositoryRoot 'install\Packaged\agents\maxime-kb.md')
        if ($maximeKbAgent -notmatch 'index\.json') {
            throw "L'agent maxime-kb genere ne mentionne pas index.json."
        }
        if ($maximeKbAgent -match '\.new\b.*ou revue|revue\)?\s*$') {
            throw "L'agent maxime-kb genere semble encore documenter l'ancienne convention de nommage .new/revue au lieu du champ status."
        }
        $true
    }

    # Decision: a fresh install creates .wip/tools/kb-network-policy.json
    # (fail-safe default: network_write false, network_read true) and writes
    # a version marker (.claude/MAXIME_VERSION) computed LIVE at install time
    # (git rev-parse HEAD of the source repo) -- never copied from a
    # committed file, which would always be at least one commit stale (it
    # can't know the commit that carries it). See decisions-log 2026-07-16.
    # maxime-kb/maxime-start/maxime-init/maxime-handoff document the new
    # network-policy, version-check, ttl-differentiation and
    # session-learnings-capture behaviors in their generated text.
    Test-Decision 'politique reseau KB + marqueur de version crees a l''installation fraiche' {
        $fixture = Join-Path $tempRoot 'fixture-kb-version'
        New-Item -ItemType Directory -Path $fixture | Out-Null
        Push-Location $fixture
        try { git init -q } finally { Pop-Location }
        & (Join-Path $repositoryRoot 'install\install.ps1') -Target claude -WorkspaceRoot $fixture | Out-Null

        $policyPath = Join-Path $fixture '.wip\tools\kb-network-policy.json'
        if (!(Test-Path $policyPath)) {
            throw '.wip/tools/kb-network-policy.json manquant apres installation fraiche.'
        }
        $policy = Get-Content -Raw -Path $policyPath | ConvertFrom-Json
        if ($policy.network_write -ne $false) {
            throw "network_write devrait etre false par defaut (fail-safe), trouve: $($policy.network_write)"
        }
        if ($policy.network_read -ne $true) {
            throw "network_read devrait etre true par defaut, trouve: $($policy.network_read)"
        }

        $installedVersionPath = Join-Path $fixture '.claude\MAXIME_VERSION'
        if (!(Test-Path $installedVersionPath)) {
            throw '.claude/MAXIME_VERSION non cree a l''installation.'
        }
        $liveSha = (& git -C $repositoryRoot rev-parse HEAD).Trim()
        $installedSha = (Get-Content -Raw -Path $installedVersionPath).Trim()
        if ($liveSha -ne $installedSha) {
            throw ".claude/MAXIME_VERSION ($installedSha) ne correspond pas au HEAD reel du repo source ($liveSha) -- devrait etre calcule en direct, pas copie d'un fichier committe."
        }

        $maximeStart = Get-Content -Raw -Path (Join-Path $repositoryRoot 'install\Packaged\agents\maxime-start.md')
        if ($maximeStart -notmatch 'MAXIME_VERSION') {
            throw "L'agent maxime-start genere ne mentionne pas la comparaison de version."
        }
        $maximeKb = Get-Content -Raw -Path (Join-Path $repositoryRoot 'install\Packaged\agents\maxime-kb.md')
        if ($maximeKb -notmatch 'kb-network-policy\.json') {
            throw "L'agent maxime-kb genere ne mentionne pas la politique reseau."
        }
        if ($maximeKb -notmatch 'ttl_days') {
            throw "L'agent maxime-kb genere ne mentionne pas ttl_days."
        }
        $maximeHandoff = Get-Content -Raw -Path (Join-Path $repositoryRoot 'install\Packaged\agents\maxime-handoff.md')
        if ($maximeHandoff -notmatch 'Maxime KB') {
            throw "L'agent maxime-handoff genere ne mentionne pas la capture de lecons via Maxime KB."
        }
        if ($maximeKb -notmatch 'network_read|network_write') {
            throw "L'agent maxime-kb genere ne mentionne pas network_read/network_write."
        }
        $maximeInit = Get-Content -Raw -Path (Join-Path $repositoryRoot 'install\Packaged\agents\maxime-init.md')
        if ($maximeInit -match 'submodule') {
            throw "L'agent maxime-init genere mentionne encore le submodule knowledge-base -- ce n'est plus sa responsabilite (deplacee vers maxime-kb, 2026-07-17)."
        }
        $true
    }

    # Decision (2026-07-17): maxime never mounts a knowledge-base/ folder or
    # submodule in the target repo -- the only local KB directory is
    # .wip/kb/. The shared repo (OurITRes/knowledge-base) is read and
    # written exclusively via the GitHub API (gh api), replacing the
    # submodule + two-repo/two-commit mechanic from issue #29 (wired once on
    # this very repo to validate it, then found undesirable and retired the
    # same day).
    Test-Decision "knowledge base partagee accedee uniquement via l'API GitHub, jamais de dossier knowledge-base/ (submodule retire, issue #29 obsolete)" {
        $maximeKbAgent = Get-Content -Raw -Path (Join-Path $repositoryRoot 'install\Packaged\agents\maxime-kb.md')
        $maximeInitAgent = Get-Content -Raw -Path (Join-Path $repositoryRoot 'install\Packaged\agents\maxime-init.md')
        if ($maximeKbAgent -notmatch 'gh api') {
            throw "L'agent maxime-kb genere ne mentionne pas l'acces via 'gh api'."
        }
        if ($maximeKbAgent -notmatch '(?i)pull request') {
            throw "L'agent maxime-kb genere ne mentionne pas l'ouverture d'une pull request pour publier."
        }
        if ($maximeKbAgent -match 'git submodule add') {
            throw "L'agent maxime-kb genere propose encore 'git submodule add' -- ce mecanisme a ete retire le 2026-07-17."
        }
        if ($maximeInitAgent -match '(?i)submodule') {
            throw "L'agent maxime-init genere mentionne 'submodule' -- ne doit jamais en avoir la responsabilite."
        }
        $true
    }

    # Decision (issue #24): the engine/effort catalog is per-host, never a
    # single universal rule -- Claude Code can pick a delegated sub-agent's
    # model itself (informing without blocking, confirming only on a clear
    # departure from the size-appropriate default), Copilot and Codex can
    # only recommend and ask (no confirmed self-configuration mechanism on
    # either platform as of the KB research date). maxime-plan documents
    # this; the 3 catalog fiches back it with sourced research.
    Test-Decision 'catalogue KB moteurs/effort par hote + politique documentee dans maxime-plan (issue #24)' {
        $maximePlanAgent = Get-Content -Raw -Path (Join-Path $repositoryRoot 'install\Packaged\agents\maxime-plan.md')
        if ($maximePlanAgent -notmatch 'engine-catalog') {
            throw "L'agent maxime-plan genere ne mentionne pas le catalogue KB engine-catalog."
        }
        if ($maximePlanAgent -notmatch '(?i)Copilot et Codex ne peuvent') {
            throw "L'agent maxime-plan genere ne documente pas la politique par hote (Claude auto-configurable, Copilot/Codex recommandent+demandent)."
        }

        foreach ($id in @('claude-code-models', 'copilot-models', 'codex-models')) {
            $fiche = Join-Path $repositoryRoot ".wip\kb\active\engine-catalog\$id.json"
            if (!(Test-Path $fiche)) {
                throw "Fiche KB manquante: $fiche"
            }
            $json = $null
            try { $json = Get-Content -Raw -Path $fiche | ConvertFrom-Json } catch { throw "Fiche KB invalide (JSON malforme): $fiche" }
            if ($json.id -ne $id -or $json.theme -ne 'engine-catalog' -or -not $json.source -or $json.source.Count -eq 0) {
                throw "Fiche KB $fiche : id/theme/source ne respectent pas le schema attendu."
            }
            $index = Get-Content -Raw -Path (Join-Path $repositoryRoot '.wip\kb\index.json') | ConvertFrom-Json
            $entry = $index | Where-Object { $_.id -eq $id }
            if (-not $entry -or $entry.path -ne "active/engine-catalog/$id.json") {
                throw "index.json ne reference pas correctement la fiche $id."
            }
        }
        $true
    }

    # Decision: cleanup-wip only purges .wip/kb/archived/ by age (never
    # .wip/kb/active/), and must not fail when .wip/kb/archived/ does not
    # exist yet (same class of regression as the 2026-07-11 set -e/tests bug).
    Test-Decision 'cleanup-wip gere .wip/kb/archived/ absent sans erreur' {
        $fixture = Join-Path $tempRoot 'fixture-kb-cleanup'
        New-Item -ItemType Directory -Path $fixture | Out-Null
        Push-Location $fixture
        try { git init -q } finally { Pop-Location }
        & (Join-Path $repositoryRoot 'install\install.ps1') -Target claude -WorkspaceRoot $fixture | Out-Null

        $kbArchived = Join-Path $fixture '.wip\kb\archived'
        if (Test-Path $kbArchived) {
            Remove-Item -Path $kbArchived -Recurse -Force
        }
        $cleanup = Join-Path $fixture '.wip\tools\cleanup-wip.ps1'
        & $cleanup -WorkspaceRoot $fixture | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "cleanup-wip.ps1 a echoue (exit $LASTEXITCODE) avec .wip/kb/archived absent."
        }
        $true
    }

    # Decision: pre-existing project-specific CLAUDE.md / copilot-instructions.md
    # / AGENTS.md content is never silently overwritten (issue #27). Claude and
    # Copilot: moved once into a companion file the host merges natively
    # (.claude/rules/, .github/instructions/). Codex: merged in place inside an
    # explicit marker block (no confirmed native merge mechanism). A repo whose
    # AGENTS.md now mixes project + generated content is not added to the
    # default git-exclude list for that file -- it is no longer purely tool-owned.
    Test-Decision 'contenu projet pre-existant preserve, jamais ecrase (issue #27)' {
        $fixture = Join-Path $tempRoot 'fixture-preserve-project'
        New-Item -ItemType Directory -Path $fixture | Out-Null
        Push-Location $fixture
        try { git init -q } finally { Pop-Location }

        $projectClaudeMarker = 'PROJET: convention Claude specifique a ce repo, jamais generee par un outil.'
        $projectCopilotMarker = 'PROJET: convention Copilot specifique a ce repo, jamais generee par un outil.'
        $projectAgentsMarker = 'PROJET: convention Codex specifique a ce repo, jamais generee par un outil.'
        Set-Content -Path (Join-Path $fixture 'CLAUDE.md') -Value $projectClaudeMarker -Encoding UTF8
        New-Item -ItemType Directory -Force -Path (Join-Path $fixture '.github') | Out-Null
        Set-Content -Path (Join-Path $fixture '.github\copilot-instructions.md') -Value $projectCopilotMarker -Encoding UTF8
        Set-Content -Path (Join-Path $fixture 'AGENTS.md') -Value $projectAgentsMarker -Encoding UTF8

        & (Join-Path $repositoryRoot 'install\install.ps1') -Target all -WorkspaceRoot $fixture | Out-Null

        $rulesFile = Join-Path $fixture '.claude\rules\project-conventions.md'
        if (!(Test-Path $rulesFile)) { throw '.claude/rules/project-conventions.md non cree.' }
        if (-not (Get-Content -Raw -Path $rulesFile).Contains($projectClaudeMarker)) {
            throw 'Contenu CLAUDE.md pre-existant absent de .claude/rules/project-conventions.md.'
        }
        $claudeMdContent = Get-Content -Raw -Path (Join-Path $fixture 'CLAUDE.md')
        if ($claudeMdContent -notmatch 'Generated from') {
            throw 'CLAUDE.md ne contient pas le contenu genere apres installation.'
        }

        $instrFile = Join-Path $fixture '.github\instructions\project-conventions.instructions.md'
        if (!(Test-Path $instrFile)) { throw '.github/instructions/project-conventions.instructions.md non cree.' }
        $instrContent = Get-Content -Raw -Path $instrFile
        if (-not $instrContent.Contains($projectCopilotMarker)) {
            throw 'Contenu copilot-instructions.md pre-existant absent du fichier instructions preserve.'
        }
        if ($instrContent -notmatch 'applyTo:\s*"\*\*"') {
            throw 'Frontmatter applyTo manquant dans le fichier instructions preserve.'
        }

        $agentsContent = Get-Content -Raw -Path (Join-Path $fixture 'AGENTS.md')
        if (-not $agentsContent.Contains($projectAgentsMarker)) {
            throw 'Contenu AGENTS.md pre-existant perdu apres installation (devrait etre fusionne, pas ecrase).'
        }
        if ($agentsContent -notmatch 'Generated from') {
            throw 'AGENTS.md ne contient pas le contenu genere apres installation.'
        }
        if ($agentsContent -notmatch '<!-- BEGIN mA\.xI\.me generated -->') {
            throw 'Bloc delimite mA.xI.me absent de AGENTS.md.'
        }

        $excludePath = (& git -C $fixture rev-parse --git-path info/exclude).Trim()
        if (![System.IO.Path]::IsPathRooted($excludePath)) { $excludePath = Join-Path $fixture $excludePath }
        $excludeContent = Get-Content -Path $excludePath
        if ($excludeContent -contains '/AGENTS.md') {
            throw 'AGENTS.md ne devrait pas etre exclu par defaut une fois melange a du contenu projet.'
        }
        if ($excludeContent -notcontains '/CLAUDE.md') {
            throw 'CLAUDE.md devrait rester exclu par defaut (redevenu propre apres preservation du contenu projet).'
        }

        # Reinstall: idempotent, no duplication of the preserved companion
        # files or of the managed block inside AGENTS.md.
        & (Join-Path $repositoryRoot 'install\install.ps1') -Target all -WorkspaceRoot $fixture | Out-Null
        $agentsContentAfterReinstall = Get-Content -Raw -Path (Join-Path $fixture 'AGENTS.md')
        $blockCount = ([regex]::Matches($agentsContentAfterReinstall, [regex]::Escape('<!-- BEGIN mA.xI.me generated -->'))).Count
        if ($blockCount -ne 1) {
            throw "Reinstallation a duplique le bloc gere dans AGENTS.md (trouve $blockCount fois, attendu 1)."
        }
        if (-not $agentsContentAfterReinstall.Contains($projectAgentsMarker)) {
            throw 'Reinstallation a perdu le contenu projet dans AGENTS.md.'
        }

        # Uninstall: the managed block is stripped, project content in
        # AGENTS.md survives (never a full-file delete for a mixed file).
        & (Join-Path $repositoryRoot 'install\uninstall.ps1') -Target codex -WorkspaceRoot $fixture | Out-Null
        $agentsPath = Join-Path $fixture 'AGENTS.md'
        if (!(Test-Path $agentsPath)) {
            throw 'uninstall a supprime AGENTS.md entierement alors qu''il contenait du contenu projet.'
        }
        $agentsAfterUninstall = Get-Content -Raw -Path $agentsPath
        if (-not $agentsAfterUninstall.Contains($projectAgentsMarker)) {
            throw 'uninstall a perdu le contenu projet dans AGENTS.md.'
        }
        if ($agentsAfterUninstall -match '<!-- BEGIN mA\.xI\.me generated -->') {
            throw 'uninstall n''a pas retire le bloc gere de AGENTS.md.'
        }
        $true
    }

    # Decision (issue #34): no write is allowed outside the target repo, not
    # just by the installer -- .wip/tmp/ is the sanctioned place for
    # ephemeral files, and 3 hooks enforce path-containment for the tools
    # that can write: Bash, PowerShell (verified empirically that Claude
    # Code hooks CAN intercept the PowerShell tool), and
    # Write/Edit/NotebookEdit (the reliable check -- exact file_path, no
    # command string to guess at). Functional checks pipe real payloads
    # through each hook and assert the actual allow/deny decision.
    Test-Decision 'aucune ecriture hors du repo -- .wip/tmp/ + 3 hooks path-aware (issue #34)' {
        $fixture = Join-Path $tempRoot 'fixture-no-outside-write'
        New-Item -ItemType Directory -Path $fixture | Out-Null
        Push-Location $fixture
        try { git init -q } finally { Pop-Location }
        # Re-resolve to whatever form git normalizes to -- the hooks resolve
        # repo_root the same way, so the fixture path used in every payload
        # below must match that exact representation.
        $fixture = (& git -C $fixture rev-parse --show-toplevel).Trim()

        & (Join-Path $repositoryRoot 'install\install.ps1') -Target claude -WorkspaceRoot $fixture | Out-Null

        if (!(Test-Path (Join-Path $fixture '.wip\tmp'))) {
            throw '.wip/tmp/ non cree a l''installation fraiche.'
        }

        $hooksDir = Join-Path $fixture '.claude\hooks'
        foreach ($f in @('lib-path-guard.sh', 'block-destructive-bash.sh', 'block-destructive-powershell.sh', 'block-outside-repo-write.sh')) {
            if (!(Test-Path (Join-Path $hooksDir $f))) {
                throw "$f manquant dans .claude/hooks/ apres installation."
            }
        }

        $settingsContent = Get-Content -Raw -Path (Join-Path $fixture '.claude\settings.json')
        if ($settingsContent -notmatch '"matcher": "PowerShell"') {
            throw '.claude/settings.json ne declare pas de hook pour l''outil PowerShell.'
        }
        if ($settingsContent -notmatch '"matcher": "Write\|Edit\|NotebookEdit"') {
            throw '.claude/settings.json ne declare pas de hook pour Write/Edit/NotebookEdit.'
        }

        # Claude Code's own hook runner resolves "bash" to git-bash (that's
        # what the in-session, end-to-end hook tests exercised and confirmed
        # working). A plain PATH lookup in a standalone PowerShell process is
        # not the same thing: on a machine with WSL installed, "bash" on
        # PATH can resolve to C:\Windows\system32\bash.exe (the WSL
        # launcher, mounting C:\ at /mnt/c and unable to parse Windows-style
        # paths at all) instead of git-bash. Resolve git-bash explicitly so
        # this test exercises the same interpreter production uses.
        $gitBash = Join-Path (Split-Path (Split-Path (Get-Command git.exe -ErrorAction Stop).Source -Parent) -Parent) 'bin\bash.exe'
        if (!(Test-Path $gitBash)) {
            throw "git-bash introuvable a l'emplacement attendu ($gitBash) -- impossible de tester fonctionnellement les hooks depuis ce checker."
        }

        $outsideDir = Join-Path ([System.IO.Path]::GetTempPath()) ([Guid]::NewGuid())
        New-Item -ItemType Directory -Path $outsideDir | Out-Null
        # JSON string literals can't contain a bare backslash -- forward
        # slashes are valid on Windows and the hooks normalize them anyway.
        $outsideDirJson = $outsideDir -replace '\\', '/'
        $payload = Join-Path $tempRoot 'hook-payload.json'

        function Invoke-Hook {
            param([string]$Script, [string]$Json)
            Set-Content -Path $payload -Value $Json -Encoding UTF8 -NoNewline
            # git-bash's argv handling mangles backslashes in a plain path
            # argument (they're consumed as escape characters) -- pass the
            # script path with forward slashes instead.
            $bashScript = $Script -replace '\\', '/'
            $out = Get-Content -Raw -Path $payload | & $gitBash $bashScript
            return $out
        }

        $writeHook = Join-Path $hooksDir 'block-outside-repo-write.sh'
        $out = Invoke-Hook -Script $writeHook -Json ("{`"cwd`":`"$fixture`",`"tool_input`":{`"file_path`":`"$outsideDirJson/outside.txt`",`"content`":`"x`"}}")
        if ([string]::IsNullOrEmpty($out)) {
            throw 'block-outside-repo-write.sh laisse passer une ecriture hors repo (Write/Edit).'
        }

        $out = Invoke-Hook -Script $writeHook -Json ("{`"cwd`":`"$fixture`",`"tool_input`":{`"file_path`":`"$fixture/.wip/tmp/inside.txt`",`"content`":`"x`"}}")
        if (-not [string]::IsNullOrEmpty($out)) {
            throw 'block-outside-repo-write.sh bloque une ecriture legitime DANS le repo (.wip/tmp/).'
        }

        $bashHook = Join-Path $hooksDir 'block-destructive-bash.sh'
        $out = Invoke-Hook -Script $bashHook -Json ("{`"cwd`":`"$fixture`",`"tool_input`":{`"command`":`"echo hello > $outsideDirJson/outside.txt`"}}")
        if ([string]::IsNullOrEmpty($out)) {
            throw 'block-destructive-bash.sh laisse passer une redirection vers un chemin absolu hors repo.'
        }

        $out = Invoke-Hook -Script $bashHook -Json ("{`"cwd`":`"$fixture`",`"tool_input`":{`"command`":`"echo hello > .wip/tmp/inside.txt`"}}")
        if (-not [string]::IsNullOrEmpty($out)) {
            throw 'block-destructive-bash.sh bloque une redirection relative legitime DANS le repo (regression du faux positif issue #27).'
        }

        # Forward slashes are a valid Windows path form and sidestep JSON
        # backslash-escaping entirely -- the hook only pattern-matches the
        # command text, it never executes it, so this is a faithful test.
        $psHook = Join-Path $hooksDir 'block-destructive-powershell.sh'
        $out = Invoke-Hook -Script $psHook -Json ("{`"cwd`":`"$fixture`",`"tool_input`":{`"command`":`"Set-Content -Path \`"$outsideDirJson/outside.txt\`" -Value hello`"}}")
        if ([string]::IsNullOrEmpty($out)) {
            throw 'block-destructive-powershell.sh laisse passer une ecriture vers un chemin absolu entre guillemets hors repo.'
        }

        Remove-Item -Path $outsideDir -Recurse -Force -ErrorAction SilentlyContinue
        $true
    }

    # Decision (2026-07-17): switching to main/master (git checkout|switch main)
    # used to be a hard DENY in both destructive-command hooks -- too strict, it
    # blocked a routine, safe post-merge sync just as hard as an actual direct
    # commit on main. Softened to ASK: a human must still confirm, but it is no
    # longer an unconditional block. Regression-checked alongside: the other
    # hard_deny patterns (checkout --, checkout ., branch -D, reset --hard) stay
    # DENY, unaffected by this change.
    Test-Decision 'bascule vers main/master assouplie de deny vers ask, sans affaiblir les autres hard_deny' {
        $fixture = Join-Path $tempRoot 'fixture-checkout-main-ask'
        New-Item -ItemType Directory -Path $fixture | Out-Null
        Push-Location $fixture
        try { git init -q } finally { Pop-Location }
        $fixture = (& git -C $fixture rev-parse --show-toplevel).Trim()

        & (Join-Path $repositoryRoot 'install\install.ps1') -Target claude -WorkspaceRoot $fixture | Out-Null

        $gitBash = Join-Path (Split-Path (Split-Path (Get-Command git.exe -ErrorAction Stop).Source -Parent) -Parent) 'bin\bash.exe'
        if (!(Test-Path $gitBash)) {
            throw "git-bash introuvable a l'emplacement attendu ($gitBash) -- impossible de tester fonctionnellement les hooks depuis ce checker."
        }

        $hooksDir = Join-Path $fixture '.claude\hooks'
        $payload = Join-Path $tempRoot 'hook-payload-checkout-main.json'

        function Invoke-HookAndGetDecision {
            param([string]$Script, [string]$Json)
            Set-Content -Path $payload -Value $Json -Encoding UTF8 -NoNewline
            $bashScript = $Script -replace '\\', '/'
            $out = Get-Content -Raw -Path $payload | & $gitBash $bashScript
            if ([string]::IsNullOrEmpty($out)) { return '' }
            return ($out | & $gitBash -c 'jq -r ".hookSpecificOutput.permissionDecision // empty"')
        }

        $bashHook = Join-Path $hooksDir 'block-destructive-bash.sh'
        $psHook = Join-Path $hooksDir 'block-destructive-powershell.sh'

        $decision = Invoke-HookAndGetDecision -Script $bashHook -Json ("{`"cwd`":`"$fixture`",`"tool_input`":{`"command`":`"git checkout main`"}}")
        if ($decision -ne 'ask') {
            throw "'git checkout main' n'est pas traite en ask par block-destructive-bash.sh (decision: '$decision')."
        }

        $decision = Invoke-HookAndGetDecision -Script $psHook -Json ("{`"cwd`":`"$fixture`",`"tool_input`":{`"command`":`"git switch master`"}}")
        if ($decision -ne 'ask') {
            throw "'git switch master' n'est pas traite en ask par block-destructive-powershell.sh (decision: '$decision')."
        }

        $decision = Invoke-HookAndGetDecision -Script $bashHook -Json ("{`"cwd`":`"$fixture`",`"tool_input`":{`"command`":`"git checkout -- .`"}}")
        if ($decision -ne 'deny') {
            throw "regression: 'git checkout -- .' n'est plus un deny dur (decision: '$decision')."
        }

        $true
    }

    # Decision (2026-07-17): text alone does not reliably stop an agent from
    # proposing to wire knowledge-base as a submodule -- verified in real
    # use: core/workflows/maxime-kb.md was strengthened 3 times (a plain
    # rule, an explicit callout, a top-of-document blockquote) and a live
    # maxi-claude-kb agent proposed 'git submodule add ... knowledge-base'
    # all 3 times anyway. Mechanical hard_deny added on top of the text,
    # same family as the other irreversible-action guards.
    Test-Decision "git submodule add/update vers knowledge-base bloque mecaniquement (hard_deny), le texte seul a echoue 3 fois en test reel" {
        $fixture = Join-Path $tempRoot 'fixture-kb-submodule-deny'
        New-Item -ItemType Directory -Path $fixture | Out-Null
        Push-Location $fixture
        try { git init -q } finally { Pop-Location }
        $fixture = (& git -C $fixture rev-parse --show-toplevel).Trim()

        & (Join-Path $repositoryRoot 'install\install.ps1') -Target claude -WorkspaceRoot $fixture | Out-Null

        $gitBash = Join-Path (Split-Path (Split-Path (Get-Command git.exe -ErrorAction Stop).Source -Parent) -Parent) 'bin\bash.exe'
        if (!(Test-Path $gitBash)) {
            throw "git-bash introuvable a l'emplacement attendu ($gitBash) -- impossible de tester fonctionnellement les hooks depuis ce checker."
        }

        $hooksDir = Join-Path $fixture '.claude\hooks'
        $payload = Join-Path $tempRoot 'hook-payload-kb-submodule.json'

        function Invoke-HookAndGetDecision2 {
            param([string]$Script, [string]$Json)
            Set-Content -Path $payload -Value $Json -Encoding UTF8 -NoNewline
            $bashScript = $Script -replace '\\', '/'
            $out = Get-Content -Raw -Path $payload | & $gitBash $bashScript
            if ([string]::IsNullOrEmpty($out)) { return '' }
            return ($out | & $gitBash -c 'jq -r ".hookSpecificOutput.permissionDecision // empty"')
        }

        $bashHook = Join-Path $hooksDir 'block-destructive-bash.sh'
        $psHook = Join-Path $hooksDir 'block-destructive-powershell.sh'

        $decision = Invoke-HookAndGetDecision2 -Script $bashHook -Json ("{`"cwd`":`"$fixture`",`"tool_input`":{`"command`":`"git submodule add https://github.com/OurITRes/knowledge-base knowledge-base`"}}")
        if ($decision -ne 'deny') {
            throw "'git submodule add ... knowledge-base' n'est pas bloque par block-destructive-bash.sh (decision: '$decision')."
        }

        $decision = Invoke-HookAndGetDecision2 -Script $psHook -Json ("{`"cwd`":`"$fixture`",`"tool_input`":{`"command`":`"git submodule update --init --recursive knowledge-base`"}}")
        if ($decision -ne 'deny') {
            throw "'git submodule update ... knowledge-base' n'est pas bloque par block-destructive-powershell.sh (decision: '$decision')."
        }

        $decision = Invoke-HookAndGetDecision2 -Script $bashHook -Json ("{`"cwd`":`"$fixture`",`"tool_input`":{`"command`":`"git submodule add https://example.com/other-repo.git vendor/other-repo`"}}")
        if ($decision -eq 'deny') {
            throw "un submodule sans rapport avec knowledge-base est bloque a tort (decision: '$decision')."
        }

        $true
    }

    # Decision: by default, projected files (CLAUDE.md, .claude/, etc.) are added to
    # .git/info/exclude AND to .gitignore -- the whole install stays local via exclude,
    # and .gitignore documents/enforces the same patterns so the tool is never
    # accidentally committed even from a different clone. -Shared restores the old
    # commitable behavior (neither exclude nor .gitignore touched). uninstall.ps1
    # removes the same entries it added, from both files.
    Test-Decision 'installation locale par defaut (info/exclude + .gitignore), -Shared rend commitable, uninstall nettoie' {
        $fixtureDefault = Join-Path $tempRoot 'fixture-local'
        New-Item -ItemType Directory -Path $fixtureDefault | Out-Null
        Push-Location $fixtureDefault
        try { git init -q } finally { Pop-Location }
        & (Join-Path $repositoryRoot 'install\install.ps1') -Target claude -WorkspaceRoot $fixtureDefault | Out-Null
        $statusDefault = @(& git -C $fixtureDefault status --short)
        if (@($statusDefault | Where-Object { $_ -notmatch '\.gitignore$' }).Count -gt 0) {
            throw "installation par defaut : seul .gitignore devrait apparaitre en non-suivi (le reste doit etre exclu), trouve: $($statusDefault -join '; ')"
        }
        if (@($statusDefault | Where-Object { $_ -match '\.gitignore$' }).Count -eq 0) {
            throw "installation par defaut : .gitignore devrait avoir ete cree et apparaitre en non-suivi."
        }
        $gitignoreDefault = Get-Content (Join-Path $fixtureDefault '.gitignore')
        if ($gitignoreDefault -notcontains '/CLAUDE.md') {
            throw "installation par defaut : /CLAUDE.md absent de .gitignore."
        }

        & (Join-Path $repositoryRoot 'install\uninstall.ps1') -Target claude -WorkspaceRoot $fixtureDefault | Out-Null
        $excludeDefault = Get-Content (Join-Path $fixtureDefault '.git\info\exclude')
        if ($excludeDefault -contains '/CLAUDE.md') {
            throw "uninstall n'a pas retire /CLAUDE.md de .git/info/exclude."
        }
        if (($excludeDefault -notcontains '/.wip/') -or ($excludeDefault -notcontains '/.bkp/')) {
            throw "uninstall a retire /.wip/ ou /.bkp/ de .git/info/exclude -- ne doit retirer que les entrees qu'il a ajoutees."
        }
        $gitignoreAfterUninstall = Get-Content (Join-Path $fixtureDefault '.gitignore')
        if ($gitignoreAfterUninstall -contains '/CLAUDE.md') {
            throw "uninstall n'a pas retire /CLAUDE.md de .gitignore."
        }

        $fixtureShared = Join-Path $tempRoot 'fixture-shared'
        New-Item -ItemType Directory -Path $fixtureShared | Out-Null
        Push-Location $fixtureShared
        try { git init -q } finally { Pop-Location }
        & (Join-Path $repositoryRoot 'install\install.ps1') -Target claude -WorkspaceRoot $fixtureShared -Shared | Out-Null
        $statusShared = & git -C $fixtureShared status --short
        $claudeMdUntracked = $statusShared | Where-Object { $_ -match 'CLAUDE\.md$' }
        if (-not $claudeMdUntracked) {
            throw "-Shared : CLAUDE.md devrait apparaitre en non-suivi (commitable) dans git status."
        }
        if (Test-Path (Join-Path $fixtureShared '.gitignore')) {
            throw "-Shared : aucun .gitignore ne devrait etre cree."
        }
        $true
    }

    # Decision: install/lib/install-claude.ps1 (and the other per-host scripts) must be
    # callable standalone, without going through install.ps1 -Target. This is what lets
    # an agent (Maxime Init) compose the exact pieces it needs instead of negotiating a
    # -Target flag.
    Test-Decision 'install/lib/install-claude.ps1 fonctionne seul, sans passer par install.ps1' {
        $fixture = Join-Path $tempRoot 'fixture-standalone-lib'
        New-Item -ItemType Directory -Path $fixture | Out-Null
        Push-Location $fixture
        try { git init -q } finally { Pop-Location }
        & (Join-Path $repositoryRoot 'install\lib\install-claude.ps1') -RepoRoot $fixture | Out-Null
        if (!(Test-Path (Join-Path $fixture 'CLAUDE.md'))) {
            throw "install-claude.ps1 execute seul n'a pas cree CLAUDE.md."
        }
        if (!(Test-Path (Join-Path $fixture '.claude\agents\maxime.md'))) {
            throw "install-claude.ps1 execute seul n'a pas cree .claude/agents/maxime.md."
        }
        $true
    }

    # Decision: each workflow is generated as a dedicated agent (Claude + Copilot) with
    # the tool-scoping its own text justifies, not the orchestrator's full tool set.
    # Codex has no agent/tools mechanism, so it is excluded here (see the allowed-tools
    # decision above). maxime-init is the only workflow allowed to skip the bootstrap
    # guard, since it is what creates .wip/ in the first place.
    Test-Decision 'chaque agent de workflow genere a le tool-scoping et la garde bootstrap attendus' {
        $writeCapableWorkflows = @('maxime-plan', 'maxime-handoff', 'maxime-retrofit', 'maxime-kb')
        $readOnlyWorkflows = @('maxime-start', 'maxime-init', 'maxime-review')
        $claudeAgentsDir = Join-Path $repositoryRoot 'install\Packaged\agents'
        $copilotAgentsDir = Join-Path $repositoryRoot 'install\Packaged\.copilot\agents'

        foreach ($name in ($writeCapableWorkflows + $readOnlyWorkflows)) {
            $claudeAgentPath = Join-Path $claudeAgentsDir "$name.md"
            if (!(Test-Path $claudeAgentPath)) { throw "Agent Claude manquant: $claudeAgentPath" }
            $claudeContent = Get-Content -Path $claudeAgentPath -Raw
            $toolsLine = ($claudeContent -split "`n" | Where-Object { $_ -match '^tools:' }) -join ''
            $shouldHaveWrite = $name -in $writeCapableWorkflows
            $hasWrite = $toolsLine -match '\bWrite\b'
            if ($shouldHaveWrite -and -not $hasWrite) {
                throw "$name (Claude) devrait avoir Write dans tools: mais ne l'a pas ($toolsLine)."
            }
            if (-not $shouldHaveWrite -and $hasWrite) {
                throw "$name (Claude) ne devrait pas avoir Write dans tools: ($toolsLine)."
            }

            $copilotAgentPath = Join-Path $copilotAgentsDir "$name.agent.md"
            if (!(Test-Path $copilotAgentPath)) { throw "Agent Copilot manquant: $copilotAgentPath" }
            $copilotContent = Get-Content -Path $copilotAgentPath -Raw
            $copilotToolsLine = ($copilotContent -split "`n" | Where-Object { $_ -match '^tools:' }) -join ''
            $hasEdit = $copilotToolsLine -match '\bedit\b'
            if ($shouldHaveWrite -and -not $hasEdit) {
                throw "$name (Copilot) devrait avoir edit dans tools: mais ne l'a pas ($copilotToolsLine)."
            }
            if (-not $shouldHaveWrite -and $hasEdit) {
                throw "$name (Copilot) ne devrait pas avoir edit dans tools: ($copilotToolsLine)."
            }

            $expectGuard = $name -ne 'maxime-init'
            $hasGuardClaude = $claudeContent -match 'demander l''autorisation explicite'
            $hasGuardCopilot = $copilotContent -match 'demander l''autorisation explicite'
            if ($expectGuard -and (-not $hasGuardClaude -or -not $hasGuardCopilot)) {
                throw "$name : garde bootstrap (redirection vers Maxime Init) manquante."
            }
            if (-not $expectGuard -and ($hasGuardClaude -or $hasGuardCopilot)) {
                throw "$name : ne devrait pas contenir la garde bootstrap (c'est Maxime Init lui-meme)."
            }
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
