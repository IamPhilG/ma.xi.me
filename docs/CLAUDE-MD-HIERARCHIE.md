# Hiérarchie & chargement des CLAUDE.md (Claude Code)

Source officielle (lue et vérifiée) :
https://code.claude.com/docs/en/memory

---

## 1. Les 4 niveaux (par ordre de chargement, du plus large au plus spécifique)

| Scope | Emplacement | Rôle | Partagé avec |
|-------|-------------|------|--------------|
| **Managed policy** | macOS : `/Library/Application Support/ClaudeCode/CLAUDE.md`<br>Linux/WSL : `/etc/claude-code/CLAUDE.md`<br>Windows : `C:\Program Files\ClaudeCode\CLAUDE.md` | Instructions imposées par l'organisation (IT/DevOps) : standards, sécurité, conformité | Tous les utilisateurs de la machine/org |
| **User instructions** | `~/.claude/CLAUDE.md` | Préférences personnelles, tous projets | Moi seul (tous projets) |
| **Project instructions** | `./CLAUDE.md` ou `./.claude/CLAUDE.md` | Instructions partagées de l'équipe | L'équipe via le contrôle de source |
| **Local instructions** | `./CLAUDE.local.md` | Préférences perso d'un projet ; à mettre dans `.gitignore` | Moi seul (projet courant) |

Les niveaux se **cumulent** (concaténés), ils ne s'écrasent pas.

---

## 2. Comment le chargement fonctionne RÉELLEMENT (le point clé)

Claude Code ne lit pas une liste fixe d'emplacements. Il **remonte l'arborescence**
depuis le répertoire de travail (cwd) jusqu'à la racine, et charge chaque
`CLAUDE.md` et `CLAUDE.local.md` rencontré en chemin.

Exemple : lancé dans `foo/bar/`, il charge `foo/bar/CLAUDE.md`, puis `foo/CLAUDE.md`,
plus les `CLAUDE.local.md` à côté.

**Ordre dans le contexte** : de la racine du système vers le cwd. Donc les
instructions les plus proches de l'endroit où tu lances Claude sont lues **en
dernier**. En cas de contradiction, le "dernier lu" agit comme un signal de priorité.
Dans chaque dossier, `CLAUDE.local.md` est ajouté APRÈS `CLAUDE.md`.

Les `CLAUDE.md` des sous-dossiers (sous le cwd) ne sont PAS chargés au lancement :
ils se chargent à la demande quand Claude lit un fichier de ce sous-dossier.

### ⚠️ Piège vécu (2026-06-16)
Le niveau "Project" est relatif au cwd. Lancer Claude Code depuis un dossier qui
n'est pas un repo git (ex : `C:\Users\<username>` ou `...\source\repos`) fait que
`./CLAUDE.md` se rabat sur le `CLAUDE.md` de CE dossier. C'est ce qui avait créé
l'illusion d'un "CLAUDE.md à la racine du profil" : ce n'était pas un emplacement
officiel séparé, juste un palier de la remontée d'arbre.
→ **Toujours lancer Claude Code depuis un vrai repo git** pour que le niveau
Project pointe au bon endroit.

---

## 3. CLAUDE.md ≠ configuration imposée (TRÈS important)

> Les CLAUDE.md (et l'auto memory) sont traités comme du **contexte**, pas comme
> de la configuration appliquée de force. Pour bloquer une action quoi que Claude
> décide, il faut un **hook PreToolUse**, pas une ligne de texte.

Conséquence directe pour nos "règles inviolables" (jamais `git add -A`, jamais main) :
- Écrites dans le CLAUDE.md = instructions FORTES, mais pas un verrou.
- Pour un vrai blocage technique → **hook** (`PreToolUse`) ou **managed settings**
  (`permissions.deny`). À considérer pour les garde-fous critiques.

CLAUDE.md content est délivré comme un message utilisateur après le system prompt :
Claude le lit et tente de le suivre, sans garantie de conformité stricte —
surtout si les instructions sont vagues ou contradictoires.

---

## 4. Bonnes pratiques d'écriture (officiel)

- **Taille** : viser **< 200 lignes** par CLAUDE.md. Plus long = plus de contexte
  consommé et **moins bonne adhérence**. (Cette limite des 200 lignes / 25 KB
  s'applique à `MEMORY.md` de l'auto-memory ; les CLAUDE.md, eux, sont chargés en
  entier quelle que soit la longueur — mais plus court = mieux suivi.)
- **Spécificité** : "Use 2-space indentation" plutôt que "format code properly".
  "Run `npm test` before committing" plutôt que "test your changes".
- **Structure** : titres markdown + bullets. Claude scanne la structure comme un lecteur.
- **Cohérence** : si deux règles se contredisent, Claude en choisit une arbitrairement.
  Revoir périodiquement pour retirer le contradictoire ou l'obsolète.

---

## 5. Astuces utiles découvertes

### Commentaires HTML = notes gratuites
Les commentaires HTML de niveau bloc `<!-- ... -->` sont **retirés avant injection**
dans le contexte. → Laisser des notes aux mainteneurs humains SANS consommer de
tokens. (Les commentaires DANS un bloc de code sont, eux, préservés. Et `Read`
sur le fichier les montre.)

### Imports `@path`
Un CLAUDE.md peut importer d'autres fichiers via `@chemin/fichier`. Chemins relatifs
(résolus par rapport au fichier qui importe) ou absolus. Récursif, max 4 niveaux.
⚠️ Les fichiers importés sont chargés au lancement → ça n'économise PAS de contexte,
ça organise seulement.
Exemple : `# git workflow @docs/git-instructions.md`
Partager du perso entre worktrees : `@~/.claude/my-project-instructions.md`.

### `/init` pour démarrer un CLAUDE.md projet
Analyse le codebase et génère un CLAUDE.md de départ (build, tests, conventions).
S'il existe déjà, `/init` propose des améliorations au lieu d'écraser.
`CLAUDE_CODE_NEW_INIT=1` active un flux interactif multi-phases.

### AGENTS.md
Claude Code lit `CLAUDE.md`, pas `AGENTS.md`. Si un repo a déjà un AGENTS.md :
créer un CLAUDE.md qui l'importe → `@AGENTS.md` (puis ajouter des instructions
Claude-spécifiques en dessous). Sur Windows, préférer l'import `@AGENTS.md` au
symlink (le symlink exige les droits admin / mode développeur).

### `.claude/rules/` pour les gros projets
Découper en fichiers par sujet (`testing.md`, `security.md`...). Chargés à chaque
session avec la même priorité que `.claude/CLAUDE.md`. Peuvent être **scopés par
chemin** via frontmatter `paths:` (glob) → ne se chargent que quand Claude touche
les fichiers correspondants = moins de bruit, contexte économisé.
Règles user-level : `~/.claude/rules/` (préférences perso, tous projets).
Partage entre projets via symlinks.

### Skills vs rules vs CLAUDE.md (quand utiliser quoi)
- **CLAUDE.md** : faits à garder chaque session (build, conventions, "always X").
- **Rules** (`.claude/rules/`) : modulaire, scopable par chemin, chargé en contexte.
- **Skills** : workflows répétables, chargés UNIQUEMENT à l'invocation ou quand
  Claude juge pertinent. Pour les procédures qui n'ont pas à être en contexte tout le temps.

### Monorepo — exclure des CLAUDE.md parasites
`claudeMdExcludes` (dans `.claude/settings.local.json`) saute des CLAUDE.md
d'autres équipes par chemin/glob. Les managed policy ne peuvent PAS être exclus.

### Survie au /compact
Le CLAUDE.md de racine de projet survit au `/compact` (re-lu depuis le disque).
Les CLAUDE.md de sous-dossiers ne sont pas réinjectés auto : ils rechargent au
prochain accès à un fichier de ce sous-dossier. → Mettre dans CLAUDE.md ce qui
ne doit pas se perdre (pas seulement dans la conversation).

### Débogage "Claude ne suit pas mon CLAUDE.md"
1. `/memory` → vérifier que le fichier est bien listé (sinon Claude ne le voit pas).
2. Vérifier que l'emplacement est bien chargé pour la session (cf. remontée d'arbre).
3. Rendre les instructions plus spécifiques.
4. Chercher les contradictions entre fichiers.
5. Si ça doit s'exécuter à un moment précis (avant chaque commit...) → **hook**, pas CLAUDE.md.
Astuce : hook `InstructionsLoaded` pour logger quels fichiers d'instructions
sont chargés, quand et pourquoi.

---

## 6. CLAUDE_CONFIG_DIR (notre cas)

Déplace le dossier de config (`~/.claude` → dossier choisi). Vérifié sur la
machine : elle ne redirige pas le chargement des CLAUDE.md comme on pourrait le
croire ; elle déplace surtout l'état local (auto-memory, sessions).
→ Par défaut : NE PAS la définir. Rester au standard. (On l'a retirée le 2026-06-16.)

NB auto-memory : chaque projet a `~/.claude/projects/<project>/memory/` avec un
`MEMORY.md` (index, 200 lignes / 25 KB chargées par session) + fichiers par sujet
chargés à la demande. `<project>` dérive du repo git → hors repo git, c'est la
racine du dossier qui sert. Raison de plus pour travailler dans de vrais repos git.

---

## 7. Application à mA.xI.me

- **Méthode + socle** → User (`~/.claude/CLAUDE.md`), toujours actif.
- **mA.xI.me** → agent (`~/.claude/agents/maxime.md`) + skills, activable.
- **Spécifique projet** → `./.claude/CLAUDE.md` du repo de travail.
- **Perso non partagé** (sandbox, données test) → `./CLAUDE.local.md` + `.gitignore`.
- **Garde-fous critiques** (jamais main, jamais `git add -A`) → envisager des
  **hooks PreToolUse** en complément du texte, car le CLAUDE.md n'est pas un verrou.
- **KB** → submodule à `knowledge-base/` (chemin relatif au repo).
