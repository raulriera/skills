# Known disk culprits — removal commands & caveats

Read the relevant section before deleting a category. Everything here regenerates; the notes are about *how* to remove it cleanly and *what it costs* to rebuild.

## Table of contents
- [Measurement caveats (read first)](#measurement-caveats-read-first)
- [XcodeBuildMCP workspace caches](#xcodebuildmcp-workspace-caches)
- [Xcode DerivedData](#xcode-deriveddata)
- [XCTestDevices (test-sim clones)](#xctestdevices-test-sim-clones)
- [Simulator runtimes](#simulator-runtimes)
- [iOS DeviceSupport](#ios-devicesupport)
- [Git worktrees](#git-worktrees)
- [Smaller / situational](#smaller--situational)

## Measurement caveats (read first)

- **`df` is truth, `du` runs high.** APFS clones share blocks; `du` counts shared blocks against every clone, so a directory can `du` at 50 GB while only ~10 GB is uniquely reclaimable. Report reclaimed space as the `df -h /` free-space delta, not the `du` change.
- **The Storage pane lags.** macOS Settings → General → Storage recalculates "System Data" lazily (minutes). After a delete it may still show the old number; don't chase it — re-check `df`.
- **"System Data" is everything uncategorized.** `/Library/Developer/...` lives outside your home folder, so it never shows under the "Developer" category — it lands in System Data. That's why a 60 GB simulator-runtime folder looks like mystery "System Data."
- **Branches and stashes survive `git worktree remove`.** Only uncommitted working-tree changes are at risk. See [Git worktrees](#git-worktrees).

## XcodeBuildMCP workspace caches

**Path:** `~/Library/Developer/XcodeBuildMCP/workspaces/<worktree-basename>-<hash>/`
**Why it's big:** XcodeBuildMCP builds each workspace into its own cache (~3–6 GB) and never garbage-collects. Every worktree ever built leaves a cache behind, even after the worktree is deleted. Frequently the largest single consumer on a worktree-heavy Mac.
**Remove:** `scripts/prune-mcp-orphans.sh` (dry-run by default; `--delete` to act). Keeps caches for live worktrees, deletes orphans.
**Cost to rebuild:** next build in that workspace is a clean build (one-time).
**Pairing:** always run this *after* removing worktrees — the removal is what orphans the caches.

## Xcode DerivedData

**Path:** `~/Library/Developer/Xcode/DerivedData`
**Remove:** `rm -rf ~/Library/Developer/Xcode/DerivedData/*`
**Cost:** next build of each project is a clean build. Safe to do with Xcode open (it repopulates). This is the most universally safe large reclaim.

## XCTestDevices (test-sim clones)

**Path:** `~/Library/Developer/XCTestDevices`
**Why:** `xcodebuild test` spawns ephemeral simulator clones here; they accumulate, especially with parallel/cloned test runs.
**Remove:** `rm -rf ~/Library/Developer/XCTestDevices/*` (when no test run is active).
**Cost:** recreated on the next test run.

## Simulator runtimes

**Path:** `/Library/Developer/CoreSimulator` (system-wide; the `Volumes/`, `Caches/`, and `Cryptex/` subdirs hold the runtime images + their expanded patchable volumes).
**Never `rm` these** — they're mounted volumes with a registry. Use `simctl`:

```bash
xcrun simctl runtime list -v          # inventory: ids, sizes, last-used, "Deletable: YES"
xcrun simctl list devices booted      # don't delete a runtime a booted sim is on
xcrun simctl runtime delete <id>      # unmounts + removes image, volume, caches together
xcrun simctl delete unavailable       # clean devices tied to deleted runtimes
```

**What to keep:** the latest of each major version you target. Drop redundant point releases (keep the newest of a major version, delete the superseded one) and OS versions you don't actually test (you may still *build* for an older min-deployment without needing its *simulator runtime*).
**Cost:** Xcode re-downloads a runtime on demand (several GB download). Fully reversible.
**Note:** deletion finalizes asynchronously — the runtime shows `(Deleting)` briefly. Real reclaim ≈ the runtime's image size; `du` on `Volumes/` overstates it because of APFS sharing with the read-only system volume.

## iOS DeviceSupport

**Path:** `~/Library/Developer/Xcode/iOS DeviceSupport/<version>` (also `watchOS`/`tvOS DeviceSupport`)
**Why:** Xcode caches symbol files per physical device OS version you've debugged. Old versions linger.
**Remove:** delete subfolders for OS versions you no longer debug on device.
**Cost:** re-fetched (slowly) the next time you attach a device on that OS.

## Git worktrees

**The reframe:** `git worktree remove` deletes only the working-tree checkout. The **branch ref stays** in the repo, and **stashes are global** to the repo — both survive. So the only thing you can lose is **uncommitted working-tree changes**.

**Audit:** `scripts/audit-worktrees.sh [repo]` — shows real (non-noise) uncommitted changes, branch-vs-main/remote status, and stash associations.

**Noise vs signal when judging "is there work here":**
- Noise (ignore): lockfiles, `.xcodebuildmcp/`, `.DS_Store`, local-only `.claude/plans/*.md`, and per-project env-flipping files (e.g. a credentials/config file committed blank and filled in locally).
- Signal: modified/new source, tests, scripts.

**Verify "already merged" before discarding uncommitted work.** "N commits ahead of main" says nothing about whether the *uncommitted* edits are saved elsewhere. Diff the working tree against `origin/main` (and the integration branch) for the changed files: empty diff → folded in (safe); non-empty → unique edits that removal will destroy (e.g. a regression test on no branch). Surface that, don't assume.

**Remove:**
```bash
git worktree remove --force <path>   # --force: worktrees are usually dirty with noise files
git worktree prune                   # clear stale admin entries
rm -rf <orphan-dir>                  # any dir in the worktrees folder git no longer tracks
```
Branches are kept by default — that's intentional; pruning branches frees almost nothing and risks losing refs. Only delete branches that are fully merged/pushed, and only if explicitly asked.

## Smaller / situational

- **Time Machine local snapshots:** `tmutil listlocalsnapshots /` — purgeable, can be large. Thin via `tmutil deletelocalsnapshots <date>` if present. Often empty on dev Macs; check before blaming.
- **CoreDevice prep images:** `~/Library/Containers/com.apple.CoreDevice.CoreDeviceService` — device-prep images; regenerate.
- **Caches:** `~/Library/Caches/*` (swiftpm, Homebrew → `brew cleanup`, node-gyp, etc.). Individually small; collectively a few GB.
- **Swap / sleepimage:** `/private/var/vm` — system-managed; needs sudo and disables safe-sleep. Usually not worth it.
- **App data masquerading as System Data:** large `~/Library/Application Support/<app>` folders (chat history, model caches). Not disposable — that's user data. Flag it, let the user decide; never auto-delete.
