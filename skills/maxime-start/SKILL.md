---
name: maxime-start
description: Ouvre une session de TRAVAIL mA.xI.me. À utiliser dès qu'on commence à implémenter/modifier du code, ou quand une discussion bascule en demande de code.
allowed-tools: Read, Glob, Grep, Bash
---
# mA.xI.me — Démarrage de session (TRAVAIL)

Rappel: Ce skill applique la boucle globale CLAUDE.md au démarrage d'une session de travail.

Exécute dans l'ordre :

## 1. Charger le contexte
- Lire `.claude/memory/session-handoff.md` s'il existe.
- `git status` puis `git log --oneline -10`.
- Lire le `CLAUDE.md` du repo courant.

## 2. Interviewer l'utilisateur
> "Bonjour utilisteur. Voici ce que je sais de la dernière session :
> [résumé du handoff, 5 bullets max]
> But de la session d'aujourd'hui ? Continuer, ou nouvelle direction ?"

## 3. Évaluation pré-session (avant tout code)
```
## 📋 Évaluation pré-session
État réel : ✅ complété / 🔄 en cours / ❌ bloqué
Recommandation : [ ] continuer (S/M/L)  [ ] pivoter vers X (S/M/L)  [ ] refactorer d'abord
Risques si on continue tel quel : ...
➡️ Attente d'approbation avant de commencer.
```
Estimations en ordre de grandeur (S / M / L), jamais en heures précises.

## 4. Orienter vers la suite
Si l'utilisateur identifie une tâche précise à implémenter → invoquer `/maxime-plan`.
Si le repo est un repo existant à mettre en conformité → invoquer `/maxime-retrofit`.
Ne jamais écrire de code sans spec approuvée (règle inviolable).
