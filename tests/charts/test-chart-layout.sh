#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== Chart layout tests ==="

for expected_dir in \
  "charts/platform/edge-gateway" \
  "charts/workloads/backstage"; do
  if [ -d "$expected_dir" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: expected chart directory exists"
    echo "  missing: $expected_dir"
  fi
done

for old_dir in \
  "charts/edge-gateway" \
  "charts/backstage"; do
  if [ ! -e "$old_dir" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: old chart directory removed"
    echo "  still present: $old_dir"
  fi
done

report_results "Chart layout"
