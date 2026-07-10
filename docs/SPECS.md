# SPECS — Système mA.xI.me + Hiérarchie CLAUDE.md

- Spécification fonctionnelle issue de la session du 2026-06-16
- Auteur : IamPhilG | Statut : à valider avant implémentation

---

## 1. CONTEXTE ET OBJECTIF

### 1.1 Problème à résoudre

L'utilisateur travaille avec Claude Code (Windows 11 + VS Code) sur de multiples
repos de sujets différents (AD DS / IAM, géométrie, et autres à venir).
Les problèmes actuels :

- Perte de contexte entre les sessions (Claude Code n'a pas de mémoire native)
- Répétition des mêmes instructions à chaque session et chaque repo
- Erreurs évitables qu'une autre IA détecterait immédiatement
- Risque de gaspiller une journée dans une mauvaise direction
- Consommation de tokens non maîtrisée sur les grosses tâches

### 1.2 Objectif

Mettre en place un système auto-optimisant où :

- Claude commence chaque session de travail par un état des lieux honnête
- Le contexte est préservé entre les sessions via un handoff
- Les bonnes pratiques sont imposées systématiquement (plan, specs, branches, tests)
- Claude s'enrichit de chaque session et évite les impasses déjà explorées
- Claude minimise sa consommation de tokens avec le meilleur rendement possible
- Le système devient PLUS SIMPLE avec le temps (Claude fait de plus en plus nativement)

### 1.3 Critère de succès

Évaluation factuelle, pas un pourcentage inventé :
objectif de session atteint (oui/partiel/non), nombre de retravaux évitables,
impasses évitées, handoff complet, CLAUDE.md allégé vs alourdi.

---

## 2. ARCHITECTURE GLOBALE

### 2.1 Hiérarchie des CLAUDE.md (additive, native à Claude Code)

```text
~/.claude/CLAUDE.md          → règles de comportement globales (le COMMENT)
    +
{repo}/CLAUDE.md             → contexte et règles spécifiques au repo (le QUOI)
    +
{repo}/sous-dossier/CLAUDE.md → précisions locales si nécessaire
```

Les trois niveaux se CUMULENT. Le repo n'écrase pas le global.
LIMITE CONNUE : ce cumul est une convention, pas un verrou technique.
Un repo PEUT techniquement contredire le global ; Claude doit le signaler.

### 2.2 mA.xI.me

mA.xI.me = l'alter ego automatisé de l'utilisateur.
UN SEUL agent orchestrateur (pas 8 agents permanents), avec trois capacités :

1. Orchestration du workflow (plan → spec → code → vérif → handoff)
2. Gestion du contexte (spawn de sous-agents éphémères sur déclencheurs observables)
3. Auto-optimisation (révision du CLAUDE.md en fin de session, avec validation)

### 2.3 Sous-agents éphémères

Créés à la demande pour une tâche isolée/parallélisable/lourde, avec leur
propre contexte et mémoire ciblée, puis oubliés. Résultat TOUJOURS vérifié
avant réintégration dans .claude/memory/.

---

## 3. EXIGENCES FONCTIONNELLES

### EF-01 — Détection de mode

Au début de chaque interaction, détecter :

- Mode QUESTION (léger) : juste une question → répondre, pas de protocole
- Mode TRAVAIL : implémentation/modification → lancer SESSION START PROTOCOL

### EF-02 — Session Start (mode travail)

Lire le handoff, exécuter git status + git log, interviewer l'utilisateur sur
l'objectif, produire une évaluation pré-session avec recommandation
(continuer / pivoter / refactorer), attendre approbation avant tout code.

### EF-03 — Discipline de branche

Jamais travailler sur main/master. Toujours créer feature/ ou fix/.

### EF-04 — Spec d'abord

Pas d'implémentation sans spec écrite et approuvée
La spec complète vit dans .claude/specs/YYYYMMDD-titre.md.
Le decisions-log.md ne reçoit qu'un résumé court (une ligne : décision + rationale), pas la spec.
Deux rôles distincts : specs/ = le détail complet ; decisions-log.md = la trace chronologique append-only.

### EF-05 — Capture de skills (deux déclencheurs)

- Tâche répétitive (≥3 fois) → skill qui sert de mode d'emploi à un sous-agent
- Problème résolu → skill défensif pour éviter de répéter l'erreur

Vérifier en fin de session si un skill est devenu natif → proposer retrait.

### EF-06 — Vérification de l'output

Avant de déclarer terminé : identifier le meilleur outil de vérification,
l'exécuter, montrer le résultat. Jamais "ça devrait marcher".

### EF-07 — Obligation d'honnêteté

Signaler toute meilleure approche, mauvaise direction, ou dette technique,
même si cela implique de défaire du travail fait.

### EF-08 — Gestion du contexte / sous-agents

Spawn d'un sous-agent éphémère sur déclencheurs OBSERVABLES (gros fichiers,
tâche répétitive parallélisable, tâche isolée, conversation déjà longue).
PAS sur un % de contexte (non mesurable de façon fiable).
Vérification obligatoire du résultat avant réintégration.

### EF-09 — Handoff vivant

Le handoff se met à jour en fin de bloc de travail (~20-30 min), sur décision structurante,
ou sur blocage. PAS après chaque tâche ou fichier modifié.

### EF-10 — End of Session

Sur phrases déclencheuses (FR/EN) : git status (jamais git add -A auto),
écrire le handoff complet, append au decisions-log, append au dead-ends si besoin,
lancer l'auto-optimisation, confirmer.

### EF-11 — Changement mineur vs significatif

- Mineur (localisé) : signaler dans la conversation + exécuter automatiquement
- Significatif (global/multi-repos/architecture) : STOP, expliquer en langage
  clair (quoi/pourquoi/impacts/temps/alternative), mode plan, attendre approbation

### EF-12 — Setup nouveau repo

Mode plan d'abord : détecter le thème, proposer la structure .claude/,
générer le CLAUDE.md repo basé sur le global, charger la KB pertinente,
attendre approbation avant création.

### EF-13 — Knowledge base centralisée

Repo dédié `knowledge-base/` avec dossiers par thème + dossier global.
mA.xI.me lit index.md, charge SEULEMENT les fichiers du thème pertinent,
enrichit la KB en fin de session.

### EF-14 — Auto-optimisation du CLAUDE.md

En fin de session, Claude PROPOSE des modifications (règles devenues natives,
skills obsolètes, simplifications). Validation explicite de l'utilisateur requise.
Backup auto dans ~/.claude/backups/ avant écriture. INVIOLABLE RULES
jamais supprimables sans confirmation séparée.

### EF-15 — Pilotage mobile (Remote Control)

La session tourne sur le Windows 11 ; pilotable depuis iPhone/iPad via
Remote Control (app Claude). Tout le contexte local (CLAUDE.md, skills, MCP,
fichiers) reste disponible. Le PC doit rester allumé et la session active.

---

## 4. EXIGENCES NON FONCTIONNELLES

### ENF-01 — Légèreté

Le CLAUDE.md doit rester le plus court possible. Less is more.
Objectif long terme : un fichier minimal, Claude faisant le reste nativement.

### ENF-02 — Transparence

Toute action expliquée en langage clair, jamais une ligne de commande obscure
suivie d'une demande d'approbation que l'utilisateur accepterait sans comprendre.

### ENF-03 — Sécurité / prudence

Jamais git add -A automatique. Jamais réintégrer un résultat non vérifié.
Jamais écraser un fichier de config existant sans backup et confirmation.

### ENF-04 — Économie de tokens

Chargement intelligent de la KB (par thème), délégation aux sous-agents
pour isoler le contexte, compression des décisions anciennes.

### ENF-05 — Auto-amélioration mesurable

Le système doit pouvoir se simplifier au fil du temps et le démontrer
(lignes retirées vs ajoutées au CLAUDE.md à chaque session).

---

## 5. STRUCTURE DE FICHIERS CIBLE

### 5.1 Global

```text
~/.claude/
├── CLAUDE.md                  ← règles globales (le COMMENT)
├── mA.xI.me-ARCHITECTURE.md   ← doc de référence de l'architecture
├── backups/                   ← backups auto du CLAUDE.md (existe déjà)
├── skills/                    ← slash commands mA.xI.me-* (voir 6)
└── memory/
    ├── decisions-log-global.md
    └── dead-ends-global.md
```

### 5.2 Par repo

```text
{repo}/.claude/
├── CLAUDE.md                  ← contexte du repo (le QUOI)
├── memory/
│   ├── YYYYMMDD.session-handoff.md  ← un fichier par session (accumulation locale)
│   ├── decisions-log.md       ← append-only
│   └── dead-ends.md           ← append-only
├── specs/
└── skills/
```

### 5.3 Knowledge base (repo dédié)

```text
knowledge-base/
├── index.md                   ← lu en premier par mA.xI.me
├── ad-ds/
├── [autre-theme]/
└── global/
```

---

## 6. NOTE TECHNIQUE — SLASH COMMANDS (mise à jour 2026)

Depuis Claude Code v2.1.101, les custom slash commands ont fusionné avec
les skills. Deux formats coexistent :

- `.claude/commands/<nom>.md` → format LEGACY, fonctionne toujours
- `.claude/skills/<nom>/SKILL.md` → format RECOMMANDÉ, supporte /nom ET
  l'invocation autonome par Claude

DÉCISION POUR mA.xI.me : implémenter les commandes mA.xI.me-* comme des SKILLS
(double avantage : appel manuel /maxime-setup + auto-déclenchement par Claude).

Format frontmatter :

```text
---

name: maxime-setup
description: Ce que fait la commande et quand l'utiliser...
allowed-tools: Read, Glob, Grep, Bash

---

# Instructions impératives, étape par étape

```

Les sous-agents peuvent charger un scope mémoire ciblé via le champ
frontmatter `memory: user|project|local`, ce qui valide les sous-agents
éphémères à contexte isolé.

---

## 7. CONTRAINTES ET LIMITES CONNUES

- Claude ne peut pas mesurer son % de contexte de façon fiable → déclencheurs observables.
- Les CLAUDE.md sont additifs, pas de protection technique du global contre un repo.
- Les slash commands doivent exister comme fichiers réels.
- Un sous-agent peut se tromper → vérification obligatoire.
- Remote Control : research preview, une session par machine, pas de push notifications
  natives, PC doit rester allumé.
- L'environnement de travail ne doit PAS être $HOME directement
  mais un vrai dossier de repo.

---

## 8. ÉTAT D'IMPLÉMENTATION

### Phase 1 — Fondations ✅

- [x] CLAUDE.md méthode dans le repo (installé via install.ps1 / install.sh)
- [x] Agent `maxime` + `maxime-reviewer` (agents/)
- [x] 7 skills mA.xI.me-* (skills/ + .agents/skills/ pour Codex)
- [x] Adaptateur GitHub Copilot (.copilot/ → .github/ à l'install)
- [x] Adaptateur Codex (.codex/ + .agents/skills/)
- [x] Installers repo-only avec backup horodaté (install.ps1 + install.sh)
- [x] Hook anti-commandes-destructrices (block-destructive-bash.sh)
- [x] Validation croisée par Codex, Gemini, Claude Code, Copilot (2026-06-17)

### Phase 2 — Knowledge base

- [ ] Créer/peupler le repo `OurITRes/knowledge-base` (index.md, active/, archived/)
- [ ] Connecter via submodule `knowledge-base/` dans les repos consommateurs
  (le skill `maxime-kb` est prêt — il attend juste la KB)

### Phase 3 — Déploiement sur repos réels

- [ ] Lancer `maxime-setup` sur un vrai projet
- [ ] Valider le cycle complet : start → travail → handoff daté → reprise

### Phase 4 — Boucle d'auto-optimisation (usage)

- [ ] Laisser tourner plusieurs semaines
- [ ] Vérifier que le CLAUDE.md s'allège et que les dead-ends s'accumulent utilement

### Hors périmètre de ce repo

- Mobile / Remote Control : fonctionnalité Claude, non implémentable ici
