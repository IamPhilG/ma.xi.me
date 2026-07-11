# mA.xI.me — Handoff

À utiliser à la fin d'un bloc de travail, sur une décision structurante ou avant l'arrêt d'une session.

1. Exécuter `git status` ; ne jamais lancer de staging global automatique.
2. Créer, sans écraser, `.wip/memory/YYYYMMDD.session-handoff.md`.
3. Y noter : terminé, en cours, blocages, décisions, fichiers modifiés, contexte critique et prochaine action précise.
4. Ajouter les décisions et impasses utiles à `.wip/adr/decisions-log.md` et `.wip/results/dead-ends.md`.
5. Indiquer l'objectif atteint, partiel ou non et la meilleure reprise.

Le handoff est concis, factuel et actionnable. Il ne doit pas être mis à jour après chaque micro-tâche.
