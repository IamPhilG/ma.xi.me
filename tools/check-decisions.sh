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

# Decision: a fresh install creates .wip/tools/kb-network-policy.json
# (fail-safe default: network_write false, network_read true) and writes a
# version marker (.claude/MAXIME_VERSION) computed LIVE at install time (git
# rev-parse HEAD of the source repo) -- never copied from a committed file,
# which would always be at least one commit stale (it can't know the commit
# that carries it). See decisions-log 2026-07-16.
# maxime-kb/maxime-start/maxime-init/maxime-handoff document the new
# network-policy, version-check, ttl-differentiation and
# session-learnings-capture behaviors in their generated text.
check_kb_network_policy_and_version() {
  local name="politique reseau KB + marqueur de version crees a l'installation fraiche"
  local fixture="$temp_root/fixture-kb-version"
  mkdir -p "$fixture"
  (cd "$fixture" && git init -q)

  if ! bash "$repository_root/install/install.sh" --target claude --workspace-root "$fixture" >/dev/null; then
    fail "$name" "Installation a echoue."
    return
  fi

  local policy_path="$fixture/.wip/tools/kb-network-policy.json"
  if [ ! -f "$policy_path" ]; then
    fail "$name" ".wip/tools/kb-network-policy.json manquant apres installation fraiche."
    return
  fi
  if ! grep -q '"network_write": false' "$policy_path"; then
    fail "$name" "network_write devrait etre false par defaut, trouve: $(cat "$policy_path")"
    return
  fi
  if ! grep -q '"network_read": true' "$policy_path"; then
    fail "$name" "network_read devrait etre true par defaut, trouve: $(cat "$policy_path")"
    return
  fi

  local installed_version_path="$fixture/.claude/MAXIME_VERSION"
  if [ ! -f "$installed_version_path" ]; then
    fail "$name" ".claude/MAXIME_VERSION non cree a l'installation."
    return
  fi
  local live_sha installed_sha
  live_sha="$(git -C "$repository_root" rev-parse HEAD)"
  installed_sha="$(cat "$installed_version_path")"
  if [ "$live_sha" != "$installed_sha" ]; then
    fail "$name" ".claude/MAXIME_VERSION ($installed_sha) ne correspond pas au HEAD reel du repo source ($live_sha) -- devrait etre calcule en direct, pas copie d'un fichier committe."
    return
  fi

  if ! grep -q 'MAXIME_VERSION' "$repository_root/install/Packaged/agents/maxime-start.md"; then
    fail "$name" "L'agent maxime-start genere ne mentionne pas la comparaison de version."
    return
  fi
  local maxime_kb_agent="$repository_root/install/Packaged/agents/maxime-kb.md"
  if ! grep -q 'kb-network-policy\.json' "$maxime_kb_agent"; then
    fail "$name" "L'agent maxime-kb genere ne mentionne pas la politique reseau."
    return
  fi
  if ! grep -q 'ttl_days' "$maxime_kb_agent"; then
    fail "$name" "L'agent maxime-kb genere ne mentionne pas ttl_days."
    return
  fi
  if ! grep -q 'Maxime KB' "$repository_root/install/Packaged/agents/maxime-handoff.md"; then
    fail "$name" "L'agent maxime-handoff genere ne mentionne pas la capture de lecons via Maxime KB."
    return
  fi
  if ! grep -qE 'network_read|network_write' "$repository_root/install/Packaged/agents/maxime-init.md"; then
    fail "$name" "L'agent maxime-init genere ne mentionne pas la question de politique reseau."
    return
  fi

  pass "$name"
}

# Decision (issue #29): maxime-kb documents not just the network-write guard
# but the actual two-repo Git mechanic needed to push a fiche to
# knowledge-base/ -- checkout main before writing (submodules default to
# detached HEAD) and a second commit in the consumer repo to bump the
# submodule pointer, proposed in the same pass, not a step to forget.
check_kb_submodule_push_mechanics() {
  local name="maxime-kb documente la mecanique Git en 2 temps pour pousser vers knowledge-base (issue #29)"
  local maxime_kb_agent="$repository_root/install/Packaged/agents/maxime-kb.md"
  if ! grep -q 'checkout main' "$maxime_kb_agent"; then
    fail "$name" "L'agent maxime-kb genere ne mentionne pas de sortir le submodule du detached HEAD (git checkout main)."
    return
  fi
  if ! grep -qi 'bump' "$maxime_kb_agent"; then
    fail "$name" "L'agent maxime-kb genere ne mentionne pas le second commit de bump du pointeur de submodule."
    return
  fi
  if ! grep -q 'submodule (new commits)' "$maxime_kb_agent"; then
    fail "$name" "L'agent maxime-kb genere ne mentionne pas la verification de derive post-push (git status)."
    return
  fi

  pass "$name"
}

# Decision: cleanup-wip only purges .wip/kb/archived/ by age (never
# .wip/kb/active/), and must not fail when .wip/kb/archived/ does not exist
# yet (same class of regression as the 2026-07-11 set -e/tests bug).
check_kb_cleanup_without_archived() {
  local name="cleanup-wip gere .wip/kb/archived/ absent sans erreur"
  local fixture="$temp_root/fixture-kb-cleanup"
  mkdir -p "$fixture"
  (cd "$fixture" && git init -q)

  if ! bash "$repository_root/install/install.sh" --target claude --workspace-root "$fixture" >/dev/null; then
    fail "$name" "Installation a echoue."
    return
  fi

  rm -rf "$fixture/.wip/kb/archived"
  if ! bash "$fixture/.wip/tools/cleanup-wip.sh" --workspace-root "$fixture" >/dev/null; then
    fail "$name" "cleanup-wip.sh a echoue avec .wip/kb/archived absent."
    return
  fi

  pass "$name"
}

# Decision: pre-existing project-specific CLAUDE.md / copilot-instructions.md
# / AGENTS.md content is never silently overwritten (issue #27). Claude and
# Copilot: moved once into a companion file the host merges natively
# (.claude/rules/, .github/instructions/). Codex: merged in place inside an
# explicit marker block (no confirmed native merge mechanism). A repo whose
# AGENTS.md now mixes project + generated content is not added to the
# default git-exclude list for that file -- it is no longer purely tool-owned.
check_preserve_project_content() {
  local name="contenu projet pre-existant preserve, jamais ecrase (issue #27)"
  local fixture="$temp_root/fixture-preserve-project"
  mkdir -p "$fixture"
  (cd "$fixture" && git init -q)

  local project_claude_marker="PROJET: convention Claude specifique a ce repo, jamais generee par un outil."
  local project_copilot_marker="PROJET: convention Copilot specifique a ce repo, jamais generee par un outil."
  local project_agents_marker="PROJET: convention Codex specifique a ce repo, jamais generee par un outil."
  printf '%s' "$project_claude_marker" > "$fixture/CLAUDE.md"
  mkdir -p "$fixture/.github"
  printf '%s' "$project_copilot_marker" > "$fixture/.github/copilot-instructions.md"
  printf '%s' "$project_agents_marker" > "$fixture/AGENTS.md"

  if ! bash "$repository_root/install/install.sh" --target all --workspace-root "$fixture" >/dev/null; then
    fail "$name" "Installation a echoue."
    return
  fi

  local rules_file="$fixture/.claude/rules/project-conventions.md"
  if [ ! -f "$rules_file" ]; then
    fail "$name" ".claude/rules/project-conventions.md non cree."
    return
  fi
  if ! grep -qF "$project_claude_marker" "$rules_file"; then
    fail "$name" "Contenu CLAUDE.md pre-existant absent de .claude/rules/project-conventions.md."
    return
  fi
  if ! grep -q "Generated from" "$fixture/CLAUDE.md"; then
    fail "$name" "CLAUDE.md ne contient pas le contenu genere apres installation."
    return
  fi

  local instr_file="$fixture/.github/instructions/project-conventions.instructions.md"
  if [ ! -f "$instr_file" ]; then
    fail "$name" ".github/instructions/project-conventions.instructions.md non cree."
    return
  fi
  if ! grep -qF "$project_copilot_marker" "$instr_file"; then
    fail "$name" "Contenu copilot-instructions.md pre-existant absent du fichier instructions preserve."
    return
  fi
  if ! grep -qE 'applyTo:\s*"\*\*"' "$instr_file"; then
    fail "$name" "Frontmatter applyTo manquant dans le fichier instructions preserve."
    return
  fi

  local agents_target="$fixture/AGENTS.md"
  if ! grep -qF "$project_agents_marker" "$agents_target"; then
    fail "$name" "Contenu AGENTS.md pre-existant perdu apres installation (devrait etre fusionne, pas ecrase)."
    return
  fi
  if ! grep -q "Generated from" "$agents_target"; then
    fail "$name" "AGENTS.md ne contient pas le contenu genere apres installation."
    return
  fi
  if ! grep -qF '<!-- BEGIN mA.xI.me generated -->' "$agents_target"; then
    fail "$name" "Bloc delimite mA.xI.me absent de AGENTS.md."
    return
  fi

  local exclude_path
  exclude_path="$(git -C "$fixture" rev-parse --git-path info/exclude)"
  case "$exclude_path" in
    /*) ;;
    *) exclude_path="$fixture/$exclude_path" ;;
  esac
  if grep -qxF '/AGENTS.md' "$exclude_path" 2>/dev/null; then
    fail "$name" "AGENTS.md ne devrait pas etre exclu par defaut une fois melange a du contenu projet."
    return
  fi
  if ! grep -qxF '/CLAUDE.md' "$exclude_path" 2>/dev/null; then
    fail "$name" "CLAUDE.md devrait rester exclu par defaut (redevenu propre apres preservation du contenu projet)."
    return
  fi

  # Reinstall: idempotent, no duplication of the preserved companion files or
  # of the managed block inside AGENTS.md.
  if ! bash "$repository_root/install/install.sh" --target all --workspace-root "$fixture" >/dev/null; then
    fail "$name" "Reinstallation a echoue."
    return
  fi
  local block_count
  block_count="$(grep -oF '<!-- BEGIN mA.xI.me generated -->' "$agents_target" | wc -l | tr -d ' ')"
  if [ "$block_count" != "1" ]; then
    fail "$name" "Reinstallation a duplique le bloc gere dans AGENTS.md (trouve $block_count fois, attendu 1)."
    return
  fi
  if ! grep -qF "$project_agents_marker" "$agents_target"; then
    fail "$name" "Reinstallation a perdu le contenu projet dans AGENTS.md."
    return
  fi

  # Uninstall: the managed block is stripped, project content in AGENTS.md
  # survives (never a full-file delete for a mixed file).
  if ! bash "$repository_root/install/uninstall.sh" --target codex --workspace-root "$fixture" >/dev/null; then
    fail "$name" "Uninstall a echoue."
    return
  fi
  if [ ! -f "$agents_target" ]; then
    fail "$name" "uninstall a supprime AGENTS.md entierement alors qu'il contenait du contenu projet."
    return
  fi
  if ! grep -qF "$project_agents_marker" "$agents_target"; then
    fail "$name" "uninstall a perdu le contenu projet dans AGENTS.md."
    return
  fi
  if grep -qF '<!-- BEGIN mA.xI.me generated -->' "$agents_target"; then
    fail "$name" "uninstall n'a pas retire le bloc gere de AGENTS.md."
    return
  fi

  pass "$name"
}

# Decision (issue #34): no write is allowed outside the target repo, not
# just by the installer -- .wip/tmp/ is the sanctioned place for ephemeral
# files, and 3 hooks enforce path-containment for the tools that can write:
# Bash (block-destructive-bash.sh), PowerShell (block-destructive-powershell.sh,
# verified empirically that Claude Code hooks CAN intercept the PowerShell
# tool), and Write/Edit/NotebookEdit (block-outside-repo-write.sh, the
# reliable check -- it reads tool_input.file_path directly, no command
# string to guess at). A fresh install creates .wip/tmp/ and the three hook
# scripts + lib-path-guard.sh; functional checks below pipe real payloads
# through each hook and assert the actual allow/deny decision, not just
# file presence.
check_no_writes_outside_repo() {
  local name="aucune ecriture hors du repo -- .wip/tmp/ + 3 hooks path-aware (issue #34)"
  local fixture="$temp_root/fixture-no-outside-write"
  mkdir -p "$fixture"
  (cd "$fixture" && git init -q)
  # Re-resolve to whatever form `git rev-parse --show-toplevel` normalizes
  # to (on this git-bash/Windows setup, that's the C:/... drive-letter form,
  # not the /tmp/... form mktemp -d originally returned) -- the hooks
  # themselves resolve repo_root the same way, so the fixture path used in
  # every payload below must match that exact representation or the
  # containment check compares two different spellings of the same directory.
  fixture="$(git -C "$fixture" rev-parse --show-toplevel)"

  if ! bash "$repository_root/install/install.sh" --target claude --workspace-root "$fixture" >/dev/null; then
    fail "$name" "Installation a echoue."
    return
  fi

  if [ ! -d "$fixture/.wip/tmp" ]; then
    fail "$name" ".wip/tmp/ non cree a l'installation fraiche."
    return
  fi

  local hooks_dir="$fixture/.claude/hooks"
  for f in lib-path-guard.sh block-destructive-bash.sh block-destructive-powershell.sh block-outside-repo-write.sh; do
    if [ ! -f "$hooks_dir/$f" ]; then
      fail "$name" "$f manquant dans .claude/hooks/ apres installation."
      return
    fi
  done

  if ! grep -q '"matcher": "PowerShell"' "$fixture/.claude/settings.json"; then
    fail "$name" ".claude/settings.json ne declare pas de hook pour l'outil PowerShell."
    return
  fi
  if ! grep -qE '"matcher": "Write\|Edit\|NotebookEdit"' "$fixture/.claude/settings.json"; then
    fail "$name" ".claude/settings.json ne declare pas de hook pour Write/Edit/NotebookEdit."
    return
  fi

  # Functional checks: real payloads through the real hooks, asserting the
  # actual allow/deny decision (jq present is a prerequisite of this repo's
  # own hook, see README "Prerequis").
  local outside_dir
  outside_dir="$(mktemp -d)"
  local payload out

  payload="$(mktemp)"
  printf '{"cwd":"%s","tool_input":{"file_path":"%s/outside.txt","content":"x"}}' "$fixture" "$outside_dir" > "$payload"
  out="$(bash "$hooks_dir/block-outside-repo-write.sh" < "$payload")"
  if [ -z "$out" ]; then
    fail "$name" "block-outside-repo-write.sh laisse passer une ecriture hors repo (Write/Edit)."
    rm -rf "$outside_dir" "$payload"
    return
  fi

  printf '{"cwd":"%s","tool_input":{"file_path":"%s/.wip/tmp/inside.txt","content":"x"}}' "$fixture" "$fixture" > "$payload"
  out="$(bash "$hooks_dir/block-outside-repo-write.sh" < "$payload")"
  if [ -n "$out" ]; then
    fail "$name" "block-outside-repo-write.sh bloque une ecriture legitime DANS le repo (.wip/tmp/)."
    rm -rf "$outside_dir" "$payload"
    return
  fi

  printf '{"cwd":"%s","tool_input":{"command":"echo hello > %s/outside.txt"}}' "$fixture" "$outside_dir" > "$payload"
  out="$(bash "$hooks_dir/block-destructive-bash.sh" < "$payload")"
  if [ -z "$out" ]; then
    fail "$name" "block-destructive-bash.sh laisse passer une redirection vers un chemin absolu hors repo."
    rm -rf "$outside_dir" "$payload"
    return
  fi

  printf '{"cwd":"%s","tool_input":{"command":"echo hello > .wip/tmp/inside.txt"}}' "$fixture" > "$payload"
  out="$(bash "$hooks_dir/block-destructive-bash.sh" < "$payload")"
  if [ -n "$out" ]; then
    fail "$name" "block-destructive-bash.sh bloque une redirection relative legitime DANS le repo (regression du faux positif issue #27)."
    rm -rf "$outside_dir" "$payload"
    return
  fi

  printf '{"cwd":"%s","tool_input":{"command":"Set-Content -Path \\"%s\\\\outside.txt\\" -Value hello"}}' "$fixture" "$outside_dir" > "$payload"
  out="$(bash "$hooks_dir/block-destructive-powershell.sh" < "$payload")"
  if [ -z "$out" ]; then
    fail "$name" "block-destructive-powershell.sh laisse passer une ecriture vers un chemin absolu entre guillemets hors repo."
    rm -rf "$outside_dir" "$payload"
    return
  fi

  rm -rf "$outside_dir" "$payload"
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
check_kb_network_policy_and_version
check_kb_submodule_push_mechanics
check_kb_cleanup_without_archived
check_preserve_project_content
check_no_writes_outside_repo
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
