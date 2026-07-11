#!/usr/bin/env bash
# Installe mA.xI.me en mode repo-only pour Claude Code, GitHub Copilot et/ou Codex.
# Les modes d'installation globaux ont ete retires.
# Initialise aussi .wip/ et les exclusions Git locales du repo cible.
# Usage :
#   ./install.sh [--dry-run] [--target claude|copilot|codex|both|all] [--copilot-scope user|workspace] [--workspace-root path]
set -euo pipefail

dry=0
target="all"
copilot_scope="workspace"
workspace_root=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1 ;;
    --target)
      shift
      if [ $# -eq 0 ] || [ -z "${1:-}" ] || [ "${1#--}" != "$1" ]; then
        echo "Missing value for --target" >&2
        exit 1
      fi
      target="${1:-}"
      ;;
    --copilot-scope)
      shift
      if [ $# -eq 0 ] || [ -z "${1:-}" ] || [ "${1#--}" != "$1" ]; then
        echo "Missing value for --copilot-scope" >&2
        exit 1
      fi
      copilot_scope="${1:-}"
      ;;
    --workspace-root)
      shift
      if [ $# -eq 0 ] || [ -z "${1:-}" ] || [ "${1#--}" != "$1" ]; then
        echo "Missing value for --workspace-root" >&2
        exit 1
      fi
      workspace_root="${1:-}"
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

if [ "$target" != "claude" ] && [ "$target" != "copilot" ] && [ "$target" != "codex" ] && [ "$target" != "both" ] && [ "$target" != "all" ]; then
  echo "Invalid --target: $target (expected claude|copilot|codex|both|all)" >&2
  exit 1
fi

if [ "$copilot_scope" != "user" ] && [ "$copilot_scope" != "workspace" ]; then
  echo "Invalid --copilot-scope: $copilot_scope (expected user|workspace)" >&2
  exit 1
fi

run() { if [ "$dry" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src_repo_root="$(dirname "$script_dir")"
stamp="$(date +%Y%m%d-%H%M%S)"
day_stamp="$(date +%Y%m%d)"

target_includes_copilot() {
  case "$target" in
    copilot|both|all) return 0 ;;
    *) return 1 ;;
  esac
}

assert_repo_only_mode() {
  if [ "$copilot_scope" != "workspace" ]; then
    echo "Installation globale retiree: --copilot-scope '$copilot_scope' n'est plus supporte. Utilise --copilot-scope workspace." >&2
    exit 1
  fi
}

resolve_workspace_repo_root() {
  local repo_root
  if [ -n "$workspace_root" ]; then
    if ! repo_root="$(git -C "$workspace_root" rev-parse --show-toplevel 2>/dev/null)"; then
      echo "Le chemin --workspace-root '$workspace_root' ne pointe pas vers un repo git valide." >&2
      exit 1
    fi
  else
    if ! repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
      echo "Aucun repo git detecte dans le repertoire courant. Fournis --workspace-root <chemin-du-repo-cible>." >&2
      exit 1
    fi
  fi

  repo_root="$(cd "$repo_root" && pwd)"
  if [ "$repo_root" = "$src_repo_root" ]; then
    echo "Le repo cible ne peut pas etre le repo source mA.xI.me. Fournis --workspace-root <chemin-du-repo-cible>." >&2
    exit 1
  fi

  printf '%s\n' "$repo_root"
}

initialize_maxime_local_state() {
  local repo_root="$1"
  local state_root="$repo_root/.wip"
  local exclude_path
  local handoff_path="$state_root/memory/$day_stamp.session-handoff.md"
  local decisions_path="$state_root/adr/decisions-log.md"
  local dead_ends_path="$state_root/results/dead-ends.md"

  if [ "$dry" = 1 ]; then
    echo "[dry-run] mkdir -p $state_root/memory $state_root/specs $state_root/adr $state_root/results $state_root/tools $repo_root/.bkp"
    echo "[dry-run] copy cleanup-wip.ps1 and cleanup-wip.sh into $state_root/tools"
    echo "[dry-run] add /.wip/ and /.bkp/ to the target repo's Git local exclude file"
    return
  fi

  mkdir -p "$state_root/memory" "$state_root/specs" "$state_root/adr" "$state_root/results" "$state_root/tools" "$repo_root/.bkp"

  if [ ! -f "$handoff_path" ]; then
    cat > "$handoff_path" <<EOF
# Session Handoff

## Date
- $day_stamp

## Etat courant
- Aucun handoff initialise.

## Prochaines actions
- Definir la tache active.
- Confirmer les criteres d'acceptation.
- Executer puis verifier.
EOF
  fi

  [ -f "$decisions_path" ] || printf '# Decisions Log\n' > "$decisions_path"
  [ -f "$dead_ends_path" ] || printf '# Dead Ends\n' > "$dead_ends_path"

  local tools_source="$src_repo_root/core/tools"
  local tools_backup_dir="$repo_root/.bkp/maxime-tools/$stamp"
  for tool_name in cleanup-wip.ps1 cleanup-wip.sh; do
    if [ -f "$tools_source/$tool_name" ]; then
      backup_if_exists "$state_root/tools/$tool_name" "$tools_backup_dir"
      cp -f "$tools_source/$tool_name" "$state_root/tools/$tool_name"
      chmod +x "$state_root/tools/$tool_name" 2>/dev/null || true
    fi
  done

  exclude_path="$(git -C "$repo_root" rev-parse --git-path info/exclude)"
  case "$exclude_path" in
    /*) ;;
    *) exclude_path="$repo_root/$exclude_path" ;;
  esac
  mkdir -p "$(dirname "$exclude_path")"
  touch "$exclude_path"
  for entry in '/.wip/' '/.bkp/'; do
    grep -Fxq "$entry" "$exclude_path" || printf '%s\n' "$entry" >> "$exclude_path"
  done
}

backup_if_exists() {
  local src_path="$1"
  local backup_dir="$2"
  if [ -e "$src_path" ]; then
    run mkdir -p "$backup_dir"
    run cp -f "$src_path" "$backup_dir/$(basename "$src_path")"
  fi
}

backup_dir_if_exists() {
  local src_dir="$1"
  local backup_dir="$2"
  if [ -d "$src_dir" ]; then
    run mkdir -p "$backup_dir"
    run cp -R "$src_dir" "$backup_dir/"
  fi
}

install_claude_workspace() {
  local repo_root="$1"
  local src_claude_md="$src_repo_root/CLAUDE.md"
  local src_agents="$src_repo_root/agents"
  local src_skills="$src_repo_root/skills"
  local src_settings="$src_repo_root/.claude/settings.json"
  local src_hooks="$src_repo_root/.claude/hooks"

  if [ ! -f "$src_claude_md" ]; then
    echo "Missing source file: $src_claude_md" >&2
    exit 1
  fi
  if [ ! -d "$src_agents" ]; then
    echo "Missing source directory: $src_agents" >&2
    exit 1
  fi
  if [ ! -d "$src_skills" ]; then
    echo "Missing source directory: $src_skills" >&2
    exit 1
  fi

  local backup_dir="$repo_root/.bkp/claude-install/$stamp"
  local claude_root="$repo_root/.claude"
  local claude_md_target="$repo_root/CLAUDE.md"
  local agents_target="$claude_root/agents"
  local skills_target="$claude_root/skills"
  local hooks_target="$claude_root/hooks"
  local settings_target="$claude_root/settings.json"

  run mkdir -p "$agents_target" "$skills_target" "$hooks_target"

  backup_if_exists "$claude_md_target" "$backup_dir"
  run cp -f "$src_claude_md" "$claude_md_target"

  if [ -f "$src_settings" ]; then
    backup_if_exists "$settings_target" "$backup_dir"
    run cp -f "$src_settings" "$settings_target"
  fi

  if [ -d "$src_hooks" ]; then
    for f in "$src_hooks"/*; do
      [ -f "$f" ] || continue
      dest="$hooks_target/$(basename "$f")"
      backup_if_exists "$dest" "$backup_dir/hooks"
      run cp -f "$f" "$dest"
    done
  fi

  local has_agent=0
  for f in "$src_agents"/maxime*.md; do
    [ -f "$f" ] || continue
    has_agent=1
    dest="$agents_target/$(basename "$f")"
    backup_if_exists "$dest" "$backup_dir/agents"
    run cp -f "$f" "$dest"
  done
  if [ "$has_agent" -ne 1 ]; then
    echo "Aucun agent maxime*.md trouve dans $src_agents" >&2
    exit 1
  fi

  local has_skill=0
  for d in "$src_skills"/maxime*; do
    [ -d "$d" ] || continue
    has_skill=1
    dest="$skills_target/$(basename "$d")"
    backup_dir_if_exists "$dest" "$backup_dir/skills"
    run cp -R "$d" "$skills_target/"
  done
  if [ "$has_skill" -ne 1 ]; then
    echo "Aucun skill maxime* trouve dans $src_skills" >&2
    exit 1
  fi

  if [ "$dry" = 0 ]; then
    echo -e "\033[32mmA.xI.me installe pour Claude (workspace).\033[0m"
    echo "Repo cible: $repo_root"
    echo "CLAUDE.md: $claude_md_target"
    echo "Agents: $agents_target"
    echo "Skills: $skills_target"
    echo "Backups locaux: $backup_dir"
  fi
}

install_copilot_workspace() {
  local repo_root="$1"
  local copilot_src="$src_repo_root/.copilot"
  if [ ! -d "$copilot_src" ]; then
    echo "Missing source directory: $copilot_src" >&2
    exit 1
  fi

  local agents_target prompts_target instructions_target backup_dir
  agents_target="$repo_root/.github/agents"
  prompts_target="$repo_root/.github/prompts"
  instructions_target="$repo_root/.github/copilot-instructions.md"
  backup_dir="$repo_root/.bkp/copilot-install/$stamp"

  run mkdir -p "$agents_target" "$prompts_target"

  backup_if_exists "$instructions_target" "$backup_dir"

  for f in "$copilot_src"/agents/*.agent.md; do
    [ -e "$f" ] || continue
    dest="$agents_target/$(basename "$f")"
    backup_if_exists "$dest" "$backup_dir"
    run cp -f "$f" "$dest"
  done

  for f in "$copilot_src"/prompts/*.prompt.md; do
    [ -e "$f" ] || continue
    dest="$prompts_target/$(basename "$f")"
    backup_if_exists "$dest" "$backup_dir"
    run cp -f "$f" "$dest"
  done

  run cp -f "$copilot_src/copilot-instructions.md" "$instructions_target"

  if [ "$dry" = 0 ]; then
    echo -e "\033[32mmA.xI.me installe pour Copilot (workspace).\033[0m"
    echo "Repo cible: $repo_root"
    echo "Instructions: $instructions_target"
    echo "Agents: $agents_target"
    echo "Prompts: $prompts_target"
    echo "Backups locaux: $backup_dir"
  fi
}

install_codex_workspace() {
  local repo_root="$1"
  local codex_source="$src_repo_root/.codex/AGENTS.md"
  local skills_source_root="$src_repo_root/.agents/skills"
  local check_script="$src_repo_root/tools/check-adapter-sync.sh"

  if [ ! -f "$codex_source" ]; then
    echo "Missing source file: $codex_source" >&2
    exit 1
  fi
  if [ ! -d "$skills_source_root" ]; then
    echo "Missing source directory: $skills_source_root" >&2
    exit 1
  fi

  if [ -f "$check_script" ]; then
    if [ "$dry" = 1 ]; then
      echo "[dry-run] bash $check_script"
    else
      bash "$check_script"
    fi
  fi

  local backup_dir="$repo_root/.bkp/codex-install/$stamp"
  local agents_target="$repo_root/AGENTS.md"
  local skills_target_root="$repo_root/.agents/skills"

  run mkdir -p "$skills_target_root"

  backup_if_exists "$agents_target" "$backup_dir"
  run cp -f "$codex_source" "$agents_target"

  local has_skill=0
  for d in "$skills_source_root"/maxime*; do
    [ -d "$d" ] || continue
    has_skill=1
    dest="$skills_target_root/$(basename "$d")"
    backup_dir_if_exists "$dest" "$backup_dir/skills"
    run cp -R "$d" "$skills_target_root/"
  done
  if [ "$has_skill" -ne 1 ]; then
    echo "Aucun skill maxime* trouve dans $skills_source_root" >&2
    exit 1
  fi

  if [ "$dry" = 0 ]; then
    echo -e "\033[32mmA.xI.me installe pour Codex (workspace).\033[0m"
    echo "Repo cible: $repo_root"
    echo "Instructions: $agents_target"
    echo "Skills: $skills_target_root"
    echo "Backups locaux: $backup_dir"
  fi
}

assert_repo_only_mode
workspace_repo_root="$(resolve_workspace_repo_root)"
initialize_maxime_local_state "$workspace_repo_root"

case "$target" in
  claude)
    install_claude_workspace "$workspace_repo_root"
    ;;
  copilot)
    install_copilot_workspace "$workspace_repo_root"
    ;;
  codex)
    install_codex_workspace "$workspace_repo_root"
    ;;
  both)
    install_claude_workspace "$workspace_repo_root"
    install_copilot_workspace "$workspace_repo_root"
    ;;
  all)
    install_claude_workspace "$workspace_repo_root"
    install_copilot_workspace "$workspace_repo_root"
    install_codex_workspace "$workspace_repo_root"
    ;;
esac
