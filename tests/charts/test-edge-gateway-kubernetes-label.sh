#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== Edge gateway Kubernetes label tests ==="

output=$(helm template edge-gateway charts/platform/edge-gateway -f deploy/dev/edge-gateway.yaml 2>&1)

assert_contains "Gateway is rendered" "$output" "kind: Gateway"
assert_contains "Gateway has kubernetes-id label" "$output" "backstage.io/kubernetes-id: edge-gateway"

report_results "Edge gateway Kubernetes labels"
