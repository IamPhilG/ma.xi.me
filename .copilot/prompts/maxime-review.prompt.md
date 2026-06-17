---
name: maxime-review
description: Lance une revue ciblee avec le sous-agent maxime-reviewer.
agent: maxime
tools: [read_file, grep_search, file_search]
---

Objectif:
- Deleguer une revue lourde en lecture seule.

Instruction:
- Confier la cible a maxime-reviewer.
- Exiger la sortie dans l'ordre: resume, risques, fichiers, recommandation.
- Revenir a maxime pour arbitrage et execution.
