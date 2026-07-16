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
codex_agents_mixed=0

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

  # No confirmed native import/merge mechanism for AGENTS.md (issue #27): the
  # override-file semantics found in research were ambiguous ("at most one
  # file used per directory" suggests replace, not merge). Instead of
  # overwriting AGENTS.md wholesale, splice the generated content into an
  # explicit marker block, preserving any pre-existing project content
  # around it.
  backup_if_exists "$agents_target" "$backup_dir"
  if [ "$dry" = 0 ]; then
    local merge_result
    merge_result="$(merge_maxime_managed_block "$agents_target" "$codex_source")"
    if [ "$merge_result" = "mixed" ]; then
      codex_agents_mixed=1
      echo "AGENTS.md contient du contenu projet pre-existant -- fusionne avec le contenu genere via un bloc delimite, jamais ecrase entierement."
    fi
  else
    echo "[dry-run] merge generated content into $agents_target (preserving any pre-existing project content)"
  fi

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

  write_maxime_version_marker "$src_repo_root" "$repo_root/.agents/MAXIME_VERSION" "$backup_dir"

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
  # AGENTS.md is excluded by default only when it's purely tool-owned. Once
  # it mixes in real project content (issue #27 merge), it is no longer ours
  # alone to exclude -- the project content it now carries deserves the same
  # git treatment it would have had before mA.xI.me touched it.
  codex_exclude_entries=('/.agents/skills/maxime-*/' '/.agents/MAXIME_VERSION')
  if [ "$codex_agents_mixed" != 1 ]; then
    codex_exclude_entries=('/AGENTS.md' "${codex_exclude_entries[@]}")
  fi
  add_git_exclude_entries "$repo_root" "${codex_exclude_entries[@]}"
  add_gitignore_entries "$repo_root" '# mA.xI.me -- Codex (outil installe, pas du code source)' "${codex_exclude_entries[@]}"
fi
