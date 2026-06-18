---
name: maxime-start
description: Ouvre une session de travail mA.xI.me (contexte, interview, evaluation pre-session).
agent: maxime
tools: [read_file, run_in_terminal]
---

Objectif:
- Charger le contexte recent.
- Clarifier le but de session.
- Evaluer avant de coder.

Etapes:
1. Lire le dernier #file:.copilot/memory/YYYYMMDD.session-handoff.md si present.
2. Executer git status et git log --oneline -10.
3. Resumer l'etat en 5 points max.
4. Poser la question de direction: continuer ou pivoter.
5. Produire une evaluation pre-session: etat, recommandation, risques.

Interdit:
- Ecrire du code avant validation explicite de l'utilisateur.
