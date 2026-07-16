#!/usr/bin/env bash
# Helpers partages par les hooks garde-fou mA.xI.me. Source uniquement,
# jamais execute directement.

# resolve_repo_root <cwd>
# Racine du repo git pour cwd, ou cwd lui-meme si ce n'est pas un repo git
# (fail permissif sur cette resolution precise -- l'appelant verifie quand
# meme le confinement contre ce qui est retourne).
resolve_repo_root() {
  local cwd="$1"
  git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$cwd"
}

# path_outside_repo <chemin_candidat> <cwd> <repo_root>
# Retourne 0 (vrai, donc hors repo) si chemin_candidat, resolu par rapport a
# cwd, n'est PAS a l'interieur de repo_root. Best-effort : ne rejoue pas le
# quoting/expansion complet d'un shell -- meme limite deja acceptee pour la
# detection des verbes destructeurs dans cette famille de hooks (regex sur
# la chaine brute, pas un parseur semantique).
path_outside_repo() {
  local candidate="$1"
  local cwd="$2"
  local repo_root="$3"
  local resolved

  case "$candidate" in
    /*|[A-Za-z]:\\*|[A-Za-z]:/*) resolved="$candidate" ;;
    ~*) resolved="$HOME${candidate#\~}" ;;
    *) resolved="$cwd/$candidate" ;;
  esac

  if command -v realpath >/dev/null 2>&1; then
    resolved="$(realpath -m "$resolved" 2>/dev/null || printf '%s' "$resolved")"
  fi

  # Normalise les antislashs (chemin Windows vs racine resolue via git-bash,
  # toujours en slashs) et la casse (la lettre de lecteur differe souvent en
  # casse entre les deux sources -- systeme de fichiers Windows insensible
  # a la casse de toute facon).
  local norm_resolved norm_root
  norm_resolved="$(printf '%s' "${resolved//\\//}" | tr '[:upper:]' '[:lower:]')"
  norm_root="$(printf '%s' "${repo_root//\\//}" | tr '[:upper:]' '[:lower:]')"

  case "$norm_resolved" in
    "$norm_root"|"$norm_root"/*) return 1 ;;
    *) return 0 ;;
  esac
}

# extract_path_candidates <commande>
# Emet un chemin candidat par ligne : chaque token separe par des espaces
# qui ressemble a un chemin absolu (Unix, Windows, ou ~), token entier
# uniquement -- jamais un sous-segment trouve au milieu d'un token (ex: ne
# doit jamais matcher "/tmp/x" a l'interieur du token relatif ".wip/tmp/x").
# Le decoupage par mot (pas une regex de recherche libre) garantit cet
# ancrage. Les chemins relatifs eux-memes ne sont jamais des candidats --
# ils restent par construction a l'interieur du repo tant que cwd y est,
# donc jamais bloques par ce garde-fou.
extract_path_candidates() {
  local cmd="$1"
  local token stripped
  set -f
  for token in $cmd; do
    # Un chemin passe entre guillemets (cas courant : -Path "C:\...\x.txt")
    # garde ses guillemets comme caracteres litteraux apres le decoupage par
    # mot -- on les retire (une seule paire, en tete/en queue) avant le test,
    # sinon le token commence par `"` et ne matche jamais un chemin absolu.
    stripped="$token"
    stripped="${stripped#\"}"
    stripped="${stripped%\"}"
    stripped="${stripped#\'}"
    stripped="${stripped%\'}"
    case "$stripped" in
      /*|[A-Za-z]:\\*|[A-Za-z]:/*|~*) printf '%s\n' "$stripped" ;;
    esac
  done
  set +f
}
