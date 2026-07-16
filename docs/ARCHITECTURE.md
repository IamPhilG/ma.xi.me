# Architecture mA.xI.me

## Produit

mA.xI.me est un socle de méthode et un orchestrateur uniques pour Claude Code,
GitHub Copilot et Codex. Il est installé **dans un repository Git cible** : aucune
instruction, mémoire ou skill mA.xI.me n'est écrit dans un répertoire global utilisateur.

Le produit a deux phases :

1. **Phase 1 — manuel** : sources canoniques, adaptateurs de workspace, installateurs
   repo-only et vérifications reproductibles.
2. **Phase 2 — VSIX** : commande VS Code pour automatiser l'installation dans le
   workspace et expérience Copilot dédiée. Cette phase ne commence qu'après validation
   manuelle de la phase 1.

## Modèle à trois couches

```text
core/                         source canonique, éditée directement
  socle.md                    invariants et méthode portables
  workflows/maxime-*.md       contrats des sept workflows
        |
        | generate-adapters.ps1 / generate-adapters.sh
        v
install/Packaged/             projections inspectables, jamais éditées directement
  CLAUDE.md                   Claude Code
  .copilot/                   GitHub Copilot -> .github/ dans le repo cible
  .codex/AGENTS.md            Codex -> AGENTS.md dans le repo cible
  agents/                     un agent dedie par workflow (Claude), + orchestrateur
  .copilot/agents/            idem, cote Copilot
  .agents/skills/             workflows Codex (skills -- pas de notion d'agent cote Codex)
  .claude/                    settings.json + hooks/ (maintenus a la main)
        |
        | install.ps1 / install.sh (ou install/lib/install-<hote>.* seul)
        v
repository Git cible          installation locale et sauvegardée
                               (peut etre le repo source mA.xI.me lui-meme)
```

Les adaptateurs ajoutent seulement le frontmatter, les chemins et les capacités propres
à leur hôte. Les règles communes et les contrats de workflow proviennent de `core/`.

## Socle, orchestrateur et agents de workflow

Le **socle** impose la méthode `SPEC → PLAN → LIVRABLE → VERIFY → REVIEW → IMPROVE`,
les hypothèses explicites, l'approbation avant action non autorisée, la prudence Git et
la vérification avant clôture. Il est projeté dans :

| Hôte | Instructions durables | Workflows | Orchestrateur |
| --- | --- | --- | --- |
| Claude Code | `CLAUDE.md` | `.claude/agents/maxime-*.md` (sous-agents dédiés) | `.claude/agents/maxime.md` (`maxi-claude`) |
| GitHub Copilot | `.github/copilot-instructions.md` | `.github/agents/maxime-*.agent.md` (sous-agents dédiés) | `.github/agents/maxime.agent.md` (`maxi-copilot`) |
| Codex | `AGENTS.md` | `.agents/skills/` | `maxi-codex` (identité logique, sans picker agent) |

Le socle `maxime` est l'unique orchestrateur de travail structuré : lui parler directement
impose toujours la méthode ci-dessus. Chacun des 7 workflows (`start`, `plan`, `handoff`,
`init`, `retrofit`, `review`, `kb`) est généré comme un **agent dédié** côté Claude et
Copilot — pas un skill/prompt — avec le tool-scoping que son propre texte justifie (ex.
`maxime-review` n'a jamais `Write`/`edit`, `maxime-start` non plus). L'orchestrateur délègue
à l'agent correspondant pour chaque phase (Task tool côté Claude, `agents:`/`handoffs:` côté
Copilot) ; chaque agent est aussi individuellement invocable pour un développement/test
indépendant. **Aucun agent de workflow ne travaille si le repository n'a pas encore été
initialisé** (absence de `.wip/adr/decisions-log.md`) : il redirige vers `maxime-init`
("Maxime Init") et demande l'autorisation de le lancer, jamais automatiquement.

Codex n'a aucune notion d'agent (confirmé par recherche, voir la fiche KB citée plus bas) :
ses 7 workflows restent des skills textuels, avec la même garde bootstrap injectée comme
texte plutôt que comme restriction mécanique.

## État local partagé

Tous les outils lisent et écrivent le même état local :

```text
.wip/
  memory/
    YYYYMMDD.session-handoff.md
  specs/
    <fonction-ou-feature>.md
  adr/
    decisions-log.md
  results/
    dead-ends.md
  tools/
    cleanup-wip.ps1
    cleanup-wip.sh
```

L'installateur crée ces dossiers et ajoute `/.wip/` ainsi que `/.bkp/` au fichier
Git local `info/exclude` du repository cible. Les fichiers de remplacement sont
sauvegardés dans `.bkp/<cible>-install/<horodatage>/`.

`.wip/tools/cleanup-wip.ps1` et `.wip/tools/cleanup-wip.sh` sont copiés depuis
`core/tools/` à chaque installation. Ils purgent les artefacts `.wip/` obsolètes
(handoffs anciens, specs/résultats/tests périmés) en mode `dry-run` par défaut ;
la suppression réelle exige `-Apply` / `--apply`. Ils ne touchent jamais rien
hors de `.wip/`.

## Installation

Les installateurs prennent un repo cible implicite (repository du répertoire courant)
ou explicite (`-WorkspaceRoot` / `--workspace-root`). Ils refusent :

- un dossier qui n'est pas un repository Git ;
- le mode Copilot global (`user`) ;
- toute écriture hors du repository cible.

Le repository source mA.xI.me peut désormais être ciblé lui-même (dogfooding) :
`generate-adapters.*` écrit exclusivement sous `install/Packaged/` (source de
l'installation), jamais aux emplacements finaux (`CLAUDE.md`, `.claude/`,
`AGENTS.md`, `.agents/skills/`, `.github/`) — plus de collision possible entre
le matériel de construction et le résultat d'une installation.

Les cibles disponibles sont `claude`, `copilot`, `codex`, `both` et `all`.

Par défaut, les fichiers projetés par cible sont ajoutés à `.git/info/exclude`
du repo cible (motifs précis : `/CLAUDE.md`, `/.claude/agents/maxime*.md`,
`/.claude/skills/maxime-*/`, `/.claude/hooks/block-destructive-bash.sh`,
`/.claude/settings.json`, `/.github/copilot-instructions.md`,
`/.github/agents/maxime*.agent.md`, `/.github/prompts/maxime-*.prompt.md`,
`/AGENTS.md`, `/.agents/skills/maxime-*/`) — jamais de dossier entier comme
`/.github/`, pour ne pas masquer du contenu de l'équipe sans rapport avec
mA.xI.me. Les mêmes motifs, par cible, sont aussi ajoutés (création ou mise à
jour) au `.gitignore` du repo cible, sous un bloc `# mA.xI.me -- <hôte> (outil
installe, pas du code source)` : `.git/info/exclude` protège la machine qui a
lancé l'installateur, `.gitignore` protège tout autre clone/contributeur qui
ne l'a pas lancé — différent de `.wip/`/`.bkp/`, qui restent volontairement
exclusifs à `.git/info/exclude` (état de travail, jamais un `.gitignore`).
`-Shared`/`--shared` desactive les deux ajouts : les fichiers redeviennent
commitables (comportement historique, pensé pour un socle partagé en équipe).

`install/uninstall.ps1` et `.sh` sont le miroir exact de l'installateur par
cible : ils retirent uniquement ce que l'installateur a projeté (jamais un
fichier non reconnu comme provenant de mA.xI.me), sauvegardent avant
suppression dans `.bkp/<cible>-uninstall/<horodatage>/`, et retirent aussi les
entrées `info/exclude` et `.gitignore` correspondantes. `.wip/` et `.bkp/`
sont conservés par défaut (`-RemoveState`/`--remove-state` pour les
supprimer aussi).

`tools/cleanup-global.ps1` et `.sh` détectent (et suppriment avec `--apply`)
les reliquats d'installations globales des toutes premières versions de
mA.xI.me, antérieures au mode repo-only (`~/.claude`, `~/.copilot`,
`~/.codex`, `~/.agents`). Les fichiers partagés ambigus (`CLAUDE.md`,
`AGENTS.md` globaux, qui peuvent être le contenu personnel de l'utilisateur)
ne sont jamais supprimés automatiquement, seulement signalés.

## Contrôles

- `tools/generate-adapters.ps1` et `tools/generate-adapters.sh` régénèrent les projections.
- `tools/check-adapter-sync.ps1` et `tools/check-adapter-sync.sh` régénèrent dans un
  espace temporaire puis comparent les hashes ou le contenu avec les projections versionnées
  (agents Claude/Copilot inclus, un par workflow).
- Les installateurs exécutent ce contrôle avant une projection Codex.
- `tools/check-codex-skills-sync.*` a été retiré (2026-07-14) : sa prémisse (comparer le
  contenu des skills Claude à celui des skills Codex) n'a plus de sens depuis que Claude
  n'a plus de skills pour ces 7 workflows (agents dédiés à la place) ; `check-adapter-sync`
  couvre déjà la validité de chaque projection contre `core/`.
- `tools/check-decisions.ps1` et `tools/check-decisions.sh` exécutent un test par
  décision structurante de `.wip/adr/decisions-log.md` (installation fraîche sur
  fixture temporaire, absence de résidus de nommage legacy, structure `.wip/`,
  synchronisation croisée `check-adapter-sync.ps1`/`.sh`, etc.). Toute nouvelle
  décision référence le test qui la vérifie ; sans test référencé, la décision
  est incomplète (règle du socle). La synchronisation croisée existe
  spécifiquement parce que lancer un seul langage ne suffit pas : il compare le
  générateur de ce langage aux fichiers commités, donc il peut passer même si
  les deux générateurs divergent entre eux (régression réelle du 2026-07-12).

## Limites assumées

- Les instructions sont du contexte, pas un verrou technique universel.
- Le hook Claude n'est pas disponible dans les autres hôtes.
- Un VSIX peut améliorer l'intégration Copilot, mais ne peut pas imposer son interface
  aux extensions Claude Code ou Codex.
- La découverte réelle des adaptateurs reste à valider manuellement dans les versions
  ciblées de Claude Code, VS Code Copilot et Codex.
- La restriction d'outils par workflow (`allowed-tools` côté Claude, `tools:` côté
  Copilot) n'a pas d'équivalent côté Codex, confirmé par la documentation officielle
  ([VS Code Agent Skills](https://code.visualstudio.com/docs/agent-customization/agent-skills),
  [OpenAI Codex skills](https://learn.chatgpt.com/docs/build-skills)) : ni le frontmatter
  `SKILL.md`, ni le fichier optionnel `agents/openai.yaml` (sa section `dependencies.tools`
  déclare des dépendances requises, pas des restrictions) n'offrent ce mécanisme. Pour
  Codex, un workflow lecture seule (ex. `maxime-review`) reste une consigne textuelle, pas
  une garantie technique ; la garantie réelle passe par le sandbox de session
  (`codex exec --sandbox read-only` ou `/permissions`), jamais par le fichier skill.
- **Côté Copilot, le même trou existe, mais la cause et la garantie réelle sont
  différentes** — étude complète dans
  [`.wip/kb/20260713.new.agent-skills-cross-tool-integration.md`](../.wip/kb/20260713.new.agent-skills-cross-tool-integration.md).
  Copilot découvre nativement les `SKILL.md` sous **trois** emplacements
  (`.github/skills/`, `.claude/skills/`, `.agents/skills/` — standard ouvert
  [Agent Skills](https://agentskills.io)), donc peut charger le `SKILL.md`
  Claude ou Codex de `maxime-review` au lieu du prompt Copilot dédié. Confirmé
  par une issue du dépôt VS Code lui-même
  ([microsoft/vscode#293276](https://github.com/microsoft/vscode/issues/293276),
  citant le message du validateur : *"Attribute 'allowed-tools' is not
  supported in skill files"*) : **aucun `SKILL.md`, quel que soit son
  emplacement, ne peut restreindre ou accorder d'outils dans Copilot** — c'est
  du texte injecté dans le contexte de l'agent déjà actif, jamais un mécanisme
  d'octroi. La seule restriction réelle vient de l'agent Copilot **actif**
  (`tools:` d'un `.agent.md`, ex. `maxi-copilot-reviewer`) : si cet agent est
  bien actif au moment de l'invocation, `edit`/`execute` restent indisponibles
  quel que soit le skill chargé. Le risque n'existe que si le workflow est
  invoqué depuis un contexte non restreint (chat par défaut, ou `maxi-copilot`
  lui-même). Une issue distincte
  ([microsoft/vscode#307630](https://github.com/microsoft/vscode/issues/307630))
  confirme qu'aucun mécanisme ne permet aujourd'hui de restreindre quels
  skills un agent peut charger — c'est un manque connu et non résolu de
  l'écosystème, pas une lacune spécifique à mA.xI.me.
