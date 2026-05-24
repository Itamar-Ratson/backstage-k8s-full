#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

CHART_DIR="charts/platform/envoy-gateway"

echo "=== Platform envoy-gateway render tests ==="

cleanup() {
  rm -rf "$CHART_DIR/charts" "$CHART_DIR/Chart.lock"
}
trap cleanup EXIT

assert_file_exists "wrapper Chart.yaml exists" "$CHART_DIR/Chart.yaml"
assert_git_ignored "dependency archive is gitignored" "$CHART_DIR/charts/gateway-helm-v1.8.0.tgz"

if output=$(helm dependency build "$CHART_DIR" 2>&1); then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: helm dependency build succeeds"
  echo "$output"
fi

if rendered=$(helm template envoy-gateway "$CHART_DIR" \
  --namespace envoy-gateway-system \
  -f deploy/dev/envoy-gateway.yaml 2>&1); then
  assert_contains "renders a Deployment" "$rendered" "kind: Deployment"
  assert_contains "renders envoy-gateway controller" "$rendered" "app.kubernetes.io/name: gateway-helm"
  assert_contains "renders eg-lb GatewayClass" "$rendered" "name: eg-lb"
  assert_contains "renders LoadBalancer Envoy Service patch" "$rendered" "type: LoadBalancer"
  assert_contains "renders pinned Envoy loadBalancerIP" "$rendered" "loadBalancerIP: 172.18.0.250"
  assert_contains "renders IPv4 Service family" "$rendered" "ipFamilies:"
  assert_contains "renders IPv4 Service family value" "$rendered" "- IPv4"
  assert_not_contains "rendered Envoy config has no NodePort" "$rendered" "nodePort: 30080"
else
  FAIL=$((FAIL + 1))
  echo "FAIL: helm template succeeds"
  echo "$rendered"
fi

report_results "Platform envoy-gateway render"
