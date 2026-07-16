#!/usr/bin/env bash
# Installe mA.xI.me en mode repo-only pour Claude Code, GitHub Copilot et/ou Codex.
# Wrapper fin autour des scripts specialises sous install/lib/ : chacun
# (install-claude.sh, install-copilot.sh, install-codex.sh, init-local-state.sh)
# est callable seul. Ce script orchestre la combinaison demandee par --target,
# retrocompatible avec les versions precedentes.
# Usage :
#   ./install.sh [--dry-run] [--target claude|copilot|codex|both|all] [--copilot-scope user|workspace] [--workspace-root path] [--shared]
set -euo pipefail

dry=0
target="all"
copilot_scope="workspace"
workspace_root=""
shared=0

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1 ;;
    --shared) shared=1 ;;
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

if [ "$copilot_scope" != "workspace" ]; then
  echo "Installation globale retiree: --copilot-scope '$copilot_scope' n'est plus supporte. Utilise --copilot-scope workspace." >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lib_root="$script_dir/lib"
# shellcheck source=lib/common.sh
. "$lib_root/common.sh"

dry_flag=()
[ "$dry" = 1 ] && dry_flag=(--dry-run)
shared_flag=()
[ "$shared" = 1 ] && shared_flag=(--shared)

workspace_repo_root="$(resolve_workspace_repo_root "$workspace_root")"

bash "$lib_root/init-local-state.sh" "${dry_flag[@]}" --repo-root "$workspace_repo_root"

case "$target" in
  claude)
    bash "$lib_root/install-claude.sh" "${dry_flag[@]}" "${shared_flag[@]}" --repo-root "$workspace_repo_root"
    ;;
  copilot)
    bash "$lib_root/install-copilot.sh" "${dry_flag[@]}" "${shared_flag[@]}" --repo-root "$workspace_repo_root"
    ;;
  codex)
    bash "$lib_root/install-codex.sh" "${dry_flag[@]}" "${shared_flag[@]}" --repo-root "$workspace_repo_root"
    ;;
  both)
    bash "$lib_root/install-claude.sh" "${dry_flag[@]}" "${shared_flag[@]}" --repo-root "$workspace_repo_root"
    bash "$lib_root/install-copilot.sh" "${dry_flag[@]}" "${shared_flag[@]}" --repo-root "$workspace_repo_root"
    ;;
  all)
    bash "$lib_root/install-claude.sh" "${dry_flag[@]}" "${shared_flag[@]}" --repo-root "$workspace_repo_root"
    bash "$lib_root/install-copilot.sh" "${dry_flag[@]}" "${shared_flag[@]}" --repo-root "$workspace_repo_root"
    bash "$lib_root/install-codex.sh" "${dry_flag[@]}" "${shared_flag[@]}" --repo-root "$workspace_repo_root"
    ;;
esac

if [ "$dry" = 0 ]; then
  if [ "$shared" = 1 ]; then
    echo -e "\033[36mMode partage : les fichiers installes restent commitables (comme avant).\033[0m"
  else
    echo -e "\033[36mMode local (par defaut) : les fichiers installes sont exclus localement via .git/info/exclude, jamais commitables. Utilise --shared pour les rendre commitables et partages avec l'equipe.\033[0m"
  fi
fi
