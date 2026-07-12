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
adaptateurs versionnés        projections inspectables, jamais éditées directement
  CLAUDE.md                   Claude Code
  .copilot/                   GitHub Copilot -> .github/ dans le repo cible
  .codex/AGENTS.md            Codex -> AGENTS.md dans le repo cible
  skills/ et .agents/skills/  workflows Claude et Codex
        |
        | install.ps1 / install.sh
        v
repository Git cible          installation locale et sauvegardée
```

Les adaptateurs ajoutent seulement le frontmatter, les chemins et les capacités propres
à leur hôte. Les règles communes et les contrats de workflow proviennent de `core/`.

## Socle et orchestrateur

Le **socle** impose la méthode `SPEC → PLAN → LIVRABLE → VERIFY → REVIEW → IMPROVE`,
les hypothèses explicites, l'approbation avant action non autorisée, la prudence Git et
la vérification avant clôture. Il est projeté dans :

| Hôte | Instructions durables | Workflows | Orchestrateur |
| --- | --- | --- | --- |
| Claude Code | `CLAUDE.md` | `.claude/skills/` | `.claude/agents/maxime.md` (`maxi-claude`) |
| GitHub Copilot | `.github/copilot-instructions.md` | `.github/prompts/` | `.github/agents/maxime.agent.md` (`maxi-copilot`) |
| Codex | `AGENTS.md` | `.agents/skills/` | `maxi-codex` (identité logique, sans picker agent) |

Le socle `maxime` est l'unique orchestrateur de travail structuré. Les agents de revue et le
hook Claude sont des extensions facultatives d'hôte : ils ne sont pas une promesse de
protection équivalente dans Copilot ou Codex.

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
- le repository source mA.xI.me comme cible ;
- le mode Copilot global (`user`) ;
- toute écriture hors du repository cible.

Les cibles disponibles sont `claude`, `copilot`, `codex`, `both` et `all`.

Par défaut, les fichiers projetés par cible sont ajoutés à `.git/info/exclude`
du repo cible (motifs précis : `/CLAUDE.md`, `/.claude/agents/maxime*.md`,
`/.claude/skills/maxime-*/`, `/.claude/hooks/block-destructive-bash.sh`,
`/.claude/settings.json`, `/.github/copilot-instructions.md`,
`/.github/agents/maxime*.agent.md`, `/.github/prompts/maxime-*.prompt.md`,
`/AGENTS.md`, `/.agents/skills/maxime-*/`) — jamais de dossier entier comme
`/.github/`, pour ne pas masquer du contenu de l'équipe sans rapport avec
mA.xI.me. `-Shared`/`--shared` desactive cet ajout : les fichiers redeviennent
commitables (comportement historique, pensé pour un socle partagé en équipe).

`install/uninstall.ps1` et `.sh` sont le miroir exact de l'installateur par
cible : ils retirent uniquement ce que l'installateur a projeté (jamais un
fichier non reconnu comme provenant de mA.xI.me), sauvegardent avant
suppression dans `.bkp/<cible>-uninstall/<horodatage>/`, et retirent aussi les
entrées `info/exclude` correspondantes. `.wip/` et `.bkp/` sont conservés par
défaut (`-RemoveState`/`--remove-state` pour les supprimer aussi).

`tools/cleanup-global.ps1` et `.sh` détectent (et suppriment avec `--apply`)
les reliquats d'installations globales des toutes premières versions de
mA.xI.me, antérieures au mode repo-only (`~/.claude`, `~/.copilot`,
`~/.codex`, `~/.agents`). Les fichiers partagés ambigus (`CLAUDE.md`,
`AGENTS.md` globaux, qui peuvent être le contenu personnel de l'utilisateur)
ne sont jamais supprimés automatiquement, seulement signalés.

## Contrôles

- `tools/generate-adapters.ps1` et `tools/generate-adapters.sh` régénèrent les projections.
- `tools/check-adapter-sync.ps1` et `tools/check-adapter-sync.sh` régénèrent dans un
  espace temporaire puis comparent les hashes ou le contenu avec les projections versionnées.
- `tools/check-codex-skills-sync.*` reste un contrôle de compatibilité ciblé pour les
  skills Codex.
- Les installateurs exécutent le contrôle global avant une projection Codex.
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
