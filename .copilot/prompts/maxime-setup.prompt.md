---
name: maxime-setup
description: mA.xI.me workflow generated from the canonical source.
agent: maxi-copilot
tools: [read, grep, search, execute, edit]
---

# mA.xI.me — Initialisation d'un repository

À utiliser pour préparer un nouveau repository à recevoir mA.xI.me.

1. Vérifier que le dossier cible est un repository Git.
2. Inspecter le contexte et les conventions existantes sans les écraser.
3. Proposer les adaptateurs à installer : Claude, Copilot, Codex ou tous.
4. Présenter les fichiers à créer ou remplacer et les sauvegardes prévues.
5. Attendre la validation avant l'installation.
6. Vérifier les fichiers projetés et l'exclusion Git de `.wip/` et `.bkp/`.

L'installation est toujours locale au repository cible ; aucun répertoire global utilisateur n'est utilisé.
