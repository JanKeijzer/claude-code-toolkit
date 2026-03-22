---
name: extend
description: Add more sub-issues to an existing tracking PR for a parent issue
argument-hint: <parent-issue> | add #issue [#issue...] [to #parent]
user-invocable: true
---

# Extend Decomposition Skill

Add more sub-issues to an existing parent issue that already has a tracking PR.

Use this when you've implemented the first batch of sub-issues and want to decompose the next phase.

## Input

The user provides: `$ARGUMENTS`

**Two modes of operation:**

### Mode 1: Add existing issues to tracking PR (NEW)
- `add #<issue> [#<issue>...] [to #<parent>]`

**Examples:**
```bash
/extend add #1042              # Add issue #1042, parent auto-detected from branch
/extend add #1042 to #723     # Add issue #1042 to epic #723
/extend add #1042 #1043 #1044 to #723  # Add multiple issues at once
```

### Mode 2: Decompose new sub-issues (original behavior)
- `<parent-issue>` - The parent issue number (e.g., `723`)
- No argument - Auto-detect from current branch

**Examples:**
```bash
/extend 723        # Extend decomposition of #723
/extend            # Detect parent from branch (issue-723-...)
```

**Disambiguation:** If `$ARGUMENTS` starts with `add` → Mode 1. Otherwise → Mode 2.

## Workflow

### Mode 1: Add Existing Issues

Use this when you have already-created issues that need to be linked to an epic's tracking PR.

#### Step A1: Parse Arguments

Extract from `$ARGUMENTS` (after stripping the `add` keyword):
- **Issue numbers**: all `#<number>` tokens before the `to` keyword (strip the `#` prefix)
- **Parent issue**: the `#<number>` after `to`, or auto-detect from branch if no `to` keyword

```bash
# Auto-detect parent from branch if needed
PARENT_ISSUE=$(~/.claude/bin/extract-issue-from-branch.sh)
```

If no parent found and no `to #<parent>` given: ask the user to provide one explicitly.

#### Step A2: Find Tracking PR

```bash
~/.claude/bin/find-tracking-pr.sh <repo> $PARENT_ISSUE
```

**If no tracking PR exists:** Inform the user and suggest using `/decompose` first.

Read the tracking PR body to understand the current Closes statements and tracking table.

#### Step A3: Fetch Issue Details

Fetch details for all issues to be added:
```bash
~/.claude/bin/batch-issue-view.sh <repo> [issue-numbers...]
```

Use the Read tool to read the output. For each issue, extract: number, title, state, labels.

#### Step A4: Update Tracking PR

**4a. Add Closes statements** for each new issue (append after existing Closes lines):
```markdown
Closes #[existing-issues]
Closes #1042  ← NEW
Closes #1043  ← NEW
```

**4b. Add rows to tracking table** for each new issue:
```markdown
| # | Sub-Issue | Status | PR |
|---|-----------|--------|-----|
| ... existing entries ... |
| N | #1042 - [Issue title] | ⏳ Pending | - |   ← NEW
| N+1 | #1043 - [Issue title] | ⏳ Pending | - | ← NEW
```

Map issue state to status: OPEN → ⏳ Pending, CLOSED → ✅ Complete.

**4c. Update progress line** to reflect the new total.

#### Step A5: Link as Native GitHub Sub-Issues

Link the added issues to the parent issue using the GitHub GraphQL API:

1. Fetch the node IDs for parent and all sub-issues in one query:
```bash
gh api graphql -f query='
{
  repository(owner: "OWNER", name: "REPO") {
    parent: issue(number: [parent-number]) { id }
    sub1: issue(number: [sub-number-1]) { id }
    sub2: issue(number: [sub-number-2]) { id }
    ...
  }
}'
```

2. Link each sub-issue to the parent:
```bash
gh api graphql -f query='
mutation {
  addSubIssue(input: {issueId: "[parent-node-id]", subIssueId: "[sub-node-id]"}) {
    issue { number }
    subIssue { number }
  }
}'
```

**Do this for ALL added issues.** This enables GitHub's native sub-issue tracking in the UI.

#### Step A6: Show Summary

```markdown
## Issues Added to Epic

✅ Added #1042 - [title] to tracking PR #[pr-number]
✅ Added #1043 - [title] to tracking PR #[pr-number]
✅ Closes statements updated
✅ Progress: X of Y sub-issues complete (Z%)

### Quick Links
- Tracking PR: #[pr-number]
- Parent issue: #[parent-issue]
```

---

### Mode 2: Decompose New Sub-Issues (Original)

### Step 1: Identify Parent Issue

```bash
# If argument provided
PARENT_ISSUE=$ARGUMENTS

# Otherwise, detect from branch
PARENT_ISSUE=$(~/.claude/bin/extract-issue-from-branch.sh)
```

### Step 2: Fetch Parent Issue

```bash
~/.claude/bin/gh-save.sh /tmp/issue-$PARENT_ISSUE.json issue view $PARENT_ISSUE --json number,title,body,labels
```

Use the Read tool to read `/tmp/issue-$PARENT_ISSUE.json`. Parse the issue body to identify:
- All phases/sections/tasks defined
- Checklists with `- [ ]` items
- Numbered implementation steps

### Step 3: Find Existing Tracking PR

```bash
~/.claude/bin/find-tracking-pr.sh <repo> $PARENT_ISSUE
```

**If no tracking PR exists (script exits 1):** Suggest using `/decompose` instead.

### Step 4: Analyze Current State

**From tracking PR, extract existing sub-issue numbers, then fetch their current status in one batch:**
```bash
~/.claude/bin/batch-issue-status.sh <repo> [sub-issue-numbers...]
```

**From those results, determine:**
- Their status (✅ complete, 🔄 in progress, ⏳ pending)
- Closes statements already present

**From parent issue body, extract:**
- All defined phases/tasks
- Which ones are NOT yet covered by sub-issues

### Step 5: Show Current State & Propose New Sub-Issues

```markdown
## Extend Decomposition - #[parent-issue]

### Current Progress
Tracking PR: #[pr-number]
Existing sub-issues: [N]

| # | Existing Sub-Issue | Status |
|---|-------------------|--------|
| 1 | #724 - Phase 1: Foundation | ✅ Complete |
| 2 | #725 - Phase 2: Core feature | ✅ Complete |
| 3 | #726 - Phase 3: Webhooks | 🔄 In Progress |

### Remaining Tasks (from parent issue)
These tasks don't have sub-issues yet:

- [ ] Phase 4: Frontend updates
- [ ] Phase 5: Testing & documentation
- [ ] Phase 6: Deployment

### Proposed New Sub-Issues

| # | New Sub-Issue Title | Scope |
|---|---------------------|-------|
| 4 | Phase 4: Frontend Stripe integration | Frontend |
| 5 | Phase 5: Test suite & documentation | Testing |
| 6 | Phase 6: Deployment & monitoring | DevOps |

Create these sub-issues?
- **A)** Create all proposed sub-issues
- **B)** Select which ones to create
- **C)** Modify the breakdown first
- **D)** Cancel
```

### Step 6: Create New Sub-Issues

For each confirmed sub-issue, first write the body using the Write tool to `/tmp/sub-issue-<n>.md`:
```markdown
## Parent Issue
Part of #[parent-issue] ([parent title])

## Scope
[What this sub-issue covers]

## Tasks
- [ ] Task 1
- [ ] Task 2

## Dependencies
- Requires: #[previous-sub-issues] to be complete
- Blocks: [next phases if any]

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
```

Then create the issue:
```bash
gh issue create --title "[Parent #$PARENT_ISSUE] [Sub-issue title]" --body-file /tmp/sub-issue-<n>.md
```

### Step 6b: Link as Native GitHub Sub-Issues

After creating all sub-issues, link them to the parent issue using the GitHub GraphQL API:

1. Fetch the node IDs for parent and all new sub-issues in one query:
```bash
gh api graphql -f query='
{
  repository(owner: "OWNER", name: "REPO") {
    parent: issue(number: [parent-number]) { id }
    sub1: issue(number: [sub-number-1]) { id }
    sub2: issue(number: [sub-number-2]) { id }
    ...
  }
}'
```

2. Link each sub-issue to the parent:
```bash
gh api graphql -f query='
mutation {
  addSubIssue(input: {issueId: "[parent-node-id]", subIssueId: "[sub-node-id]"}) {
    issue { number }
    subIssue { number }
  }
}'
```

**Do this for ALL created sub-issues.** This enables GitHub's native sub-issue tracking in the UI.

### Step 7: Update Tracking PR

**7a. Add new Closes statements:**
```markdown
Closes #723
Closes #724
Closes #725
Closes #726
Closes #727  ← NEW
Closes #728  ← NEW
Closes #729  ← NEW
```

**7b. Add to tracking table:**
```markdown
| # | Sub-Issue | Status | PR |
|---|-----------|--------|-----|
| 1 | #724 - Phase 1: Foundation | ✅ Complete | PR #730 |
| 2 | #725 - Phase 2: Core feature | ✅ Complete | PR #731 |
| 3 | #726 - Phase 3: Webhooks | 🔄 In Progress | PR #732 |
| 4 | #727 - Phase 4: Frontend | ⏳ Pending | - |      ← NEW
| 5 | #728 - Phase 5: Testing | ⏳ Pending | - |       ← NEW
| 6 | #729 - Phase 6: Deployment | ⏳ Pending | - |    ← NEW
```

**7c. Update progress:**
```markdown
**Progress:** 2 of 6 sub-issues complete (33%)
```

### Step 8: Show Summary

```markdown
## Extension Complete

✅ Created 3 new sub-issues: #727, #728, #729
✅ Updated tracking PR #[pr-number]
✅ All 6 sub-issues will auto-close on merge

### Next Steps
- Continue working on #726
- When ready, start #727 with: `git checkout -b issue-727-frontend`
```

## Difference from /decompose

| Aspect | /decompose | /extend |
|--------|-----------|---------|
| When to use | Start of large issue | After first batch done |
| Creates PR | Yes (draft) | No (updates existing) |
| Analyzes | Full issue | Remaining tasks only |
| Sub-issues | Initial set | Additional set |

