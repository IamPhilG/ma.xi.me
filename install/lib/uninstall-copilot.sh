#!/usr/bin/env bash
# Retire mA.xI.me pour GitHub Copilot d'un repository Git cible.
# Script specialise, miroir de install-copilot.sh.
# Usage: uninstall-copilot.sh [--dry-run] [--remove-state] --repo-root <path>
set -euo pipefail

dry=0
remove_state=0
repo_root=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1 ;;
    --remove-state) remove_state=1 ;;
    --repo-root)
      shift
      repo_root="${1:-}"
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

[ -n "$repo_root" ] || { echo "Missing --repo-root" >&2; exit 1; }

run() { if [ "$dry" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./common.sh
. "$script_dir/common.sh"

stamp="$(date +%Y%m%d-%H%M%S)"

remove_if_exists() {
  local path="$1"
  local backup_dir="$2"
  [ -e "$path" ] || return 0
  if [ "$remove_state" != 1 ]; then
    if [ -d "$path" ]; then
      backup_dir_if_exists "$path" "$backup_dir"
    else
      backup_if_exists "$path" "$backup_dir"
    fi
  fi
  run rm -rf "$path"
}

remove_empty_dir() {
  local dir="$1"
  [ "$dry" = 1 ] && return 0
  if [ -d "$dir" ] && [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
    rmdir "$dir"
  fi
}

backup_dir="$repo_root/.bkp/copilot-uninstall/$stamp"
gh_root="$repo_root/.github"

remove_if_exists "$gh_root/copilot-instructions.md" "$backup_dir"

agents_target="$gh_root/agents"
if [ -d "$agents_target" ]; then
  for f in "$agents_target"/maxime*.agent.md; do
    [ -e "$f" ] || continue
    remove_if_exists "$f" "$backup_dir/agents"
  done
  remove_empty_dir "$agents_target"
fi

prompts_target="$gh_root/prompts"
if [ -d "$prompts_target" ]; then
  for f in "$prompts_target"/maxime-*.prompt.md; do
    [ -e "$f" ] || continue
    remove_if_exists "$f" "$backup_dir/prompts"
  done
  remove_empty_dir "$prompts_target"
fi

remove_empty_dir "$gh_root"

remove_git_exclude_entries "$repo_root" \
  '/.github/copilot-instructions.md' \
  '/.github/agents/maxime*.agent.md'
remove_gitignore_entries "$repo_root" '# mA.xI.me -- GitHub Copilot (outil installe, pas du code source)' \
  '/.github/copilot-instructions.md' \
  '/.github/agents/maxime*.agent.md'

echo -e "\033[32mmA.xI.me retire pour Copilot (workspace).\033[0m"
[ "$remove_state" = 1 ] || echo "Backups locaux: $backup_dir"
