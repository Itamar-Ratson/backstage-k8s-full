#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== ConfigMap app-config tests ==="

# Test 1: Default values produce a ConfigMap with appConfig content
output=$(helm template backstage "$CHART_DIR" -f "$FIXTURES/minimal.yaml" 2>&1)
assert_contains "ConfigMap is rendered" "$output" "kind: ConfigMap"
assert_contains "ConfigMap has runtime config filename" "$output" "app-config.runtime.yaml"
assert_contains "ConfigMap preserves POSTGRES_HOST substitution" "$output" '${POSTGRES_HOST}'
assert_contains "ConfigMap preserves POSTGRES_PORT substitution" "$output" '${POSTGRES_PORT}'
assert_contains "ConfigMap preserves POSTGRES_USER substitution" "$output" '${POSTGRES_USER}'
assert_contains "ConfigMap preserves POSTGRES_PASSWORD substitution" "$output" '${POSTGRES_PASSWORD}'
assert_contains "ConfigMap has app baseUrl" "$output" "baseUrl: http://backstage.localtest.me:8080"
assert_contains "ConfigMap has backend listen" "$output" 'listen: :7007'
assert_contains "ConfigMap has guest auth" "$output" "dangerouslyAllowOutsideDevelopment: true"

# Test 2: Deployment mounts the ConfigMap
assert_contains "Deployment has volume mount path" "$output" "/etc/backstage"
assert_contains "Deployment has app-config volume" "$output" "name: app-config"
assert_contains "Deployment references configmap" "$output" "backstage-app-config"

# Test 3: Deployment uses explicit command/args with --config for runtime config
assert_contains "Deployment has node command" "$output" 'command:'
assert_contains "Deployment has --config arg for runtime" "$output" "/etc/backstage/app-config.runtime.yaml"
assert_contains "Deployment has --config arg for defaults" "$output" "app-config.yaml"

# Test 4: Deployment has checksum annotation
assert_contains "Deployment has checksum annotation" "$output" "checksum/config:"

# Test 5: Custom appConfig override appears in rendered ConfigMap
custom_output=$(helm template backstage "$CHART_DIR" \
  -f "$FIXTURES/minimal.yaml" \
  --set "appConfig.app.baseUrl=http://custom.example.com" 2>&1)
assert_contains "Custom baseUrl in ConfigMap" "$custom_output" "baseUrl: http://custom.example.com"

# Test 6: Checksum changes when appConfig changes
checksum1=$(grep "checksum/config:" <<<"$output" | awk '{print $2}')
checksum2=$(grep "checksum/config:" <<<"$custom_output" | awk '{print $2}')
if [ "$checksum1" != "$checksum2" ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: checksum should change when appConfig changes"
fi

report_results "ConfigMap"
