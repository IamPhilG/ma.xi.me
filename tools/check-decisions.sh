#!/usr/bin/env bash
# Executable regression tests for the decisions recorded in .wip/adr/decisions-log.md.
# One check per structural decision. Add a new check here whenever maxime-plan adds a
# decision line, per the mA.xI.me rule: "toute decision doit avoir un test executable".
set -uo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(dirname "$script_dir")"
[ -d "$repository_root/core" ] || { echo "Repository root not found from '$script_dir' (missing core/)." >&2; exit 1; }

temp_root="$(mktemp -d)"
trap 'rm -rf "$temp_root"' EXIT

failures=()

pass() { echo "PASS: $1"; }
fail() { echo "FAIL: $1 -- $2"; failures+=("$1"); }

# Decision: tools/ (root) contains only source-repo maintenance scripts, never
# host-distributed tools like cleanup-wip.*.
check_tools_root() {
  local name="tools/ ne contient que les scripts de maintenance du repo source"
  local expected="check-adapter-sync.ps1 check-adapter-sync.sh check-codex-skills-sync.ps1 check-codex-skills-sync.sh check-decisions.ps1 check-decisions.sh cleanup-global.ps1 cleanup-global.sh generate-adapters.ps1 generate-adapters.sh"
  local unexpected=()
  for f in "$repository_root"/tools/*; do
    local base
    base="$(basename "$f")"
    case " $expected " in
      *" $base "*) ;;
      *) unexpected+=("$base") ;;
    esac
  done
  if [ "${#unexpected[@]}" -gt 0 ]; then
    fail "$name" "Fichiers inattendus sous tools/: ${unexpected[*]}"
  else
    pass "$name"
  fi
}

# Decision: cleanup-wip is distributed to target repos from core/tools/.
check_core_tools_source() {
  local name="core/tools/ contient cleanup-wip.ps1 et .sh (source canonique distribuee)"
  if [ -f "$repository_root/core/tools/cleanup-wip.ps1" ] && [ -f "$repository_root/core/tools/cleanup-wip.sh" ]; then
    pass "$name"
  else
    fail "$name" "core/tools/cleanup-wip.ps1 ou .sh manquant."
  fi
}

# Decision: no dated spec filenames anywhere under core/ or .wip/specs/.
check_no_dated_specs() {
  local name="aucune spec datee (YYYYMMDD-) sous core/ ou .wip/specs/"
  local hits
  hits="$(find "$repository_root/core" "$repository_root/.wip/specs" -type f -name '*.md' 2>/dev/null | grep -E '/[0-9]{8}-' || true)"
  if [ -n "$hits" ]; then
    fail "$name" "Specs datees trouvees: $hits"
  else
    pass "$name"
  fi
}

# Decision: docs/SPECS.md removed, no dangling reference in product docs.
check_specs_md_removed() {
  local name="docs/SPECS.md absent et non reference dans README/ARCHITECTURE"
  if [ -f "$repository_root/docs/SPECS.md" ]; then
    fail "$name" "docs/SPECS.md existe encore."
    return
  fi
  local hits
  hits="$(grep -l 'SPECS\.md' "$repository_root/README.md" "$repository_root/docs/ARCHITECTURE.md" 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    fail "$name" "Reference residuelle a SPECS.md: $hits"
  else
    pass "$name"
  fi
}

# Decision: no leftover .wip/maxime path or bare "maxime" agent identifier in
# portable/generated source (excludes .wip/ local narrative and this checker's own
# source, which legitimately mentions the old name/path as literal text).
check_no_legacy_naming() {
  local name='aucun residu .wip/maxime ou identifiant agent "maxime" nu dans le source portable'
  local hits
  hits="$(grep -rEn '\.wip/maxime|agent: *maxime\b|name: *maxime\b($|[^-])' \
    "$repository_root/core" "$repository_root/agents" "$repository_root/skills" \
    "$repository_root/.agents" "$repository_root/.copilot" "$repository_root/.codex" \
    "$repository_root/install" \
    "$repository_root/CLAUDE.md" "$repository_root/AGENTS.md" "$repository_root/README.md" \
    2>/dev/null || true)"
  if [ -n "$hits" ]; then
    fail "$name" "Residus trouves: $hits"
  else
    pass "$name"
  fi
}

# Decision: Copilot tool identifiers use VS Code's current names (read, search,
# execute, edit, agent -- no standalone 'grep', folded into 'search'), never the
# renamed/unknown legacy names that VS Code's own agent-file linter flagged
# (read_file, grep_search, file_search, run_in_terminal, apply_patch, create_file,
# runSubagent).
check_no_legacy_copilot_tools() {
  local name="aucun nom d'outil Copilot obsolete (read_file/grep_search/file_search/run_in_terminal/apply_patch/create_file/runSubagent/grep)"
  local hits
  hits="$(grep -rEln 'read_file|grep_search|file_search|run_in_terminal|apply_patch|create_file|runSubagent' \
    "$repository_root/.copilot" \
    "$repository_root/tools/generate-adapters.ps1" "$repository_root/tools/generate-adapters.sh" \
    2>/dev/null || true)"
  if [ -n "$hits" ]; then
    fail "$name" "Noms d'outils Copilot obsoletes trouves: $hits"
    return
  fi
  hits="$(grep -rEln '^tools:.*\bgrep\b' "$repository_root/.copilot" 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    fail "$name" "'grep' n'est pas un outil Copilot valide (utiliser 'search'): $hits"
  else
    pass "$name"
  fi
}

# Decision: Codex-facing SKILL.md (.agents/skills/) must not declare
# 'allowed-tools' -- VS Code's Codex extension rejects it (supported frontmatter:
# argument-hint, compatibility, context, description, disable-model-invocation,
# license, metadata, name, user-invocable). Claude-facing skills/*/SKILL.md keeps
# it; the two are generated as distinct bodies, not copies of each other.
check_no_allowed_tools_in_codex_skills() {
  local name="aucun allowed-tools dans .agents/skills/*/SKILL.md (Codex)"
  local hits
  hits="$(grep -rEln '^allowed-tools:' "$repository_root/.agents/skills" 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    fail "$name" "allowed-tools trouve dans une SKILL.md Codex: $hits"
  else
    pass "$name"
  fi
}

# Decision: generate-adapters.ps1 and generate-adapters.sh must produce byte-identical
# projections from the same core/ source (see the matching PowerShell check for the
# 2026-07-12 backtick-escape regression this guards against).
check_cross_generator_sync() {
  local name="generate-adapters.ps1 et .sh produisent une projection identique"
  if ! bash "$repository_root/tools/check-adapter-sync.sh" >/dev/null; then
    fail "$name" "check-adapter-sync.sh echoue."
    return
  fi
  local pwsh_cmd=""
  if command -v pwsh >/dev/null 2>&1; then
    pwsh_cmd="pwsh"
  elif command -v powershell >/dev/null 2>&1; then
    pwsh_cmd="powershell"
  fi
  if [ -z "$pwsh_cmd" ]; then
    fail "$name" "powershell/pwsh introuvable -- impossible de verifier check-adapter-sync.ps1 depuis ce checker."
    return
  fi
  if ! "$pwsh_cmd" -ExecutionPolicy Bypass -File "$repository_root/tools/check-adapter-sync.ps1" >/dev/null; then
    fail "$name" "check-adapter-sync.ps1 echoue (les deux generateurs divergent)."
    return
  fi
  pass "$name"
}

# Decision: a fresh install produces the standardized .wip/ layout and distributes
# cleanup-wip, and cleanup-wip runs safely even without .wip/tests/ present
# (regression test for the set -e / bare `return` bug fixed 2026-07-11).
check_fresh_install() {
  local name="installation fraiche: structure .wip/ standard + cleanup-wip fonctionnel"
  local fixture="$temp_root/fixture"
  mkdir -p "$fixture"
  (cd "$fixture" && git init -q)

  if ! bash "$repository_root/install/install.sh" --target claude --workspace-root "$fixture" >/dev/null; then
    fail "$name" "Installation a echoue."
    return
  fi

  for dir in memory specs adr results tools; do
    if [ ! -d "$fixture/.wip/$dir" ]; then
      fail "$name" "Repertoire .wip/$dir manquant apres installation."
      return
    fi
  done

  local exclude_path
  exclude_path="$(git -C "$fixture" rev-parse --git-path info/exclude)"
  case "$exclude_path" in
    /*) ;;
    *) exclude_path="$fixture/$exclude_path" ;;
  esac
  if ! grep -qxF '/.wip/' "$exclude_path" 2>/dev/null || ! grep -qxF '/.bkp/' "$exclude_path" 2>/dev/null; then
    fail "$name" ".git/info/exclude ne contient pas /.wip/ et /.bkp/ apres installation (exclusion locale attendue, pas de .gitignore)."
    return
  fi
  if [ -f "$fixture/.gitignore" ]; then
    fail "$name" "Un .gitignore a ete cree pour .wip/.bkp -- l'exclusion doit rester locale via .git/info/exclude uniquement."
    return
  fi

  local installed_cleanup="$fixture/.wip/tools/cleanup-wip.sh"
  if [ ! -f "$installed_cleanup" ]; then
    fail "$name" "cleanup-wip.sh non distribue dans .wip/tools/ du repo cible."
    return
  fi
  if ! cmp -s "$repository_root/core/tools/cleanup-wip.sh" "$installed_cleanup"; then
    fail "$name" "cleanup-wip.sh distribue ne correspond pas a core/tools/cleanup-wip.sh."
    return
  fi
  if [ ! -x "$installed_cleanup" ]; then
    fail "$name" "cleanup-wip.sh distribue n'est pas executable."
    return
  fi

  # .wip/tests/ deliberately does not exist here: this is the exact condition that
  # used to crash cleanup-wip.sh under set -e before the 2026-07-11 fix.
  if ! bash "$installed_cleanup" >/dev/null; then
    fail "$name" "cleanup-wip.sh a echoue sur une installation fraiche sans .wip/tests/."
    return
  fi

  pass "$name"
}

# Decision: by default, projected files (CLAUDE.md, .claude/, etc.) are added to
# .git/info/exclude -- the whole install stays local, nothing commitable by
# accident. --shared restores the old commitable behavior. uninstall.sh removes
# the same entries it added.
check_local_by_default() {
  local name="installation locale par defaut (info/exclude), --shared rend commitable, uninstall nettoie"

  local fixture_default="$temp_root/fixture-local"
  mkdir -p "$fixture_default"
  (cd "$fixture_default" && git init -q)
  bash "$repository_root/install/install.sh" --target claude --workspace-root "$fixture_default" >/dev/null
  local status_default
  status_default="$(git -C "$fixture_default" status --short)"
  if [ -n "$status_default" ]; then
    fail "$name" "installation par defaut : git status devrait etre vide (tout exclu), trouve: $status_default"
    return
  fi

  bash "$repository_root/install/uninstall.sh" --target claude --workspace-root "$fixture_default" >/dev/null
  if grep -qxF '/CLAUDE.md' "$fixture_default/.git/info/exclude"; then
    fail "$name" "uninstall n'a pas retire /CLAUDE.md de .git/info/exclude."
    return
  fi
  if ! grep -qxF '/.wip/' "$fixture_default/.git/info/exclude" || ! grep -qxF '/.bkp/' "$fixture_default/.git/info/exclude"; then
    fail "$name" "uninstall a retire /.wip/ ou /.bkp/ de .git/info/exclude -- ne doit retirer que les entrees qu'il a ajoutees."
    return
  fi

  local fixture_shared="$temp_root/fixture-shared"
  mkdir -p "$fixture_shared"
  (cd "$fixture_shared" && git init -q)
  bash "$repository_root/install/install.sh" --target claude --workspace-root "$fixture_shared" --shared >/dev/null
  if ! git -C "$fixture_shared" status --short | grep -q 'CLAUDE.md$'; then
    fail "$name" "--shared : CLAUDE.md devrait apparaitre en non-suivi (commitable) dans git status."
    return
  fi

  pass "$name"
}

check_tools_root
check_core_tools_source
check_no_dated_specs
check_specs_md_removed
check_no_legacy_naming
check_no_legacy_copilot_tools
check_no_allowed_tools_in_codex_skills
check_cross_generator_sync
check_fresh_install
check_local_by_default

echo
if [ "${#failures[@]}" -gt 0 ]; then
  echo "mA.xI.me decision checks failed:"
  for f in "${failures[@]}"; do
    echo "- $f"
  done
  exit 1
fi

echo "mA.xI.me decision checks passed."
