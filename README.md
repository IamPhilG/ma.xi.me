# mA.xI.me

> A.I.me · MAX iMe · *Medium AI with eXtreme Intelligence for me*

Agent d'orchestration et de méthode pour Claude Code. mA.xI.me uniformise
mes repos : même structure, même façon de travailler avec Claude partout,
selon une boucle **SPEC → PLAN → LIVRABLE → VERIFY → REVIEW → IMPROVE**.

## Contenu
- `CLAUDE.md` — méthode universelle + socle de comportement (toujours actif)
- `agents/maxime.md` — orchestrateur (activable via `@maxime`)
- `agents/maxime-reviewer.md` — sous-agent d'analyse (read-only via hook de garde-fou) pour les grosses revues
- `skills/maxime-*/` — 7 workflows : start, plan, handoff, setup, retrofit, review, kb
- `docs/` — architecture et spécifications de référence
- `install/install.ps1` & `install/install.sh` — installe le contenu dans `~/.claude/`

## Installation

### Windows

```powershell
git clone https://github.com/IamPhilG/ma.xi.me
cd ma.xi.me

# La policy d'exécution PowerShell par défaut bloque les scripts.
# Pour en savoir plus sur les policy Powershell :
#  https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies?view=powershell-7.6)

# Lance l'installeur sans modifier la policy de ta machine :
#   powershell -ExecutionPolicy Bypass -File install\install.ps1

# Ou
# Pour pré-visualiser ce qui sera fait, sans rien modifier :
  powershell -ExecutionPolicy Bypass -File install\install.ps1 -WhatIf
```

Puis dans Claude Code : `/memory`, `/agents`, `/` pour vérifier le chargement.

L'installeur sauvegarde tout `~/.claude/agents` et `~/.claude/skills`
existant dans `~/.claude/backups/` avant d'écrire, et ne copie que les
fichiers `maxime*` — tes autres agents/skills ne sont pas touchés.

### macOS / Linux

    chmod +x install/install.sh
    ./install/install.sh

Pour pré-visualiser sans rien modifier :

    ./install/install.sh --dry-run

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
