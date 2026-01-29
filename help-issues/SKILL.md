---
name: help-issues
description: Show quick reference for issue management skills
user-invocable: true
---

# Help Issues Skill

Show the documentation for issue management skills.

## Behavior

When invoked, display the following quick reference:

---

## Issue Management Skills - Quick Reference

| Skill | Syntax | When to Use |
|-------|--------|-------------|
| `/decompose` | `/decompose <issue>` | Start: break down large issue |
| `/extend` | `/extend <issue>` | Later: add more sub-issues |
| `/bug` | `/bug "<title>"` | Bug found during work |
| `/update-tracking` | `/update-tracking <pr>` | Update status table |
| `/sync-closes` | `/sync-closes <pr>` | Sync Closes statements |

---

## Workflow

```
/decompose 723     →  Draft PR + sub-issues
      ↓
   (work)          →  /bug "title" if needed
      ↓
/update-tracking   →  Update status
      ↓
/extend 723        →  More sub-issues (optional)
      ↓
/sync-closes       →  Ensure all Closes #
      ↓
   Merge           →  Auto-close all issues
```

---

## Examples

```bash
# Break down new large issue
/decompose 723

# Report bug (parent from branch)
/bug "Webhook fails in test mode"

# Report bug (explicit parent)
/bug 724 "Webhook fails in test mode"

# Update tracking PR
/update-tracking 727

# Add more sub-issues
/extend 723

# Sync Closes statements
/sync-closes 727
```

---

## Status Indicators

| Emoji | Meaning |
|-------|---------|
| ⏳ | Pending |
| 🔄 | In Progress |
| ✅ | Complete |
| ❌ | Blocked |
| 🐛 | Bug |

---

**Full documentation:** `~/.claude/skills/README.md`
