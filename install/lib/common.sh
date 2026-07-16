#!/usr/bin/env bash
# Helpers partages par les scripts install/lib/*.sh. Source uniquement,
# jamais execute directement.

# Present in the header of every file generate-adapters.* produces -- used to
# tell "this is our own prior output" apart from "the target repo already had
# its own project-specific file before mA.xI.me was installed" (issue #27).
MAXIME_GENERATED_MARKER='Generated from `core/socle.md`. Do not edit directly.'

# save_pre_existing_project_content <target_path> <preserve_destination> [preserve_header]
# Before a generated file overwrites target_path, checks whether it already
# exists and is NOT one of mA.xI.me's own prior outputs. If so, moves its
# content to preserve_destination (created once, never touched again on
# later installs). Returns 0 (true) if content was preserved this way.
save_pre_existing_project_content() {
  local target_path="$1"
  local preserve_destination="$2"
  local preserve_header="${3:-}"
  [ -f "$target_path" ] || return 1
  [ -f "$preserve_destination" ] && return 1
  grep -qF "$MAXIME_GENERATED_MARKER" "$target_path" && return 1

  mkdir -p "$(dirname "$preserve_destination")"
  if [ -n "$preserve_header" ]; then
    { printf '%s' "$preserve_header"; cat "$target_path"; } > "$preserve_destination"
  else
    cp -f "$target_path" "$preserve_destination"
  fi
  return 0
}

# merge_maxime_managed_block <target_path> <generated_content_file>
# For hosts with no confirmed native import/merge mechanism (Codex/AGENTS.md
# -- the override-file semantics found in research were ambiguous, "at most
# one file used per directory" suggests replace, not merge). Writes the
# generated content inside an explicit marker block instead of overwriting
# target_path wholesale: no pre-existing file -> block alone; pre-existing
# managed block -> replace only that block; old-style fully-generated file
# (has the marker, no block yet) -> replace wholesale, nothing to lose;
# real project content never touched before -> append the block, preserve
# everything. Prints "mixed" (managed + non-managed content coexist -- caller
# should skip default git-exclude for that file) or "clean" to stdout.
merge_maxime_managed_block() {
  local target_path="$1"
  local generated_content_file="$2"
  local begin_marker='<!-- BEGIN mA.xI.me generated -->'
  local end_marker='<!-- END mA.xI.me generated -->'

  local block_file
  block_file="$(mktemp)"
  { echo "$begin_marker"; cat "$generated_content_file"; echo "$end_marker"; } > "$block_file"

  if [ ! -f "$target_path" ]; then
    cp "$block_file" "$target_path"
    rm -f "$block_file"
    echo "clean"
    return
  fi

  if grep -qF "$begin_marker" "$target_path" && grep -qF "$end_marker" "$target_path"; then
    local outside
    outside="$(awk -v b="$begin_marker" -v e="$end_marker" 'index($0,b){inblock=1;next} index($0,e){inblock=0;next} !inblock' "$target_path")"
    awk -v b="$begin_marker" -v e="$end_marker" -v blockfile="$block_file" '
      index($0,b){
        while ((getline line < blockfile) > 0) print line
        close(blockfile)
        inblock=1
        next
      }
      index($0,e){ inblock=0; next }
      !inblock{ print }
    ' "$target_path" > "$target_path.tmp"
    mv "$target_path.tmp" "$target_path"
    rm -f "$block_file"
    if [ -n "$(printf '%s' "$outside" | tr -d '[:space:]')" ]; then
      echo "mixed"
    else
      echo "clean"
    fi
    return
  fi

  if grep -qF "$MAXIME_GENERATED_MARKER" "$target_path"; then
    cp "$block_file" "$target_path"
    rm -f "$block_file"
    echo "clean"
    return
  fi

  { cat "$target_path"; echo; cat "$block_file"; } > "$target_path.tmp"
  mv "$target_path.tmp" "$target_path"
  rm -f "$block_file"
  echo "mixed"
}

# remove_maxime_managed_block <target_path>
# Mirror of merge_maxime_managed_block for uninstall. If target_path
# contains an explicit marker block, removes ONLY that block, leaving any
# surrounding project content untouched (deletes the file entirely if
# nothing remains), and returns 0 (true). If no marker block is found, does
# nothing and returns 1 (false) -- caller falls back to its normal
# whole-file removal.
remove_maxime_managed_block() {
  local target_path="$1"
  local begin_marker='<!-- BEGIN mA.xI.me generated -->'
  local end_marker='<!-- END mA.xI.me generated -->'
  [ -f "$target_path" ] || return 1
  grep -qF "$begin_marker" "$target_path" || return 1
  grep -qF "$end_marker" "$target_path" || return 1

  local outside
  outside="$(awk -v b="$begin_marker" -v e="$end_marker" 'index($0,b){inblock=1;next} index($0,e){inblock=0;next} !inblock' "$target_path")"
  if [ -z "$(printf '%s' "$outside" | tr -d '[:space:]')" ]; then
    rm -f "$target_path"
  else
    printf '%s\n' "$outside" > "$target_path"
  fi
  return 0
}

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
  [ "$missing" -eq 1 ] || return 0
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
