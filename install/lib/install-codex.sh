#!/usr/bin/env bash
# Installe mA.xI.me pour Codex dans un repository Git cible.
# Script specialise, callable seul ou depuis install.sh.
# Usage: install-codex.sh [--dry-run] [--shared] --repo-root <path>
set -euo pipefail

dry=0
shared=0
repo_root=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1 ;;
    --shared) shared=1 ;;
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
src_repo_root="$(dirname "$(dirname "$script_dir")")"
# shellcheck source=./common.sh
. "$script_dir/common.sh"

stamp="$(date +%Y%m%d-%H%M%S)"

install_codex_workspace() {
  local codex_source="$src_repo_root/install/Packaged/.codex/AGENTS.md"
  local skills_source_root="$src_repo_root/install/Packaged/.agents/skills"
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

  local src_version="$src_repo_root/install/Packaged/VERSION"
  if [ -f "$src_version" ]; then
    local version_target="$repo_root/.agents/MAXIME_VERSION"
    backup_if_exists "$version_target" "$backup_dir"
    run cp -f "$src_version" "$version_target"
  fi

  if [ "$dry" = 0 ]; then
    echo -e "\033[32mmA.xI.me installe pour Codex (workspace).\033[0m"
    echo "Repo cible: $repo_root"
    echo "Instructions: $agents_target"
    echo "Skills: $skills_target_root"
    echo "Backups locaux: $backup_dir"
  fi
}

install_codex_workspace

if [ "$shared" != 1 ]; then
  add_git_exclude_entries "$repo_root" \
    '/AGENTS.md' \
    '/.agents/skills/maxime-*/' \
    '/.agents/MAXIME_VERSION'
  add_gitignore_entries "$repo_root" '# mA.xI.me -- Codex (outil installe, pas du code source)' \
    '/AGENTS.md' \
    '/.agents/skills/maxime-*/' \
    '/.agents/MAXIME_VERSION'
fi
