#!/bin/bash
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# Create ~/.claude if it doesn't exist
mkdir -p ~/.claude

# Symlink skills
if [ -L ~/.claude/skills ] || [ -e ~/.claude/skills ]; then
    echo "~/.claude/skills already exists. Remove it first if you want to reinstall."
else
    ln -sfn "$REPO_DIR/skills" ~/.claude/skills
    echo "Installed: ~/.claude/skills → $REPO_DIR/skills/"
fi

# Symlink global CLAUDE.md
if [ -L ~/.claude/CLAUDE.md ] || [ -e ~/.claude/CLAUDE.md ]; then
    echo "~/.claude/CLAUDE.md already exists. Remove it first if you want to reinstall."
else
    ln -sf "$REPO_DIR/claude-md/global.md" ~/.claude/CLAUDE.md
    echo "Installed: ~/.claude/CLAUDE.md → $REPO_DIR/claude-md/global.md"
fi
