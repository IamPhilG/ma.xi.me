# mA.xI.me

> A.I.me · MAX iMe · *Medium AI with eXtreme Intelligence for me*

Un socle de méthode et un orchestrateur unique pour Claude Code, GitHub Copilot et Codex.
mA.xI.me projette les mêmes règles et workflows dans chaque outil, selon la boucle
**SPEC → PLAN → LIVRABLE → VERIFY → REVIEW → IMPROVE**.

## Contenu
- `core/` — source canonique du socle et des 7 workflows
- `CLAUDE.md`, `.copilot/` et `.codex/` — adaptateurs générés pour les trois outils
- `agents/maxime.md` et `.copilot/agents/maxime.agent.md` — orchestrateur mA.xI.me selon les capacités de l'hôte
- `skills/maxime-*/`, `.agents/skills/maxime-*/` et `.copilot/prompts/` — projections générées des workflows
- `.claude/hooks/` — extension de protection propre à Claude Code, non présentée comme une garantie multi-outils
- `docs/` — architecture et spécifications de référence
- `install/` — installation repo-only pour Claude, Copilot et Codex
- `tools/generate-adapters.*` et `tools/check-adapter-sync.*` — génération et contrôle des projections

## Installation

L'installateur déploie mA.xI.me **dans un repo git uniquement**.
Il ne modifie jamais les répertoires globaux de Claude Code, Copilot ou Codex.

### Prérequis

- **Git Bash** et **jq** sont requis pour le hook de garde-fou
  (`.claude/hooks/block-destructive-bash.sh`). Sur Windows, Git Bash est
  fourni avec Git for Windows ; installer `jq` via `winget install jqlang.jq`.
  (macOS : `brew install jq` · Linux : `apt install jq`).

- **Vérifie que `jq` est bien trouvé** après installation :

      jq --version

  Sur Windows, redémarre ton terminal après `winget install` pour que `jq`
  entre dans le PATH.

> ⚠️ **Sans `jq`, le garde-fou n'offre aucune protection.** Le hook le détecte
> et l'affiche (`garde-fou DÉSACTIVÉ`) au lieu d'échouer en silence — mais il
> n'empêchera aucune commande destructrice. Installe `jq` avant de t'y fier.

### Étapes d'installation

1. Clone ce dépôt et place-toi à sa racine.
2. Lance l’installateur depuis le repo cible, ou indique ce repo avec `WorkspaceRoot` / `--workspace-root`.
3. Choisis la cible à installer.

| Cible | Installe dans le repo cible |
| --- | --- |
| `claude` | `CLAUDE.md`, `.claude/settings.json`, hooks, agents et skills mA.xI.me |
| `copilot` | `.github/copilot-instructions.md`, agents et prompts |
| `codex` | `AGENTS.md` et `.agents/skills/maxime*` |
| `both` | Claude Code + Copilot |
| `all` (défaut) | Claude Code + Copilot + Codex |

L'installateur initialise également l'état partagé local `.wip/maxime/` (handoffs,
spécifications et journaux) et ajoute `/.wip/` ainsi que `/.bkp/` au fichier Git
local `info/exclude` du repo cible. Ces données ne sont donc pas synchronisées.

### Windows

Depuis le repo cible :

```powershell
powershell -ExecutionPolicy Bypass -File C:\chemin\vers\ma.xi.me\install\install.ps1
```

Depuis un autre répertoire, avec un repo cible explicite :

```powershell
powershell -ExecutionPolicy Bypass -File C:\chemin\vers\ma.xi.me\install\install.ps1 -Target all -WorkspaceRoot C:\chemin\vers\repo-cible
```

Depuis la racine de mA.xI.me, avec un repo cible explicite :

```powershell
powershell -ExecutionPolicy Bypass -File install\install.ps1 -Target all -WorkspaceRoot C:\chemin\vers\repo-cible
```

Ajoute `-WhatIf` à l’une de ces commandes pour prévisualiser les changements sans écrire.

### macOS / Linux

Depuis le repo cible :

```bash
/chemin/vers/ma.xi.me/install/install.sh
```

Depuis un autre répertoire, avec un repo cible explicite :

```bash
/chemin/vers/ma.xi.me/install/install.sh --target all --workspace-root /chemin/vers/repo-cible
```

Depuis la racine de mA.xI.me, avec un repo cible explicite :

```bash
./install/install.sh --target all --workspace-root /chemin/vers/repo-cible
```

Ajoute `--dry-run` à l’une de ces commandes pour prévisualiser les changements sans écrire.

### Sources et vérification

Le repo mA.xI.me reste la source des templates. Les fichiers sous `core/` sont la
source canonique ; les adaptateurs Claude, Copilot et Codex sont générés et ne doivent
pas être édités directement.

Pour régénérer puis vérifier les projections :

```powershell
powershell -ExecutionPolicy Bypass -File tools\generate-adapters.ps1
powershell -ExecutionPolicy Bypass -File tools\check-adapter-sync.ps1
```

```bash
bash tools/generate-adapters.sh
bash tools/check-adapter-sync.sh
```

Note modele:
- Les fichiers n'imposent pas un modele unique.
- Recommandation: laisser le modele actif de l'utilisateur, et n'imposer un modele
  que sur un agent/prompt precis si une tache le justifie.

## Un socle, un orchestrateur, trois adaptateurs

- **Socle mA.xI.me** : règles et workflows portables issus de `core/`, projetés dans
  `CLAUDE.md` pour Claude Code, `.github/copilot-instructions.md` pour Copilot et
  `AGENTS.md` pour Codex lors de l'installation.
- **Orchestrateur mA.xI.me** : point d'entrée du travail structuré. Claude et Copilot
  disposent d'un agent `maxime` ; Codex utilise les workflows projetés dans
  `.agents/skills/`.
- **Extensions d'hôte** : les hooks Claude ou les sous-agents disponibles dans Copilot
  complètent le socle, sans être faussement présentés comme universels.

Un VSIX est prévu en phase 2 seulement : il automatisera l'installation dans le
workspace et l'expérience Copilot après validation de ce fonctionnement manuel.

## Licence
Voir `LICENSE`.
