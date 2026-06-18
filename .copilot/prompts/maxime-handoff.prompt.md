---
name: maxime-handoff
description: Cloture un bloc de travail et met a jour le handoff de session.
agent: maxime
tools: [read_file, create_file, apply_patch]
---

Objectif:
- Ecrire un handoff concis, utile, actionnable.

Mise a jour cible:
- #file:.copilot/memory/YYYYMMDD.session-handoff.md (fichier du jour)

Si le fichier n'existe pas:
- Le creer (YYYYMMDD.session-handoff.md) puis ecrire le handoff.

Contenu attendu:
- Ce qui est fait
- Ce qui reste
- Risques / blocages
- Prochaine action recommandee

Regles:
- Factuel, court, sans duplication inutile.
