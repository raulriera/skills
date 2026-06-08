# skills

Personal [Claude](https://claude.com/claude-code) skills.

Each top-level directory is a self-contained skill (a `SKILL.md` plus any bundled `scripts/` and `references/`).

## Install

Symlink a skill into your personal skills directory so Claude Code discovers it:

```bash
ln -s "$PWD/<skill-name>" ~/.claude/skills/<skill-name>
```

## Skills

| Skill | What it does |
|-------|--------------|
| [`reclaim-dev-disk-space`](reclaim-dev-disk-space) | Diagnose and safely reclaim disk space on a macOS dev machine (the XcodeBuildMCP cache leak, DerivedData, simulator runtimes) and audit/remove git worktrees — investigate → tiered approval → dry-run → verify, so nothing irreplaceable is deleted. |
| [`reflect`](reflect) | `/reflect <topic>` — write a blameless reflection about a situation that went off track this session into `.claude/reflections/`, so the same mistake isn't repeated. |
