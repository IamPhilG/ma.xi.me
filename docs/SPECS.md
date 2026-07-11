# Spécification fonctionnelle — mA.xI.me phase 1

## Objectif

Fournir une installation manuelle, repo-only et vérifiable de mA.xI.me pour Claude
Code, GitHub Copilot et Codex. Les trois outils reçoivent le même socle de méthode,
les mêmes contrats de workflow et le même état local partagé.

## Hors périmètre

- VSIX et commande VS Code d'installation ;
- contrôle de l'interface d'extensions Claude Code ou Codex ;
- installation globale dans un profil utilisateur ;
- promesse de garde-fou technique identique entre les trois hôtes.

## Exigences fonctionnelles

### EF-01 — Source canonique

Les invariants du socle sont stockés dans `core/socle.md`. Les sept workflows sont
stockés dans `core/workflows/maxime-*.md`. Ces fichiers sont les seules sources à
éditer pour un comportement portable.

### EF-02 — Adaptateurs générés

Les adaptateurs Claude, Copilot et Codex sont générés de façon déterministe depuis
`core/`. Chaque adaptateur peut ajouter sa syntaxe et ses capacités spécifiques, mais
ne peut pas modifier silencieusement le contrat de workflow commun.

### EF-03 — Socle multi-outils

Après une installation `all`, Claude Code, Copilot et Codex disposent chacun :

- de la méthode structurée ;
- des règles de validation, prudence et vérification ;
- des sept workflows `maxime-*` ;
- de la référence à l'état local `.wip/maxime/`.

### EF-04 — Orchestrateur unique

`maxime` est le point d'entrée de travail structuré dans les hôtes qui prennent en
charge un agent personnalisé. Dans Codex, les workflows projetés sont le point
d'entrée équivalent. La documentation ne doit pas prétendre que tous les hôtes
exposent une interface identique.

### EF-05 — État local commun

Les handoffs, décisions, impasses et spécifications sont situés sous `.wip/maxime/`.
Cet état est local au repository et exclu par `Git info/exclude` ; il n'est pas écrit
sous `.claude/`, `.copilot/`, `.codex/` ou un répertoire utilisateur global.

### EF-06 — Installation repo-only

Les installateurs acceptent les cibles `claude`, `copilot`, `codex`, `both` et `all`.
Ils doivent : détecter ou recevoir un repository Git cible, refuser la cible source,
sauvegarder les fichiers remplacés sous `.bkp/`, initialiser l'état local et refuser
les options globales.

### EF-07 — Vérification de cohérence

Un contrôle PowerShell et un contrôle Bash doivent détecter toute projection générée
absente ou différente. Les scripts de génération PowerShell et Bash doivent produire
les mêmes projections pour une même source canonique.

## Critères d'acceptation

| ID | Critère vérifiable |
| --- | --- |
| CA-01 | Modifier un fichier dans `core/`, régénérer, puis exécuter les deux contrôles de synchronisation avec succès. |
| CA-02 | Les adaptateurs générés contiennent le socle et les sept workflows. |
| CA-03 | `-Target all` et `--target all` installent les trois adaptateurs dans un repository Git fixture. |
| CA-04 | L'installation crée `.wip/maxime/memory`, `.wip/maxime/specs` et `.bkp`, puis ajoute `/.wip/` et `/.bkp/` à `info/exclude`. |
| CA-05 | Les options Copilot globales sont refusées et aucune écriture globale n'est observée. |
| CA-06 | `-WhatIf` et `--dry-run` n'écrivent pas dans le repository fixture. |
| CA-07 | Les README et documents d'architecture ne présentent plus `CLAUDE.md` ou un chemin global comme socle universel. |

## Phase 2 — VSIX

Le VSIX sera spécifié seulement après les validations manuelles de phase 1. Il pourra
proposer une commande « Install mA.xI.me in current workspace » et un participant
Copilot, mais restera un déclencheur d'installation repo-only et ne simulera pas le
contrôle des interfaces Claude Code ou Codex.
