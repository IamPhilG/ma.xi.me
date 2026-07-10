---
name: maxime-setup
description: Prepare une structure mA.xI.me dans un repo cible pour Copilot.
agent: maxime
tools: [read_file, file_search, create_file, apply_patch]
---

Objectif:
- Initialiser une base propre et minimale.

Checklist:
1. Verifier presence de .github/.
2. Verifier .github/copilot-instructions.md, .github/agents/ et .github/prompts/.
3. Ajouter la memoire session-handoff.
4. Valider que le repository contient les fichiers de base.

Sortie:
- Resume des actions faites.
- Gaps restants.
