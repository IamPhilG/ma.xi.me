#!/usr/bin/env bash
# Installe mA.xI.me pour Claude, GitHub Copilot et/ou Codex.
# Usage :
#   ./install.sh [--dry-run] [--target claude|copilot|codex|both|all] [--copilot-scope user|workspace] [--workspace-root path]
set -euo pipefail

dry=0
target="claude"
copilot_scope="user"
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
if [ -n "$workspace_root" ]; then
  workspace_repo_root="$(cd "$workspace_root" && pwd)"
else
  workspace_repo_root="$(pwd)"
fi
stamp="$(date +%Y%m%d-%H%M%S)"
day_stamp="$(date +%Y%m%d)"

backup_if_exists() {
  local src_path="$1"
  local backup_dir="$2"
  if [ -e "$src_path" ]; then
    run mkdir -p "$backup_dir"
    run cp -f "$src_path" "$backup_dir/$(basename "$src_path")"
  fi
}

install_claude() {
  local target_dir="$HOME/.claude"
  if [ ! -d "$target_dir" ]; then
    run mkdir -p "$target_dir"
  else
    run mkdir -p "$target_dir/backups"
    for d in agents skills; do
      if [ -d "$target_dir/$d" ]; then
        local bk="$target_dir/backups/${d}-pre-maxime-$stamp"
        run mkdir -p "$bk"
        run cp -R "$target_dir/$d/." "$bk/"
      fi
    done
    if [ -f "$target_dir/CLAUDE.md" ]; then
      run cp -f "$target_dir/CLAUDE.md" "$target_dir/backups/CLAUDE-pre-maxime-$stamp.md"
    fi
  fi

  run cp -f "$src_repo_root/CLAUDE.md" "$target_dir/CLAUDE.md"
  run mkdir -p "$target_dir/agents" "$target_dir/skills"
  run cp -R "$src_repo_root"/agents/maxime* "$target_dir/agents/"
  run cp -R "$src_repo_root"/skills/maxime* "$target_dir/skills/"

  if [ "$dry" = 0 ]; then
    echo -e "\033[32mmA.xI.me installe pour Claude dans $target_dir.\033[0m"
  fi
}

install_copilot() {
  local copilot_src="$src_repo_root/.copilot"
  if [ ! -d "$copilot_src" ]; then
    echo "Missing source directory: $copilot_src" >&2
    exit 1
  fi

  local agents_target prompts_target instructions_target instructions_dir backup_dir memory_target
  if [ "$copilot_scope" = "workspace" ]; then
    agents_target="$workspace_repo_root/.github/agents"
    prompts_target="$workspace_repo_root/.github/prompts"
    instructions_target="$workspace_repo_root/.github/copilot-instructions.md"
    instructions_dir=""
    memory_target="$workspace_repo_root/.copilot/memory/$day_stamp.session-handoff.md"
    backup_dir="$HOME/.copilot/backups/$stamp"

    if [ "$workspace_repo_root" = "$src_repo_root" ]; then
      echo "Warning: workspace scope cible le repo source mA.xI.me ($workspace_repo_root). Utilise --workspace-root <repo-cible> pour un autre repo." >&2
    fi
  else
    agents_target="$HOME/.copilot/agents"
    if [ "$(uname -s)" = "Darwin" ]; then
      prompts_target="$HOME/Library/Application Support/Code/User/prompts"
    else
      prompts_target="$HOME/.config/Code/User/prompts"
    fi
    instructions_dir="$HOME/.copilot/instructions"
    instructions_target="$instructions_dir/maxime-global.instructions.md"
    memory_target=""
    backup_dir="$HOME/.copilot/backups/$stamp"
  fi

  run mkdir -p "$agents_target" "$prompts_target"
  if [ -n "$instructions_dir" ]; then
    run mkdir -p "$instructions_dir"
  fi

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

  if [ "$copilot_scope" = "workspace" ]; then
    run mkdir -p "$(dirname "$memory_target")"
    if [ ! -f "$memory_target" ]; then
      if [ "$dry" = 1 ]; then
        echo "[dry-run] create $memory_target"
      else
        cat > "$memory_target" <<EOF
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
    fi
  fi

  if [ "$dry" = 0 ]; then
    echo -e "\033[32mmA.xI.me installe pour Copilot ($copilot_scope).\033[0m"
    echo "Instructions: $instructions_target"
    echo "Agents: $agents_target"
    echo "Prompts: $prompts_target"
  fi
}

install_codex() {
  local codex_home="$HOME/.codex"
  local skills_target="$HOME/.agents/skills"
  local backup_dir="$codex_home/backups/$stamp"
  local global_agents="$codex_home/AGENTS.md"
  local codex_src="$src_repo_root/.codex"
  local repo_skills_src="$src_repo_root/.agents/skills"

  if [ ! -d "$codex_src" ]; then
    echo "Missing source directory: $codex_src" >&2
    exit 1
  fi
  if [ ! -d "$repo_skills_src" ]; then
    echo "Missing source directory: $repo_skills_src" >&2
    exit 1
  fi

  bash "$src_repo_root/tools/check-codex-skills-sync.sh"

  run mkdir -p "$codex_home" "$skills_target"

  backup_if_exists "$global_agents" "$backup_dir"

  if compgen -G "$skills_target/maxime*" > /dev/null; then
    run mkdir -p "$backup_dir/skills"
    for f in "$skills_target"/maxime*; do
      [ -e "$f" ] || continue
      run cp -R "$f" "$backup_dir/skills/"
    done
  fi

  run cp -f "$codex_src/AGENTS.md" "$global_agents"
  run cp -R "$repo_skills_src"/maxime* "$skills_target/"

  if [ "$dry" = 0 ]; then
    echo -e "\033[32mmA.xI.me installe pour Codex.\033[0m"
    echo "Instructions: $global_agents"
    echo "Skills: $skills_target"
  fi
}

if [ "$target" = "claude" ]; then
  install_claude
elif [ "$target" = "copilot" ]; then
  install_copilot
elif [ "$target" = "codex" ]; then
  install_codex
elif [ "$target" = "all" ]; then
  install_claude
  install_copilot
  install_codex
else
  install_claude
  install_copilot
fi
