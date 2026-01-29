---
name: decompose
description: Decompose a large GitHub issue into sub-issues and create a tracking draft PR
argument-hint: <issue-number>
user-invocable: true
---

# Issue Decomposition Skill

Help the user break down a large GitHub issue into manageable sub-issues, tracked via a draft PR.

## Input

The user provides an issue number: `$ARGUMENTS`

## Workflow

### Step 1: Fetch and Analyze the Issue

```bash
gh issue view $ARGUMENTS --json title,body,labels,milestone
```

Analyze the issue body to identify:
- **Phases/Sections**: Look for headers, checklists, numbered lists
- **Dependencies**: Which tasks must complete before others
- **Logical groupings**: Backend vs frontend, foundation vs features

### Step 2: Propose Sub-Issue Breakdown

Present a table to the user:

```markdown
## Proposed Sub-Issues for #[issue-number]

| # | Sub-Issue Title | Depends On | Scope |
|---|-----------------|------------|-------|
| 1 | Phase 1: [Foundation/Setup] | - | Backend/Frontend/Both |
| 2 | Phase 2: [Core Feature] | #1 | ... |
| 3 | Phase 3: [Integration] | #1, #2 | ... |
| ... | ... | ... | ... |

Does this breakdown look correct? I can:
- **A)** Create these sub-issues now
- **B)** Adjust the breakdown first
- **C)** Just create the draft PR template (no sub-issues yet)
```

### Step 3: Create Branch (if needed)

Check if branch exists:
```bash
git fetch origin
git branch -a | grep "issue-$ARGUMENTS" || echo "Branch does not exist"
```

If no branch exists, ask if user wants to create it:
```bash
git checkout -b issue-$ARGUMENTS-[feature-name]
```

### Step 4: Create Draft PR

Use this template structure:

```markdown
Closes #[issue-number]

This PR tracks the complete [feature name] implementation across all sub-issues.

---

## Parent Issue Progress

[Brief description of what this implements]

### Sub-Issues

| # | Sub-Issue | Status | PR |
|---|-----------|--------|-----|
| 1 | #XXX - [Title] | ⏳ Pending | - |
| 2 | #XXX - [Title] | ⏳ Pending | - |
| ... | ... | ... | ... |

**Progress:** 0 of N sub-issues complete (0%)

---

## Branch Structure
```
develop
  ↑
issue-[number]-[feature] (this PR)
  ↑
(sub-branches will be added as work progresses)
```

---

## Implementation Phases

### Phase 1: [Name]
- [ ] Task 1
- [ ] Task 2

### Phase 2: [Name]
- [ ] Task 3
- [ ] Task 4

---

## Related Issues
- [List any related/blocking issues]

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

### Step 5: Create Sub-Issues (if user confirms)

For each sub-issue:
```bash
gh issue create --title "[Parent #] Sub-issue: [Title]" --body "$(cat <<'EOF'
Parent issue: #[parent-number]

## Scope
[What this sub-issue covers]

## Tasks
- [ ] Task 1
- [ ] Task 2

## Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2

## Dependencies
- Blocked by: [list or "None"]
- Blocks: [list or "None"]
EOF
)"
```

### Step 6: Update Parent Issue

Add a tracking section to the parent issue:
```bash
gh issue edit $ARGUMENTS --body "$(original body + sub-issue tracking table)"
```

## Important Notes

1. **Always ask before creating**: Never create issues/PRs without user confirmation
2. **Preserve original content**: When editing issues, preserve all original content
3. **Use consistent naming**: `issue-[number]-[feature-name]` for branches
4. **Link everything**: Sub-issues reference parent, PR references all issues
5. **Status emojis**: ⏳ Pending, 🔄 In Progress, ✅ Complete, ❌ Blocked

## Example Usage

```
/decompose 723
```

This will:
1. Fetch issue #723
2. Analyze and propose sub-issues
3. Ask user for confirmation
4. Create draft PR and optionally sub-issues
5. Update parent issue with tracking table
