#!/usr/bin/env bash
# Detecte et retire les artefacts globaux (hors repo) laisses par d'anciennes
# versions de mA.xI.me qui installaient globalement, avant le mode repo-only.
#
# Emplacements historiques scannes : ~/.claude, ~/.copilot, ~/.codex, ~/.agents.
# Les fichiers/dossiers identifiables sans ambiguite (motif maxime*/maxi-*)
# peuvent etre retires avec --apply. Les fichiers partages ambigus
# (~/.claude/CLAUDE.md, ~/.codex/AGENTS.md) ne sont jamais supprimes
# automatiquement : signales seulement, decision manuelle requise.
#
# Mode dry-run par defaut (aucune suppression). --apply supprime reellement
# les elements non ambigus.
# Usage : ./cleanup-global.sh [--apply] [--home path]
# --home est reserve aux tests (tools/check-decisions.sh) : simule un autre
# repertoire home sans toucher au vrai profil utilisateur.
set -uo pipefail

apply=0
home_dir="$HOME"
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) apply=1 ;;
    --home)
      shift
      home_dir="${1:-}"
      ;;
  esac
  shift
done
unambiguous=()
ambiguous=()
informational=()

add_unambiguous_glob() {
  local dir="$1" pattern="$2"
  [ -d "$dir" ] || return 0
  for item in "$dir"/$pattern; do
    [ -e "$item" ] && unambiguous+=("$item")
  done
}

add_unambiguous_target() {
  [ -e "$1" ] && unambiguous+=("$1")
}

add_ambiguous_if_exists() {
  [ -e "$1" ] && ambiguous+=("$1 -- $2")
}

add_informational_if_exists() {
  [ -e "$1" ] && informational+=("$1 -- $2")
}

# --- ~/.claude (generation 1 : install global historique) ---
add_unambiguous_glob "$home_dir/.claude/agents" 'maxime*.md'
add_unambiguous_glob "$home_dir/.claude/skills" 'maxime-*'
add_ambiguous_if_exists "$home_dir/.claude/CLAUDE.md" \
  "peut etre ton CLAUDE.md personnel ou un reliquat mA.xI.me -- verifie le contenu avant toute action"
add_informational_if_exists "$home_dir/.claude/backups" \
  "backups locaux Claude Code (peuvent contenir ton contenu pre-mA.xI.me original si un install global a deja ecrase quelque chose)"

# --- ~/.copilot (generation 2 : install global Copilot) ---
add_unambiguous_glob "$home_dir/.copilot/agents" 'maxime*.agent.md'
add_unambiguous_target "$home_dir/.copilot/instructions/maxime-global.instructions.md"
add_informational_if_exists "$home_dir/.copilot/backups" "backups locaux Copilot"

# --- ~/.codex + ~/.agents (generation 3 : install global Codex) ---
add_ambiguous_if_exists "$home_dir/.codex/AGENTS.md" \
  "peut etre ta config Codex globale personnelle ou un reliquat mA.xI.me -- verifie le contenu avant toute action"
add_informational_if_exists "$home_dir/.codex/backups" "backups locaux Codex"
add_unambiguous_glob "$home_dir/.agents/skills" 'maxime-*'

echo "mA.xI.me est repo-only depuis la refonte de phase 1 -- ce script cherche des reliquats de versions plus anciennes."
echo

if [ "${#unambiguous[@]}" -eq 0 ]; then
  echo "Aucun artefact global non ambigu trouve."
else
  echo "Artefacts mA.xI.me non ambigus trouves (${#unambiguous[@]}) :"
  for item in "${unambiguous[@]}"; do echo "  - $item"; done
fi

if [ "${#ambiguous[@]}" -gt 0 ]; then
  echo
  echo "Fichiers ambigus (jamais supprimes automatiquement, decision manuelle requise) :"
  for item in "${ambiguous[@]}"; do echo "  - $item"; done
fi

if [ "${#informational[@]}" -gt 0 ]; then
  echo
  echo "Informatif (non supprime, juste signale) :"
  for item in "${informational[@]}"; do echo "  - $item"; done
fi

if [ "$apply" = 1 ] && [ "${#unambiguous[@]}" -gt 0 ]; then
  echo
  echo "Suppression des artefacts non ambigus..."
  for item in "${unambiguous[@]}"; do
    rm -rf "$item"
    echo "  supprime: $item"
  done
  echo "Termine."
elif [ "${#unambiguous[@]}" -gt 0 ]; then
  echo
  echo "Mode lecture seule (dry-run). Relance avec --apply pour supprimer les ${#unambiguous[@]} element(s) non ambigu(s) ci-dessus."
fi
