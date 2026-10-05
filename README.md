# skills

Personal [Claude](https://claude.com/claude-code) skills.

Each top-level directory is a self-contained skill (a `SKILL.md` plus any bundled `scripts/` and `references/`).

## Install

This repo is a Claude Code plugin marketplace. Add it once, then install the `skills` plugin, which bundles every skill below:

```bash
claude plugin marketplace add raulriera/skills
claude plugin install skills@raulriera
```

Or from inside a session: `/plugin marketplace add raulriera/skills`, then `/plugin install skills@raulriera`.

Skills are namespaced under the plugin, so `reflect` runs as `/skills:reflect`. To pick up new and updated skills, run `claude plugin marketplace update raulriera`, then `claude plugin update skills@raulriera`.

To use a single skill without the plugin, symlink it into your personal skills directory instead:

```bash
ln -s "$PWD/<skill-name>" ~/.claude/skills/<skill-name>
```

## Adding a skill

Create a top-level directory containing a `SKILL.md` and add a row to the table below. The plugin scans the repo root for skill folders (see [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json)), so the manifest doesn't need editing. Run `claude plugin validate .` before pushing.

## Skills

| Skill | What it does |
|-------|--------------|
| [`logging-best-practices`](logging-best-practices) | The call-site contract for Swift logging with [Logbook](https://github.com/raulriera/Logbook) — constant messages, metadata keys that name their value so redaction can match them, level semantics, bootstrap/flush wiring, and keeping log files out of tests. |
| [`reclaim-dev-disk-space`](reclaim-dev-disk-space) | Diagnose and safely reclaim disk space on a macOS dev machine (the XcodeBuildMCP cache leak, DerivedData, simulator runtimes) and audit/remove git worktrees — investigate → tiered approval → dry-run → verify, so nothing irreplaceable is deleted. |
| [`reflect`](reflect) | `/reflect <topic>` — write a blameless reflection about a situation that went off track this session into `.claude/reflections/`, so the same mistake isn't repeated. |
