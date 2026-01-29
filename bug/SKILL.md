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

## Workflow

### Step 1: Parse Arguments and Detect Parent Issue

**Check if first argument is a number:**
- If `$ARGUMENTS` starts with a number → use that as parent issue
- Otherwise → extract from branch name

**Extract from branch:**
```bash
BRANCH=$(git branch --show-current)
# Pattern: issue-XXX-... or issue-XXX
PARENT_ISSUE=$(echo "$BRANCH" | grep -oP 'issue-\K\d+')
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
# Try by branch pattern first
gh pr list --search "head:issue-[parent-issue]" --state open --json number,title,body

# Or by Closes reference
gh pr list --search "Closes #[parent-issue] in:body" --state open --json number,title,body
```

If parent is a sub-issue (e.g., #724), also find the grandparent tracking PR:
```bash
# Check if parent issue mentions a parent
gh issue view [parent-issue] --json body | grep -oP 'Parent issue: #\K\d+'
```

### Step 5: Create Bug Issue

```bash
gh issue create \
  --title "🐛 [Parent #XXX] Bug: [bug title]" \
  --label "bug" \
  --body "$(cat <<'EOF'
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
EOF
)"
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
