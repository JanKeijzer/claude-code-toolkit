#!/usr/bin/env bash
set -euo pipefail

# Audit project dependencies for known vulnerabilities.
# Runs npm audit and/or pip-audit depending on what's present.
#
# Usage: deps-audit.sh [project-dir]
# Example: deps-audit.sh /path/to/project

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "Error: directory not found: $PROJECT_DIR" >&2
  exit 2
fi

FOUND_ANY=false
ISSUES=0

echo "Dependency Security Audit"
echo "=================================================="
echo "Project: $PROJECT_DIR"
echo ""

# --- npm audit ---
audit_npm() {
  local dir="$1"
  local rel_dir="${dir#"$PROJECT_DIR"/}"
  [[ "$rel_dir" == "$PROJECT_DIR" ]] && rel_dir="."

  if [[ ! -f "$dir/package-lock.json" ]]; then
    return
  fi
  FOUND_ANY=true

  echo "── npm ($rel_dir) ──"
  echo ""

  if ! command -v npm &>/dev/null; then
    echo "  SKIP: npm not installed"
    echo ""
    return
  fi

  local output
  output="$(cd "$dir" && npm audit --json 2>/dev/null)" || true

  # Parse vulnerability counts from npm audit JSON
  local critical high moderate low total
  critical=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('metadata',{}).get('vulnerabilities',{}).get('critical',0))" 2>/dev/null || echo 0)
  high=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('metadata',{}).get('vulnerabilities',{}).get('high',0))" 2>/dev/null || echo 0)
  moderate=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('metadata',{}).get('vulnerabilities',{}).get('moderate',0))" 2>/dev/null || echo 0)
  low=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('metadata',{}).get('vulnerabilities',{}).get('low',0))" 2>/dev/null || echo 0)
  total=$((critical + high + moderate + low))

  if [[ $total -eq 0 ]]; then
    echo "  No vulnerabilities found."
  else
    echo "  Vulnerabilities: $total"
    [[ $critical -gt 0 ]] && echo "    Critical: $critical"
    [[ $high -gt 0 ]] && echo "    High:     $high"
    [[ $moderate -gt 0 ]] && echo "    Moderate: $moderate"
    [[ $low -gt 0 ]] && echo "    Low:      $low"
    ISSUES=$((ISSUES + total))
  fi
  echo ""
}

# --- pip-audit ---
audit_python() {
  local dir="$1"
  local rel_dir="${dir#"$PROJECT_DIR"/}"
  [[ "$rel_dir" == "$PROJECT_DIR" ]] && rel_dir="."

  local has_python=false
  [[ -f "$dir/pyproject.toml" ]] && has_python=true
  [[ -f "$dir/requirements.txt" ]] && has_python=true

  if [[ "$has_python" != "true" ]]; then
    return
  fi
  FOUND_ANY=true

  echo "── Python ($rel_dir) ──"
  echo ""

  # Try uv first, then pip-audit directly
  local output=""
  local ran=false

  if [[ -f "$dir/uv.lock" ]] && command -v uv &>/dev/null; then
    # Check if pip-audit is available via uv
    if (cd "$dir" && uv run pip-audit --version &>/dev/null); then
      echo "  Scanner: uv run pip-audit"
      output="$(cd "$dir" && uv run pip-audit --json 2>&1)" || true
      ran=true
    fi
  fi

  if [[ "$ran" != "true" ]] && command -v pip-audit &>/dev/null; then
    echo "  Scanner: pip-audit"
    if [[ -f "$dir/requirements.txt" ]]; then
      output="$(cd "$dir" && pip-audit -r requirements.txt --json 2>&1)" || true
    else
      output="$(cd "$dir" && pip-audit --json 2>&1)" || true
    fi
    ran=true
  fi

  if [[ "$ran" != "true" ]]; then
    echo "  SKIP: pip-audit not available"
    echo "  Install with: uv add --dev pip-audit  or  pip install pip-audit"
    echo ""
    return
  fi

  # pip-audit JSON is an array of vulnerability objects
  local count
  count=$(echo "$output" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('dependencies', []) if isinstance(d, dict) else [v for v in d if v.get('vulns',[])]))" 2>/dev/null || echo 0)

  if [[ "$count" -eq 0 ]]; then
    echo "  No vulnerabilities found."
  else
    echo "  Vulnerable packages: $count"
    # Show package names
    echo "$output" | python3 -c "
import sys, json
data = json.load(sys.stdin)
deps = data.get('dependencies', data) if isinstance(data, dict) else data
for dep in deps:
    vulns = dep.get('vulns', [])
    if vulns:
        name = dep.get('name', '?')
        version = dep.get('version', '?')
        ids = ', '.join(v.get('id', '?') for v in vulns[:3])
        extra = f' (+{len(vulns)-3} more)' if len(vulns) > 3 else ''
        print(f'    {name}=={version}: {ids}{extra}')
" 2>/dev/null || true
    ISSUES=$((ISSUES + count))
  fi
  echo ""
}

# Search for dependency files in the project tree
# Check project root and immediate subdirectories
for dir in "$PROJECT_DIR" "$PROJECT_DIR"/*/; do
  [[ -d "$dir" ]] || continue
  # Skip node_modules, .git, etc.
  basename="$(basename "$dir")"
  case "$basename" in
    node_modules|.git|dist|build|.next|__pycache__|.venv|venv) continue ;;
  esac
  audit_npm "$dir"
  audit_python "$dir"
done

if [[ "$FOUND_ANY" != "true" ]]; then
  echo "Error: no package-lock.json, pyproject.toml, or requirements.txt found" >&2
  exit 2
fi

# Summary
echo "── Summary ──"
if [[ $ISSUES -eq 0 ]]; then
  echo "Result: CLEAN"
  exit 0
else
  echo "Result: $ISSUES VULNERABILITY(IES) FOUND"
  exit 1
fi
