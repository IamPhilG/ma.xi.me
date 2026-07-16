---
name: maxi-copilot-start
description: mA.xI.me workflow generated from the canonical source.
tools: [read, search, execute]
user-invocable: true
handoffs:
  - label: Retour a maxime
    agent: maxi-copilot
    prompt: Integre ce retour et decide des actions suivantes.
    send: false
---

> Prerequis : verifier que ce repository a deja ete initialise avec mA.xI.me
> (presence de .wip/ et .wip/adr/decisions-log.md). Si absent, s'arreter
> immediatement, l'expliquer, et demander l'autorisation explicite de lancer
> Maxime Init avant de continuer. Ne jamais lancer Maxime Init automatiquement
> sans confirmation.

# mA.xI.me — Démarrage de session

À utiliser lorsqu'une demande devient une tâche de travail ou de modification.

1. Lire le handoff le plus récent dans `.wip/memory/`, s'il existe.
2. Exécuter `git status` et `git log --oneline -10`.
3. Résumer l'état connu en cinq points maximum.
4. Demander si l'objectif est de continuer ou de changer de direction.
5. Formuler cet objectif explicitement dans la sortie de `maxime-start` :
   c'est ce que l'orchestrateur transmet à `maxime-kb` avant de poursuivre
   (voir orchestrateur). `maxime-start` n'a pas d'accès en écriture ni au
   Task/agent tool — il ne déclenche pas `maxime-kb` lui-même, il produit
   l'information dont l'orchestrateur a besoin pour le faire.
6. Produire une évaluation pré-session : état réel, recommandation, risques et taille S/M/L.
7. Pour une tâche précise, passer à `maxime-plan` avant toute écriture.

Ne pas modifier de fichier avant l'approbation explicite de la spécification quand la tâche est significative.
