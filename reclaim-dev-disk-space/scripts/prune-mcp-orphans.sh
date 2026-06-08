#!/usr/bin/env bash
# prune-mcp-orphans.sh — reclaim orphaned XcodeBuildMCP workspace build caches.
#
# XcodeBuildMCP stores a ~3-6 GB build cache per workspace under
#   ~/Library/Developer/XcodeBuildMCP/workspaces/<worktree-basename>-<hash>/
# and NEVER deletes them. Once a worktree is gone, its cache is a pure orphan.
# This finds caches whose worktree no longer exists and removes them.
#
# Usage:
#   prune-mcp-orphans.sh [repo-path ...]            # DRY RUN (default) — lists keep/delete
#   prune-mcp-orphans.sh --delete [repo-path ...]   # actually delete the orphans
#
# The keep-set is built from the LIVE worktrees of the repo paths you pass
# (default: current dir). A workspace is KEEP if its name matches a live
# worktree basename; everything else is an ORPHAN candidate.
#
# ⚠ If you work across multiple repos, PASS ALL THEIR PATHS — otherwise caches
#   from repos you didn't list will be misflagged as orphans. Always review the
#   dry-run list before re-running with --delete.

set -uo pipefail
WS="$HOME/Library/Developer/XcodeBuildMCP/workspaces"

DELETE=0
REPOS=()
for arg in "$@"; do
  case "$arg" in
    --delete) DELETE=1 ;;
    *) REPOS+=("$arg") ;;
  esac
done
[ ${#REPOS[@]} -eq 0 ] && REPOS=("$(pwd)")

[ -d "$WS" ] || { echo "No XcodeBuildMCP workspaces dir — nothing to do."; exit 0; }

# Build keep-set: basenames of every live worktree (incl. main checkout) per repo.
KEEP=()
for repo in "${REPOS[@]}"; do
  if git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    while read -r wt; do KEEP+=("$(basename "$wt")"); done \
      < <(git -C "$repo" worktree list --porcelain | awk '/^worktree /{print $2}')
  else
    echo "warning: not a git repo, ignoring: $repo" >&2
  fi
done

echo "Live worktree basenames in keep-set (${#KEEP[@]}): ${KEEP[*]}"
echo

keep_n=0; del_n=0; del_list=()
for dir in "$WS"/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  is_keep=0
  for base in "${KEEP[@]}"; do
    if [[ $name == "$base"-* || $name == "$base" ]]; then is_keep=1; break; fi
  done
  sz=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
  if [ $is_keep -eq 1 ]; then
    printf 'KEEP    %-8s %s\n' "$sz" "$name"; keep_n=$((keep_n+1))
  else
    printf 'ORPHAN  %-8s %s\n' "$sz" "$name"; del_n=$((del_n+1)); del_list+=("$dir")
  fi
done

echo
echo "Summary: $keep_n keep, $del_n orphan."
if [ "$DELETE" -eq 1 ]; then
  echo "Deleting $del_n orphan cache(s)..."
  for d in "${del_list[@]}"; do rm -rf -- "$d"; done
  echo "Done. Verify reclaimed space with: df -h /"
else
  echo "DRY RUN — nothing deleted. Review the ORPHAN list above, confirm the keep-set"
  echo "covers every repo you use, then re-run with --delete to remove them."
fi
