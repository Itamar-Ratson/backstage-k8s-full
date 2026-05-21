#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== GitHub App auth tests ==="

# Test 1: dev values use the single GitHub App Secret and do not render GitHub credentials
output=$(helm template backstage "$CHART_DIR" -f deploy/dev/backstage.yaml 2>&1)
assert_contains "deployment refs GitHub App existingSecret" "$output" "name: backstage-github-app"
assert_not_contains "GitHub App Secret is not rendered" "$output" "APP_ID:"
assert_not_contains "legacy PAT Secret data key is not rendered" "$output" "GITHUB_TOKEN:"
assert_not_contains "legacy OAuth client ID key is not rendered" "$output" "AUTH_GITHUB_CLIENT_ID:"
assert_not_contains "legacy OAuth client secret key is not rendered" "$output" "AUTH_GITHUB_CLIENT_SECRET:"

# Test 2: create=false with existingSecret — no GitHub Secret rendered, Deployment references supplied name
output=$(helm template backstage "$CHART_DIR" -f "$FIXTURES/github-existing-secret.yaml" 2>&1)
assert_contains "deployment refs existingSecret" "$output" "name: my-gh-secret"
assert_not_contains "github create=false should not render PAT Secret data key" "$output" "GITHUB_TOKEN:"

echo ""
echo "=== Postgres auth hybrid tests ==="

# Test 4: create=true renders postgres Secret, both deployments reference it
output=$(helm template backstage "$CHART_DIR" -f "$FIXTURES/postgres-create-true.yaml" 2>&1)
assert_contains "postgres create=true renders Secret" "$output" "name: backstage-postgres"
assert_contains "postgres Secret has POSTGRES_USER" "$output" "POSTGRES_USER:"
assert_contains "postgres Secret has POSTGRES_PASSWORD" "$output" "POSTGRES_PASSWORD:"
assert_contains "postgres Secret has POSTGRES_HOST" "$output" "POSTGRES_HOST:"

# Test 5: create=false with existingSecret — no postgres Secret rendered, Deployment references supplied name
output=$(helm template backstage "$CHART_DIR" -f "$FIXTURES/postgres-existing-secret.yaml" 2>&1)
assert_contains "backstage deployment refs pg existingSecret" "$output" "name: my-pg-secret"
assert_not_contains "postgres create=false should not render postgres Secret data keys" "$output" "POSTGRES_USER:"

# Test 6: create=true with empty password fails with required message
assert_fails "postgres empty password fails" "postgres.auth.password is required" \
  helm template backstage "$CHART_DIR" -f "$FIXTURES/postgres-create-empty-password.yaml"

echo ""
echo "=== Postgres toggle tests ==="

# Test 7: postgres.enabled=true renders Deployment, Service, PVC
output=$(helm template backstage "$CHART_DIR" -f "$FIXTURES/postgres-create-true.yaml" 2>&1)
deploy_count=$(echo "$output" | grep -c "kind: Deployment" || true)
assert_contains "postgres enabled has 2 Deployments" "count:$deploy_count" "count:2"
assert_contains "postgres Service present" "$output" "name: postgres"
assert_contains "postgres PVC present" "$output" "kind: PersistentVolumeClaim"

# Test 8: postgres.enabled=false — no postgres Deployment, Service, PVC, or Secret
output=$(helm template backstage "$CHART_DIR" -f "$FIXTURES/postgres-disabled.yaml" 2>&1)
deploy_count=$(echo "$output" | grep -c "kind: Deployment" || true)
assert_contains "postgres disabled has 1 Deployment" "count:$deploy_count" "count:1"
assert_not_contains "no PVC when postgres disabled" "$output" "kind: PersistentVolumeClaim"
assert_not_contains "no postgres Secret when disabled" "$output" "POSTGRES_USER:"
assert_contains "backstage refs external pg secret" "$output" "name: external-pg-secret"

report_results "Secrets/postgres"
