---
name: implement
description: Implement a GitHub issue with automated PR creation
argument-hint: <issue-number>
user-invocable: true
---

# Implement GitHub Issue

Implement GitHub issue with automated workflow.

## Input

The user provides an issue number: `$ARGUMENTS`

FOLLOW ALL STEPS STRICTLY. NO SHORTCUTS. MUST use ~/.claude/bin/git-find-base-branch for base branch detection for the PR.

## Tool Rules

- Use Glob to find files — NEVER use `find` or `ls` via Bash
- Use Grep to search file contents — NEVER use `grep` or `rg` via Bash
- Use Read to read files — NEVER use `cat`, `head`, or `tail` via Bash
- Bash is for `gh` commands, `git` commands, running tests, and `~/.claude/bin/` scripts only
- NEVER write files via Bash (no `echo >`, `cat <<`, `tee`, heredoc) — use the Write tool to write to `/tmp/`, then reference the file
- NEVER use `python3 -c`, `sed`, or `awk` for file modifications — use Grep to find occurrences, then Edit to replace them
- Use Write to create new files — NEVER use `mkdir` via Bash (Write auto-creates parent directories)
- Use `git rm` to delete files — NEVER use `rm` via Bash
- For batch operations on multiple issues, use `~/.claude/bin/` scripts (e.g., `batch-issue-status.sh`, `batch-issue-view.sh`) — NEVER use `for` loops in Bash

Follow the Test Quality Policy and Anti-Patterns from CLAUDE.md throughout all phases.

## Phase 1: Discovery & Planning

1. Fetch issue details: `gh issue view $ARGUMENTS --json title,body,labels`
2. Read AND verify understanding of existing code:
   * Read all CLAUDE.md files (root, frontend, backend if they exist)
   * Read the ACTUAL source files you plan to modify
   * Check what attributes/methods ACTUALLY exist on models you'll use
   * Find existing patterns for similar functionality (grep/search)
   * NEVER assume a model has an attribute - READ the model first
3. Create detailed implementation plan showing:
   * Issue requirements understanding
   * Existing code patterns you found and will follow
   * Files to modify/create
   * Test strategy: what scenarios to test, what to mock (and why), what to test through the full stack
   * Todo list with explicit reference to steps in phases 2-4 below

STOP HERE and ask for confirmation before proceeding to implementation.

## Phase 2: Branch & Implementation

1. Create and checkout branch: `issue-$ARGUMENTS-<descriptive-label>`
2. Before writing new code, verify your assumptions:
   * If using model attributes, confirm they exist: `grep "attribute_name" models.py`
   * If importing classes, confirm they exist: `python -c "from module import Class"`
   * If ANY verification fails, STOP and reassess your approach
3. Implement all changes following the plan and existing patterns
4. Implement tests following the Test Quality Policy from CLAUDE.md

## Phase 3: Test Review & Verification (MANDATORY)

DO NOT SKIP THIS PHASE. DO NOT PROCEED WITHOUT GREEN TESTS.

### Step 1: Self-review before running tests

Before running anything, critically review your own test code:
* Are you testing implementation details or actual behavior?
* Would these tests still pass if the feature is subtly broken?
* Are your mocks hiding the exact bugs you should be catching?
* Do your fixtures represent realistic data or lazy placeholders?

If you find weaknesses, fix them BEFORE running the tests.

### Step 2: Run tests and SHOW THE OUTPUT

```bash
pytest tests/path/to/your_test.py -v
```

* Paste the actual pytest output in your response
* If you see ANY error (ImportError, AttributeError, assertion failures), STOP

### Step 3: Fix failures at the root cause

If tests fail:
* Read the error message carefully
* Fix the root cause (not just the symptom)
* Re-run tests and show output again
* Repeat until ALL tests pass

### Step 4: Run project validation

* Check for: `npm run validate:all`, `make validate`, `./validate.sh`
* If validation command exists, run it
* If backend schemas were modified, ensure OpenAPI is regenerated
* Paste the actual output (or summary if long)
* Fix any errors before proceeding

### Step 5: Commit changes

Commit with descriptive message summarizing what was implemented and tested.

## Phase 4: PR Creation

1. Push branch to remote
2. Create PR with:
   * Title: `<concise description of change>` (no "Closes" keyword in title)
   * Body: `Closes #$ARGUMENTS\n\n<implementation summary + test checklist>`
   * Against base branch from: `~/.claude/bin/git-find-base-branch`
3. Return PR URL for review
