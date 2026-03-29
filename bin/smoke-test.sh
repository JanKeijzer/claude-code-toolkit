#!/usr/bin/env bash
set -euo pipefail

# API endpoint smoke testing with auto-discovery.
# Hits endpoints and reports HTTP status codes.
# Detects health endpoints automatically.
#
# Usage: smoke-test.sh [base-url] [--health-token TOKEN] [--endpoints file]
# Example: smoke-test.sh http://localhost:8080 --health-token mysecret

BASE_URL=""
HEALTH_TOKEN=""
ENDPOINTS_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --health-token)
      HEALTH_TOKEN="$2"
      shift 2
      ;;
    --endpoints)
      ENDPOINTS_FILE="$2"
      shift 2
      ;;
    -*)
      echo "Error: unknown option: $1" >&2
      echo "Usage: smoke-test.sh [base-url] [--health-token TOKEN] [--endpoints file]" >&2
      exit 2
      ;;
    *)
      BASE_URL="$1"
      shift
      ;;
  esac
done

# Auto-discover base URL if not provided
if [[ -z "$BASE_URL" ]]; then
  # Try .env files
  for envfile in .env backend/.env backend/docker/.env; do
    if [[ -f "$envfile" ]]; then
      for var in API_URL VITE_API_URL BASE_URL; do
        val=$(grep -E "^${var}=" "$envfile" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '"'"'" || true)
        if [[ -n "$val" ]]; then
          BASE_URL="$val"
          break 2
        fi
      done
    fi
  done

  # Try docker compose port mappings
  if [[ -z "$BASE_URL" ]]; then
    for compose in docker-compose.yml compose.yml backend/docker/docker-compose.yml; do
      if [[ -f "$compose" ]]; then
        # Look for published port mappings in running containers
        port=$(docker compose -f "$compose" ps --format json 2>/dev/null | \
          jq -r 'select(.Publishers) | .Publishers[] | select(.TargetPort == 8080 or .TargetPort == 8000 or .TargetPort == 3000 or .TargetPort == 80) | .PublishedPort' 2>/dev/null | head -1 || true)
        if [[ -n "$port" ]]; then
          BASE_URL="http://localhost:$port"
          break
        fi
      fi
    done
  fi

  # Fallback
  if [[ -z "$BASE_URL" ]]; then
    echo "Error: could not determine base URL" >&2
    echo "Tried: .env files (API_URL, VITE_API_URL, BASE_URL), docker compose port mappings" >&2
    echo "Usage: smoke-test.sh <base-url> [--health-token TOKEN]" >&2
    exit 2
  fi
fi

# Strip trailing slash
BASE_URL="${BASE_URL%/}"

echo "API Smoke Test"
echo "=================================================="
echo "Base URL: $BASE_URL"
echo ""

ISSUES=0
TOTAL=0
TESTED=()

# Test a single endpoint
test_endpoint() {
  local method="$1"
  local path="$2"
  local url="${BASE_URL}${path}"
  local display_path="$path"

  # Mask health token in display
  if [[ "$display_path" == *"token="* ]]; then
    display_path=$(echo "$display_path" | sed 's/token=[^&]*/token=***/')
  fi

  TOTAL=$((TOTAL + 1))

  # Measure response time and status code
  local start_ms
  start_ms=$(date +%s%N 2>/dev/null || date +%s)

  local status
  status=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 --max-time 10 "$url" 2>/dev/null || echo "000")

  local end_ms
  end_ms=$(date +%s%N 2>/dev/null || date +%s)

  # Calculate duration (handle both nanosecond and second precision)
  local duration_ms
  if [[ ${#start_ms} -gt 10 ]]; then
    duration_ms=$(( (end_ms - start_ms) / 1000000 ))
  else
    duration_ms=$(( (end_ms - start_ms) * 1000 ))
  fi

  # Determine pass/fail
  local result_icon="✓"
  if [[ "$status" == "000" ]]; then
    result_icon="✗"
    ISSUES=$((ISSUES + 1))
    status="CONN_FAIL"
  elif [[ "$status" -ge 500 ]]; then
    result_icon="✗"
    ISSUES=$((ISSUES + 1))
  elif [[ "$status" -ge 400 ]]; then
    result_icon="~"
  fi

  printf "  %s %-6s %-40s %s  (%sms)\n" "$result_icon" "$method" "$display_path" "$status" "$duration_ms"

  TESTED+=("$path")
}

# Check if endpoint was already tested
already_tested() {
  local path="$1"
  for t in "${TESTED[@]+"${TESTED[@]}"}"; do
    if [[ "$t" == "$path" ]]; then
      return 0
    fi
  done
  return 1
}

echo "── Endpoints ──"

# Test root
test_endpoint "GET" "/"

# Test well-known health endpoints (skip 404s silently — only report if reachable)
HEALTH_ENDPOINTS=("/livez" "/healthz" "/health" "/api/health" "/api/v1/admin/health" "/docs" "/openapi.json")

for ep in "${HEALTH_ENDPOINTS[@]}"; do
  # Quick check if endpoint exists (don't count 404s as issues)
  check_status=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 5 "${BASE_URL}${ep}" 2>/dev/null || echo "000")
  if [[ "$check_status" != "404" && "$check_status" != "000" ]]; then
    test_endpoint "GET" "$ep"
  fi
done

# Test health endpoint with token if provided
if [[ -n "$HEALTH_TOKEN" ]]; then
  # Try common health paths with token
  for ep in "/api/v1/admin/health" "/health" "/api/health"; do
    token_path="${ep}?token=${HEALTH_TOKEN}"
    if ! already_tested "$token_path"; then
      check_status=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 --max-time 5 "${BASE_URL}${token_path}" 2>/dev/null || echo "000")
      if [[ "$check_status" != "404" && "$check_status" != "000" ]]; then
        test_endpoint "GET" "$token_path"

        # If health endpoint returned 200, try to parse JSON for component status
        if [[ "$check_status" == "200" || "$check_status" == "503" ]]; then
          health_body=$(curl -s --connect-timeout 3 --max-time 5 "${BASE_URL}${token_path}" 2>/dev/null || true)
          if [[ -n "$health_body" ]]; then
            overall=$(echo "$health_body" | jq -r '.status // empty' 2>/dev/null || true)
            if [[ -n "$overall" ]]; then
              echo ""
              echo "  Health detail: status=$overall"
              # Show component statuses if available
              components=$(echo "$health_body" | jq -r '.checks // .components // empty | to_entries[]? | "    \(.key): \(.value.status // .value)"' 2>/dev/null || true)
              if [[ -n "$components" ]]; then
                echo "$components"
              fi
            fi
          fi
        fi
        break
      fi
    fi
  done
fi

# Test custom endpoints from file
if [[ -n "$ENDPOINTS_FILE" && -f "$ENDPOINTS_FILE" ]]; then
  echo ""
  echo "  Custom endpoints ($ENDPOINTS_FILE):"
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == "#"* ]] && continue
    method="GET"
    path="$line"
    if [[ "$line" == *" "* ]]; then
      method="${line%% *}"
      path="${line#* }"
    fi
    if ! already_tested "$path"; then
      test_endpoint "$method" "$path"
    fi
  done < "$ENDPOINTS_FILE"
fi

echo ""

# Summary
echo "── Summary ──"
if [[ $ISSUES -eq 0 ]]; then
  echo "Result: HEALTHY ($TOTAL/$TOTAL endpoints OK)"
  exit 0
else
  passed=$((TOTAL - ISSUES))
  echo "Result: $ISSUES ISSUE(S) ($passed/$TOTAL endpoints OK)"
  exit 1
fi
