#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== Backstage HTTPRoute Gateway API defaults tests ==="

rendered=$(helm template backstage "$CHART_DIR" -f deploy/dev/backstage.yaml)
httproute=$(yq eval 'select(.kind == "HTTPRoute" and .metadata.name == "backstage")' <<<"$rendered")

assert_contains "HTTPRoute parentRef group is explicit" "$httproute" "group: gateway.networking.k8s.io"
assert_contains "HTTPRoute parentRef kind is explicit" "$httproute" "kind: Gateway"
assert_contains "HTTPRoute backendRef group is explicit" "$httproute" "group: \"\""
assert_contains "HTTPRoute backendRef kind is explicit" "$httproute" "kind: Service"
assert_contains "HTTPRoute backendRef weight is explicit" "$httproute" "weight: 1"

report_results "Backstage HTTPRoute Gateway API defaults"
