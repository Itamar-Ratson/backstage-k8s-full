#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

CHART_DIR="charts/platform/argo-cd"

echo "=== Platform argo-cd render tests ==="

cleanup() {
  rm -rf "$CHART_DIR/charts" "$CHART_DIR/Chart.lock"
}
trap cleanup EXIT

assert_file_exists "wrapper Chart.yaml exists" "$CHART_DIR/Chart.yaml"
assert_git_ignored "dependency archive is gitignored" "$CHART_DIR/charts/argo-cd-9.5.15.tgz"

if output=$(helm dependency build "$CHART_DIR" 2>&1); then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: helm dependency build succeeds"
  echo "$output"
fi

if rendered=$(helm template argo-cd "$CHART_DIR" --namespace argocd -f deploy/dev/argo-cd.yaml 2>&1); then
  assert_contains "renders a StatefulSet" "$rendered" "kind: StatefulSet"
  assert_contains "renders application controller" "$rendered" "app.kubernetes.io/name: argocd-application-controller"
  httproute=$(yq eval 'select(.kind == "HTTPRoute" and .metadata.name == "argo-cd")' <<<"$rendered")
  assert_contains "HTTPRoute hostname is argocd.localtest.me" "$httproute" "argocd.localtest.me"
  assert_contains "HTTPRoute parentRef group is explicit" "$httproute" "group: gateway.networking.k8s.io"
  assert_contains "HTTPRoute parentRef kind is explicit" "$httproute" "kind: Gateway"
  assert_contains "HTTPRoute backendRef group is explicit" "$httproute" "group: \"\""
  assert_contains "HTTPRoute backendRef kind is explicit" "$httproute" "kind: Service"
  assert_contains "HTTPRoute backendRef weight is explicit" "$httproute" "weight: 1"
  assert_contains "ArgoCD server runs insecure behind Gateway" "$rendered" "server.insecure: \"true\""
else
  FAIL=$((FAIL + 1))
  echo "FAIL: helm template succeeds"
  echo "$rendered"
fi

report_results "Platform argo-cd render"
