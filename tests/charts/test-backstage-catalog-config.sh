#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== Catalog config tests ==="

# Test 1: Discovery URL rendered in ConfigMap
output=$(helm template backstage "$CHART_DIR" -f "$FIXTURES/catalog-discovery.yaml" 2>&1)
assert_contains "ConfigMap has catalog url location type" "$output" "type: url"
assert_contains "ConfigMap has discovery glob target" "$output" "**/*catalog-info.yaml"
assert_contains "ConfigMap uses GitHub owner placeholder" "$output" '${GITHUB_OWNER}'
assert_contains "ConfigMap uses GitHub repo placeholder" "$output" '${GITHUB_REPO}'

# Test 2: Default values render expanded catalog rules allowlist
assert_contains "catalog rules include Component" "$output" "Component"
assert_contains "catalog rules include Domain" "$output" "Domain"
assert_contains "catalog rules include User" "$output" "User"
assert_contains "catalog rules include Group" "$output" "Group"

# Test 3: Default values without overlay have empty locations
default_output=$(helm template backstage "$CHART_DIR" -f "$FIXTURES/minimal.yaml" 2>&1)
assert_contains "default catalog rules include Domain" "$default_output" "Domain"
assert_contains "default catalog rules include User" "$default_output" "User"
assert_contains "default catalog rules include Group" "$default_output" "Group"
assert_not_contains "default has no file locations" "$default_output" "target: ./examples/"

report_results "Catalog config"
