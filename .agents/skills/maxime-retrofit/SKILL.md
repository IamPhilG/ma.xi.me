---
name: maxime-retrofit
description: Audite un repo existant et produit un plan de mise en conformité mA.xI.me. Lecture seule, rapport d'écarts, plan validé avant toute modification.
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash
---

> Sécurité : Bash est présent pour l'audit en lecture (git status, git log...).
> Un hook PreToolUse anti-mutation doit être actif pour garantir le "lecture seule".

# mA.xI.me — Retrofit (mise en conformité repo existant)

## Quand
Repo existant sans structure mA.xI.me, ou partiellement conforme.
Distinct de `maxime-setup` (initialise un repo vierge/nouveau).

## 1. Reverse-engineer le repo
- Structure : fichiers à la racine + `src/`, `app/`, `lib/` (depth 3 max, hors node_modules/.git).
- Stack technique : lire README, package.json / pyproject.toml / go.mod / pom.xml… (ce qui existe).
- Conventions détectées : nommage, organisation des tests, commandes build/lint/test.
- `git status` + `git log --oneline -10` + branche courante.
- `.claude/` existant ? Lister son contenu sans rien écraser.

## 2. Auditer les écarts vs standards mA.xI.me
Checklist complète :
- [ ] `.claude/CLAUDE.md` présent et adapté au repo (contexte, stack, commandes)
- [ ] `.claude/memory/session-handoff.md` (persistance inter-sessions)
- [ ] `.claude/memory/decisions-log.md` (traçabilité des décisions)
- [ ] `.claude/memory/dead-ends.md` (mémoire des impasses)
- [ ] Commandes test / lint / build documentées dans CLAUDE.md
- [ ] Branche de travail ≠ main/master (convention feature/ fix/ chore/ docs/)
- [ ] Agent global `~/.claude/agents/maxime-reviewer.md` accessible
- [ ] Skills globaux mA.xI.me accessibles (`~/.claude/skills/maxime-*/`)

## 3. Rapport d'audit
```
## Audit mA.xI.me — [nom du repo]
### Conforme ✅
- …
### Écarts ❌
- [élément manquant ou incorrect] → [action recommandée]
### Stack détectée
- Langage / framework : …
- Test : [commande]  Lint : [commande]  Build : [commande]
### Plan de mise en conformité
Ordre suggéré (taille estimée par étape) :
1. [action] — S/M/L
2. …
```

## 4. Attendre validation
Ne rien créer ni modifier. L'utilisateur valide le plan, puis applique via `/maxime-setup`
ou manuellement selon les écarts identifiés.
