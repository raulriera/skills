#!/usr/bin/env bash
# audit-worktrees.sh — read-only audit of every git worktree's at-risk content.
#
# Remember: `git worktree remove` keeps the branch ref, and stashes are global
# to the repo, so BOTH survive removal. The only thing lost is uncommitted
# working-tree changes. This script highlights those, filtering out
# environment/disposable noise so real work stands out.
#
# Usage: audit-worktrees.sh [repo-path]   (default: current directory)
#
# Tune NOISE for your project — these are files whose changes are not "real work":
#   - local-only working docs (.claude/plans)
#   - lockfiles / tool scratch (.xcodebuildmcp, *.lock, .DS_Store)
#   - files that flip per local env (e.g. a credentials/config file committed blank, filled in locally)

set -uo pipefail
REPO="${1:-$(pwd)}"
# Extended-regex of paths whose changes are NOT real work (tune per project).
# Matched against `git status --porcelain` lines, so use no leading slash.
# Add your own env-specific files here (e.g. a local credentials/config file).
NOISE_GLOBS='\.claude/plans/|\.xcodebuildmcp/|\.DS_Store|\.lock$'

cd "$REPO" 2>/dev/null || { echo "not a directory: $REPO"; exit 1; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "not a git repo: $REPO"; exit 1; }

git fetch --quiet 2>/dev/null || true
MAIN="origin/main"
git show-ref --verify --quiet refs/remotes/origin/main || MAIN="origin/master"

echo "=== Global stashes (survive worktree removal; shown for reference) ==="
git stash list 2>/dev/null || echo "(none)"

echo
echo "=== Per-worktree audit (repo: $REPO) ==="
git worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r wt; do
  b=$(git -C "$wt" symbolic-ref --short HEAD 2>/dev/null || echo DETACHED)
  # real (non-noise) uncommitted changes
  real=$(git -C "$wt" status --porcelain 2>/dev/null | grep -Ev "$NOISE_GLOBS" || true)
  realcount=$(printf '%s' "$real" | grep -c . || true)
  ahead=$(git -C "$wt" rev-list --count "$MAIN".."$b" 2>/dev/null || echo '?')
  remote=""
  if git show-ref --verify --quiet "refs/remotes/origin/$b"; then remote="origin/$b"; fi
  if [ -n "$remote" ]; then
    unpushed=$(git -C "$wt" rev-list --count "$remote".."$b" 2>/dev/null || echo '?')
    rstate="$remote (+$unpushed unpushed)"
  else
    rstate="NO REMOTE"
  fi
  stash=$(git stash list 2>/dev/null | grep -F "$b" | head -1)

  echo
  echo "### $(basename "$wt")  [$b]"
  echo "    commits vs $MAIN: $ahead    remote: $rstate"
  [ -n "$stash" ] && echo "    stash: $stash"
  if [ "${realcount:-0}" -gt 0 ]; then
    echo "    ⚠ REAL uncommitted changes ($realcount) — at risk on removal:"
    printf '%s\n' "$real" | sed 's/^/        /'
    echo "      → to verify it's already shipped, diff working tree vs $MAIN for these files;"
    echo "        empty diff = folded in (safe); non-empty = unique work that would be lost."
  else
    echo "    clean of real work (only env/disposable noise, if any) — safe to remove"
  fi
done

echo
echo "Remove with: git worktree remove --force <path>   (force: dirty with noise files)"
echo "Then:        git worktree prune                    (clear stale metadata)"
echo "Then run prune-mcp-orphans.sh to reclaim the removed worktrees' build caches."
