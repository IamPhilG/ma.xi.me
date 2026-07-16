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
  local expected="check-adapter-sync.ps1 check-adapter-sync.sh check-decisions.ps1 check-decisions.sh cleanup-global.ps1 cleanup-global.sh generate-adapters.ps1 generate-adapters.sh"
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
    "$repository_root/core" "$repository_root/install" \
    "$repository_root/README.md" \
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
    "$repository_root/install/Packaged/.copilot" \
    "$repository_root/tools/generate-adapters.ps1" "$repository_root/tools/generate-adapters.sh" \
    2>/dev/null || true)"
  if [ -n "$hits" ]; then
    fail "$name" "Noms d'outils Copilot obsoletes trouves: $hits"
    return
  fi
  hits="$(grep -rEln '^tools:.*\bgrep\b' "$repository_root/install/Packaged/.copilot" 2>/dev/null || true)"
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
  hits="$(grep -rEln '^allowed-tools:' "$repository_root/install/Packaged/.agents/skills" 2>/dev/null || true)"
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

  for dir in memory specs adr results kb tools; do
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
  if [ -f "$fixture/.gitignore" ] && (grep -qxF '/.wip/' "$fixture/.gitignore" || grep -qxF '/.bkp/' "$fixture/.gitignore"); then
    fail "$name" "/.wip/ ou /.bkp/ trouve dans .gitignore -- cette exclusion doit rester locale via .git/info/exclude uniquement."
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

# Decision: KB fiches under .wip/kb/ are JSON (id/type/theme/tags/scope/status/
# confidence/audience/source/validated/created/ttl_days/links/content), not
# Markdown+frontmatter. A fresh install creates .wip/kb/index.json (empty array),
# .wip/kb/active/ and .wip/kb/archived/ -- never .wip/kb/INDEX.md. The generated
# maxime-kb agent documents the JSON schema, not the old ".new" filename convention.
check_kb_json_format() {
  local name="KB au format JSON (index.json + active/archived), pas Markdown+INDEX.md"
  local fixture="$temp_root/fixture-kb-json"
  mkdir -p "$fixture"
  (cd "$fixture" && git init -q)

  if ! bash "$repository_root/install/install.sh" --target claude --workspace-root "$fixture" >/dev/null; then
    fail "$name" "Installation a echoue."
    return
  fi

  local index_path="$fixture/.wip/kb/index.json"
  if [ ! -f "$index_path" ]; then
    fail "$name" ".wip/kb/index.json manquant apres installation fraiche."
    return
  fi
  if [ -f "$fixture/.wip/kb/INDEX.md" ]; then
    fail "$name" ".wip/kb/INDEX.md ne devrait plus etre cree (remplace par index.json)."
    return
  fi
  local index_content
  index_content="$(cat "$index_path")"
  if [ "$(echo "$index_content" | tr -d '[:space:]')" != "[]" ]; then
    fail "$name" ".wip/kb/index.json d'une installation fraiche devrait etre un tableau vide, trouve: $index_content"
    return
  fi
  for dir in active archived; do
    if [ ! -d "$fixture/.wip/kb/$dir" ]; then
      fail "$name" "Repertoire .wip/kb/$dir manquant apres installation."
      return
    fi
  done

  local maxime_kb_agent="$repository_root/install/Packaged/agents/maxime-kb.md"
  if ! grep -q 'index\.json' "$maxime_kb_agent"; then
    fail "$name" "L'agent maxime-kb genere ne mentionne pas index.json."
    return
  fi

  pass "$name"
}

# Decision: by default, projected files (CLAUDE.md, .claude/, etc.) are added to
# .git/info/exclude AND to .gitignore -- the whole install stays local via exclude,
# and .gitignore documents/enforces the same patterns so the tool is never
# accidentally committed even from a different clone. --shared restores the old
# commitable behavior (neither exclude nor .gitignore touched). uninstall.sh
# removes the same entries it added, from both files.
check_local_by_default() {
  local name="installation locale par defaut (info/exclude + .gitignore), --shared rend commitable, uninstall nettoie"

  local fixture_default="$temp_root/fixture-local"
  mkdir -p "$fixture_default"
  (cd "$fixture_default" && git init -q)
  bash "$repository_root/install/install.sh" --target claude --workspace-root "$fixture_default" >/dev/null
  local status_default
  status_default="$(git -C "$fixture_default" status --short)"
  if [ -n "$(echo "$status_default" | grep -v '\.gitignore$')" ]; then
    fail "$name" "installation par defaut : seul .gitignore devrait apparaitre en non-suivi (le reste doit etre exclu), trouve: $status_default"
    return
  fi
  if [ -z "$(echo "$status_default" | grep '\.gitignore$')" ]; then
    fail "$name" "installation par defaut : .gitignore devrait avoir ete cree et apparaitre en non-suivi."
    return
  fi
  if ! grep -qxF '/CLAUDE.md' "$fixture_default/.gitignore"; then
    fail "$name" "installation par defaut : /CLAUDE.md absent de .gitignore."
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
  if grep -qxF '/CLAUDE.md' "$fixture_default/.gitignore"; then
    fail "$name" "uninstall n'a pas retire /CLAUDE.md de .gitignore."
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
  if [ -f "$fixture_shared/.gitignore" ]; then
    fail "$name" "--shared : aucun .gitignore ne devrait etre cree."
    return
  fi

  pass "$name"
}

# Decision: install/lib/install-claude.sh (and the other per-host scripts) must be
# callable standalone, without going through install.sh --target. This is what lets
# an agent (Maxime Init) compose the exact pieces it needs instead of negotiating a
# --target flag.
check_standalone_lib_script() {
  local name="install/lib/install-claude.sh fonctionne seul, sans passer par install.sh"
  local fixture="$temp_root/fixture-standalone-lib"
  mkdir -p "$fixture"
  (cd "$fixture" && git init -q)
  if ! bash "$repository_root/install/lib/install-claude.sh" --repo-root "$fixture" >/dev/null; then
    fail "$name" "install-claude.sh execute seul a echoue."
    return
  fi
  if [ ! -f "$fixture/CLAUDE.md" ]; then
    fail "$name" "install-claude.sh execute seul n'a pas cree CLAUDE.md."
    return
  fi
  if [ ! -f "$fixture/.claude/agents/maxime.md" ]; then
    fail "$name" "install-claude.sh execute seul n'a pas cree .claude/agents/maxime.md."
    return
  fi
  pass "$name"
}

# Decision: each workflow is generated as a dedicated agent (Claude + Copilot) with
# the tool-scoping its own text justifies, not the orchestrator's full tool set.
# Codex has no agent/tools mechanism, so it is excluded here (see the allowed-tools
# decision above). maxime-init is the only workflow allowed to skip the bootstrap
# guard, since it is what creates .wip/ in the first place.
check_workflow_agent_scoping() {
  local name="chaque agent de workflow genere a le tool-scoping et la garde bootstrap attendus"
  local write_capable="maxime-plan maxime-handoff maxime-retrofit maxime-kb"
  local read_only="maxime-start maxime-init maxime-review"
  local claude_agents_dir="$repository_root/install/Packaged/agents"
  local copilot_agents_dir="$repository_root/install/Packaged/.copilot/agents"

  for workflow_name in $write_capable $read_only; do
    local claude_agent_path="$claude_agents_dir/$workflow_name.md"
    if [ ! -f "$claude_agent_path" ]; then
      fail "$name" "Agent Claude manquant: $claude_agent_path"
      return
    fi
    local should_have_write=0
    case " $write_capable " in
      *" $workflow_name "*) should_have_write=1 ;;
    esac
    local has_write=0
    grep -qE '^tools:.*\bWrite\b' "$claude_agent_path" && has_write=1
    if [ "$should_have_write" = 1 ] && [ "$has_write" = 0 ]; then
      fail "$name" "$workflow_name (Claude) devrait avoir Write dans tools: mais ne l'a pas."
      return
    fi
    if [ "$should_have_write" = 0 ] && [ "$has_write" = 1 ]; then
      fail "$name" "$workflow_name (Claude) ne devrait pas avoir Write dans tools:."
      return
    fi

    local copilot_agent_path="$copilot_agents_dir/$workflow_name.agent.md"
    if [ ! -f "$copilot_agent_path" ]; then
      fail "$name" "Agent Copilot manquant: $copilot_agent_path"
      return
    fi
    local has_edit=0
    grep -qE '^tools:.*\bedit\b' "$copilot_agent_path" && has_edit=1
    if [ "$should_have_write" = 1 ] && [ "$has_edit" = 0 ]; then
      fail "$name" "$workflow_name (Copilot) devrait avoir edit dans tools: mais ne l'a pas."
      return
    fi
    if [ "$should_have_write" = 0 ] && [ "$has_edit" = 1 ]; then
      fail "$name" "$workflow_name (Copilot) ne devrait pas avoir edit dans tools:."
      return
    fi

    local expect_guard=1
    [ "$workflow_name" = "maxime-init" ] && expect_guard=0
    local has_guard_claude=0
    local has_guard_copilot=0
    grep -q "demander l'autorisation explicite" "$claude_agent_path" && has_guard_claude=1
    grep -q "demander l'autorisation explicite" "$copilot_agent_path" && has_guard_copilot=1
    if [ "$expect_guard" = 1 ] && { [ "$has_guard_claude" = 0 ] || [ "$has_guard_copilot" = 0 ]; }; then
      fail "$name" "$workflow_name : garde bootstrap (redirection vers Maxime Init) manquante."
      return
    fi
    if [ "$expect_guard" = 0 ] && { [ "$has_guard_claude" = 1 ] || [ "$has_guard_copilot" = 1 ]; }; then
      fail "$name" "$workflow_name : ne devrait pas contenir la garde bootstrap (c'est Maxime Init lui-meme)."
      return
    fi
  done

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
check_kb_json_format
check_local_by_default
check_standalone_lib_script
check_workflow_agent_scoping

echo
if [ "${#failures[@]}" -gt 0 ]; then
  echo "mA.xI.me decision checks failed:"
  for f in "${failures[@]}"; do
    echo "- $f"
  done
  exit 1
fi

echo "mA.xI.me decision checks passed."
