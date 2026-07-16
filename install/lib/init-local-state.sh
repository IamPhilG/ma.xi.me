#!/usr/bin/env bash
# Initialise l'etat local mA.xI.me (.wip/, .bkp/) dans un repository Git cible.
# Script specialise, callable seul ou depuis install.sh.
# Usage: init-local-state.sh [--dry-run] --repo-root <path>
set -euo pipefail

dry=0
repo_root=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry=1 ;;
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
day_stamp="$(date +%Y%m%d)"

initialize_maxime_local_state() {
  local state_root="$repo_root/.wip"
  local handoff_path="$state_root/memory/$day_stamp.session-handoff.md"
  local decisions_path="$state_root/adr/decisions-log.md"
  local dead_ends_path="$state_root/results/dead-ends.md"
  local kb_index_path="$state_root/kb/index.json"

  if [ "$dry" = 1 ]; then
    echo "[dry-run] mkdir -p $state_root/{memory,specs,adr,results,kb,kb/active,kb/archived,tools} $repo_root/.bkp"
    echo "[dry-run] copy cleanup-wip.ps1 and cleanup-wip.sh into $state_root/tools"
    echo "[dry-run] add /.wip/ and /.bkp/ to the target repo's Git local exclude file"
    return
  fi

  mkdir -p "$state_root/memory" "$state_root/specs" "$state_root/adr" "$state_root/results" "$state_root/kb" "$state_root/kb/active" "$state_root/kb/archived" "$state_root/tools" "$repo_root/.bkp"

  if [ ! -f "$handoff_path" ]; then
    cat > "$handoff_path" <<EOF
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

  [ -f "$decisions_path" ] || printf '# Decisions Log\n' > "$decisions_path"
  [ -f "$dead_ends_path" ] || printf '# Dead Ends\n' > "$dead_ends_path"
  [ -f "$kb_index_path" ] || printf '[]' > "$kb_index_path"

  local network_policy_path="$state_root/tools/kb-network-policy.json"
  if [ ! -f "$network_policy_path" ]; then
    # Fail-safe default: never assume network write access. Read defaults to
    # true (most environments have outbound read access; air-gapped is the
    # exception, not the norm) -- maxime-init overwrites both once the
    # question is actually asked. See decisions-log 2026-07-16.
    printf '{"network_read": true, "network_write": false}' > "$network_policy_path"
  fi

  local tools_source="$src_repo_root/core/tools"
  local tools_backup_dir="$repo_root/.bkp/maxime-tools/$stamp"
  for tool_name in cleanup-wip.ps1 cleanup-wip.sh; do
    if [ -f "$tools_source/$tool_name" ]; then
      backup_if_exists "$state_root/tools/$tool_name" "$tools_backup_dir"
      cp -f "$tools_source/$tool_name" "$state_root/tools/$tool_name"
      chmod +x "$state_root/tools/$tool_name" 2>/dev/null || true
    fi
  done

  add_git_exclude_entries "$repo_root" '/.wip/' '/.bkp/'
}

initialize_maxime_local_state
