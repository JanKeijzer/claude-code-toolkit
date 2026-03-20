---
name: sync-toolkit
description: Sync skills, agents, and CLAUDE.md from toolkit repositories. Pull latest, check for drift, report status.
argument-hint: <pull|status|drift>
user-invocable: true
---

# Sync Toolkit

Keep skills, agents, and global CLAUDE.md in sync across devices by pulling from configured git repositories.

## Input

Command: `$ARGUMENTS` — one of `pull`, `status`, or `drift`.

## Configuration

Reads from `~/.claude/toolkit.yaml`. If the file does not exist on first run, create a default one using the template from `install.sh`.

## Symlink Detection

Before executing any command, check if `~/.claude/skills` is a symlink:

```bash
test -L ~/.claude/skills
```

If it IS a symlink, this is a local development install (via `install.sh`). Report:

```
ℹ️  Symlink-based install detected.
   ~/.claude/skills → <resolved path>

This device has a local toolkit repo clone. To update:
  cd <toolkit-repo-path> && git pull

/sync-toolkit is designed for devices WITHOUT a local clone.
To use sync-toolkit, remove the symlinks and run /sync-toolkit pull.
```

Then stop — do not proceed with pull/drift/status on a symlink install.

## Commands

### `/sync-toolkit pull`

Delegates to the helper script:

```bash
~/.claude/bin/sync-toolkit.sh pull
```

Review the script output. Report what changed: new skills added, skills updated, skills removed.

### `/sync-toolkit status`

Delegates to the helper script:

```bash
~/.claude/bin/sync-toolkit.sh status
```

Show: configured sources, last sync time, counts per source, whether cache matches remote.

### `/sync-toolkit drift`

Delegates to the helper script:

```bash
~/.claude/bin/sync-toolkit.sh drift
```

Report: local modifications (files that differ from source), unpulled remote updates, orphan files not in any source.

## Rules

- Never auto-push to source repos.
- If a skill exists in multiple sources, last source in the list wins.
- Git credentials are handled by system SSH/git config, not this skill.
