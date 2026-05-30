#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../charts/helpers.sh
source "$(dirname "$0")/../charts/helpers.sh"

policy_file="${RBAC_POLICIES_CSV:-backstage/rbac-policies.csv}"
policy_csv=$(cat "$policy_file")
former_admin_user="$(printf '%s-%s' itamar ratson)"
former_admin_binding="g, user:default/${former_admin_user}, role:default/platform-admin"

echo "=== RBAC policies CSV tests ==="

assert_contains "viewer can read catalog entities" "$policy_csv" "p, role:default/viewer, catalog-entity, read, allow"
assert_contains "viewer can read scaffolder templates" "$policy_csv" "p, role:default/viewer, scaffolder-template, read, allow"
assert_not_contains "viewer cannot execute scaffolder actions" "$policy_csv" "p, role:default/viewer, scaffolder-action, use, allow"
assert_not_contains "platform-admin no longer relies on wildcard policy" "$policy_csv" "p, role:default/platform-admin, *, *, allow"
assert_contains "platform-admin can create catalog entities" "$policy_csv" "p, role:default/platform-admin, catalog-entity, create, allow"
assert_contains "platform-admin can execute scaffolder actions" "$policy_csv" "p, role:default/platform-admin, scaffolder-action, use, allow"
assert_contains "platform-admin can manage RBAC policies" "$policy_csv" "p, role:default/platform-admin, policy-entity, update, allow"
assert_contains "guest is assigned viewer" "$policy_csv" "g, user:default/guest, role:default/viewer"
assert_not_contains "committed CSV omits former personal platform-admin binding" "$policy_csv" "$former_admin_binding"

report_results "RBAC policies CSV"
