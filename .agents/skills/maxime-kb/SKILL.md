---
name: maxime-kb
description: Charge la knowledge-base (savoir générique réutilisable) pour un thème donné, sans tout charger. Lit l'index puis seulement les fiches actives pertinentes.
allowed-tools: Read, Glob, Grep
---
# mA.xI.me — Knowledge base (chargement ciblé)

## Emplacement
La KB est un **submodule Git** monté à `knowledge-base/` à la racine du repo
(même convention que les repos consommateurs). Source : OurITRes/knowledge-base.
Si `knowledge-base/` est absent ou vide → le submodule n'est pas initialisé :
le signaler (`git submodule update --init knowledge-base`), ne pas inventer de contenu.

## Méthode
1. Lire `knowledge-base/index.md` (léger).
2. Identifier le thème de la session.
3. Charger UNIQUEMENT les fiches de `knowledge-base/active/` pertinentes au thème.
   Les fiches de `knowledge-base/archived/` ne sont pas chargées sauf demande explicite.

## Fraîcheur (par fiche)
Chaque fiche porte : Dernière validation · Source · Statut
(active/suspecte/obsolète/archivée) · Portée.

## RÈGLE DE SÉPARATION (inviolable pour la KB)
La KB ne contient QUE du savoir générique et réutilisable.
JAMAIS de contenu lié au travail, à l'employeur, aux clients, aux projets
internes ou à des données confidentielles. Le repo KB étant public, tout
enrichissement doit respecter cette séparation. En cas de doute → ne pas écrire
dans la KB, demander à l'utilisateur.

## Enrichissement
En fin de session, proposer d'ajouter/maj une fiche SEULEMENT si le savoir est
durable, transversal ET générique (cf. règle de séparation). Statut + date obligatoires.
