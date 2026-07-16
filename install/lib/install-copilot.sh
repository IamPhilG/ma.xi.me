#!/usr/bin/env bash
# Installe mA.xI.me pour GitHub Copilot dans un repository Git cible.
# Script specialise, callable seul ou depuis install.sh.
# Usage: install-copilot.sh [--dry-run] [--shared] --repo-root <path>
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

install_copilot_workspace() {
  local copilot_src="$src_repo_root/install/Packaged/.copilot"
  if [ ! -d "$copilot_src" ]; then
    echo "Missing source directory: $copilot_src" >&2
    exit 1
  fi

  local agents_target prompts_target instructions_target backup_dir
  agents_target="$repo_root/.github/agents"
  prompts_target="$repo_root/.github/prompts"
  instructions_target="$repo_root/.github/copilot-instructions.md"
  backup_dir="$repo_root/.bkp/copilot-install/$stamp"

  run mkdir -p "$agents_target"

  # Preserve pre-existing project-specific copilot-instructions.md content
  # instead of silently overwriting it (issue #27): move it once into
  # .github/instructions/, which Copilot merges automatically into context
  # alongside copilot-instructions.md -- no import syntax needed.
  local project_conventions_target="$repo_root/.github/instructions/project-conventions.instructions.md"
  local instructions_header
  instructions_header="$(printf -- '---\napplyTo: "**"\n---\n\n')"
  if [ "$dry" = 0 ] && save_pre_existing_project_content "$instructions_target" "$project_conventions_target" "$instructions_header"; then
    echo "Contenu copilot-instructions.md pre-existant preserve dans $project_conventions_target (fusionne automatiquement par Copilot, jamais touche par mA.xI.me a l'avenir)."
  fi

  backup_if_exists "$instructions_target" "$backup_dir"

  for f in "$copilot_src"/agents/*.agent.md; do
    [ -e "$f" ] || continue
    dest="$agents_target/$(basename "$f")"
    backup_if_exists "$dest" "$backup_dir"
    run cp -f "$f" "$dest"
  done

  if [ -d "$copilot_src/prompts" ]; then
    for f in "$copilot_src"/prompts/*.prompt.md; do
      [ -e "$f" ] || continue
      run mkdir -p "$prompts_target"
      dest="$prompts_target/$(basename "$f")"
      backup_if_exists "$dest" "$backup_dir"
      run cp -f "$f" "$dest"
    done
  fi

  run cp -f "$copilot_src/copilot-instructions.md" "$instructions_target"

  write_maxime_version_marker "$src_repo_root" "$repo_root/.github/MAXIME_VERSION" "$backup_dir"

  if [ "$dry" = 0 ]; then
    echo -e "\033[32mmA.xI.me installe pour Copilot (workspace).\033[0m"
    echo "Repo cible: $repo_root"
    echo "Instructions: $instructions_target"
    echo "Agents: $agents_target"
    echo "Backups locaux: $backup_dir"
  fi
}

install_copilot_workspace

if [ "$shared" != 1 ]; then
  add_git_exclude_entries "$repo_root" \
    '/.github/copilot-instructions.md' \
    '/.github/agents/maxime*.agent.md' \
    '/.github/MAXIME_VERSION'
  add_gitignore_entries "$repo_root" '# mA.xI.me -- GitHub Copilot (outil installe, pas du code source)' \
    '/.github/copilot-instructions.md' \
    '/.github/agents/maxime*.agent.md' \
    '/.github/MAXIME_VERSION'
fi
