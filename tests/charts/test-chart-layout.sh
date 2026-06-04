#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== Chart layout tests ==="

for expected_dir in \
  "charts/platform/sealed-secrets" \
  "charts/platform/edge-gateway" \
  "charts/workloads/backstage"; do
  assert_directory_exists "expected chart directory exists" "$expected_dir"
done

for old_dir in \
  "charts/edge-gateway" \
  "charts/backstage"; do
  assert_path_missing "old chart directory removed" "$old_dir"
done

report_results "Chart layout"
