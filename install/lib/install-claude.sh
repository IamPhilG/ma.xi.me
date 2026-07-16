#!/usr/bin/env bash
# Installe mA.xI.me pour Claude Code dans un repository Git cible.
# Script specialise, callable seul ou depuis install.sh.
# Usage: install-claude.sh [--dry-run] [--shared] --repo-root <path>
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

install_claude_workspace() {
  local src_claude_md="$src_repo_root/install/Packaged/CLAUDE.md"
  local src_agents="$src_repo_root/install/Packaged/agents"
  local src_skills="$src_repo_root/install/Packaged/skills"
  local src_settings="$src_repo_root/install/Packaged/.claude/settings.json"
  local src_hooks="$src_repo_root/install/Packaged/.claude/hooks"
  local src_version="$src_repo_root/install/Packaged/VERSION"

  if [ ! -f "$src_claude_md" ]; then
    echo "Missing source file: $src_claude_md" >&2
    exit 1
  fi
  if [ ! -d "$src_agents" ]; then
    echo "Missing source directory: $src_agents" >&2
    exit 1
  fi

  local backup_dir="$repo_root/.bkp/claude-install/$stamp"
  local claude_root="$repo_root/.claude"
  local claude_md_target="$repo_root/CLAUDE.md"
  local agents_target="$claude_root/agents"
  local skills_target="$claude_root/skills"
  local hooks_target="$claude_root/hooks"
  local settings_target="$claude_root/settings.json"

  run mkdir -p "$agents_target" "$hooks_target"

  backup_if_exists "$claude_md_target" "$backup_dir"
  run cp -f "$src_claude_md" "$claude_md_target"

  if [ -f "$src_settings" ]; then
    backup_if_exists "$settings_target" "$backup_dir"
    run cp -f "$src_settings" "$settings_target"
  fi

  if [ -f "$src_version" ]; then
    local version_target="$claude_root/MAXIME_VERSION"
    backup_if_exists "$version_target" "$backup_dir"
    run cp -f "$src_version" "$version_target"
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

  if [ -d "$src_skills" ]; then
    for d in "$src_skills"/maxime*; do
      [ -d "$d" ] || continue
      run mkdir -p "$skills_target"
      dest="$skills_target/$(basename "$d")"
      backup_dir_if_exists "$dest" "$backup_dir/skills"
      run cp -R "$d" "$skills_target/"
    done
  fi

  if [ "$dry" = 0 ]; then
    echo -e "\033[32mmA.xI.me installe pour Claude (workspace).\033[0m"
    echo "Repo cible: $repo_root"
    echo "CLAUDE.md: $claude_md_target"
    echo "Agents: $agents_target"
    echo "Backups locaux: $backup_dir"
  fi
}

install_claude_workspace

if [ "$shared" != 1 ]; then
  add_git_exclude_entries "$repo_root" \
    '/CLAUDE.md' \
    '/.claude/agents/maxime*.md' \
    '/.claude/skills/maxime-*/' \
    '/.claude/hooks/block-destructive-bash.sh' \
    '/.claude/settings.json' \
    '/.claude/MAXIME_VERSION'
  add_gitignore_entries "$repo_root" '# mA.xI.me -- Claude Code (outil installe, pas du code source)' \
    '/CLAUDE.md' \
    '/.claude/agents/maxime*.md' \
    '/.claude/skills/maxime-*/' \
    '/.claude/hooks/block-destructive-bash.sh' \
    '/.claude/settings.json' \
    '/.claude/MAXIME_VERSION'
fi
