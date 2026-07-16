# mA.xI.me

> A.I.me · MAX iMe · *Medium AI with eXtreme Intelligence for me*

Un socle de méthode et un orchestrateur unique pour Claude Code, GitHub Copilot et Codex.
mA.xI.me projette les mêmes règles et workflows dans chaque outil, selon la boucle
**SPEC → PLAN → LIVRABLE → VERIFY → REVIEW → IMPROVE**.

## Contenu

- `core/` — source canonique du socle et des 7 workflows
- `install/Packaged/` — tout ce que l'installateur projette dans un repo cible :
  `CLAUDE.md`, `.copilot/` et `.codex/` (adaptateurs générés pour les trois outils),
  `agents/maxime.md` et `.copilot/agents/maxime.agent.md` (orchestrateur), plus un
  agent dédié par workflow (`agents/maxime-*.md` côté Claude,
  `.copilot/agents/maxime-*.agent.md` côté Copilot, `.agents/skills/maxime-*/`
  côté Codex qui n'a pas de notion d'agent), `.claude/settings.json` et
  `.claude/hooks/` (extension de protection propre à Claude Code, non présentée
  comme une garantie multi-outils)
- `docs/` — architecture et spécifications de référence
- `install/` — installateur/désinstallateur repo-only pour Claude, Copilot et Codex,
  décomposé en petits scripts spécialisés sous `install/lib/` (un par hôte, plus
  l'initialisation de l'état local), chacun callable seul
- `tools/generate-adapters.*` et `tools/check-adapter-sync.*` — génération et contrôle des projections sous `install/Packaged/`

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
| `claude` | `CLAUDE.md`, `.claude/settings.json`, hooks, orchestrateur et un agent dédié par workflow |
| `copilot` | `.github/copilot-instructions.md`, orchestrateur et un agent dédié par workflow |
| `codex` | `AGENTS.md` et `.agents/skills/maxime*` |
| `both` | Claude Code + Copilot |
| `all` (défaut) | Claude Code + Copilot + Codex |

L'installateur initialise également l'état partagé local `.wip/` :

- `.wip/memory/` (handoffs)
- `.wip/specs/` (spécifications)
- `.wip/adr/` (décisions)
- `.wip/results/` (impasses et résultats)
- `.wip/tools/` (sorties d'outils, plus `cleanup-wip.ps1`/`.sh` — routine de nettoyage
  de `.wip/`, `dry-run` par défaut)

Il ajoute aussi `/.wip/` et `/.bkp/` au fichier Git local `info/exclude` du repo
cible. Ces données ne sont donc pas synchronisées.

### Local par défaut, partagé sur demande

**Par défaut, l'installation entière reste locale à ta machine.** Les fichiers
projetés (`CLAUDE.md`, `.claude/`, `.github/copilot-instructions.md`,
`.github/agents/maxime*`, `AGENTS.md`,
`.agents/skills/maxime-*`) sont ajoutés à `.git/info/exclude` (local, jamais
commité), exactement comme `.wip/`/`.bkp/`. Ils sont aussi ajoutés (création ou
mise à jour) au `.gitignore` du repo cible : contrairement à `.wip/`/`.bkp/`
(exclusion strictement locale, jamais de `.gitignore`), mA.xI.me est un outil —
la même protection doit tenir même depuis un autre clone ou pour un autre
contributeur qui n'a pas lancé l'installateur lui-même. Rien n'est commitable
par erreur, même avec `git add -A`.

Utilise `-Shared` (PowerShell) / `--shared` (Bash) pour revenir au
comportement partagé : les fichiers deviennent commitables, pensés pour être
partagés avec toute l'équipe via le repository.

```powershell
powershell -ExecutionPolicy Bypass -File install\install.ps1 -Target all -Shared
```

```bash
./install/install.sh --target all --shared
```

`install/uninstall.ps1` et `.sh` retirent aussi ces entrées de
`info/exclude` en même temps que les fichiers (voir plus bas).

### Windows

Depuis le repo cible :

```powershell
powershell -ExecutionPolicy Bypass -File "C:\chemin\vers\ma.xi.me\install\install.ps1"
```

Depuis un autre répertoire, avec un repo cible explicite :

```powershell
powershell -ExecutionPolicy Bypass -File "C:\chemin\vers\ma.xi.me\install\install.ps1" -Target all -WorkspaceRoot "C:\chemin\vers\repo-cible"
```

Depuis la racine de mA.xI.me, avec un repo cible explicite :

```powershell
powershell -ExecutionPolicy Bypass -File install\install.ps1 -Target all -WorkspaceRoot "C:\chemin\vers\repo-cible"
```

Ajoute `-WhatIf` à l’une de ces commandes pour prévisualiser les changements sans écrire.

**Mets systématiquement les chemins entre guillemets** (`"..."`) : un chemin
avec un espace (profil Windows `Prénom Nom`, dossier OneDrive, etc.) sans
guillemets fait échouer l'installation — PowerShell coupe l'argument au
premier espace.

### macOS / Linux

Depuis le repo cible :

```bash
/chemin/vers/ma.xi.me/install/install.sh
```

Depuis un autre répertoire, avec un repo cible explicite :

```bash
/chemin/vers/ma.xi.me/install/install.sh --target all --workspace-root "/chemin/vers/repo cible"
```

Depuis la racine de mA.xI.me, avec un repo cible explicite :

```bash
./install/install.sh --target all --workspace-root "/chemin/vers/repo cible"
```

Là aussi, mets les chemins entre guillemets s'ils contiennent un espace.

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

Pour vérifier que les décisions de `.wip/adr/decisions-log.md` sont toujours
respectées :

```powershell
powershell -ExecutionPolicy Bypass -File tools\check-decisions.ps1
```

```bash
bash tools/check-decisions.sh
```

Note modele:

- Les fichiers n'imposent pas un modele unique.
- Recommandation: laisser le modele actif de l'utilisateur, et n'imposer un modele
  que sur un agent/prompt precis si une tache le justifie.

## Un socle, un orchestrateur, trois adaptateurs

- **Socle mA.xI.me** : règles et workflows portables issus de `core/`, projetés dans
  `CLAUDE.md` pour Claude Code, `.github/copilot-instructions.md` pour Copilot et
  `AGENTS.md` pour Codex lors de l'installation.
- **Orchestrateur mA.xI.me** : point d'entrée du travail structuré, toujours actif
  quand on lui parle directement. Les identités techniques sont `maxi-claude`
  (Claude), `maxi-copilot` (Copilot) et `maxi-codex` (Codex, logique workflow
  sans picker d'agent).
- **Agents de workflow** : côté Claude et Copilot, chacun des 7 workflows est un
  agent dédié (pas un skill/prompt) avec le tool-scoping que son propre texte
  justifie ; l'orchestrateur y délègue pour chaque phase. Côté Codex, sans
  notion d'agent, les workflows restent projetés dans `.agents/skills/`.
- **Extensions d'hôte** : les hooks Claude complètent le socle, sans être
  faussement présentés comme universels.

Un VSIX est prévu en phase 2 seulement : il automatisera l'installation dans le
workspace et l'expérience Copilot après validation de ce fonctionnement manuel.

## Licence

Voir `LICENSE`.
