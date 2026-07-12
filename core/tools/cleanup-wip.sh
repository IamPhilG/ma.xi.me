#!/usr/bin/env bash
set -euo pipefail

apply=0
keep_handoffs=5
retain_specs_days=30
retain_results_days=30
retain_tools_days=14
retain_tests_days=30
workspace_root=""
no_report=0

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) apply=1 ;;
    --workspace-root)
      shift
      workspace_root="${1:-}"
      ;;
    --keep-handoffs)
      shift
      keep_handoffs="${1:-}"
      ;;
    --retain-specs-days)
      shift
      retain_specs_days="${1:-}"
      ;;
    --retain-results-days)
      shift
      retain_results_days="${1:-}"
      ;;
    --retain-tools-days)
      shift
      retain_tools_days="${1:-}"
      ;;
    --retain-tests-days)
      shift
      retain_tests_days="${1:-}"
      ;;
    --no-report) no_report=1 ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

if [ -n "$workspace_root" ]; then
  repo_root="$workspace_root"
else
  repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
fi

if [ "$(basename "$repo_root")" = ".wip" ]; then
  repo_root="$(cd "$repo_root/.." && pwd)"
else
  repo_root="$(cd "$repo_root" && pwd)"
fi

wip_root="$repo_root/.wip"
[ -d "$wip_root" ] || { echo "Missing .wip directory at '$wip_root'." >&2; exit 1; }

memory_root="$wip_root/memory"
specs_root="$wip_root/specs"
adr_root="$wip_root/adr"
results_root="$wip_root/results"
tools_root="$wip_root/tools"
tests_root="$wip_root/tests"

now_epoch="$(date +%s)"

declare -A candidates=()

to_epoch() {
  local file="$1"
  if stat -c %Y "$file" >/dev/null 2>&1; then
    stat -c %Y "$file"
  else
    stat -f %m "$file"
  fi
}

is_under_wip() {
  local p
  p="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
  case "$p" in
    "$wip_root"/*) return 0 ;;
    *) return 1 ;;
  esac
}

add_candidate() {
  local file="$1"
  local reason="$2"
  if is_under_wip "$file"; then
    candidates["$file"]="$reason"
  fi
}

collect_by_age() {
  local dir="$1"
  local keep_days="$2"
  shift 2
  local excludes=("$@")

  [ -d "$dir" ] || return 0

  while IFS= read -r -d '' file; do
    local skip=0
    local name
    name="$(basename "$file")"
    for ex in "${excludes[@]}"; do
      if [ "$name" = "$ex" ]; then
        skip=1
        break
      fi
    done
    [ "$skip" -eq 1 ] && continue

    local mtime age_days
    mtime="$(to_epoch "$file")"
    age_days="$(( (now_epoch - mtime) / 86400 ))"
    if [ "$age_days" -gt "$keep_days" ]; then
      add_candidate "$file" "older-than-${keep_days}-days"
    fi
  done < <(find "$dir" -type f -print0)
}

if [ -d "$memory_root" ]; then
  mapfile -t handoffs < <(find "$memory_root" -maxdepth 1 -type f -name '*.session-handoff.md' -print | while IFS= read -r f; do printf '%s\t%s\n' "$(to_epoch "$f")" "$f"; done | sort -r -n | awk -F'\t' '{print $2}')
  idx=0
  for h in "${handoffs[@]}"; do
    idx=$((idx + 1))
    if [ "$idx" -gt "$keep_handoffs" ]; then
      add_candidate "$h" "old-handoff"
    fi
  done
fi

collect_by_age "$specs_root" "$retain_specs_days"
collect_by_age "$results_root" "$retain_results_days"
collect_by_age "$tests_root" "$retain_tests_days"
collect_by_age "$tools_root" "$retain_tools_days" \
  cleanup-wip.ps1 cleanup-wip.sh \
  generate-adapters.ps1 generate-adapters.sh \
  check-adapter-sync.ps1 check-adapter-sync.sh \
  check-codex-skills-sync.ps1 check-codex-skills-sync.sh

deleted=()
failures=()

if [ "$apply" -eq 1 ]; then
  for file in "${!candidates[@]}"; do
    if rm -f "$file"; then
      deleted+=("$file")
    else
      failures+=("$file")
    fi
  done

  for root in "$memory_root" "$specs_root" "$results_root" "$tools_root" "$tests_root"; do
    [ -d "$root" ] || continue
    while IFS= read -r -d '' empty_dir; do
      rmdir "$empty_dir" 2>/dev/null || true
    done < <(find "$root" -depth -type d -empty -print0)
  done
fi

if [ "$no_report" -eq 0 ]; then
  mkdir -p "$results_root"
  stamp="$(date +%Y%m%d-%H%M%S)"
  report="$results_root/$stamp.wip-cleanup-report.md"

  {
    echo "# WIP Cleanup Report"
    echo
    if [ "$apply" -eq 1 ]; then
      echo "- Mode: APPLY"
    else
      echo "- Mode: DRY-RUN"
    fi
    echo "- Repo root: $repo_root"
    echo "- WIP root: $wip_root"
    echo "- Keep handoffs: $keep_handoffs"
    echo "- Retention days: specs=$retain_specs_days results=$retain_results_days tools=$retain_tools_days tests=$retain_tests_days"
    echo
    echo "## Candidates"
    if [ "${#candidates[@]}" -eq 0 ]; then
      echo "- none"
    else
      for file in "${!candidates[@]}"; do
        rel="${file#$repo_root/}"
        echo "- $rel (${candidates[$file]})"
      done | sort
    fi

    if [ "$apply" -eq 1 ]; then
      echo
      echo "## Deleted"
      if [ "${#deleted[@]}" -eq 0 ]; then
        echo "- none"
      else
        for file in "${deleted[@]}"; do
          rel="${file#$repo_root/}"
          echo "- $rel"
        done | sort
      fi

      echo
      echo "## Failures"
      if [ "${#failures[@]}" -eq 0 ]; then
        echo "- none"
      else
        for file in "${failures[@]}"; do
          rel="${file#$repo_root/}"
          echo "- $rel"
        done | sort
      fi
    fi
  } > "$report"

  echo "WIP cleanup report: $report"
fi

if [ "$apply" -eq 1 ]; then
  echo "WIP cleanup applied. Deleted: ${#deleted[@]}. Failures: ${#failures[@]}."
  [ "${#failures[@]}" -eq 0 ] || exit 1
else
  echo "WIP cleanup dry-run complete. Candidates: ${#candidates[@]}."
fi
