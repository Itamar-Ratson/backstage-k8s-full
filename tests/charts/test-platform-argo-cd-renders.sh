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

if git check-ignore -q "$CHART_DIR/charts/argo-cd-9.5.15.tgz"; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: dependency archive is gitignored"
  echo "  expected ignored: $CHART_DIR/charts/argo-cd-9.5.15.tgz"
fi

if output=$(helm dependency build "$CHART_DIR" 2>&1); then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: helm dependency build succeeds"
  echo "$output"
fi

if rendered=$(helm template argo-cd "$CHART_DIR" --namespace argocd 2>&1); then
  assert_contains "renders a StatefulSet" "$rendered" "kind: StatefulSet"
  assert_contains "renders application controller" "$rendered" "app.kubernetes.io/name: argocd-application-controller"
else
  FAIL=$((FAIL + 1))
  echo "FAIL: helm template succeeds"
  echo "$rendered"
fi

report_results "Platform argo-cd render"
