---
name: cleanup
description: Clean up after merging a PR - checkout base, fetch, pull, delete feature branch
user-invocable: true
---

# Cleanup After PR Merge

Clean up git repository after merging a PR by running the cleanup script.

## Usage

```
/cleanup
```

## What This Does

Run the cleanup script:
```bash
~/bin/git-cleanup-merged-branch.sh
```

The script will:
1. Auto-detect the current feature branch
2. Find the appropriate base branch (develop/master/main)
3. Checkout the base branch
4. Fetch and pull latest changes
5. Delete the merged feature branch (with safety checks)
6. Optionally delete the remote branch

## Important

- Only run this AFTER merging the PR in GitHub
- The script uses `git branch -d` (safe delete) - will warn if branch isn't fully merged
- Will prompt before deleting remote branches
- Checks for uncommitted changes and warns you

## Manual Usage Options

```bash
# Auto-detect everything
~/bin/git-cleanup-merged-branch.sh

# Specify feature branch
~/bin/git-cleanup-merged-branch.sh issue-123-my-feature

# Specify both branches
~/bin/git-cleanup-merged-branch.sh issue-123-my-feature develop
```
