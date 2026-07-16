#!/usr/bin/env bash
# Retire mA.xI.me d'un repo cible. Wrapper fin autour des scripts specialises
# sous install/lib/ : miroir de install.sh. Ne supprime que les fichiers que
# l'installateur projette, jamais un fichier non identifie comme provenant de
# mA.xI.me.
# Par defaut, .wip/ et .bkp/ du repo cible sont conserves. --remove-state les
# supprime aussi.
# Usage :
#   ./uninstall.sh [--dry-run] [--target claude|copilot|codex|both|all] [--workspace-root path] [--remove-state]
set -euo pipefail

dry=0
target="all"
workspace_root=""
remove_state=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1 ;;
    --remove-state) remove_state=1 ;;
    --target)
      shift
      if [ $# -eq 0 ] || [ -z "${1:-}" ] || [ "${1#--}" != "$1" ]; then
        echo "Missing value for --target" >&2
        exit 1
      fi
      target="${1:-}"
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

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lib_root="$script_dir/lib"
# shellcheck source=lib/common.sh
. "$lib_root/common.sh"

dry_flag=()
[ "$dry" = 1 ] && dry_flag=(--dry-run)
remove_state_flag=()
[ "$remove_state" = 1 ] && remove_state_flag=(--remove-state)

workspace_repo_root="$(resolve_workspace_repo_root "$workspace_root")"

case "$target" in
  claude)
    bash "$lib_root/uninstall-claude.sh" "${dry_flag[@]}" "${remove_state_flag[@]}" --repo-root "$workspace_repo_root"
    ;;
  copilot)
    bash "$lib_root/uninstall-copilot.sh" "${dry_flag[@]}" "${remove_state_flag[@]}" --repo-root "$workspace_repo_root"
    ;;
  codex)
    bash "$lib_root/uninstall-codex.sh" "${dry_flag[@]}" "${remove_state_flag[@]}" --repo-root "$workspace_repo_root"
    ;;
  both)
    bash "$lib_root/uninstall-claude.sh" "${dry_flag[@]}" "${remove_state_flag[@]}" --repo-root "$workspace_repo_root"
    bash "$lib_root/uninstall-copilot.sh" "${dry_flag[@]}" "${remove_state_flag[@]}" --repo-root "$workspace_repo_root"
    ;;
  all)
    bash "$lib_root/uninstall-claude.sh" "${dry_flag[@]}" "${remove_state_flag[@]}" --repo-root "$workspace_repo_root"
    bash "$lib_root/uninstall-copilot.sh" "${dry_flag[@]}" "${remove_state_flag[@]}" --repo-root "$workspace_repo_root"
    bash "$lib_root/uninstall-codex.sh" "${dry_flag[@]}" "${remove_state_flag[@]}" --repo-root "$workspace_repo_root"
    ;;
esac

# Etat local retire en dernier: laisse le temps aux backups d'exister avant.
if [ "$remove_state" = 1 ]; then
  for dir in "$workspace_repo_root/.wip" "$workspace_repo_root/.bkp"; do
    [ -e "$dir" ] || continue
    if [ "$dry" = 1 ]; then
      echo "[dry-run] rm -rf $dir"
    else
      rm -rf "$dir"
    fi
  done
fi

if [ "$dry" = 0 ]; then
  if [ "$remove_state" = 1 ]; then
    echo -e "\033[33mEtat local (.wip/, .bkp/) supprime.\033[0m"
  else
    echo -e "\033[36mEtat local (.wip/, .bkp/) conserve. Utilise --remove-state pour le supprimer aussi.\033[0m"
  fi
fi
