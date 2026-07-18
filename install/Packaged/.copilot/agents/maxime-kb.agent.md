---
name: maxi-copilot-kb
description: mA.xI.me workflow generated from the canonical source.
tools: [read, search, execute, edit]
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

# mA.xI.me — Knowledge base (Maxime KB)

À utiliser lorsqu'une question documentaire se pose, pour tout autre agent
mA.xI.me, ou lorsqu'une knowledge base versionnée est disponible pour un thème
pertinent.

Les fiches sont des objets JSON, pas du Markdown : chaque fiche a un nom court
(`id`), des attributs courts/contrôlés (`type`, `theme`, `tags`, `scope`,
`status`, `confidence`, `audience`) et un champ `content` en texte libre pour
le corps. Les seuls champs exemptés de concision sont ceux qui ne peuvent pas
se réduire à quelques mots (`title`, `source`, `content`). Schéma complet :
`.wip/specs/kb-json-schema.md`.

> **Contrainte absolue, sans exception : `OurITRes/knowledge-base` n'est
> jamais présent comme dossier sur le disque du repository cible.** Pas de
> clone, pas de checkout, pas de mécanisme Git qui matérialise ce dépôt sur
> le système de fichiers — ni maintenant, ni "pour plus tard", ni comme
> option secondaire même présentée comme un progrès ("accès plus
> systématique", "plus simple à l'usage"). Le seul canal, en lecture comme en
> écriture, est l'API HTTPS de GitHub (`gh api`). `.wip/kb/` est le seul
> répertoire de connaissance qui existe jamais sur disque.

1. Vérifier que `.wip/kb/` (fiches locales) est disponible ; sinon le
   signaler sans inventer son contenu. `.wip/kb/` est toujours local et
   n'est jamais concerné par la politique réseau ci-dessous.
2. **Dépôt partagé par défaut, interrogé à chaque première invocation de
   session** : `OurITRes/knowledge-base` — URL connue et fixée dans ce
   contrat, jamais à deviner ni à demander à l'utilisateur, accédé selon la
   contrainte ci-dessus (`gh api` uniquement) : lire
   `repos/OurITRes/knowledge-base/contents/index.json` (et les fiches
   `active/<theme>/<id>.json` pertinentes à la demande) avant toute action
   réseau, vérifier `.wip/tools/kb-network-policy.json` (`network_read`) ;
   s'il n'existe pas encore, le créer avec les valeurs fail-safe
   (`network_read: true`, `network_write: false`) et le signaler une fois.
   Cette interrogation a lieu systématiquement dès qu'un objectif de session
   est connu, jamais seulement sur demande explicite — c'est cet objectif,
   formulé par `maxime-start`, qui oriente la recherche (thème, techno,
   contexte), pas une condition que l'agent devrait deviner par lui-même.
   Les deux sources partagent le même schéma JSON (`index.json` +
   `active/<theme>/<id>.json` + `archived/`) — confirmé pour
   `OurITRes/knowledge-base` par lecture directe de son `KB-CONVENTIONS.md`
   le 2026-07-17.
3. Lire l'index (`.wip/kb/index.json` en local, `index.json` de
   `knowledge-base` via l'API), puis sélectionner par attribut (`theme`,
   `tags`, `type`, `scope`) les fiches pertinentes pour la tâche en cours —
   ne jamais tout charger. Le `content` de chaque fiche n'est ouvert qu'après
   cette sélection.
4. Une fois les résultats de cette première recherche présentés (y compris
   s'ils sont vides), demander explicitement si une **knowledge base JSON
   supplémentaire** — spécifique à ce projet, ce client ou cet employeur,
   distincte du dépôt par défaut — doit aussi être interrogée. Contrairement
   au dépôt par défaut, cette KB additionnelle n'a pas d'URL connue à
   l'avance : ne jamais la proposer sans que Philippe fournisse l'URL, et ne
   jamais insister s'il décline. Même règle d'accès : API uniquement, jamais
   de clone.
5. Ne pas charger `archived/` sans demande explicite.
6. Séparer strictement le savoir générique réutilisable (`audience: generic`)
   des données de projet, client, employeur ou secrets (`audience: project`
   ou `secret`).
7. Quand une fiche pertinente vit dans `knowledge-base` (référence externe,
   lue via l'API) mais n'est pas encore reprise localement, le signaler et
   proposer explicitement de l'intégrer dans `.wip/kb/` — jamais
   automatique, et jamais dans un autre dossier que `.wip/kb/`.

   Avant toute écriture réseau vers `knowledge-base` (nouvelle fiche, mise à
   jour), lire `.wip/tools/kb-network-policy.json` : ne jamais proposer
   d'écriture réseau si `network_write` est `false` ou absent — dans ce cas,
   demander explicitement si l'environnement autorise l'écriture réseau
   (push) et consigner la réponse dans ce même fichier.

   Une fois l'écriture approuvée (`network_write: true` et validation
   explicite de l'utilisateur), publier **uniquement via l'API GitHub**
   (`gh api` — Git Data API pour créer blob(s)/arbre/commit/branche, ou
   Contents API pour un commit par fichier sur une branche existante), sans
   jamais cloner `knowledge-base` localement, même dans `.wip/tmp/` :
   1. Créer une branche depuis `main` (jamais commiter directement sur
      `main` d'un repo partagé en équipe).
   2. Committer la ou les fiches sur cette branche via l'API.
   3. Ouvrir une pull request (`gh pr create`) — jamais la fusionner
      automatiquement, la revue reste humaine.
   Comme il n'existe aucun dossier `knowledge-base/` local, il n'y a plus de
   pointeur de submodule à synchroniser dans le repository consommateur —
   la pull request sur `knowledge-base` est la seule trace de la
   publication, plus simple que l'ancienne mécanique en deux commits/deux
   repos (retirée le 2026-07-17, elle supposait un submodule qui n'existe
   plus dans ce contrat).
8. Proposer la création d'une nouvelle fiche seulement si le savoir rencontré
   est durable, transversal et publiable, absent des fiches existantes.
   Toute nouvelle fiche respecte le schéma JSON (`id`, `type`, `title`,
   `theme`, `tags`, `scope`, `status`, `confidence`, `audience`, `source`,
   `validated`, `created`, `ttl_days`, `links`, `content`) — jamais une note
   libre hors schéma.
9. Tenir `.wip/kb/index.json` à jour (une entrée par fiche, sans `content`) à
   chaque création ou changement d'attribut.
10. Faire passer une fiche de `status: draft` (capture brute) à `status:
    active` une fois son contenu relu et validé.
11. Comparer `validated` à `ttl_days` pour chaque fiche consultée ; si l'écart
    dépasse `ttl_days`, proposer explicitement trois options plutôt que
    choisir seul : **revalider maintenant** (re-vérifier la source, mettre à
    jour `validated`), **marquer suspecte** (`status: suspect`, sans retoucher
    le contenu), ou **ignorer pour cette session** (aucun changement, la
    fiche sera resignalée à la prochaine consultation). `ttl_days` suit la
    nature du sujet, pas une valeur unique : court (60-90 jours) pour les
    plateformes qui évoluent vite (VS Code, Copilot, Codex, catalogues de
    modèles), long (270-365 jours) pour l'infrastructure ou les protocoles
    documentés et stables. Détail : `.wip/specs/kb-ttl-differentiation.md`.

Les autres agents mA.xI.me (`start`, `plan`, `handoff`, `retrofit`, `review`)
peuvent s'appuyer sur Maxime KB pour toute question documentaire, en
complément — jamais en remplacement — des documents fournis directement par
l'utilisateur du repository cible.

L'orchestrateur délègue systématiquement à Maxime KB en tout début de
session, avec l'objectif énoncé par `maxime-start` pour la session en
cours, pour vérifier que la connaissance pertinente est disponible et à
jour avant de démarrer le travail.
