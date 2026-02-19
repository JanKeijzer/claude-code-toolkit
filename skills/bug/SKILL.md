---
name: bug
description: Create a bug sub-issue and add it to the tracking PR
argument-hint: "<bug title>" or <parent-issue> "<bug title>"
user-invocable: true
---

# Bug Sub-Issue Skill

Create a bug issue linked to a parent issue and automatically add it to the tracking PR.

## Input

The user provides: `$ARGUMENTS`

**Default behavior:** Extract parent issue from current branch name.

**Format options:**
- `"<bug title>"` - Auto-detect parent from branch (DEFAULT)
- `<parent-issue> "<bug title>"` - Explicit parent override

**Examples:**
```bash
/bug "Webhook signature fails in test mode"        # Parent from branch
/bug 724 "Webhook signature fails in test mode"   # Explicit parent #724
```

## Tool Rules

- Use Glob to find files — NEVER use `find` or `ls` via Bash
- Use Grep to search file contents — NEVER use `grep` or `rg` via Bash
- Use Read to read files — NEVER use `cat`, `head`, or `tail` via Bash
- Bash is for `gh` commands, `git` commands, and `~/.claude/bin/` scripts only
- NEVER use heredoc or `cat <<` in Bash — use the Write tool to write to `/tmp/`, then reference the file with `--body-file`
- Use Write to create new files — NEVER use `mkdir` via Bash (Write auto-creates parent directories)
- For batch operations on multiple issues, use `~/.claude/bin/` scripts (e.g., `batch-issue-status.sh`, `batch-issue-view.sh`) — NEVER use `for` loops in Bash

## Workflow

### Step 1: Parse Arguments and Detect Parent Issue

**Check if first argument is a number:**
- If `$ARGUMENTS` starts with a number → use that as parent issue
- Otherwise → extract from branch name

**Extract from branch:**
```bash
PARENT_ISSUE=$(~/.claude/bin/extract-issue-from-branch.sh)
```

**Example branch names:**
- `issue-724-stripe-webhook` → parent = 724
- `issue-723-stripe-payment-provider` → parent = 723

**If no parent found:** Ask the user to provide one explicitly.

### Step 2: Extract Bug Title

After determining parent issue, the rest of `$ARGUMENTS` is the bug title.

Parse:
- `/bug "Webhook fails"` → parent=from branch, title="Webhook fails"
- `/bug 724 "Webhook fails"` → parent=724, title="Webhook fails"

### Step 3: Get Parent Issue Info

```bash
gh issue view [parent-issue] --json number,title,labels
```

### Step 4: Find the Tracking PR

Search for the tracking/parent PR:
```bash
~/.claude/bin/find-tracking-pr.sh <repo> [parent-issue]
```

If parent is a sub-issue (e.g., #724), also find the grandparent tracking PR:
```bash
gh issue view [parent-issue] --json body
```
Then parse the JSON output for `Parent issue: #\d+` to find the grandparent issue number.

### Step 5: Create Bug Issue

First write the body using the Write tool to `/tmp/bug-issue.md`:
```markdown
## Parent Issue
Related to #[parent-issue] ([parent title])

## Bug Description
[To be filled in]

## Steps to Reproduce
1.
2.
3.

## Expected Behavior


## Actual Behavior


## Context
- Discovered while working on: #[parent-issue]
- Branch: [current-branch]

---
_This bug blocks the completion of #[parent-issue]_
```

Then create the issue:
```bash
gh issue create --title "🐛 [Parent #XXX] Bug: [bug title]" --label "bug" --body-file /tmp/bug-issue.md
```

### Step 6: Add to Tracking PR

Update the tracking PR to include the new bug:

**6a. Add to Closes statements (at top of PR body):**
```
Closes #[parent-issue]
Closes #[other-sub-issues]
Closes #[NEW-BUG-ISSUE]  ← Add this
```

**6b. Add to tracking table:**
```markdown
| # | Sub-Issue | Status | PR |
|---|-----------|--------|-----|
| ... | existing entries ... | ... | ... |
| N | #[NEW] - 🐛 Bug: [title] | ⏳ Pending | - |
```

### Step 7: Show Summary

```markdown
## Bug Issue Created

✅ Created: #[new-issue-number] - 🐛 Bug: [title]
✅ Parent: #[parent-issue]
✅ Added to tracking PR #[pr-number]
✅ Will auto-close when PR merges to develop

### Quick Links
- Bug issue: [url]
- Parent issue: #[parent-issue]
- Tracking PR: #[pr-number]

### Next Steps
- Fix the bug in your current branch
- Or create a separate branch: `git checkout -b issue-[new-bug-number]-fix`
```

## Label Handling

Automatically add labels:
- `bug` - always
- Inherit relevant labels from parent (e.g., `payment`, `backend`)

```bash
gh issue edit [new-issue] --add-label "bug"
```

## Example Session

```
$ git branch --show-current
issue-724-stripe-webhook

$ /bug "Signature verification fails for test webhooks"

Detected parent issue: #724 (from branch: issue-724-stripe-webhook)

Creating bug issue...
✅ Created: #731 - 🐛 [Parent #724] Bug: Signature verification fails for test webhooks

Finding tracking PR...
✅ Found: PR #727 (Stripe Payment Provider)

Updating tracking PR...
✅ Added "Closes #731" to PR #727
✅ Added #731 to tracking table

Done! Bug #731 will auto-close when PR #727 merges.
```

## Notes

1. **Default = branch detection**: No number needed in most cases
2. **Always add to Closes**: The bug MUST be in Closes statements for auto-close
3. **Use bug emoji**: 🐛 in title for visibility
4. **Link bidirectionally**: Bug references parent, PR references bug
