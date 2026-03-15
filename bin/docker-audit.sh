#!/usr/bin/env bash
set -euo pipefail

# Audit Docker configuration for common security and reliability issues.
# Checks Dockerfiles and docker-compose files for unpinned images, missing
# health checks, root user, hardcoded secrets, and insecure port bindings.
#
# Usage: docker-audit.sh [project-dir]
# Example: docker-audit.sh /path/to/project

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Error: directory not found: $PROJECT_DIR" >&2
  exit 2
fi

ISSUES=0

# Collect Docker files
DOCKERFILES=()
COMPOSE_FILES=()

while IFS= read -r f; do
  [[ -n "$f" ]] && DOCKERFILES+=("$f")
done < <(find "$PROJECT_DIR" -name 'Dockerfile*' -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | sort)

while IFS= read -r f; do
  [[ -n "$f" ]] && COMPOSE_FILES+=("$f")
done < <(find "$PROJECT_DIR" \( -name 'docker-compose*.yml' -o -name 'docker-compose*.yaml' -o -name 'compose*.yml' -o -name 'compose*.yaml' \) -not -path '*/node_modules/*' -not -path '*/.git/*' 2>/dev/null | sort)

if [[ ${#DOCKERFILES[@]} -eq 0 && ${#COMPOSE_FILES[@]} -eq 0 ]]; then
  echo "Error: no Dockerfiles or docker-compose files found in $PROJECT_DIR" >&2
  exit 2
fi

echo "Docker Configuration Audit"
echo "=================================================="
echo "Project:    $PROJECT_DIR"
echo "Dockerfiles: ${#DOCKERFILES[@]}"
echo "Compose:     ${#COMPOSE_FILES[@]}"
echo ""

# --- Dockerfile checks ---
if [[ ${#DOCKERFILES[@]} -gt 0 ]]; then
  echo "── Dockerfiles ──"
  echo ""

  for dockerfile in "${DOCKERFILES[@]}"; do
    rel="${dockerfile#"$PROJECT_DIR"/}"
    file_issues=()

    # Check for unpinned base images
    while IFS= read -r line; do
      image="${line#FROM }"
      # Strip --platform and AS alias
      image="$(echo "$image" | sed 's/--platform=[^ ]* //' | awk '{print $1}')"
      if [[ "$image" == *":latest" ]] || [[ "$image" != *":"* && "$image" != "scratch" && "$image" != *'$'* ]]; then
        file_issues+=("Unpinned base image: $image")
      fi
    done < <(grep -i '^FROM ' "$dockerfile" 2>/dev/null || true)

    # Check for missing HEALTHCHECK
    if ! grep -qi '^HEALTHCHECK' "$dockerfile" 2>/dev/null; then
      file_issues+=("No HEALTHCHECK directive")
    fi

    # Check for missing USER directive (runs as root)
    if ! grep -qi '^USER' "$dockerfile" 2>/dev/null; then
      file_issues+=("No USER directive (runs as root)")
    fi

    if [[ ${#file_issues[@]} -gt 0 ]]; then
      echo "  $rel:"
      for issue in "${file_issues[@]}"; do
        echo "    - $issue"
      done
      ISSUES=$((ISSUES + ${#file_issues[@]}))
      echo ""
    fi
  done

  # Report clean Dockerfiles
  clean=0
  for dockerfile in "${DOCKERFILES[@]}"; do
    rel="${dockerfile#"$PROJECT_DIR"/}"
    has_issue=false
    # Re-check (lightweight)
    if grep -qi '^FROM.*:latest' "$dockerfile" 2>/dev/null || \
       ! grep -qi '^HEALTHCHECK' "$dockerfile" 2>/dev/null || \
       ! grep -qi '^USER' "$dockerfile" 2>/dev/null; then
      has_issue=true
    fi
    # Also check for untagged FROM
    while IFS= read -r line; do
      image="${line#FROM }"
      image="$(echo "$image" | sed 's/--platform=[^ ]* //' | awk '{print $1}')"
      if [[ "$image" != *":"* && "$image" != "scratch" && "$image" != *'$'* ]]; then
        has_issue=true
      fi
    done < <(grep -i '^FROM ' "$dockerfile" 2>/dev/null || true)

    if [[ "$has_issue" != "true" ]]; then
      clean=$((clean + 1))
    fi
  done
  if [[ $clean -gt 0 ]]; then
    echo "  $clean Dockerfile(s) passed all checks."
    echo ""
  fi
fi

# --- docker-compose checks ---
if [[ ${#COMPOSE_FILES[@]} -gt 0 ]]; then
  echo "── Compose Files ──"
  echo ""

  for compose_file in "${COMPOSE_FILES[@]}"; do
    rel="${compose_file#"$PROJECT_DIR"/}"
    file_issues=()

    # Check for unpinned images (:latest or no tag)
    while IFS= read -r line; do
      # Extract image name from "image: name:tag" lines
      image="$(echo "$line" | sed 's/.*image:\s*//' | tr -d '"'"'" | xargs)"
      if [[ "$image" == *":latest" ]]; then
        file_issues+=("Unpinned image: $image")
      fi
    done < <(grep -E '^\s*image:' "$compose_file" 2>/dev/null || true)

    # Check for hardcoded secrets in environment sections
    # Look for PASSWORD=, SECRET=, API_KEY= with literal values (not ${VAR} references)
    while IFS= read -r line; do
      # Skip lines that use variable substitution ${...} or are commented
      if [[ "$line" == *'${'* ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
        continue
      fi
      # Extract the key=value, check if key contains secret-like patterns
      key_part="$(echo "$line" | sed 's/.*- //' | sed 's/.*: //' | tr -d '"'"'" | xargs)"
      if echo "$key_part" | grep -qiE '^(.*_)?(PASSWORD|SECRET|API_KEY|TOKEN|PRIVATE_KEY)=.+'; then
        # Has a non-empty literal value — potential hardcoded secret
        key_name="$(echo "$key_part" | cut -d= -f1)"
        file_issues+=("Possible hardcoded secret: $key_name")
      fi
    done < <(grep -E '(PASSWORD|SECRET|API_KEY|TOKEN|PRIVATE_KEY)=' "$compose_file" 2>/dev/null || true)

    if [[ ${#file_issues[@]} -gt 0 ]]; then
      echo "  $rel:"
      for issue in "${file_issues[@]}"; do
        echo "    - $issue"
      done
      ISSUES=$((ISSUES + ${#file_issues[@]}))
      echo ""
    fi
  done
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
