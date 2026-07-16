#!/usr/bin/env bash
# Retire mA.xI.me pour Claude Code d'un repository Git cible.
# Script specialise, miroir de install-claude.sh.
# Usage: uninstall-claude.sh [--dry-run] [--remove-state] --repo-root <path>
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
src_repo_root="$(dirname "$(dirname "$script_dir")")"
# shellcheck source=./common.sh
. "$script_dir/common.sh"

stamp="$(date +%Y%m%d-%H%M%S)"

# remove_if_exists <path> <backup_dir>
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

backup_dir="$repo_root/.bkp/claude-uninstall/$stamp"
claude_root="$repo_root/.claude"

remove_if_exists "$repo_root/CLAUDE.md" "$backup_dir"

agents_target="$claude_root/agents"
if [ -d "$agents_target" ]; then
  for f in "$agents_target"/maxime*.md; do
    [ -e "$f" ] || continue
    remove_if_exists "$f" "$backup_dir/agents"
  done
  remove_empty_dir "$agents_target"
fi

skills_target="$claude_root/skills"
if [ -d "$skills_target" ]; then
  for d in "$skills_target"/maxime-*; do
    [ -e "$d" ] || continue
    remove_if_exists "$d" "$backup_dir/skills"
  done
  remove_empty_dir "$skills_target"
fi

src_hooks="$src_repo_root/install/Packaged/.claude/hooks"
hooks_target="$claude_root/hooks"
if [ -d "$src_hooks" ] && [ -d "$hooks_target" ]; then
  for f in "$src_hooks"/*; do
    [ -f "$f" ] || continue
    dest="$hooks_target/$(basename "$f")"
    remove_if_exists "$dest" "$backup_dir/hooks"
  done
  remove_empty_dir "$hooks_target"
fi

remove_if_exists "$claude_root/settings.json" "$backup_dir"
remove_if_exists "$claude_root/MAXIME_VERSION" "$backup_dir"
remove_empty_dir "$claude_root"

remove_git_exclude_entries "$repo_root" \
  '/CLAUDE.md' \
  '/.claude/agents/maxime*.md' \
  '/.claude/skills/maxime-*/' \
  '/.claude/hooks/block-destructive-bash.sh' \
  '/.claude/hooks/block-destructive-powershell.sh' \
  '/.claude/hooks/block-outside-repo-write.sh' \
  '/.claude/hooks/lib-path-guard.sh' \
  '/.claude/settings.json' \
  '/.claude/MAXIME_VERSION'
remove_gitignore_entries "$repo_root" '# mA.xI.me -- Claude Code (outil installe, pas du code source)' \
  '/CLAUDE.md' \
  '/.claude/agents/maxime*.md' \
  '/.claude/skills/maxime-*/' \
  '/.claude/hooks/block-destructive-bash.sh' \
  '/.claude/hooks/block-destructive-powershell.sh' \
  '/.claude/hooks/block-outside-repo-write.sh' \
  '/.claude/hooks/lib-path-guard.sh' \
  '/.claude/settings.json' \
  '/.claude/MAXIME_VERSION'

echo -e "\033[32mmA.xI.me retire pour Claude (workspace).\033[0m"
[ "$remove_state" = 1 ] || echo "Backups locaux: $backup_dir"
