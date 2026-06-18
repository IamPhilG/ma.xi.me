---
name: maxime-retrofit
description: Audite un repo existant et propose un plan de convergence vers mA.xI.me Copilot.
agent: maxime
tools: [read_file, grep_search, file_search, run_in_terminal]
---

Objectif:
- Evaluer l'existant sans casser le flux actuel.

Sortie obligatoire:
1. Etat actuel
2. Ecarts par rapport a mA.xI.me Copilot
3. Plan de migration par etapes (S/M/L)
4. Risques et ordre de priorite

Regles:
- Ne pas modifier sans validation explicite.
- Favoriser des changements incrementaux.
