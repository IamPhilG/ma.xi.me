#!/usr/bin/env bash
# Protocole JSON structuré (hookSpecificOutput.permissionDecision) : le champ JSON
# détermine le blocage, indépendamment du code de sortie (exit 0 partout ci-dessous,
# y compris sur deny). Ce n'est PAS le protocole legacy basé sur exit 2 — ne pas "corriger".
#
# Limite acceptée (vérifiée par exécution) : regex sur la chaîne brute, pas sémantique.
# Faux positifs possibles si le texte destructeur apparaît dans une chaîne (ex: message de
# commit citant "git reset --hard", echo décrivant "rm -rf"). Contournable via encodage/alias.
# Compromis assumé : simplicité > exhaustivité, coût du faux positif = reformuler la commande.
#
# Fail-open SIGNALÉ : si jq est absent ou si le parsing échoue (JSON inattendu,
# code de sortie non-zéro, champ manquant), le hook ne peut pas parser la commande
# et n'offre AUCUNE PROTECTION. Dans les deux cas, un avertissement est émis sur
# stderr (garde-fou DÉSACTIVÉ) puis le hook autorise (exit 0). Avertissement
# runtime best-effort — le filet fiable reste de vérifier jq à l'installation.
# Prérequis : winget install jqlang.jq (Windows) ou brew install jq / apt install jq.
if ! command -v jq >/dev/null 2>&1; then
  echo "[mA.xI.me] jq introuvable — garde-fou anti-commandes-destructrices DÉSACTIVÉ." >&2
  exit 0
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib-path-guard.sh
. "$script_dir/lib-path-guard.sh"

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>&1)"
jq_exit=$?
if [ $jq_exit -ne 0 ]; then
  echo "[mA.xI.me] jq a échoué (exit $jq_exit) — garde-fou DÉSACTIVÉ pour cette commande. Détail: $cmd" >&2
  exit 0
fi
[ -z "$cmd" ] && exit 0

cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[ -n "$cwd" ] || cwd="$PWD"
repo_root="$(resolve_repo_root "$cwd")"

# Irréversible, aucun usage légitime automatisé dans ce repo → DENY dur
hard_deny='rm[[:space:]]+(-[A-Za-z]+[[:space:]]+)*-[A-Za-z]*(rf|fr)[A-Za-z]*\b'
hard_deny+='|rm([[:space:]].*)?[[:space:]]-r\b.*[[:space:]]-f\b'
hard_deny+='|rm([[:space:]].*)?[[:space:]]-f\b.*[[:space:]]-r\b'
hard_deny+='|git[[:space:]]+reset[[:space:]]+--hard'
hard_deny+='|git[[:space:]]+clean[[:space:]]+[^|;&]*-[A-Za-z]*f'
hard_deny+='|git[[:space:]]+checkout[[:space:]]+--([[:space:]]|$)'
hard_deny+='|git[[:space:]]+checkout[[:space:]]+\.([[:space:]]|$)'
hard_deny+='|git[[:space:]]+branch[[:space:]]+(-D|--delete[[:space:]]+--force)'
hard_deny+='|git[[:space:]]+add[[:space:]]+(-A|--all)([[:space:]]|$)'
hard_deny+='|git[[:space:]]+(checkout|switch)[[:space:]]+(main|master)([[:space:]]|$)'

# Risqué mais parfois légitime en interactif → ASK (force un prompt humain)
soft_ask='git[[:space:]]+push[[:space:]]+[^|;&]*(--force\b|-f\b|--force-with-lease)'
soft_ask+='|git[[:space:]]+push[[:space:]]+[^|;&]*--delete'

if echo "$cmd" | grep -qE "$hard_deny"; then
  jq -n --arg reason "Commande destructrice/irréversible bloquée par garde-fou repo: $cmd" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
fi

if echo "$cmd" | grep -qE "$soft_ask"; then
  jq -n --arg reason "Commande à risque (push force/delete) — confirmation requise: $cmd" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
  exit 0
fi

# Garde-fou hors-repo (2026-07-16, issue #34) : ne bloque QUE si la commande
# ressemble a une ecriture ET reference un chemin absolu hors du repo cible.
# Remplace l'ancien blocage inconditionnel de toute redirection/mention de
# cmdlet PowerShell (trop de faux positifs sur des ecritures legitimes DANS
# le repo -- cf. issue #27 note annexe). Les chemins relatifs ne sont jamais
# des candidats : ils restent par construction dans le repo tant que cwd y
# est.
write_verb='[[:space:]](>>?)([[:space:]]|$)|\|[[:space:]]*tee\b|(^|[;&|])[[:space:]]*(cp|mv|install|tee)[[:space:]]'

if echo "$cmd" | grep -qE "$write_verb"; then
  outside=""
  while IFS= read -r candidate; do
    [ -n "$candidate" ] || continue
    if path_outside_repo "$candidate" "$cwd" "$repo_root"; then
      outside="$outside $candidate"
    fi
  done < <(extract_path_candidates "$cmd")
  if [ -n "$outside" ]; then
    jq -n --arg reason "Ecriture hors du repo cible bloquee par garde-fou mA.xI.me:$outside (repo: $repo_root). Utilise .wip/tmp/ pour les fichiers temporaires." \
      '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
    exit 0
  fi
fi

exit 0
