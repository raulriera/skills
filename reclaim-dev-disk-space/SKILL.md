---
name: reclaim-dev-disk-space
description: Diagnose and safely reclaim disk space on a macOS developer machine, and audit/remove git worktrees. Use whenever the user is low on disk, asks what's eating their storage or "System Data", wants to free up / recover space, mentions a huge System Data, Xcode, DerivedData, or simulator footprint, or wants to clean up, prune, or remove git worktrees. Also use proactively right after deleting git worktrees — their XcodeBuildMCP build caches are orphaned and must be pruned separately, and that orphaned cache is frequently the single largest consumer on a dev Mac. Drives an investigate → tiered-approval → dry-run → verify workflow so nothing irreplaceable is deleted.
license: MIT
metadata:
  author: Raul Riera
  version: "1.0"
---

# Reclaim Dev Disk Space

A playbook for recovering disk on a macOS developer machine without losing anything that matters. Two intertwined jobs:

1. **Find and clear disposable build artifacts** — the giants are almost always Xcode/simulator/MCP caches, not user data. They all regenerate.
2. **Audit and remove stale git worktrees** — and prune the per-worktree build caches they leave behind.

These are linked: most build-cache tools key their caches by worktree, so deleting worktrees without pruning their caches leaves orphaned gigabytes behind. The biggest single win on a heavily-worktree'd Mac is usually the orphaned **XcodeBuildMCP** caches (see Phase 2).

## The one idea that makes this safe

**Almost everything you'll delete regenerates.** DerivedData rebuilds, simulator runtimes re-download, build caches repopulate on the next build. So the danger isn't deleting disposable artifacts — it's accidentally deleting the one thing that *was* irreplaceable. Two facts keep you out of trouble:

- **`git worktree remove` keeps the branch ref.** Removing a worktree only deletes its working-tree checkout, never its commits. The branch survives in the repo and can be checked out again. **Stashes are global to the repo too**, so they also survive. That means the *only* thing lost when you remove a worktree is its **uncommitted working-tree changes** — modified/untracked files that were never committed. Audit for those; ignore the rest.
- **`df` is the truth; `du` and the Storage pane lie (differently).** `du` overcounts APFS-cloned/shared blocks, so a folder can `du` at 50 GB while only ~11 GB is uniquely reclaimable. macOS Settings → Storage recalculates "System Data" *lazily* — it can lag for minutes after a delete. Trust `df -h /` free space measured before and after as the real scorecard.

## Working doctrine

Run the same loop every time. It's slower than `rm -rf`-ing things, but it's why you never lose work:

1. **Investigate before touching anything** (`scripts/scan-disk.sh`). Know where the bytes are.
2. **Present findings in tiers**, with a size and a one-line "what regenerates / what's at risk" for each. Recommend the safe-and-large tier.
3. **Get explicit approval per tier.** Never escalate aggressiveness on your own — the user decides how far to go. Deleting a simulator runtime they test against, or a worktree's uncommitted fix, is a real cost only they can price.
4. **Dry-run any destructive match first.** Before deleting N matched folders, print the keep/delete split and confirm the counts look right. A bad glob is how you delete the wrong thing.
5. **Execute, then verify** with `df -h /` before/after. Report real reclaimed space, not the `du` delta.

If a destructive step errors or the numbers look wrong, **stop and report** — don't keep running diagnostics or retry blindly.

## Phase 1 — Investigate

Run `scripts/scan-disk.sh`. It's read-only and surfaces every known giant: free space, Time Machine local snapshots, the top `~/Library` consumers, the full `~/Library/Developer` breakdown, the XcodeBuildMCP workspace cache (total, folder count, biggest), the system-wide simulator runtimes in `/Library/Developer/CoreSimulator`, and the installed simulator runtimes via `simctl`.

What you're triaging toward — on a dev Mac, "System Data" is a catch-all and the bulk of it is almost always one of these:

- `~/Library/Developer/XcodeBuildMCP/workspaces` — per-workspace build caches, **never garbage-collected** (the usual #1; see Phase 2)
- `~/Library/Developer/Xcode/DerivedData` — Xcode build cache
- `/Library/Developer/CoreSimulator` — system-wide simulator runtimes + their expanded volumes (counts as System Data because it's in `/Library`, not your home folder, so it never shows under the "Developer" category)
- `~/Library/Developer/XCTestDevices` — ephemeral test-sim clones that pile up
- `~/Library/Developer/Xcode/iOS DeviceSupport` — symbol caches per physical device/OS

Always check `tmutil listlocalsnapshots /` early — Time Machine local snapshots can silently eat tens of GB and are purgeable. (On a Mac with snapshots disabled this is empty; don't assume it's the culprit without looking.)

## Phase 2 — The usual culprits

Full removal commands and caveats live in `references/known-culprits.md`. Read it before deleting any specific category. The headline items:

| What | Where | Regenerates? | How to remove |
|------|-------|--------------|---------------|
| **XcodeBuildMCP workspace caches** | `~/Library/Developer/XcodeBuildMCP/workspaces/<worktree>-<hash>/` | Yes (next build) | `scripts/prune-mcp-orphans.sh` — keeps live worktrees, deletes the rest |
| Xcode DerivedData | `~/Library/Developer/Xcode/DerivedData` | Yes (next build) | `rm -rf .../DerivedData/*` |
| Stale test-sim clones | `~/Library/Developer/XCTestDevices` | Yes (next test run) | `rm -rf .../XCTestDevices/*` |
| Simulator runtimes | `/Library/Developer/CoreSimulator` | Yes (re-download) | `xcrun simctl runtime delete <id>` — **never `rm`** |
| iOS DeviceSupport | `~/Library/Developer/Xcode/iOS DeviceSupport` | Yes (on device attach) | delete subfolders for OS versions you no longer debug |

**The XcodeBuildMCP leak — understand this one.** XcodeBuildMCP creates a separate build cache (~3–6 GB) for every workspace it has ever built, named `<worktree-basename>-<hash>`, under `~/Library/Developer/XcodeBuildMCP/workspaces/`. It **never deletes them**, even when the worktree is long gone. So every worktree you've ever built leaves multiple GB behind permanently. On a Mac that churns through feature worktrees this directory grows without bound and is routinely the largest single thing on disk — it can reach 100+ GB across dozens of stale workspaces while only a handful map to live worktrees. **This is why pruning must follow worktree deletion** — see Phase 4.

**Simulator runtimes need `simctl`, not `rm`.** They're mounted APFS volumes with caches and registrations; `rm` corrupts the registry. Use `xcrun simctl runtime delete <identifier>`, which unmounts and removes the image, its expanded volume, and its caches together. Check nothing is booted on a runtime first, and prefer deleting redundant point releases (keep the newest of a major version, drop the superseded one) and OS versions you don't actually test. Deletion is reversible — Xcode re-downloads on demand.

## Phase 3 — Git worktree audit & safe removal

Run `scripts/audit-worktrees.sh` from inside the repo. For each worktree it reports the branch, **real** uncommitted changes (filtering out environment noise — see below), how it sits versus `origin/main` and its own remote, and whether a stash references it.

Decide what's safe to remove using the reframe from the top: branches and stashes survive `git worktree remove`, so you only need to rescue **uncommitted working-tree changes**. When triaging those, separate signal from noise:

- **Noise (ignore — disposable or environment-specific):** lockfiles, `.xcodebuildmcp/`, `.DS_Store`, local-only `.claude/plans/*.md` working docs, and per-project files that flip per local environment (e.g. a credentials/config file that's committed blank but filled in locally). The audit script excludes a configurable list; tune it per project.
- **Signal (real work at risk):** modified or new source files, tests, scripts. If a worktree has these and you're about to remove it, decide deliberately: commit them onto the (kept) branch, stash, or discard.

**Verify "it's already merged / folded in" claims — don't take them on faith.** A branch being "N commits ahead of main" doesn't mean its *uncommitted* edits are saved anywhere. Before discarding a worktree's uncommitted changes on the belief that the work already shipped, diff the working tree against `origin/main` (and the integration branch) for the changed files. If the diff is empty, it's genuinely folded in and safe. If it isn't, the edits are unique and would be lost — surface that explicitly, especially for things like a regression test that exists on no branch.

Remove with `git worktree remove --force <path>` (force is needed because these worktrees are usually "dirty" with the noise files above). Then `git worktree prune` to clear stale metadata, and `rm -rf` any orphan directory left in the worktrees folder that `git worktree list` doesn't know about.

## Phase 4 — Execute in tiers, with the worktree↔cache link

Order matters: **prune worktrees first, then prune their orphaned build caches**, because the worktree deletion is what *creates* the orphans.

1. **Remove stale worktrees** (Phase 3). Keep all branches.
2. **Prune orphaned XcodeBuildMCP caches** — `scripts/prune-mcp-orphans.sh`. It builds the keep-set from your live worktrees (pass every active repo path you use) and flags the rest. **It dry-runs by default**; review the keep/delete split, then re-run with `--delete`. This is typically the single largest reclaim.
3. **Clear pure build caches** — DerivedData, XCTestDevices (Tier 1: big, zero-risk, all regenerate).
4. **Thin simulator runtimes / DeviceSupport** (Tier 2: smaller, mild re-download cost) — only with explicit approval on which OS versions to keep.

Present these as tiers with sizes and let the user pick the depth. Don't bundle a runtime deletion into a "clear caches" approval — they have different costs.

## Phase 5 — Verify and record

- Re-measure with `df -h /`. Report reclaimed space as the **free-space delta**, and note that the Storage pane's "System Data" figure will catch up lazily.
- Be honest about what remains. After the leak is cleared, what's left (active runtimes you use, current worktrees' caches, app data) is usually *legitimate*; chasing the last few GB is diminishing returns. Say so rather than over-promising.
- If this machine has a recurring pattern (e.g. the MCP cache regrows as worktrees churn), note that re-running the prune reclaims it anytime — consider recording the culprit in project/personal memory so it isn't re-investigated from scratch.

## Scripts

All scripts are safe to run as-is. The two destructive ones default to dry-run.

- `scripts/scan-disk.sh` — read-only investigation. Run first.
- `scripts/audit-worktrees.sh [repo-path]` — read-only per-worktree at-risk audit.
- `scripts/prune-mcp-orphans.sh [--delete] [repo-path...]` — list (default) or delete orphaned XcodeBuildMCP workspace caches. Pass all your active repo paths so live worktrees aren't misflagged.

## Reference

- `references/known-culprits.md` — per-category removal commands, the APFS/`du` caveats, and the simctl runtime workflow in detail. Read before deleting a specific category.
