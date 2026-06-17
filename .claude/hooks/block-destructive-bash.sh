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
# Fail-open assumé : si jq est absent ou échoue, $cmd est vide → exit 0 (tout autoriser).
# Conséquence : sans jq installé, CE HOOK N'OFFRE AUCUNE PROTECTION.
# Prérequis : winget install jqlang.jq (Windows) ou brew install jq / apt install jq.
input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)"
[ -z "$cmd" ] && exit 0

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
hard_deny+='|(^|[;&|])[[:space:]]*(echo|printf|cat)[^;&|]*(>|>>)'
hard_deny+='|(^|[;&|])[[:space:]]*(Set-Content|Out-File|New-Item|Remove-Item|Move-Item|Copy-Item)\b'

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

exit 0