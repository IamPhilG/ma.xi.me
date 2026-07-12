#!/usr/bin/env bash
# Retire mA.xI.me d'un repo cible. Miroir de install.sh : ne supprime que les
# fichiers que l'installateur projette, jamais un fichier non identifie comme
# provenant de mA.xI.me.
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

run() { if [ "$dry" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src_repo_root="$(dirname "$script_dir")"
stamp="$(date +%Y%m%d-%H%M%S)"

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
    echo "Le repo cible ne peut pas etre le repo source mA.xI.me." >&2
    exit 1
  fi

  printf '%s\n' "$repo_root"
}

backup_if_exists() {
  local src_path="$1"
  local backup_dir="$2"
  [ "$remove_state" = 1 ] && return 0
  if [ -e "$src_path" ]; then
    run mkdir -p "$backup_dir"
    run cp -Rf "$src_path" "$backup_dir/$(basename "$src_path")"
  fi
}

# remove_if_exists <path> <backup_dir>
remove_if_exists() {
  local path="$1"
  local backup_dir="$2"
  [ -e "$path" ] || return 0
  backup_if_exists "$path" "$backup_dir"
  run rm -rf "$path"
}

remove_empty_dir() {
  local dir="$1"
  [ "$dry" = 1 ] && return 0
  if [ -d "$dir" ] && [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
    rmdir "$dir"
  fi
}

# remove_git_exclude_entries <repo_root> <entry> [entry...]
remove_git_exclude_entries() {
  local repo_root="$1"
  shift
  if [ "$dry" = 1 ]; then
    for entry in "$@"; do
      echo "[dry-run] remove $entry from the target repo's Git local exclude file"
    done
    return
  fi
  local exclude_path
  exclude_path="$(git -C "$repo_root" rev-parse --git-path info/exclude)"
  case "$exclude_path" in
    /*) ;;
    *) exclude_path="$repo_root/$exclude_path" ;;
  esac
  [ -f "$exclude_path" ] || return 0
  local tmp
  tmp="$(mktemp)"
  cp "$exclude_path" "$tmp"
  for entry in "$@"; do
    local tmp2
    tmp2="$(mktemp)"
    grep -vFx "$entry" "$tmp" > "$tmp2" || true
    mv "$tmp2" "$tmp"
  done
  mv "$tmp" "$exclude_path"
}

uninstall_claude_workspace() {
  local repo_root="$1"
  local backup_dir="$repo_root/.bkp/claude-uninstall/$stamp"
  local claude_root="$repo_root/.claude"

  remove_if_exists "$repo_root/CLAUDE.md" "$backup_dir"

  local agents_target="$claude_root/agents"
  if [ -d "$agents_target" ]; then
    for f in "$agents_target"/maxime*.md; do
      [ -e "$f" ] || continue
      remove_if_exists "$f" "$backup_dir/agents"
    done
    remove_empty_dir "$agents_target"
  fi

  local skills_target="$claude_root/skills"
  if [ -d "$skills_target" ]; then
    for d in "$skills_target"/maxime-*; do
      [ -e "$d" ] || continue
      remove_if_exists "$d" "$backup_dir/skills"
    done
    remove_empty_dir "$skills_target"
  fi

  local src_hooks="$src_repo_root/.claude/hooks"
  local hooks_target="$claude_root/hooks"
  if [ -d "$src_hooks" ] && [ -d "$hooks_target" ]; then
    for f in "$src_hooks"/*; do
      [ -f "$f" ] || continue
      local dest="$hooks_target/$(basename "$f")"
      remove_if_exists "$dest" "$backup_dir/hooks"
    done
    remove_empty_dir "$hooks_target"
  fi

  remove_if_exists "$claude_root/settings.json" "$backup_dir"
  remove_empty_dir "$claude_root"

  remove_git_exclude_entries "$repo_root" \
    '/CLAUDE.md' \
    '/.claude/agents/maxime*.md' \
    '/.claude/skills/maxime-*/' \
    '/.claude/hooks/block-destructive-bash.sh' \
    '/.claude/settings.json'

  echo -e "\033[32mmA.xI.me retire pour Claude (workspace).\033[0m"
  [ "$remove_state" = 1 ] || echo "Backups locaux: $backup_dir"
}

uninstall_copilot_workspace() {
  local repo_root="$1"
  local backup_dir="$repo_root/.bkp/copilot-uninstall/$stamp"
  local gh_root="$repo_root/.github"

  remove_if_exists "$gh_root/copilot-instructions.md" "$backup_dir"

  local agents_target="$gh_root/agents"
  if [ -d "$agents_target" ]; then
    for f in "$agents_target"/maxime*.agent.md; do
      [ -e "$f" ] || continue
      remove_if_exists "$f" "$backup_dir/agents"
    done
    remove_empty_dir "$agents_target"
  fi

  local prompts_target="$gh_root/prompts"
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
    '/.github/agents/maxime*.agent.md' \
    '/.github/prompts/maxime-*.prompt.md'

  echo -e "\033[32mmA.xI.me retire pour Copilot (workspace).\033[0m"
  [ "$remove_state" = 1 ] || echo "Backups locaux: $backup_dir"
}

uninstall_codex_workspace() {
  local repo_root="$1"
  local backup_dir="$repo_root/.bkp/codex-uninstall/$stamp"

  remove_if_exists "$repo_root/AGENTS.md" "$backup_dir"

  local skills_target_root="$repo_root/.agents/skills"
  if [ -d "$skills_target_root" ]; then
    for d in "$skills_target_root"/maxime-*; do
      [ -e "$d" ] || continue
      remove_if_exists "$d" "$backup_dir/skills"
    done
    remove_empty_dir "$skills_target_root"
    remove_empty_dir "$repo_root/.agents"
  fi

  remove_git_exclude_entries "$repo_root" \
    '/AGENTS.md' \
    '/.agents/skills/maxime-*/'

  echo -e "\033[32mmA.xI.me retire pour Codex (workspace).\033[0m"
  [ "$remove_state" = 1 ] || echo "Backups locaux: $backup_dir"
}

remove_maxime_local_state() {
  local repo_root="$1"
  [ "$remove_state" = 1 ] || return 0
  for dir in "$repo_root/.wip" "$repo_root/.bkp"; do
    [ -e "$dir" ] || continue
    run rm -rf "$dir"
  done
}

workspace_repo_root="$(resolve_workspace_repo_root)"

case "$target" in
  claude) uninstall_claude_workspace "$workspace_repo_root" ;;
  copilot) uninstall_copilot_workspace "$workspace_repo_root" ;;
  codex) uninstall_codex_workspace "$workspace_repo_root" ;;
  both)
    uninstall_claude_workspace "$workspace_repo_root"
    uninstall_copilot_workspace "$workspace_repo_root"
    ;;
  all)
    uninstall_claude_workspace "$workspace_repo_root"
    uninstall_copilot_workspace "$workspace_repo_root"
    uninstall_codex_workspace "$workspace_repo_root"
    ;;
esac

# Etat local retire en dernier: laisse le temps aux backups d'exister avant.
remove_maxime_local_state "$workspace_repo_root"

if [ "$dry" = 0 ]; then
  if [ "$remove_state" = 1 ]; then
    echo -e "\033[33mEtat local (.wip/, .bkp/) supprime.\033[0m"
  else
    echo -e "\033[36mEtat local (.wip/, .bkp/) conserve. Utilise --remove-state pour le supprimer aussi.\033[0m"
  fi
fi
