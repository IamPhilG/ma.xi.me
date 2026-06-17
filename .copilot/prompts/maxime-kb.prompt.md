---
name: maxime-kb
description: Charge la knowledge-base de maniere ciblee pour eviter le bruit.
agent: maxime
tools: [read_file, file_search, grep_search]
---

Objectif:
- Charger uniquement les fiches actives pertinentes au theme demande.

Etapes:
1. Lire l'index de la KB.
2. Identifier les fiches actives pertinentes.
3. Resumer ce qui est utile a la tache en cours.
4. Signaler les zones d'incertitude.
