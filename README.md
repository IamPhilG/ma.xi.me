# mA.xI.me

> A.I.me · MAX iMe · *Medium AI with eXtreme Intelligence for me*

Agent d'orchestration et de méthode pour Claude Code, GitHub Copilot et Codex.
mA.xI.me uniformise mes repos : même structure, même façon de travailler avec l'IA partout,
selon une boucle **SPEC → PLAN → LIVRABLE → VERIFY → REVIEW → IMPROVE**.

## Contenu
- `CLAUDE.md` — méthode universelle + socle de comportement (toujours actif)
- `AGENTS.md` — instructions repo pour Codex
- `agents/maxime.md` — orchestrateur (activable via `@maxime`)
- `agents/maxime-reviewer.md` — sous-agent d'analyse (read-only via hook de garde-fou) pour les grosses revues
- `skills/maxime-*/` — 7 workflows : start, plan, handoff, setup, retrofit, review, kb
- `.agents/skills/maxime-*/` — skills repo-scoped pour Codex
- `.codex/AGENTS.md` — référence Codex conservée dans le repo
- `docs/` — architecture et spécifications de référence
- `install/install.ps1` & `install/install.sh` — installation repo-only pour Claude, Copilot et Codex

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

Le repo mA.xI.me reste la source des templates. Les projections Copilot viennent de `.copilot/`; les skills Codex viennent de `.agents/skills/`.

Pour vérifier leur synchronisation :

```powershell
powershell -ExecutionPolicy Bypass -File tools\check-codex-skills-sync.ps1
```

```bash
bash tools/check-codex-skills-sync.sh
```

Note modele:
- Les fichiers n'imposent pas un modele unique.
- Recommandation: laisser le modele actif de l'utilisateur, et n'imposer un modele
  que sur un agent/prompt precis si une tache le justifie.

## Principe à deux niveaux
- **Socle** (`CLAUDE.md`) : garde-fous toujours actifs (branches, git prudent,
  vérification, inviolables) — indépendants de mA.xI.me.
- **mA.xI.me** : agent invoqué pour le travail structuré et l'uniformisation.

## Licence
Voir `LICENSE`.
