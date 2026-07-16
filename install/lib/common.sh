#!/usr/bin/env bash
# Helpers partages par les scripts install/lib/*.sh. Source uniquement,
# jamais execute directement.

backup_if_exists() {
  local src_path="$1"
  local backup_dir="$2"
  if [ -e "$src_path" ]; then
    run mkdir -p "$backup_dir"
    run cp -f "$src_path" "$backup_dir/$(basename "$src_path")"
  fi
}

backup_dir_if_exists() {
  local src_dir="$1"
  local backup_dir="$2"
  if [ -d "$src_dir" ]; then
    run mkdir -p "$backup_dir"
    run cp -R "$src_dir" "$backup_dir/"
  fi
}

# resolve_workspace_repo_root <workspace_root_or_empty> <src_repo_root>
resolve_workspace_repo_root() {
  local workspace_root="$1"
  local repo_root
  if [ -n "$workspace_root" ]; then
    if ! repo_root="$(git -C "$workspace_root" rev-parse --show-toplevel 2>/dev/null)"; then
      echo "Le chemin --workspace-root '$workspace_root' ne pointe pas vers un repo git valide." >&2
      exit 1
    fi
  else
    if ! repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
      echo "Aucun repo git detecte dans le repertoire courant. Fournis --workspace-root <chemin-du-repo-cible>." >&2
      exit 1
    fi
  fi
  repo_root="$(cd "$repo_root" && pwd)"
  printf '%s\n' "$repo_root"
}

add_git_exclude_entries() {
  local repo_root="$1"
  shift
  if [ "$dry" = 1 ]; then
    for entry in "$@"; do
      echo "[dry-run] add $entry to the target repo's Git local exclude file"
    done
    return
  fi
  local exclude_path
  exclude_path="$(git -C "$repo_root" rev-parse --git-path info/exclude)"
  case "$exclude_path" in
    /*) ;;
    *) exclude_path="$repo_root/$exclude_path" ;;
  esac
  mkdir -p "$(dirname "$exclude_path")"
  touch "$exclude_path"
  for entry in "$@"; do
    grep -Fxq "$entry" "$exclude_path" || printf '%s\n' "$entry" >> "$exclude_path"
  done
}

remove_git_exclude_entries() {
  local repo_root="$1"
  shift
  if [ "$dry" = 1 ]; then
    for entry in "$@"; do
      echo "[dry-run] remove $entry from the target repo's Git local exclude file"
    done
    return
  fi
  local exclude_path
  exclude_path="$(git -C "$repo_root" rev-parse --git-path info/exclude)"
  case "$exclude_path" in
    /*) ;;
    *) exclude_path="$repo_root/$exclude_path" ;;
  esac
  [ -f "$exclude_path" ] || return 0
  local tmp
  tmp="$(mktemp)"
  cp "$exclude_path" "$tmp"
  for entry in "$@"; do
    local tmp2
    tmp2="$(mktemp)"
    grep -vFx "$entry" "$tmp" > "$tmp2" || true
    mv "$tmp2" "$tmp"
  done
  mv "$tmp" "$exclude_path"
}

# write_maxime_version_marker <src_repo_root> <target_path> <backup_dir>
# Computed live at install time, never copied from a committed file: a SHA
# baked into a generated file is always at least one commit stale (it can't
# know the commit that carries it). See decisions-log 2026-07-16.
write_maxime_version_marker() {
  local src_repo_root="$1"
  local target_path="$2"
  local backup_dir="$3"
  local sha
  sha="$(git -C "$src_repo_root" rev-parse HEAD 2>/dev/null || true)"
  if [ -n "$sha" ]; then
    backup_if_exists "$target_path" "$backup_dir"
    if [ "$dry" = 1 ]; then
      echo "[dry-run] write $sha to $target_path"
    else
      printf '%s' "$sha" > "$target_path"
    fi
  fi
}

add_gitignore_entries() {
  local repo_root="$1"
  local header="$2"
  shift 2
  if [ "$dry" = 1 ]; then
    echo "[dry-run] add '$header' block to the target repo's .gitignore"
    return
  fi
  local gitignore_path="$repo_root/.gitignore"
  touch "$gitignore_path"
  local missing=0
  grep -Fxq "$header" "$gitignore_path" || missing=1
  for entry in "$@"; do
    grep -Fxq "$entry" "$gitignore_path" || missing=1
  done
  [ "$missing" -eq 1 ] || return
  [ -s "$gitignore_path" ] && printf '\n' >> "$gitignore_path"
  grep -Fxq "$header" "$gitignore_path" || printf '%s\n' "$header" >> "$gitignore_path"
  for entry in "$@"; do
    grep -Fxq "$entry" "$gitignore_path" || printf '%s\n' "$entry" >> "$gitignore_path"
  done
}

remove_gitignore_entries() {
  local repo_root="$1"
  local header="$2"
  shift 2
  if [ "$dry" = 1 ]; then
    echo "[dry-run] remove '$header' block from the target repo's .gitignore"
    return
  fi
  local gitignore_path="$repo_root/.gitignore"
  [ -f "$gitignore_path" ] || return 0
  local tmp
  tmp="$(mktemp)"
  cp "$gitignore_path" "$tmp"
  local tmp2
  tmp2="$(mktemp)"
  grep -vFx "$header" "$tmp" > "$tmp2" || true
  mv "$tmp2" "$tmp"
  for entry in "$@"; do
    tmp2="$(mktemp)"
    grep -vFx "$entry" "$tmp" > "$tmp2" || true
    mv "$tmp2" "$tmp"
  done
  mv "$tmp" "$gitignore_path"
}
