#!/usr/bin/env bash
# Installe mA.xI.me dans ~/.claude (CLAUDE.md + agents/skills maxime*).
# Ne touche pas aux dossiers locaux (sessions, cache, credentials).
# Usage : ./install.sh [--dry-run]
set -euo pipefail

dry=0
[ "${1:-}" = "--dry-run" ] && dry=1
run() { if [ "$dry" = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }

target="$HOME/.claude"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$(dirname "$script_dir")"
stamp="$(date +%Y%m%d-%H%M%S)"

if [ ! -d "$target" ]; then
  run mkdir -p "$target"
else
  # Backup horodaté AVANT toute écriture. Pas de "|| true" :
  # si le backup échoue, set -e arrête tout, on n'écrase rien.
  run mkdir -p "$target/backups"
  for d in agents skills; do
    if [ -d "$target/$d" ]; then
      bk="$target/backups/${d}-pre-maxime-$stamp"
      run mkdir -p "$bk"
      run cp -R "$target/$d/." "$bk/"
    fi
  done
  if [ -f "$target/CLAUDE.md" ]; then
    run cp -f "$target/CLAUDE.md" "$target/backups/CLAUDE-pre-maxime-$stamp.md"
  fi
fi

# Installation : seulement les fichiers maxime*.
run cp -f "$src/CLAUDE.md" "$target/CLAUDE.md"
run mkdir -p "$target/agents" "$target/skills"
run cp -R "$src"/agents/maxime* "$target/agents/"
run cp -R "$src"/skills/maxime* "$target/skills/"

if [ "$dry" = 0 ]; then
  echo -e "\033[32mmA.xI.me installé dans $target. Vérifie avec /memory, /agents dans Claude Code.\033[0m"
fi