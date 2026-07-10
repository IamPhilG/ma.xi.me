---
name: maxime-handoff
description: Clôture une session mA.xI.me. À utiliser sur "on arrête", "wrap up", "fais le handoff", "on finit là", ou fin de bloc de travail.
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
---
# mA.xI.me — Clôture de session

Rappel: Ce skill applique la boucle globale CLAUDE.md à la clôture et au transfert de contexte.

## 1. Git (prudent)
`git status` d'abord. JAMAIS `git add -A`. Montrer les fichiers, vérifier
l'absence de secrets, proposer un `git add` ciblé. L'utilisateur décide.

## 2. Écrire le handoff
Créer (jamais écraser) `.claude/memory/YYYYMMDD.session-handoff.md` du jour :
```markdown
# Session Handoff — {DATE}
## Completed today
## In progress (interrupted) — état exact (fichier/ligne/étape)
## Blocked — [problème] → [pourquoi] → [prochaine tentative]
## Suspended / Archived — travaux volontairement mis de côté (branche, raison)
## Decisions made today
## Critical context (ne pas perdre)
## Files modified — `path` — pourquoi
## Recommended start for next session — une action précise
## Alternatives — Option A (S/M/L, risque) / Option B
```
NB : la section "Suspended / Archived" purge le contexte actif des features
abandonnées pour éviter que le handoff gonfle indéfiniment.

## 3. Logs (append)
- `.claude/memory/decisions-log.md` ← décisions du jour (si pas déjà persistées).
- `.claude/memory/dead-ends.md` ← ce qui a été essayé et a échoué.

## 4. Auto-optimisation (proposition uniquement)
Proposer d'alléger le CLAUDE.md SEULEMENT si une règle remplit les 3 critères
(native confirmée + inutile/contredite ≥3 sessions + accord). Jamais les inviolables.
Si proposition acceptée : diff → backup ~/.claude/backups/ → confirmation → écriture.

## 5. Confirmer
> "✅ Handoff {DATE}. Objectif : atteint/partiel/non. Retravaux : N.
> CLAUDE.md : inchangé / [changements]. Prochaine session : [1 phrase]."

## Note fréquence (anti-bureaucratie)
Le handoff vivant se met à jour à la FIN d'un bloc de travail (≈20-30 min),
sur décision structurante, fichier important modifié, ou blocage.
PAS après chaque micro-tâche.
