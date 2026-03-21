#!/usr/bin/env bash
# git-push-pr-merge.sh — Push branch, create PR, merge, return to base branch.
#
# Wraps the full post-commit workflow for sub-agents in implement-epic.
# Avoids multiline/heredoc issues by accepting PR body from a file.
#
# Usage:
#   git-push-pr-merge.sh --base <base-branch> --title "PR title" --body-file /tmp/pr-body.md
#
# What it does:
#   1. Push current branch to origin (with -u)
#   2. Create PR against base branch
#   3. Merge PR (--merge --delete-branch)
#   4. Checkout base branch and pull
#
# Options:
#   --base <branch>       Target branch for the PR (required)
#   --title <title>       PR title (required)
#   --body-file <path>    File containing PR body (required)
#   --no-merge            Create PR but don't merge (for manual review)

set -euo pipefail

BASE=""
TITLE=""
BODY_FILE=""
DO_MERGE=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --base)
            BASE="$2"
            shift 2
            ;;
        --title)
            TITLE="$2"
            shift 2
            ;;
        --body-file)
            BODY_FILE="$2"
            shift 2
            ;;
        --no-merge)
            DO_MERGE=0
            shift
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Validate required args
if [[ -z "$BASE" ]]; then
    echo "Error: --base is required" >&2
    exit 1
fi
if [[ -z "$TITLE" ]]; then
    echo "Error: --title is required" >&2
    exit 1
fi
if [[ -z "$BODY_FILE" ]]; then
    echo "Error: --body-file is required" >&2
    exit 1
fi
if [[ ! -f "$BODY_FILE" ]]; then
    echo "Error: Body file not found: $BODY_FILE" >&2
    exit 1
fi

CURRENT_BRANCH=$(git branch --show-current)
if [[ "$CURRENT_BRANCH" == "$BASE" ]]; then
    echo "Error: Current branch ($CURRENT_BRANCH) is the same as base ($BASE)" >&2
    exit 1
fi

echo "=== Pushing $CURRENT_BRANCH to origin ==="
git push -u origin "$CURRENT_BRANCH"

echo "=== Creating PR: $TITLE ==="
PR_URL=$(gh pr create --title "$TITLE" --base "$BASE" --body-file "$BODY_FILE")
PR_NUMBER=$(echo "$PR_URL" | grep -oP '/pull/\K[0-9]+')

echo "Created PR #$PR_NUMBER: $PR_URL"

if [[ "$DO_MERGE" -eq 1 ]]; then
    echo "=== Merging PR #$PR_NUMBER ==="
    gh pr merge "$PR_NUMBER" --merge --delete-branch

    echo "=== Returning to $BASE ==="
    git checkout "$BASE"
    git pull origin "$BASE"

    echo "=== Done ==="
    echo "PR_NUMBER: $PR_NUMBER"
    echo "PR_URL: $PR_URL"
    echo "STATUS: MERGED"
else
    echo "=== Done (no merge) ==="
    echo "PR_NUMBER: $PR_NUMBER"
    echo "PR_URL: $PR_URL"
    echo "STATUS: CREATED"
fi
