#!/usr/bin/env bash
# git-commit.sh — Commit with a message passed as argument or from stdin.
#
# Avoids heredoc/multiline issues in Claude Code sub-agents by writing
# the message to a temp file and using git commit -F.
#
# Usage:
#   git-commit.sh "Single line commit message"
#   git-commit.sh "Multi-line" "commit message" "each arg is a line"
#   echo "message" | git-commit.sh --stdin
#
# Options:
#   --stdin    Read commit message from stdin
#   --amend    Amend the previous commit (use with caution)

set -euo pipefail

AMEND=""
FROM_STDIN=""
MSG_ARGS=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --stdin)
            FROM_STDIN=1
            shift
            ;;
        --amend)
            AMEND="--amend"
            shift
            ;;
        *)
            MSG_ARGS+=("$1")
            shift
            ;;
    esac
done

TMPFILE=$(mktemp /tmp/commit-msg-XXXXXX.txt)
trap 'rm -f "$TMPFILE"' EXIT

if [[ -n "$FROM_STDIN" ]]; then
    cat > "$TMPFILE"
elif [[ ${#MSG_ARGS[@]} -gt 0 ]]; then
    # Join arguments with newlines (each arg = one line)
    printf '%s\n' "${MSG_ARGS[@]}" > "$TMPFILE"
else
    echo "Error: No commit message provided." >&2
    echo "Usage: git-commit.sh \"message\" or echo \"message\" | git-commit.sh --stdin" >&2
    exit 1
fi

# Verify the message is not empty
if [[ ! -s "$TMPFILE" ]]; then
    echo "Error: Commit message is empty." >&2
    exit 1
fi

exec git commit $AMEND -F "$TMPFILE"
