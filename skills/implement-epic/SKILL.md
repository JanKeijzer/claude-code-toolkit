---
name: implement-epic
description: Automatically implement all sub-issues of an epic in dependency order
argument-hint: <parent-issue>
user-invocable: true
---

# Implement Epic

Automatically implement all sub-issues of a parent epic in dependency order: branch per issue, code + tests, PR against feature branch, auto-merge, and continue to the next issue.

## Input

The user provides a parent issue number: `$ARGUMENTS`

FOLLOW ALL STEPS STRICTLY. NO SHORTCUTS. This skill runs autonomously — no confirmation stops between sub-issues.

## Tool Rules

- Use Glob to find files — NEVER use `find` or `ls` via Bash
- Use Grep to search file contents — NEVER use `grep` or `rg` via Bash
- Use Read to read files — NEVER use `cat`, `head`, or `tail` via Bash
- Bash is for `gh` commands, `git` commands, running tests, and `~/.claude/bin/` scripts only
- NEVER use heredoc or `cat <<` in Bash — use the Write tool to write to `/tmp/`, then reference the file
- For batch operations on multiple issues, use `~/.claude/bin/` scripts (e.g., `batch-issue-status.sh`, `batch-issue-view.sh`) — NEVER use `for` loops in Bash

Follow the Test Quality Policy and Anti-Patterns from CLAUDE.md throughout all phases.

## Phase 0: Setup

### Step 1: Read parent issue

```bash
gh issue view $ARGUMENTS --json title,body,labels
```

### Step 2: Parse sub-issues and implementation order

Parse the issue body for:
- **Sub-issues:** Extract issue numbers from the tracking table or checklist
- **Implementation order:** Look for explicit ordering, dependency info, or phase numbers
- **Dependencies:** Which sub-issues depend on others (from "Depends On", "Blocked by" fields)

### Step 3: Determine waves

Group sub-issues into waves based on dependencies:
- **Wave 1:** Issues with no dependencies (can be implemented first)
- **Wave 2:** Issues that only depend on wave 1 issues
- **Wave N:** Issues that only depend on issues in earlier waves

Issues within the same wave are implemented sequentially.

### Step 4: Read project context

Read all CLAUDE.md files in the project (root, frontend, backend — whatever exists) to understand:
- Tech stack and project structure
- Test commands and validation commands
- Code quality policies

### Step 5: Check/create feature branch

```bash
git fetch origin
git branch -a --list "*issue-$ARGUMENTS*"
```

If the feature branch exists, check it out. Otherwise create it:
```bash
git checkout -b issue-$ARGUMENTS-<description>
```

### Step 6: Check/create tracking PR

Find existing tracking PR:
```bash
~/.claude/bin/find-tracking-pr.sh <repo> $ARGUMENTS
```

If no tracking PR exists, create a draft PR against `develop` using the Write tool to write the body to `/tmp/tracking-pr-body.md`, then:
```bash
gh pr create --draft --title "<Epic title>" --base develop --body-file /tmp/tracking-pr-body.md
```

Store the tracking PR number for later updates.

### Step 7: Show overview and start

Display a summary of:
- Total sub-issues and wave structure
- Dependency graph
- Feature branch and tracking PR

Then proceed immediately — no confirmation stop.

## Phase 1-N: Per Wave

Process each wave sequentially. Within each wave, process sub-issues sequentially.

### Per sub-issue:

#### Step 1: Create sub-branch

```bash
git checkout <feature-branch>
git pull origin <feature-branch>
git checkout -b issue-<N>-<description>
```

#### Step 2: Read issue

```bash
gh issue view <N> --json title,body,labels
```

#### Step 3: Read codebase

Based on the issue scope, read relevant files:
- Use Glob to find related files
- Use Grep to search for relevant patterns
- Read actual source files you plan to modify
- Check model attributes, existing patterns, imports

#### Step 4: Implement

Write code and tests following:
- CLAUDE.md policies (test quality, code quality, anti-patterns)
- Existing codebase patterns
- Issue acceptance criteria

#### Step 5: Test

Run the project-specific test/validate command found in CLAUDE.md:
- Check for: `npm run validate:all`, `make validate`, `./validate.sh`, `pytest`, etc.
- Run the relevant tests
- Show test output

#### Step 6: Fix failures (up to 3 attempts)

If tests fail:
1. Read the error carefully
2. Fix the root cause (not the symptom)
3. Re-run tests
4. Repeat up to 3 times total

#### Step 7a: On unresolvable failure

If after 3 attempts the tests still fail:

1. **Create bug issue** — write body to `/tmp/bug-epic.md`:

```markdown
## Context
- Epic: #$ARGUMENTS
- Sub-issue: #<N> — <title>
- Feature branch: <feature-branch>

## Error
<error output from test/validation>

## What Was Attempted
1. <description of implementation>
2. <fix attempt 1>
3. <fix attempt 2>
4. <fix attempt 3>

## Suggested Next Steps
- <investigation suggestions>
```

```bash
gh issue create --title "🐛 [Epic #$ARGUMENTS] Bug: <description>" --label bug --body-file /tmp/bug-epic.md
```

2. **Add bug to tracking PR** — update the tracking table and Closes statements
3. **Clean up failed branch:**

```bash
git checkout <feature-branch>
git branch -D issue-<N>-<description>
```

4. **Mark dependent issues as skipped** — any issue that depends on this failed issue cannot proceed. Log which issues are skipped and why.
5. **Continue** with the next non-blocked issue.

#### Step 7b: On success

1. **Commit** with a descriptive message referencing the issue:

```bash
git add <specific-files>
git commit -F /tmp/commit-msg-<N>.txt
```

2. **Push and create PR** — write PR body to `/tmp/pr-body-<N>.md`:

```markdown
Closes #<N>

## Summary
<what was implemented>

## Test Plan
- <what was tested>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

```bash
git push -u origin issue-<N>-<description>
gh pr create --title "<concise title>" --base <feature-branch> --body-file /tmp/pr-body-<N>.md
```

3. **Auto-merge:**

```bash
gh pr merge <pr-number> --merge --delete-branch
```

4. **Return to feature branch:**

```bash
git checkout <feature-branch>
git pull origin <feature-branch>
```

#### Step 8: Update tracking PR

After each sub-issue (success or failure), update the tracking PR:
- Update status in the tracking table (✅ Complete, ❌ Failed, ⏭️ Skipped)
- Update progress percentage
- Add PR link for successful issues

Write updated body to `/tmp/tracking-pr-update.md`, then:
```bash
gh pr edit <tracking-pr-number> --body-file /tmp/tracking-pr-update.md
```

## Phase Final: Wrap-up

### Step 1: Sync Closes statements

Ensure all completed sub-issue numbers are in the tracking PR body as `Closes #<N>` statements. Failed and skipped issues should NOT have Closes statements.

### Step 2: Show summary

Display a final report:

```markdown
## Epic #$ARGUMENTS — Implementation Complete

### Results
| # | Issue | Status | PR |
|---|-------|--------|-----|
| 1 | #XX — Title | ✅ Merged | #YY |
| 2 | #XX — Title | ❌ Failed | - |
| 3 | #XX — Title | ⏭️ Skipped (depends on #XX) | - |

### Statistics
- ✅ Completed: X of Y
- ❌ Failed: X (bug issues created: #AA, #BB)
- ⏭️ Skipped: X

### Tracking PR
<tracking-pr-url>

The tracking PR is ready for manual review and merge to develop.
```

## Error Handling Summary

When a sub-issue implementation fails:
1. Create a bug issue with full context (error, attempts, suggestions)
2. Add the bug issue to the tracking PR table
3. Delete the failed sub-branch (local only — don't delete remote if not pushed)
4. Check dependency graph: if issue X fails and issue Y depends on X → skip Y with a note
5. Continue with the next non-blocked issue in the current or next wave

## Status Indicators

| Emoji | Meaning |
|-------|---------|
| ⏳ | Pending — not started |
| 🔄 | In Progress — currently being implemented |
| ✅ | Complete — PR merged |
| ❌ | Failed — bug issue created |
| ⏭️ | Skipped — blocked by failed dependency |
