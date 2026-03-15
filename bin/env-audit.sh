#!/usr/bin/env bash
set -euo pipefail

# Audit .env files against .env.example templates.
# Finds missing variables, empty values, extra variables, and secrets tracked by git.
#
# Usage: env-audit.sh [project-dir]
# Example: env-audit.sh /path/to/project

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Error: directory not found: $PROJECT_DIR" >&2
  exit 2
fi

# Find all .env.example and .env.template files
TEMPLATES=()
while IFS= read -r file; do
  [[ -n "$file" ]] && TEMPLATES+=("$file")
done < <(find "$PROJECT_DIR" -name '.env.example' -o -name '.env.template' 2>/dev/null | sort)

if [[ ${#TEMPLATES[@]} -eq 0 ]]; then
  echo "Error: no .env.example or .env.template files found in $PROJECT_DIR" >&2
  exit 2
fi

ISSUES=0

# Extract variable names from a .env file (skip comments and blank lines)
extract_keys() {
  grep -E '^[A-Za-z_][A-Za-z0-9_]*=' "$1" 2>/dev/null | cut -d= -f1 | sort -u
}

# Find empty values in a .env file
find_empty_values() {
  grep -E '^[A-Za-z_][A-Za-z0-9_]*=\s*$' "$1" 2>/dev/null | cut -d= -f1
}

echo "Environment Audit Report"
echo "=================================================="
echo "Project: $PROJECT_DIR"
echo ""

for template in "${TEMPLATES[@]}"; do
  rel_template="${template#"$PROJECT_DIR"/}"
  dir="$(dirname "$template")"

  # Determine the actual .env file path
  env_file=""
  if [[ "$template" == *.example ]]; then
    env_file="${template%.example}"
  elif [[ "$template" == *.template ]]; then
    env_file="${template%.template}"
  fi
  rel_env="${env_file#"$PROJECT_DIR"/}"

  echo "── ${rel_template} ──"
  echo ""

  if [[ ! -f "$env_file" ]]; then
    echo "  WARNING: $rel_env does not exist"
    echo "  All variables from template are missing."
    echo ""
    ISSUES=$((ISSUES + 1))
    continue
  fi

  template_keys="$(extract_keys "$template")"
  env_keys="$(extract_keys "$env_file")"

  # Missing vars (in template but not in .env)
  missing="$(comm -23 <(echo "$template_keys") <(echo "$env_keys") || true)"
  if [[ -n "$missing" ]]; then
    count=$(echo "$missing" | wc -l | tr -d ' ')
    echo "  Missing variables ($count):"
    echo "$missing" | while read -r key; do
      echo "    $key"
    done
    ISSUES=$((ISSUES + count))
    echo ""
  fi

  # Empty values in .env
  empty="$(find_empty_values "$env_file" || true)"
  if [[ -n "$empty" ]]; then
    count=$(echo "$empty" | wc -l | tr -d ' ')
    echo "  Empty values ($count):"
    echo "$empty" | while read -r key; do
      echo "    $key="
    done
    ISSUES=$((ISSUES + count))
    echo ""
  fi

  # Extra vars (in .env but not in template) — informational only
  extra="$(comm -13 <(echo "$template_keys") <(echo "$env_keys") || true)"
  if [[ -n "$extra" ]]; then
    count=$(echo "$extra" | wc -l | tr -d ' ')
    echo "  Extra variables not in template ($count) [info]:"
    echo "$extra" | while read -r key; do
      echo "    $key"
    done
    echo ""
  fi

done

# Check for .env files tracked by git
if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
  tracked_envs="$(git -C "$PROJECT_DIR" ls-files '*.env' '.env' '**/.env' 2>/dev/null | grep -v -E '\.(example|template|test|ci)$' || true)"
  if [[ -n "$tracked_envs" ]]; then
    echo "── Secrets in Git ──"
    echo ""
    echo "  WARNING: The following .env files are tracked by git:"
    echo "$tracked_envs" | while read -r f; do
      echo "    $f"
    done
    echo ""
    ISSUES=$((ISSUES + 1))
  fi
fi

# Summary
echo "── Summary ──"
if [[ $ISSUES -eq 0 ]]; then
  echo "Result: CLEAN"
  exit 0
else
  echo "Result: $ISSUES ISSUE(S) FOUND"
  exit 1
fi
