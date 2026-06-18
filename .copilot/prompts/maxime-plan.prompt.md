---
name: maxime-plan
description: Redige une spec ecrite et demande approbation avant implementation.
agent: maxime
tools: [read_file, grep_search, file_search, create_file]
---

Objectif:
- Produire une spec claire, testable, et approuvable.

Format obligatoire:
## Spec: [titre court]
- Quoi
- Pourquoi
- Fichiers touches
- Approche (etapes numerotees)
- Risques / alternatives ecartees
- Taille: S / M / L

Regles:
- Pas de code avant approbation explicite.
- Hypotheses visibles.
- Pas de sur-ingenierie.
