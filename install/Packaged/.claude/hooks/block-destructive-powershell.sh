#!/usr/bin/env bash
# PreToolUse hook (matcher: PowerShell). Meme protocole et memes limites que
# block-destructive-bash.sh (voir son en-tete) -- verifie empiriquement le
# 2026-07-16 : l'outil PowerShell recoit bien un hook distinct (payload
# tool_name="PowerShell", meme forme tool_input.command/cwd que Bash), donc
# les commandes PowerShell ne contournent plus le garde-fou comme avant
# (issue #34). Ce hook tourne lui-meme via bash (jq requis), il ne fait
# qu'analyser la chaine de commande PowerShell recue, pas l'executer.
if ! command -v jq >/dev/null 2>&1; then
  echo "[mA.xI.me] jq introuvable — garde-fou PowerShell DÉSACTIVÉ." >&2
  exit 0
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib-path-guard.sh
. "$script_dir/lib-path-guard.sh"

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty' 2>&1)"
jq_exit=$?
if [ $jq_exit -ne 0 ]; then
  echo "[mA.xI.me] jq a échoué (exit $jq_exit) — garde-fou PowerShell DÉSACTIVÉ pour cette commande. Détail: $cmd" >&2
  exit 0
fi
[ -z "$cmd" ] && exit 0

cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)"
[ -n "$cwd" ] || cwd="$PWD"
repo_root="$(resolve_repo_root "$cwd")"

hard_deny='Remove-Item\b[^|;`]*-Recurse\b[^|;`]*-Force\b'
hard_deny+='|Remove-Item\b[^|;`]*-Force\b[^|;`]*-Recurse\b'
hard_deny+='|git[[:space:]]+reset[[:space:]]+--hard'
hard_deny+='|git[[:space:]]+clean[[:space:]]+[^|;`]*-[A-Za-z]*f'
hard_deny+='|git[[:space:]]+checkout[[:space:]]+--([[:space:]]|$)'
hard_deny+='|git[[:space:]]+checkout[[:space:]]+\.([[:space:]]|$)'
hard_deny+='|git[[:space:]]+branch[[:space:]]+(-D|--delete[[:space:]]+--force)'
hard_deny+='|git[[:space:]]+add[[:space:]]+(-A|--all)([[:space:]]|$)'
# mA.xI.me n'a jamais de dossier knowledge-base/ local (decision 2026-07-17) :
# meme raisonnement que block-destructive-bash.sh -- voir son en-tete.
hard_deny+='|git[[:space:]]+submodule[[:space:]]+(add|update)[^|;`]*knowledge-base'

soft_ask='git[[:space:]]+push[[:space:]]+[^|;`]*(--force\b|-f\b|--force-with-lease)'
soft_ask+='|git[[:space:]]+push[[:space:]]+[^|;`]*--delete'

# Bascule vers une branche protegee : voir block-destructive-bash.sh (meme
# raisonnement, assoupli le 2026-07-17) -- ASK, pas DENY.
soft_ask_branch='git[[:space:]]+(checkout|switch)[[:space:]]+(main|master)([[:space:]]|$)'

if echo "$cmd" | grep -qE "$hard_deny"; then
  jq -n --arg reason "Commande destructrice/irreversible bloquee par garde-fou repo (PowerShell): $cmd" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$reason}}'
  exit 0
fi

if echo "$cmd" | grep -qE "$soft_ask"; then
  jq -n --arg reason "Commande a risque (push force/delete) -- confirmation requise: $cmd" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
  exit 0
fi

if echo "$cmd" | grep -qE "$soft_ask_branch"; then
  jq -n --arg reason "Bascule vers une branche protegee (main/master) -- est-ce bien toi qui acceptes ce checkout ? $cmd" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:$reason}}'
  exit 0
fi

# Garde-fou hors-repo (2026-07-16, issue #34) : meme logique que le hook
# Bash, adaptee aux cmdlets d'ecriture PowerShell.
write_verb='(Set-Content|Add-Content|Out-File|New-Item|Copy-Item|Move-Item)\b'

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
