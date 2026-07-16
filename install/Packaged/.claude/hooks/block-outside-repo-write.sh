#!/usr/bin/env bash
# PreToolUse hook (matcher: Write|Edit|NotebookEdit). Refuse toute ecriture
# dont le chemin cible resout hors du repository courant. Verification
# fiable : le chemin exact vient de tool_input.file_path, pas d'un texte de
# commande a deviner (contrairement a block-destructive-bash.sh/-powershell.sh,
# qui font du best-effort sur une chaine de commande).
#
# Fail-open SIGNALE : si jq est absent ou si le parsing echoue, le hook
# n'offre AUCUNE PROTECTION et l'autorise (exit 0), avec avertissement sur
# stderr. Meme discipline que block-destructive-bash.sh.
if ! command -v jq >/dev/null 2>&1; then
  echo "[mA.xI.me] jq introuvable — garde-fou hors-repo (Write/Edit) DÉSACTIVÉ." >&2
  exit 0
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib-path-guard.sh
. "$script_dir/lib-path-guard.sh"

input="$(cat)"
file_path="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>&1)"
jq_exit=$?
if [ $jq_exit -ne 0 ]; then
  echo "[mA.xI.me] jq a échoué (exit $jq_exit) — garde-fou hors-repo (Write/Edit) DÉSACTIVÉ pour cet appel. Détail: $file_path" >&2
  exit 0
fi
[ -z "$file_path" ] && exit 0

cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[ -n "$cwd" ] || cwd="$PWD"
repo_root="$(resolve_repo_root "$cwd")"

if path_outside_repo "$file_path" "$cwd" "$repo_root"; then
  jq -n --arg reason "Ecriture hors du repo cible bloquee par garde-fou mA.xI.me: $file_path (repo: $repo_root). Utilise .wip/tmp/ pour les fichiers temporaires." \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
fi

exit 0
