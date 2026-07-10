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
- `install/install.ps1` & `install/install.sh` — projection Copilot repo-scoped uniquement (`.github`)

## Installation

### Windows

```powershell
git clone https://github.com/IamPhilG/ma.xi.me
cd ma.xi.me

# La policy d'exécution PowerShell par défaut bloque les scripts.
# Pour en savoir plus sur les policy PowerShell :
#  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.6)
# Enlever le '#' ci-dessous pour choisir:

# Choix 1:
# Lance l'installeur sans modifier la policy de ta machine :
#  powershell -ExecutionPolicy Bypass -File install\install.ps1 -Target copilot -CopilotScope workspace

# Installer Copilot (scope workspace .github):
#  powershell -ExecutionPolicy Bypass -File install\install.ps1 -Target copilot -CopilotScope workspace -WorkspaceRoot C:\chemin\vers\repo-cible

# Ou choix 2:
# Pour pré-visualiser ce qui sera fait, sans rien modifier :
#  powershell -ExecutionPolicy Bypass -File install\install.ps1 -WhatIf -Target copilot -CopilotScope workspace
```

Les anciennes options globales (`-Target claude|codex|both|all` et `-CopilotScope user`) sont refusées explicitement.

Backups de projection Copilot : `./.bkp/copilot-install/<timestamp>/` dans le repo cible.

### macOS / Linux

    chmod +x install/install.sh
    ./install/install.sh --target copilot --copilot-scope workspace

Pour installer Copilot dans le repo (.github) :

  ./install/install.sh --target copilot --copilot-scope workspace --workspace-root /chemin/vers/repo-cible

Pour pré-visualiser sans rien modifier :

  ./install/install.sh --dry-run --target copilot --copilot-scope workspace

Les anciennes options globales (`--target claude|codex|both|all` et `--copilot-scope user`) sont refusées explicitement.

## Codex (repo)

Compatibilité repo conservée :
- `AGENTS.md` est lu par Codex à la racine du repo.
- `.agents/skills/maxime-*/SKILL.md` expose les workflows mA.xI.me comme skills repo-scoped.
- `skills/maxime-*` reste la source de vérité; `.agents/skills/maxime-*` doit rester synchronisé.

Vérifier la synchronisation des skills Codex :

```powershell
powershell -ExecutionPolicy Bypass -File tools\check-codex-skills-sync.ps1
```

```bash
bash tools/check-codex-skills-sync.sh
```

## Installation GitHub Copilot (adaptation .copilot)

Le dossier source de verite est `./.copilot/`.

Contenu principal :
- `./.copilot/copilot-instructions.md`
- `./.copilot/agents/*.agent.md`
- `./.copilot/agents/maxime-reviewer.agent.md` (read-only, n'execute pas le terminal et redirige)
- `./.copilot/agents/maxime-reviewer-shell.agent.md` (audit avance avec terminal, risque assume)
- `./.copilot/prompts/*.prompt.md`
- `./.copilot/memory/YYYYMMDD.session-handoff.md` (local, non versionne)

### Deploiement via scripts

Mode unique supporté : portée repo/workspace.

Les scripts copient les fichiers vers :
  - `./.github/copilot-instructions.md`
  - `./.github/agents/`
  - `./.github/prompts/`

Important : la cible est le repo courant s'il est git, sinon fournir `-WorkspaceRoot` / `--workspace-root`.
Le repo ma.xi.me reste la source des fichiers `.copilot`.

Backups Copilot (locaux, non sync GitHub) :
- `./.bkp/copilot-install/<timestamp>/`

Memoire de session (sans partage Claude Code) :
- `#file:.copilot/memory/YYYYMMDD.session-handoff.md`
- Fichier local uniquement (ignore par git). En scope workspace, l'installeur cree/utilise le fichier du jour (format `YYYYMMDD.session-handoff.md`).

Note modele:
- Les fichiers n'imposent pas un modele unique.
- Recommandation: laisser le modele actif de l'utilisateur, et n'imposer un modele
  que sur un agent/prompt precis si une tache le justifie.

## Prérequis
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

## Principe à deux niveaux
- **Socle** (`CLAUDE.md`) : garde-fous toujours actifs (branches, git prudent,
  vérification, inviolables) — indépendants de mA.xI.me.
- **mA.xI.me** : agent invoqué pour le travail structuré et l'uniformisation.

## Licence
Voir `LICENSE`.
