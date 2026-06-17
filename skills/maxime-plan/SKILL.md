---
name: maxime-plan
description: Rédige et fait approuver une spec écrite avant toute implémentation. À invoquer dès qu'une tâche précise est identifiée, avant d'écrire le moindre code.
allowed-tools: Read, Glob, Grep, Bash, Write
---
# mA.xI.me — Plan (spec avant implémentation)

## Quand
Dès qu'une tâche concrète est identifiée (feature, fix, refacto, migration).
JAMAIS de code avant que la spec soit écrite et approuvée explicitement.

## 1. Analyser la cible
- Lire les fichiers concernés (contexte minimal suffisant, pas tout le repo).
- Identifier : quoi changer / pourquoi / quels fichiers touchés / contraintes.

## 2. Rédiger la spec
Format obligatoire :
```
## Spec : [titre court]
**Quoi** : description précise du changement
**Pourquoi** : motivation (bug, feature, dette, conformité)
**Fichiers touchés** : liste exhaustive
**Approche** : étapes ordonnées, numérotées
**Risques / alternatives écartées** : ce qu'on ne fait PAS et pourquoi
**Taille** : S / M / L
```

## 3. Persister immédiatement
Écrire la spec complète (Quoi/Pourquoi/Fichiers/Approche/Risques/Taille) 
dans .claude/specs/YYYYMMDD-titre.md — en créant le dossier specs/ s'il n'existe pas.
N'ajouter qu'une ligne de résumé (décision + rationale) dans .claude/memory/decisions-log.md.
Ne pas attendre la fin de session — anti-crash.

## 4. Attendre l'approbation explicite
Aucune ligne de code avant "ok", "go", "approuvé" ou équivalent de l'utilisateur.
Si l'utilisateur modifie la spec → mettre à jour decisions-log.md avant de commencer.
