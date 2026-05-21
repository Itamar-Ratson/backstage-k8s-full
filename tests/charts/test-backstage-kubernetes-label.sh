#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== Backstage Kubernetes label tests ==="

output=$(helm template backstage "$CHART_DIR" -f deploy/dev/backstage.yaml 2>&1)

assert_contains "Deployment has kubernetes-id label" "$output" "kind: Deployment"
assert_contains "Backstage resources have kubernetes-id label" "$output" "backstage.io/kubernetes-id: backstage"

for resource in \
  "name: backstage" \
  "name: backstage-app-config" \
  "name: backstage-rbac" \
  "kind: ServiceAccount" \
  "kind: HTTPRoute" \
  "name: backstage-postgres" \
  "name: postgres" \
  "kind: PersistentVolumeClaim"; do
  assert_contains "Rendered output includes $resource" "$output" "$resource"
done

label_count=$(grep -c "backstage.io/kubernetes-id: backstage" <<<"$output" || true)
assert_contains "kubernetes-id label appears on chart-rendered resources" "count:$label_count" "count:14"

report_results "Backstage Kubernetes labels"
