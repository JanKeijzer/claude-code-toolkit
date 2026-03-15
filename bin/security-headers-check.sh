#!/usr/bin/env bash
set -euo pipefail

# Check HTTP security headers on a running web application.
# Tests for OWASP-recommended security headers.
#
# Usage: security-headers-check.sh <url>
# Example: security-headers-check.sh https://apptest.polyamoriematch.nl
#          security-headers-check.sh http://localhost:3000

URL="${1:-}"

if [[ -z "$URL" ]]; then
  echo "Usage: security-headers-check.sh <url>" >&2
  echo "Example: security-headers-check.sh https://apptest.polyamoriematch.nl" >&2
  exit 2
fi

# Strip trailing slash
URL="${URL%/}"

ISSUES=0
WARNINGS=0

echo "HTTP Security Headers Audit"
echo "=================================================="
echo "Target: $URL"
echo ""

# Fetch headers
HEADERS_FILE="$(mktemp)"
HTTP_CODE="$(curl -sS -o /dev/null -D "$HEADERS_FILE" -w '%{http_code}' --max-time 10 "$URL" 2>/dev/null || echo "000")"

if [[ "$HTTP_CODE" == "000" ]]; then
  echo "Error: could not connect to $URL" >&2
  rm -f "$HEADERS_FILE"
  exit 2
fi

echo "HTTP Status: $HTTP_CODE"
echo ""

# Normalize headers to lowercase for matching
HEADERS_LOWER="$(tr '[:upper:]' '[:lower:]' < "$HEADERS_FILE")"

check_header() {
  local header_name="$1"
  local severity="$2"  # CRITICAL, WARNING, INFO
  local description="$3"
  local recommended="${4:-}"

  local header_lower
  header_lower="$(echo "$header_name" | tr '[:upper:]' '[:lower:]')"

  local found_value
  found_value="$(echo "$HEADERS_LOWER" | grep -i "^${header_lower}:" | head -1 | sed "s/^${header_lower}:\s*//" | tr -d '\r' || true)"

  if [[ -n "$found_value" ]]; then
    echo "  [PASS] $header_name: $found_value"
  else
    if [[ "$severity" == "CRITICAL" ]]; then
      echo "  [FAIL] $header_name — MISSING"
      echo "         $description"
      [[ -n "$recommended" ]] && echo "         Recommended: $recommended"
      ISSUES=$((ISSUES + 1))
    elif [[ "$severity" == "WARNING" ]]; then
      echo "  [WARN] $header_name — MISSING"
      echo "         $description"
      [[ -n "$recommended" ]] && echo "         Recommended: $recommended"
      WARNINGS=$((WARNINGS + 1))
    else
      echo "  [INFO] $header_name — not set"
      echo "         $description"
    fi
  fi
}

echo "── Security Headers ──"
echo ""

check_header \
  "Strict-Transport-Security" \
  "CRITICAL" \
  "Enforces HTTPS connections. Prevents protocol downgrade attacks." \
  "Strict-Transport-Security: max-age=31536000; includeSubDomains"

check_header \
  "Content-Security-Policy" \
  "CRITICAL" \
  "Prevents XSS by controlling which resources can be loaded." \
  "Content-Security-Policy: default-src 'self'; script-src 'self'"

check_header \
  "X-Content-Type-Options" \
  "CRITICAL" \
  "Prevents MIME-type sniffing attacks." \
  "X-Content-Type-Options: nosniff"

check_header \
  "X-Frame-Options" \
  "CRITICAL" \
  "Prevents clickjacking by controlling iframe embedding." \
  "X-Frame-Options: DENY (or SAMEORIGIN)"

check_header \
  "Referrer-Policy" \
  "WARNING" \
  "Controls how much referrer information is sent with requests." \
  "Referrer-Policy: strict-origin-when-cross-origin"

check_header \
  "Permissions-Policy" \
  "WARNING" \
  "Controls which browser features the page can use (camera, microphone, etc.)." \
  "Permissions-Policy: camera=(), microphone=(), geolocation=()"

check_header \
  "X-XSS-Protection" \
  "INFO" \
  "Legacy XSS filter (modern browsers use CSP instead). Still useful for older browsers." \
  "X-XSS-Protection: 1; mode=block"

echo ""

# --- CORS headers check ---
echo "── CORS Configuration ──"
echo ""

# Make a preflight-like request with an Origin header
CORS_HEADERS="$(curl -sS -H "Origin: https://evil.example.com" -D - -o /dev/null --max-time 10 "$URL" 2>/dev/null || true)"

if echo "$CORS_HEADERS" | grep -qi "access-control-allow-origin.*\*"; then
  echo "  [FAIL] Access-Control-Allow-Origin: * (wildcard)"
  echo "         Wildcard CORS allows any website to make requests to your API."
  echo "         Should be restricted to specific origins."
  ISSUES=$((ISSUES + 1))
elif echo "$CORS_HEADERS" | grep -qi "access-control-allow-origin.*evil.example.com"; then
  echo "  [FAIL] Access-Control-Allow-Origin reflects arbitrary origin"
  echo "         Server is reflecting the Origin header without validation."
  ISSUES=$((ISSUES + 1))
else
  echo "  [PASS] CORS does not allow arbitrary origins"
fi
echo ""

# --- HTTPS check ---
echo "── Transport Security ──"
echo ""

if [[ "$URL" == https://* ]]; then
  echo "  [PASS] URL uses HTTPS"

  # Check if HTTP redirects to HTTPS
  HTTP_URL="${URL/https:/http:}"
  HTTP_REDIRECT="$(curl -sS -o /dev/null -w '%{redirect_url}' --max-time 10 "$HTTP_URL" 2>/dev/null || true)"
  if [[ "$HTTP_REDIRECT" == https://* ]]; then
    echo "  [PASS] HTTP redirects to HTTPS"
  else
    echo "  [WARN] HTTP does not redirect to HTTPS"
    WARNINGS=$((WARNINGS + 1))
  fi
elif [[ "$URL" == http://localhost* ]] || [[ "$URL" == http://127.0.0.1* ]]; then
  echo "  [INFO] Localhost — HTTPS check not applicable"
else
  echo "  [FAIL] URL does not use HTTPS"
  ISSUES=$((ISSUES + 1))
fi
echo ""

# --- Cookie security (if Set-Cookie headers present) ---
echo "── Cookie Security ──"
echo ""

COOKIES="$(grep -i "^set-cookie:" "$HEADERS_FILE" || true)"
if [[ -n "$COOKIES" ]]; then
  while IFS= read -r cookie_line; do
    cookie_name="$(echo "$cookie_line" | sed 's/^[Ss]et-[Cc]ookie:\s*//' | cut -d= -f1 | tr -d ' ')"
    cookie_lower="$(echo "$cookie_line" | tr '[:upper:]' '[:lower:]')"

    if ! echo "$cookie_lower" | grep -q "httponly"; then
      echo "  [WARN] Cookie '$cookie_name' missing HttpOnly flag"
      WARNINGS=$((WARNINGS + 1))
    fi
    if ! echo "$cookie_lower" | grep -q "secure"; then
      if [[ "$URL" != http://localhost* ]] && [[ "$URL" != http://127.0.0.1* ]]; then
        echo "  [WARN] Cookie '$cookie_name' missing Secure flag"
        WARNINGS=$((WARNINGS + 1))
      fi
    fi
    if ! echo "$cookie_lower" | grep -q "samesite"; then
      echo "  [WARN] Cookie '$cookie_name' missing SameSite attribute"
      WARNINGS=$((WARNINGS + 1))
    fi
  done <<< "$COOKIES"

  if [[ $WARNINGS -eq 0 ]]; then
    echo "  [PASS] All cookies have security attributes"
  fi
else
  echo "  [INFO] No Set-Cookie headers in response"
fi
echo ""

# --- Server info disclosure ---
echo "── Information Disclosure ──"
echo ""

SERVER_HEADER="$(grep -i "^server:" "$HEADERS_FILE" | head -1 | sed 's/^[Ss]erver:\s*//' | tr -d '\r' || true)"
if [[ -n "$SERVER_HEADER" ]]; then
  echo "  [WARN] Server header present: $SERVER_HEADER"
  echo "         Consider removing or generalizing to reduce fingerprinting."
  WARNINGS=$((WARNINGS + 1))
else
  echo "  [PASS] No Server header (good — reduces fingerprinting)"
fi

POWERED_BY="$(grep -i "^x-powered-by:" "$HEADERS_FILE" | head -1 | sed 's/^[Xx]-[Pp]owered-[Bb]y:\s*//' | tr -d '\r' || true)"
if [[ -n "$POWERED_BY" ]]; then
  echo "  [WARN] X-Powered-By header present: $POWERED_BY"
  echo "         Remove this header to reduce fingerprinting."
  WARNINGS=$((WARNINGS + 1))
else
  echo "  [PASS] No X-Powered-By header"
fi
echo ""

# Cleanup
rm -f "$HEADERS_FILE"

# Summary
echo "── Summary ──"
echo "Critical issues: $ISSUES"
echo "Warnings:        $WARNINGS"
echo ""
if [[ $ISSUES -eq 0 && $WARNINGS -eq 0 ]]; then
  echo "Result: CLEAN — all security headers present"
  exit 0
elif [[ $ISSUES -eq 0 ]]; then
  echo "Result: PASS with $WARNINGS warning(s)"
  exit 0
else
  echo "Result: $ISSUES CRITICAL ISSUE(S) FOUND"
  exit 1
fi
