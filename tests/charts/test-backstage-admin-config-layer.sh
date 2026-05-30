#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== Backstage admin config layer chart tests ==="

test_owner="test-owner"

without_admin=$(helm template backstage "$CHART_DIR" \
  -f deploy/dev/backstage.yaml \
  --set-string rbac.adminUser="" 2>&1)

without_admin_config_count=$(grep -cF -- '- "--config"' <<<"$without_admin")
assert_not_contains "Admin app config key omitted when adminUser is empty" "$without_admin" "app-config.admin.yaml:"
assert_not_contains "Admin app config arg omitted when adminUser is empty" "$without_admin" "/etc/backstage/app-config.admin.yaml"
assert_contains "Deployment has exactly two config args without adminUser" "count:${without_admin_config_count}" "count:2"

with_admin=$(helm template backstage "$CHART_DIR" \
  -f deploy/dev/backstage.yaml \
  --set-string "rbac.adminUser=${test_owner}" 2>&1)

with_admin_config_count=$(grep -cF -- '- "--config"' <<<"$with_admin")
assert_contains "Admin app config key rendered when adminUser is set" "$with_admin" "app-config.admin.yaml:"
assert_contains "Admin app config grants derived admin user" "$with_admin" "name: user:default/${test_owner}"
assert_contains "Deployment loads admin app config when adminUser is set" "$with_admin" "/etc/backstage/app-config.admin.yaml"
assert_contains "Deployment has exactly three config args with adminUser" "count:${with_admin_config_count}" "count:3"

report_results "Backstage admin config layer chart"
