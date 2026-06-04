#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

CHART_DIR="charts/platform/sealed-secrets"

echo "=== Platform sealed-secrets render tests ==="

cleanup() {
  rm -rf "$CHART_DIR/charts" "$CHART_DIR/Chart.lock"
}
trap cleanup EXIT

assert_file_exists "wrapper Chart.yaml exists" "$CHART_DIR/Chart.yaml"
assert_git_ignored "dependency archive is gitignored" "$CHART_DIR/charts/sealed-secrets-2.18.6.tgz"
assert_file_exists "catalog-info exists" "$CHART_DIR/catalog-info.yaml"
assert_file_exists "mkdocs config exists" "$CHART_DIR/mkdocs.yaml"
assert_file_exists "docs index exists" "$CHART_DIR/docs/index.md"

if output=$(helm dependency build "$CHART_DIR" 2>&1); then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: helm dependency build succeeds"
  echo "$output"
fi

if rendered=$(helm template sealed-secrets "$CHART_DIR" --namespace sealed-secrets -f deploy/dev/sealed-secrets.yaml 2>&1); then
  assert_contains "renders a Deployment" "$rendered" "kind: Deployment"
  assert_contains "renders sealed-secrets controller" "$rendered" "app.kubernetes.io/name: sealed-secrets"
  assert_contains "controller runs in sealed-secrets namespace" "$rendered" "namespace: sealed-secrets"
else
  FAIL=$((FAIL + 1))
  echo "FAIL: helm template succeeds"
  echo "$rendered"
fi

docs=$(sed -n '1,$p' "$CHART_DIR/docs/index.md" 2>/dev/null || true)
assert_contains "docs mention cluster recreate persistence" "$docs" "kind delete cluster && terraform apply"
assert_contains "docs mention terraform destroy invalidation" "$docs" "terraform destroy"
assert_contains "docs mention taint invalidation" "$docs" "terraform taint tls_private_key.sealed_secrets"
assert_contains "docs mention controller rotation preserves old keys" "$docs" "scheduled key rotation"

report_results "Platform sealed-secrets render"
