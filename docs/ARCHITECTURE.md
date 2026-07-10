# mA.xI.me — Architecture (v2)
# Dernière modification : 2026-06-16
# Corrigée après audit croisé ChatGPT + Gemini

---

## NOM
mA.xI.me se lit "Maxime". Couches de sens :
A.I.me (l'IA qui me vise/représente) · MAX iMe (version max, le moi numérique) ·
mA.xI.me = Medium AI with eXtreme Intelligence for me.
- Identité affichée / prose / titres : **mA.xI.me**
- Identifiants techniques (dossiers skills, agents, commandes) : **maxime-*** (minuscules, traits d'union — contrainte Claude Code)

---

## PRINCIPE
UN orchestrateur, léger et honnête, qui devient PLUS SIMPLE avec le temps.
Pas une usine multi-agents. La délégation se fait vers de VRAIS sous-agents
Claude Code (read-only), pas vers des "CLAUDE.md éphémères" (modèle abandonné en v2).

---

## CORRECTIONS CLÉS DE LA v2 (issues de l'audit)
1. **Sous-agents = vrais `.claude/agents/*.md`** avec frontmatter (name, description,
   tools, permissionMode, maxTurns, memory). Read-only par défaut.
   On abandonne l'idée d'écrire un CLAUDE.md temporaire : il n'y a pas d'isolation
   mémoire réelle, c'est le même modèle dans la même fenêtre. Le gain d'un vrai
   sous-agent = contexte ciblé + outils restreints, pas une "VM cognitive".
2. **CLAUDE.md allégé** : règles permanentes seulement. Tous les workflows longs
   sont des skills (`~/.claude/skills/maxime-*/SKILL.md`).
3. **Skills uniquement** (pas de `.claude/commands/`). Format moderne :
   dossier + SKILL.md + frontmatter YAML en clés (pas en liste).
   `disable-model-invocation: true` sur les commandes à effet de bord (handoff, setup).
4. **Handoff moins fréquent** : fin de bloc (~20-30 min) / décision / fichier
   important / blocage. Pas après chaque micro-tâche.
5. **Décisions persistées immédiatement** (anti-crash Remote Control).
6. **Bascule Question→Travail** : pause + maxime-start avant de coder.
7. **"Vérifier la sanité" → exécuter les tests** du repo avant réintégration.
8. **"Changement significatif" défini factuellement** (API / schéma / dépendance /
   config-sécu / >3 fichiers).
9. **Inviolables HORS périmètre de l'auto-optimisation** (pas de boucle logique).

##  Emplacement des specs

La spec complète vit dans .claude/specs/YYYYMMDD-titre.md.
Le decisions-log.md ne reçoit qu'un résumé court (une ligne : décision + rationale), pas la spec.
Deux rôles distincts : specs/ = le détail complet ; decisions-log.md = la trace chronologique append-only.

---

## STRUCTURE DE FICHIERS

### Global (~/.claude/)
```
~/.claude/
├── CLAUDE.md                    # règles permanentes (court)
├── backups/                     # backups du CLAUDE.md (existe déjà)
├── skills/
│   ├── maxime-start/SKILL.md
│   ├── maxime-handoff/SKILL.md
│   ├── maxime-plan/SKILL.md
│   ├── maxime-setup/SKILL.md
│   ├── maxime-retrofit/SKILL.md
│   ├── maxime-review/SKILL.md
│   └── maxime-kb/SKILL.md
└── agents/
    └── maxime-reviewer.md       # sous-agent read-only
# Note : ARCHITECTURE.md n'est pas copié dans ~/.claude/ — il vit dans le repo
# (référence : https://github.com/IamPhilG/ma.xi.me/blob/main/docs/ARCHITECTURE.md)
```

### Par repo (.claude/)
```
.claude/
├── CLAUDE.md                    # contexte repo (le QUOI)
├── memory/  (session-handoff.md, decisions-log.md, dead-ends.md)
├── specs/
├── skills/   # skills spécifiques au repo (ad-ds-pattern-review/SKILL.md ...)
└── agents/   # sous-agents spécifiques au repo
```

### Codex
```
~/.codex/
├── AGENTS.md                    # guidance globale Codex
└── backups/                     # backups de l'installateur

~/.agents/
└── skills/
    └── maxime-*/SKILL.md        # skills globaux Codex

repo/
├── AGENTS.md                    # guidance repo Codex
└── .agents/
    └── skills/
        └── maxime-*/SKILL.md    # skills repo-scoped Codex
```

Codex utilise `AGENTS.md` pour les instructions durables et `.agents/skills`
pour les workflows réutilisables. `CLAUDE.md` reste le socle méthodologique
partagé du repo; `AGENTS.md` l'adapte à la surface Codex.
Les dossiers `skills/maxime-*` restent la source de vérité; `.agents/skills`
est une projection versionnée pour Codex, vérifiée par `tools/check-codex-skills-sync.*`.

Note installateur: `install/install.ps1` et `install/install.sh` sont désormais
repo-only. Ils ne déploient plus de contenu global vers `~/.codex` ou `~/.agents`.

### GitHub Copilot
```
repo source ma.xi.me/
└── .copilot/                    # source de vérité versionnée (templates)
  ├── copilot-instructions.md
  ├── agents/*.agent.md
  └── prompts/*.prompt.md

repo cible/
└── .github/                     # projection workspace/repo-scoped pour Copilot
  ├── copilot-instructions.md
  ├── agents/*.agent.md
  └── prompts/*.prompt.md
```

En scope `workspace`, Copilot doit lire la projection dans `.github/` du repo cible.
Le dossier `.copilot/` du repo ma.xi.me reste la source d'édition des templates.
Les installateurs rejettent explicitement les options globales (`target` autre que
`copilot` et scope autre que `workspace`). Les backups de projection sont stockés
dans le repo cible sous `./.bkp/copilot-install/`.

### Knowledge base (repo dédié)
```
knowledge-base/
├── index.md
├── active/      # fiches chargées (statut/date/source/portée obligatoires)
├── archived/    # non chargées sauf demande explicite
└── [themes...]
```

---

## SOUS-AGENTS — RÈGLES
- Définis dans `.claude/agents/` ou `~/.claude/agents/`.
- `tools` restreints par défaut (un reviewer = Read, Grep, Glob).
- `permissionMode: plan` pour les agents d'analyse.
- Read-only sauf justification ; jamais d'écriture de fichier projet par l'agent.
- Mémoire : par défaut sans persistance. `memory: local` seulement pour un
  reviewer récurrent d'un repo. Jamais `memory: user` sans raison explicite.
- Chaînage : si un agent dépend d'un autre, l'orchestrateur injecte le résultat
  précédent dans le brief suivant (pas d'écrasement d'output partagé).
- Réintégration : TOUJOURS exécuter les tests du repo avant d'agir sur un retour.

---

## SKILL CAPTURE — SEUIL RELEVÉ
Créer un skill seulement si une tâche revient **≥3 fois sur des sessions
différentes** ET représente une complexité asymétrique (dur à retrouver,
facile à oublier). Pas pour une routine de code standard (évite le "skill bloat").
Deux types : tâche répétitive (mode d'emploi réutilisable) / problème résolu (défensif).

---

## AUTO-OPTIMISATION — GARDE-FOUS
- Propose seulement (jamais d'écriture directe).
- Une règle candidate au retrait doit : capacité native confirmée (doc/test)
  + inutile ou contredite sur ≥3 sessions + accord explicite de l'utilisateur.
- Les INVIOLABLES ne sont jamais évaluées (pas dans le périmètre).
- Process d'écriture : diff → backup → "j'approuve la modification de CLAUDE.md" → écrire.
- KPI = clarté et incidents évités, PAS "lignes retirées" (un fichier court mais
  obscur n'est pas un progrès).

---

## PILOTAGE MOBILE (Remote Control)
La session tourne sur le Windows 11 ; pilotable depuis iPhone/iPad via l'app Claude.
Tout le contexte local (CLAUDE.md, skills, agents, MCP) reste actif.
Contraintes : research preview, une session par machine, pas de push natives,
le PC doit rester allumé et la session active. Canal d'accès, pas composant d'archi.
À tester APRÈS 2 cycles desktop complets validés.

---

## PLAN D'IMPLÉMENTATION (corrigé)

**Phase 0 — Normalisation (faite dans cette v2)**
maxime-* en minuscules · skills only · frontmatter correct · sous-agents en
.claude/agents/ · CLAUDE.md réduit.

**Phase 1 — Fondations minimales**
~/.claude/CLAUDE.md + skills maxime-start, maxime-handoff, maxime-setup.

**Phase 2 — Repo de test jouet**
maxime-setup, puis cycle start → petit changement → tests → handoff → reprise.

**Phase 3 — Sous-agent read-only**
agents/maxime-reviewer.md, testé sur gros fichier / diff.

**Phase 4 — Knowledge base**
index.md + active/ minimal AD DS + statut/fraîcheur/source.

**Phase 5 — Premier repo réel AD DS**
Auto-optimisation DÉSACTIVÉE au début. Observer 3-5 sessions.

**Phase 6 — Auto-optimisation contrôlée**
Seulement après preuve d'usage. Diff + backup + confirmation obligatoires.

**Mobile** : après Phase 5.

---

## LIMITES ASSUMÉES (honnêteté)
- Pas d'isolation mémoire réelle entre "agents" dans une même session : un vrai
  sous-agent aide par contexte ciblé et outils restreints, pas par magie.
- Le respect des règles peut se diluer sur une très longue session (dérive
  d'attention) : pour les garde-fous critiques (branche, secrets), préférer des
  hooks Git en complément du texte.
- Remote Control dépend d'un PC allumé : ce n'est pas de l'autonomie.
- "Gros fichier" n'est pas un déclencheur fiable (fenêtres de contexte larges) :
  privilégier le spawn de sous-agent sur décision explicite plutôt qu'automatique.
