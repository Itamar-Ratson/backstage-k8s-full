#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../charts/helpers.sh
source "$(dirname "$0")/../charts/helpers.sh"

echo "=== GitHub admin auth config tests ==="

backend_index_path="backstage/packages/backend/src/index.ts"
app_config_path="backstage/app-config.yaml"
local_config_example_path="backstage/app-config.local.example.yaml"
local_config_path="backstage/app-config.local.yaml"
rbac_policies_path="backstage/rbac-policies.csv"
users_path="users.yaml"
sign_in_module_path="backstage/packages/app/src/modules/signIn/index.tsx"
app_path="backstage/packages/app/src/App.tsx"
dev_values_path="deploy/dev/backstage.yaml"
chart_values_path="charts/workloads/backstage/values.yaml"

backend_index=$(cat "$backend_index_path")
app_config=$(cat "$app_config_path")
rbac_policies=$(cat "$rbac_policies_path")
sign_in_module=$(cat "$sign_in_module_path" 2>/dev/null || true)
app_tsx=$(cat "$app_path")
dev_values=$(cat "$dev_values_path")
chart_values=$(cat "$chart_values_path")

assert_contains "GitHub auth backend module is registered" "$backend_index" "backend.add(import('@backstage/plugin-auth-backend-module-github-provider'))"
assert_contains "GitHub auth provider is declared" "$app_config" "github:"
assert_contains "GitHub username resolver is configured" "$app_config" "resolver: usernameMatchingUserEntityName"
assert_not_contains "Base app config does not contain GitHub client ID" "$app_config" "clientId:"
assert_not_contains "Base app config does not contain GitHub client secret" "$app_config" "clientSecret:"
assert_not_contains "Base app config does not contain bootstrap admin users" "$app_config" "admin:"

tracked_files=$(git ls-files --cached)
repo_visible_files=$(git ls-files --cached --others --exclude-standard)

assert_contains "users.yaml is tracked" "$tracked_files" "$users_path"
assert_not_contains "local config example is not tracked" "$tracked_files" "$local_config_example_path"
assert_not_contains "real local config is not tracked or unignored" "$repo_visible_files" "$local_config_path"

users_yaml=$(cat "$users_path" 2>/dev/null || true)
assert_contains "admin user entity is named itamar-ratson" "$users_yaml" "name: itamar-ratson"
assert_contains "admin user display name is configured" "$users_yaml" "displayName: Itamar Ratson"
assert_contains "admin user has empty group membership" "$users_yaml" "memberOf: []"

assert_contains "admin user is assigned platform-admin" "$rbac_policies" "g, user:default/itamar-ratson, role:default/platform-admin"

assert_contains "dev values use GitHub App client ID env placeholder" "$dev_values" 'clientId: ${CLIENT_ID}'
assert_contains "dev values use GitHub App client secret env placeholder" "$dev_values" 'clientSecret: ${CLIENT_SECRET}'
assert_contains "dev values use GitHub App ID env placeholder" "$dev_values" 'appId: ${APP_ID}'
assert_contains "dev values use GitHub App private key env placeholder" "$dev_values" 'privateKey: ${PRIVATE_KEY}'
assert_contains "dev values configure RBAC admin user" "$dev_values" "user:default/itamar-ratson"
assert_contains "dev values override RBAC CSV path" "$dev_values" "/etc/backstage/rbac/rbac-policies.csv"
assert_contains "dev values catalog users from mounted file" "$dev_values" "target: /etc/backstage/rbac/users.yaml"
assert_contains "dev values reference GitHub App existing secret" "$dev_values" "existingSecret: backstage-github-app"
assert_contains "chart values declare OAuth section" "$chart_values" "oauth:"
assert_contains "chart values declare OAuth GitHub section" "$chart_values" "github:"
assert_contains "chart values default OAuth creation off" "$chart_values" "create: false"
assert_contains "chart values declare OAuth existingSecret" "$chart_values" "existingSecret: backstage-github-app"

assert_contains "sign-in module exports signInModule" "$sign_in_module" "export const signInModule"
assert_contains "sign-in module uses SignInPageBlueprint" "$sign_in_module" "SignInPageBlueprint"
assert_contains "sign-in module uses GitHub auth api ref" "$sign_in_module" "githubAuthApiRef"
assert_contains "sign-in module keeps guest provider" "$sign_in_module" "'guest'"
assert_contains "sign-in module declares GitHub provider id" "$sign_in_module" "'github-auth-provider'"
assert_contains "App imports signInModule" "$app_tsx" "import { signInModule } from './modules/signIn';"
assert_contains "App registers signInModule in features" "$app_tsx" "signInModule,"

report_results "GitHub admin auth config"
