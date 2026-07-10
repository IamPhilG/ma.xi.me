---
name: maxime-setup
description: Initialise la structure mA.xI.me d'un repo VIERGE (memory, specs, skills, agents) après validation explicite. Commande à effet de bord.
disable-model-invocation: true
allowed-tools: Read, Glob, Grep, Bash, Write, Edit
---
# mA.xI.me — Setup d'un repo (mode plan d'abord)

NE RIEN CRÉER avant accord.
NE RIEN CRÉER sans avoir complété l'interview et rédigé la spec.

## Garde-fou .gitignore (tout repo)
Lors de l'init, créer ou compléter le `.gitignore` du repo avec au minimum :
  .claude/memory/
  .claude/backups/
  .claude/settings.local.json
  .env.*
  *.pem  *.key  *.pfx
Vérifier qu'aucun de ces chemins n'est déjà tracké (git rm --cached si besoin).
Raison : les handoffs et secrets ne doivent JAMAIS être versionnés, dans aucun repo.

## 0. Prérequis (AVANT TOUT)
- Lancer `maxime-start` si la session n'est pas déjà ouverte.
- Interviewer l'utilisateur — questions obligatoires, toutes posées avant d'analyser :
  1. Quel est le but et le rôle de ce repo ? (qu'est-ce qu'il contient, à quoi sert-il ?)
  2. Qui va l'utiliser ? (toi seul, équipe, agents IA, combinaison ?)
  3. Quel type de contenu est attendu ? (décisions, runbooks, ADRs, référentiels, autre ?)
  4. Stratégie git : branches, conventions de commit, protection de main, PR ou push direct ?
  5. Liens avec d'autres repos / projets ?
- **NE PAS inventer le thème depuis les fichiers alentour.** Toujours demander.
- Attendre les réponses avant de passer à l'étape 1.

## 1. Analyser
- Vérifier si git est initialisé (`git rev-parse --is-inside-work-tree 2>$null`).
  - **Si NON** → STOP. Demander à l'utilisateur :
    1. Faut-il faire `git init` maintenant ?
    2. Si oui : quelle branche principale ? (`main` recommandé)
    3. Y a-t-il un remote à configurer (GitHub, Azure DevOps, autre) ?
    - Ne jamais faire `git init` sans accord explicite.
  - **Si OUI** → `git status`, branche courante, `git log --oneline -5`.
    - Si branche = `main` ou `master` → STOP, demander sur quelle branche travailler.
- Lister la structure existante.
- Si des fichiers existent déjà → les LISTER, ne rien écraser.
Thème du repo, branche courante, structure existante. Lister tout `.claude/`

## 2. Spec au format maxime-plan (OBLIGATOIRE)
Invoquer `maxime-plan` pour produire la spec structurée :
```
## Spec : Setup .claude/ — [nom du repo]
**Quoi** : ...
**Pourquoi** : ...
**Fichiers touchés** : liste exhaustive
**Approche** : étapes ordonnées
**Risques / alternatives écartées** : ...
**Taille** : S / M / L
```
Écrire la spec complète (Quoi/Pourquoi/Fichiers/Approche/Risques/Taille)
dans .claude/specs/YYYYMMDD-titre.md AVANT toute création — en créant le dossier specs/ s'il n'existe pas.
N'ajouter qu'une ligne de résumé (décision + rationale) dans .claude/memory/decisions-log.md.
Attendre l'approbation explicite de l'utilisateur ("ok", "go", "approuvé").

Proposer la structure (plan)
Si le repo a besoin de la knowledge-base : proposer aussi de l'ajouter en
submodule à `knowledge-base/` (`git submodule add` — action significative, donc validation explicite).
La structure cible ci-dessous est un **modèle de référence**, pas un plan approuvé :
```
.claude/
├── CLAUDE.md          (contexte repo : but réel, terminologie, contraintes, stratégie git)
├── memory/  (YYYYMMDD.session-handoff.md, decisions-log.md, dead-ends.md)
├── specs/
├── skills/
└── agents/            (sous-agents read-only spécifiques au repo)
```

## 3. Après accord seulement
Créer les dossiers et, ou, fichiers manquants. Backup horodaté de tout fichier existant avant modification . 
Générer le CLAUDE.md repo à partir des réponses
de l'interview (jamais depuis des suppositions)  (court : contexte, terminologie, commande de
validation/test, et `@knowledge-base/index.md` si la KB est montée).


## 4. Confirmer ce qui a été créé vs préservé (rapport de fin)
Lister explicitement, en deux colonnes :
- **Créé** : chaque dossier/fichier nouvellement créé, avec son chemin.
- **Préservé** : chaque fichier existant laissé intact (et son backup s'il y en a un).
Terminer par les éventuelles actions restantes pour l'utilisateur (ex : init submodule,
première spec à rédiger via `maxime-plan`).