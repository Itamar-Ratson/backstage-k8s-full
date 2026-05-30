#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== Backstage RBAC admin user chart tests ==="

test_owner="test-owner"
admin_binding="g, user:default/${test_owner}, role:default/platform-admin"

without_admin=$(helm template backstage "$CHART_DIR" \
  -f deploy/dev/backstage.yaml \
  --set-string rbac.adminUser="" 2>&1)

assert_contains "RBAC ConfigMap preserves platform-admin policy definitions" "$without_admin" "p, role:default/platform-admin, policy-entity, update, allow"
assert_contains "RBAC ConfigMap preserves guest viewer binding" "$without_admin" "g, user:default/guest, role:default/viewer"
assert_not_matches "RBAC ConfigMap omits platform-admin user binding when adminUser is empty" "$without_admin" 'g, user:default/[^,]+, role:default/platform-admin'

with_admin=$(helm template backstage "$CHART_DIR" \
  -f deploy/dev/backstage.yaml \
  --set-string "rbac.adminUser=${test_owner}" 2>&1)

assert_contains "RBAC ConfigMap preserves platform-admin policy definitions with adminUser" "$with_admin" "p, role:default/platform-admin, policy-entity, update, allow"
assert_contains "RBAC ConfigMap preserves guest viewer binding with adminUser" "$with_admin" "g, user:default/guest, role:default/viewer"
assert_contains "RBAC ConfigMap appends derived platform-admin user binding" "$with_admin" "$admin_binding"

report_results "Backstage RBAC admin user chart"
