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

**FOLLOW ALL STEPS STRICTLY. NO SHORTCUTS.**
**MUST use ~/bin/git-find-base-branch for base branch detection for the PR**

---

## Phase 1: Discovery & Planning

1. Fetch issue details: `gh issue view $ARGUMENTS --json title,body,labels`

2. **Read AND verify understanding of existing code:**
   - Read all CLAUDE.md files (root, frontend, backend if they exist)
   - Read the ACTUAL source files you plan to modify
   - Check what attributes/methods ACTUALLY exist on models you'll use
   - Find existing patterns for similar functionality (grep/search)
   - **NEVER assume a model has an attribute - READ the model first**

3. Create detailed implementation plan showing:
   - Issue requirements understanding
   - **Existing code patterns** you found and will follow
   - Files to modify/create
   - Required tests and validations to run
   - Todo list with explicit reference to steps 4-15 below

**STOP HERE and ask for confirmation before proceeding to implementation.**

---

## Phase 2: Branch & Implementation

4. Create and checkout branch: `issue-$ARGUMENTS-<descriptive-label>`

5. **Before writing new code, verify your assumptions:**
   - If using model attributes, confirm they exist: `grep "attribute_name" models.py`
   - If importing classes, confirm they exist: `python -c "from module import Class"`
   - **If ANY verification fails, STOP and reassess your approach**

6. Implement all changes following the plan and existing patterns

7. Implement test(s) that:
   - Import the same modules your implementation uses
   - Test actual behavior, not assumed behavior
   - Cover both success and error cases

---

## Phase 3: Test Verification (MANDATORY)

**DO NOT SKIP THIS PHASE. DO NOT PROCEED WITHOUT GREEN TESTS.**

8. **Run tests and SHOW THE OUTPUT:**
   ```bash
   pytest tests/path/to/your_test.py -v
   ```
   - Paste the actual pytest output in your response
   - If you see ANY error (ImportError, AttributeError, assertion failures), STOP

9. **If tests fail:**
   - Read the error message carefully
   - Fix the root cause (not just the symptom)
   - Re-run tests and show output again
   - Repeat until ALL tests pass

10. **Run project validation (if available) and SHOW THE OUTPUT:**
    - Check for: `npm run validate:all`, `make validate`, `./validate.sh`
    - If validation command exists, run it
    - If backend schemas were modified, ensure OpenAPI is regenerated
    - Paste the actual output (or summary if long)
    - Fix any errors before proceeding

11. Commit changes with descriptive message

---

## Phase 4: PR Creation

12. Push branch to remote

13. Create PR with:
    - Title: "<Issue title>" (no "Closes" keyword in title)
    - Body: "Closes #$ARGUMENTS\n\n<implementation summary + test checklist>"
    - Against base branch from: `~/bin/git-find-base-branch`

14. Return PR URL for review

---

## Anti-Patterns to Avoid

**NEVER do these:**
- Assume a model has attributes without reading the model file
- Write tests that import non-existent classes
- Claim tests pass without showing actual pytest output
- Skip validation because "it should work"
- Commit code that you haven't actually tested

**Example of what can go wrong:**
```python
# WRONG - Assumed model had attribute without checking
person.education_id  # AttributeError - attribute doesn't exist!

# WRONG - Imported non-existent class
from database.models import Education  # ImportError - class doesn't exist!
```

If you had run the tests, these would have failed immediately.
