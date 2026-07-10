#!/usr/bin/env bash
# Installe mA.xI.me en mode repo-only pour GitHub Copilot.
# Les modes d'installation globaux ont ete retires.
# Usage :
#   ./install.sh [--dry-run] [--target claude|copilot|codex|both|all] [--copilot-scope user|workspace] [--workspace-root path]
set -euo pipefail

dry=0
target="copilot"
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

assert_repo_only_mode() {
  if [ "$target" != "copilot" ]; then
    echo "Installation globale retiree: --target '$target' n'est plus supporte. Utilise --target copilot --copilot-scope workspace." >&2
    exit 1
  fi

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

  printf '%s\n' "$repo_root"
}

backup_if_exists() {
  local src_path="$1"
  local backup_dir="$2"
  if [ -e "$src_path" ]; then
    run mkdir -p "$backup_dir"
    run cp -f "$src_path" "$backup_dir/$(basename "$src_path")"
  fi
}

install_copilot_workspace() {
  local repo_root="$1"
  local copilot_src="$src_repo_root/.copilot"
  if [ ! -d "$copilot_src" ]; then
    echo "Missing source directory: $copilot_src" >&2
    exit 1
  fi

  local agents_target prompts_target instructions_target backup_dir memory_target
  agents_target="$repo_root/.github/agents"
  prompts_target="$repo_root/.github/prompts"
  instructions_target="$repo_root/.github/copilot-instructions.md"
  memory_target="$repo_root/.copilot/memory/$day_stamp.session-handoff.md"
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

  if [ "$dry" = 0 ]; then
    echo -e "\033[32mmA.xI.me installe pour Copilot (workspace).\033[0m"
    echo "Repo cible: $repo_root"
    echo "Instructions: $instructions_target"
    echo "Agents: $agents_target"
    echo "Prompts: $prompts_target"
    echo "Backups locaux: $backup_dir"
  fi
}

assert_repo_only_mode
workspace_repo_root="$(resolve_workspace_repo_root)"
install_copilot_workspace "$workspace_repo_root"
