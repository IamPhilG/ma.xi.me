---
name: maxime-plan
description: mA.xI.me workflow generated from the canonical source.
---

> Prerequis : verifier que ce repository a deja ete initialise avec mA.xI.me
> (presence de .wip/ et .wip/adr/decisions-log.md). Si absent, s'arreter
> immediatement, l'expliquer, et demander l'autorisation explicite de lancer
> Maxime Init avant de continuer. Ne jamais lancer Maxime Init automatiquement
> sans confirmation.

# mA.xI.me — Spécification et plan

À utiliser dès qu'une tâche concrète de modification, fonctionnalité, correction ou migration est identifiée.

1. Lire le contexte minimal des fichiers concernés.
2. Rédiger une spécification : quoi, pourquoi, fichiers touchés, approche ordonnée, risques ou alternatives écartées et taille S/M/L/XL.
3. Une fois la taille connue, consulter le catalogue KB (thème `engine-catalog`,
   une fiche par hôte) pour le moteur/effort recommandé. Comportement par
   hôte, jamais une règle unique : Claude Code peut choisir lui-même le
   moteur d'un sous-agent délégué (capacité technique réelle — informer sans
   bloquer, sauf écart net avec le défaut attendu pour la taille, auquel cas
   confirmer explicitement avant de continuer) ; Copilot et Codex ne peuvent
   que recommander et demander à l'utilisateur de sélectionner le moteur
   (contrainte de plateforme, aucune auto-configuration confirmée à ce jour
   sur aucune des deux surfaces). Aucune exécution n'est bloquée si le
   catalogue est absent ou périmé : signaler, proposer un défaut
   raisonnable, continuer.
4. Définir des critères d'acceptation testables.
5. Enregistrer la spécification dans `.wip/specs/<fonction-ou-feature>.md`.
6. Ajouter une ligne de décision dans `.wip/adr/decisions-log.md`, avec le test exécutable qui la vérifie (chemin ou commande). Une décision sans test référencé est incomplète.
7. Attendre une approbation explicite avant toute écriture de produit.

Ne jamais confondre une hypothèse avec un fait ni produire un plan décoratif.
