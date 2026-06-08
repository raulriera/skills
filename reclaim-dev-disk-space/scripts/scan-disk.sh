#!/usr/bin/env bash
# scan-disk.sh — read-only disk investigation for a macOS developer machine.
# Surfaces the usual "System Data" giants so you know where the bytes are
# before deleting anything. Touches nothing.
#
# Usage: scan-disk.sh
#
# Note: `du` overcounts APFS-cloned/shared blocks, so its numbers run high.
# Use `df` free space (printed first/last) as the real scorecard.

set -uo pipefail
DEV="$HOME/Library/Developer"

hr() { printf '\n=== %s ===\n' "$1"; }

hr "Free space (this is the truth; du below runs high due to APFS clones)"
df -h / | awk 'NR==1 || /\/$/'

hr "Time Machine local snapshots (purgeable; can be tens of GB)"
snaps=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c 'com.apple' || true)
echo "snapshot count: ${snaps:-0}"
[ "${snaps:-0}" -gt 0 ] && tmutil listlocalsnapshots / 2>/dev/null | head -20

hr "Top ~/Library consumers (depth 1)"
du -sh "$HOME"/Library/* 2>/dev/null | sort -rh | head -12

hr "~/Library/Developer breakdown (the dev giant)"
du -sh "$DEV"/* 2>/dev/null | sort -rh

hr "Xcode subdirectories"
du -sh "$DEV"/Xcode/* 2>/dev/null | sort -rh | head -12

hr "XcodeBuildMCP workspace caches (the leak — never GC'd)"
WS="$DEV/XcodeBuildMCP/workspaces"
if [ -d "$WS" ]; then
  du -sh "$WS" 2>/dev/null
  echo "folder count: $(find "$WS" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')"
  echo "biggest folders:"
  du -sh "$WS"/* 2>/dev/null | sort -rh | head -10
else
  echo "(no XcodeBuildMCP workspaces dir — not using XcodeBuildMCP, or nothing cached)"
fi

hr "System-wide simulator runtimes (/Library — counts as System Data)"
du -sh /Library/Developer/CoreSimulator 2>/dev/null
du -sh /Library/Developer/CoreSimulator/* 2>/dev/null | sort -rh | head

hr "Installed simulator runtimes (delete redundant ones via simctl)"
xcrun simctl runtime list 2>/dev/null | grep -E 'iOS|watchOS|tvOS|visionOS|Total' || echo "(simctl unavailable)"

hr "Booted simulators (don't delete a runtime one of these is on)"
xcrun simctl list devices booted 2>/dev/null | grep -E '\(Booted\)|--' || echo "(none booted)"

hr "Container disk images (Docker / OrbStack / Colima, if any)"
for p in "$HOME/Library/Containers/com.docker.docker" "$HOME/.docker" "$HOME/.orbstack" "$HOME/.colima"; do
  [ -e "$p" ] && du -sh "$p" 2>/dev/null
done
echo "(none of the above printed = no container images)"

hr "Final free space"
df -h / | awk '/\/$/'
echo
echo "Next: review the giants above, then use audit-worktrees.sh and prune-mcp-orphans.sh."
echo "Read references/known-culprits.md before deleting any specific category."
