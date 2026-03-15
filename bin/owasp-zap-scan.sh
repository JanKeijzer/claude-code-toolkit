#!/usr/bin/env bash
set -euo pipefail

# Run OWASP ZAP baseline scan against a target URL.
# Uses the official ZAP Docker image for a passive baseline scan.
#
# Usage: owasp-zap-scan.sh <target-url> [output-dir]
# Example: owasp-zap-scan.sh https://apptest.polyamoriematch.nl
#          owasp-zap-scan.sh http://localhost:3000 /tmp/zap-results
#
# Prerequisites: Docker must be running.
# The scan uses zaproxy/zap-stable and runs a baseline (passive) scan.

TARGET="${1:-}"
OUTPUT_DIR="${2:-/tmp/zap-results}"

if [[ -z "$TARGET" ]]; then
  echo "Usage: owasp-zap-scan.sh <target-url> [output-dir]" >&2
  echo "Example: owasp-zap-scan.sh https://apptest.polyamoriematch.nl" >&2
  exit 2
fi

# Check Docker is available
if ! command -v docker &>/dev/null; then
  echo "Error: docker is not installed or not in PATH" >&2
  exit 2
fi

if ! docker info &>/dev/null 2>&1; then
  echo "Error: Docker daemon is not running" >&2
  exit 2
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
REPORT_HTML="$OUTPUT_DIR/zap-report-$TIMESTAMP.html"
REPORT_JSON="$OUTPUT_DIR/zap-report-$TIMESTAMP.json"
REPORT_MD="$OUTPUT_DIR/zap-report-$TIMESTAMP.md"

echo "OWASP ZAP Baseline Scan"
echo "=================================================="
echo "Target:  $TARGET"
echo "Output:  $OUTPUT_DIR"
echo "Reports: HTML + JSON + Markdown"
echo ""

# Determine network mode
# If targeting localhost, use host network so ZAP container can reach it
NETWORK_ARGS=""
if [[ "$TARGET" == *"localhost"* ]] || [[ "$TARGET" == *"127.0.0.1"* ]]; then
  NETWORK_ARGS="--network host"
  echo "Note: Using host network mode for localhost target"
  echo ""
fi

echo "Starting ZAP baseline scan (this may take 2-5 minutes)..."
echo ""

# Pull latest ZAP image if not present
docker pull zaproxy/zap-stable --quiet 2>/dev/null || true

# Run ZAP baseline scan
# -t: target URL
# -J: JSON report filename
# -w: Markdown report filename
# -r: HTML report filename
# -I: don't return failure codes for warnings (only for errors)
# -d: show debug messages
docker run --rm \
  $NETWORK_ARGS \
  -v "$OUTPUT_DIR:/zap/wrk:rw" \
  -u "$(id -u):$(id -g)" \
  zaproxy/zap-stable \
  zap-baseline.py \
  -t "$TARGET" \
  -J "zap-report-$TIMESTAMP.json" \
  -w "zap-report-$TIMESTAMP.md" \
  -r "zap-report-$TIMESTAMP.html" \
  -I \
  2>&1 | tee "$OUTPUT_DIR/zap-scan-$TIMESTAMP.log"

SCAN_EXIT=$?

echo ""
echo "=================================================="
echo ""

# Parse results from JSON report
if [[ -f "$REPORT_JSON" ]]; then
  echo "── Findings Summary ──"
  echo ""

  # Count alerts by risk level
  python3 -c "
import json, sys

try:
    with open('$REPORT_JSON') as f:
        data = json.load(f)

    alerts = data.get('site', [{}])[0].get('alerts', []) if data.get('site') else []

    high = sum(1 for a in alerts if a.get('riskcode') == '3')
    medium = sum(1 for a in alerts if a.get('riskcode') == '2')
    low = sum(1 for a in alerts if a.get('riskcode') == '1')
    info = sum(1 for a in alerts if a.get('riskcode') == '0')

    print(f'  High risk:   {high}')
    print(f'  Medium risk: {medium}')
    print(f'  Low risk:    {low}')
    print(f'  Info:        {info}')
    print()

    # Show high and medium alerts
    for a in sorted(alerts, key=lambda x: int(x.get('riskcode', 0)), reverse=True):
        risk = int(a.get('riskcode', 0))
        if risk >= 2:
            risk_label = 'HIGH' if risk == 3 else 'MEDIUM'
            name = a.get('name', 'Unknown')
            count = a.get('count', '?')
            desc = a.get('desc', '')[:120]
            print(f'  [{risk_label}] {name} ({count} instances)')
            print(f'           {desc}')
            solution = a.get('solution', '')[:120]
            if solution:
                print(f'           Fix: {solution}')
            print()
except Exception as e:
    print(f'  Could not parse JSON report: {e}', file=sys.stderr)
" 2>/dev/null || echo "  Could not parse JSON report"

else
  echo "  JSON report not generated — check scan log for errors."
fi

echo "── Reports ──"
echo ""
[[ -f "$REPORT_HTML" ]] && echo "  HTML:     $REPORT_HTML"
[[ -f "$REPORT_JSON" ]] && echo "  JSON:     $REPORT_JSON"
[[ -f "$REPORT_MD" ]] && echo "  Markdown: $REPORT_MD"
echo "  Log:      $OUTPUT_DIR/zap-scan-$TIMESTAMP.log"
echo ""

# Summary
echo "── Summary ──"
if [[ $SCAN_EXIT -eq 0 ]]; then
  echo "Result: PASS — no high-risk findings"
  exit 0
elif [[ $SCAN_EXIT -eq 1 ]]; then
  echo "Result: WARNINGS — review findings above"
  exit 0
elif [[ $SCAN_EXIT -eq 2 ]]; then
  echo "Result: FAILURES — high-risk issues found, action required"
  exit 1
else
  echo "Result: SCAN ERROR (exit code: $SCAN_EXIT) — check log file"
  exit 1
fi
