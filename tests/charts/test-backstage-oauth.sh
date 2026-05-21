#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== Backstage GitHub OAuth chart tests ==="

dev_values_args=(
  -f deploy/dev/backstage.yaml
)

dev_output=$(helm template backstage "$CHART_DIR" \
  "${dev_values_args[@]}" 2>&1)

assert_contains "Deployment refs single GitHub App existingSecret" "$dev_output" "name: backstage-github-app"
assert_not_contains "OAuth Secret not rendered by dev default" "$dev_output" "AUTH_GITHUB_CLIENT_ID:"
assert_not_contains "GitHub PAT Secret not rendered by dev default" "$dev_output" "GITHUB_TOKEN:"
assert_contains "ConfigMap has runtime config" "$dev_output" "app-config.runtime.yaml:"
assert_contains "ConfigMap has RBAC policies key" "$dev_output" "rbac-policies.csv:"
assert_contains "ConfigMap has users key" "$dev_output" "users.yaml:"
assert_contains "Runtime config uses GitHub Apps form" "$dev_output" "apps:"
assert_contains "Runtime config has GitHub App ID placeholder" "$dev_output" 'appId: ${APP_ID}'
assert_contains "Runtime config has GitHub App client ID placeholder" "$dev_output" 'clientId: ${CLIENT_ID}'
assert_contains "Runtime config has GitHub App client secret placeholder" "$dev_output" 'clientSecret: ${CLIENT_SECRET}'
assert_contains "Runtime config has GitHub App private key placeholder" "$dev_output" 'privateKey: ${PRIVATE_KEY}'
assert_contains "Runtime config has RBAC admin user" "$dev_output" "user:default/itamar-ratson"
assert_contains "Runtime config has absolute RBAC CSV path" "$dev_output" "policies-csv-file: /etc/backstage/rbac/rbac-policies.csv"
assert_contains "Runtime config targets mounted users catalog" "$dev_output" "target: /etc/backstage/rbac/users.yaml"
assert_contains "ConfigMap remains mounted at /etc/backstage" "$dev_output" "mountPath: /etc/backstage"
assert_contains "ConfigMap volume mount remains read only" "$dev_output" "readOnly: true"

report_results "Backstage GitHub OAuth chart"
