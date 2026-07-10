---
name: maxime-review
description: Délègue une analyse read-only (gros fichier, diff, audit) à un sous-agent isolé, puis vérifie par les tests avant d'agir.
allowed-tools: Read, Glob, Grep, Bash
---
# mA.xI.me — Review déléguée

## Quand
Analyse lourde ou isolée qu'on veut sortir du contexte principal : gros diff,
audit d'un module, revue de conformité, lecture de nombreux fichiers.

## Comment
1. Invoquer le sous-agent `maxime-reviewer` (défini dans `.claude/agents/` du repo courant),
   read-only, avec la cible précise (fichiers, diff, périmètre).
2. Le sous-agent retourne : résumé / risques / fichiers concernés / recommandation.
   Il ne modifie RIEN.
3. mA.xI.me lit le retour. AVANT toute action qui en découle :
   exécuter la commande de test/lint du repo. Ne jamais agir sur la seule
   "sanité" perçue du résultat.

## Chaînage (plusieurs reviews)
Si une 2e review dépend de la 1re, injecter explicitement le résultat de la
1re dans le brief de la 2e. Ne pas laisser deux agents écraser le même output.
