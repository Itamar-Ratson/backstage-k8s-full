#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source tests/charts/helpers.sh

SKELETON_DIR="templates/application/skeleton"
TEMPLATE="$(cat templates/application/template.yaml)"
HELPERS_TEMPLATE="$(cat "$SKELETON_DIR/templates/_helpers.tpl")"
NAMESPACE_TEMPLATE="$(cat "$SKELETON_DIR/templates/namespace.yaml")"
CATALOG_TEMPLATE="$(cat "$SKELETON_DIR/catalog-info.yaml.njk")"
DEPLOY_TEMPLATE="$(cat "templates/application/skeleton-values/\${{ values.name }}.yaml.njk" 2>/dev/null || true)"

echo "=== Application Kubernetes scaffold tests ==="

assert_contains "template targets workload chart path" "$TEMPLATE" 'targetPath: charts/workloads/${{ parameters.name }}'
assert_contains "template emits dev values file" "$TEMPLATE" "targetPath: deploy/dev"
assert_contains "template name is application" "$TEMPLATE" "name: application"
assert_contains "catalog records application template" "$CATALOG_TEMPLATE" "backstage.io/managed-by-template: application"
assert_contains "catalog records generated source paths" "$CATALOG_TEMPLATE" "backstage.io/source-paths: '[\"charts/workloads/\${{ values.name }}\",\"deploy/dev/\${{ values.name }}.yaml\"]'"
assert_contains "dev values skeleton contains image" "$DEPLOY_TEMPLATE" 'image: ${{ values.image }}'
assert_contains "dev values skeleton contains host" "$DEPLOY_TEMPLATE" 'host: ${{ values.host }}'
assert_contains "dev values skeleton contains port" "$DEPLOY_TEMPLATE" 'port: ${{ values.port }}'
assert_contains "helpers scaffold emits kubernetes-id label" "$HELPERS_TEMPLATE" "backstage.io/kubernetes-id: {{ .Chart.Name }}"
assert_contains "catalog scaffold has kubernetes-id annotation" "$CATALOG_TEMPLATE" 'backstage.io/kubernetes-id: ${{ values.name }}'
assert_contains "catalog source-location uses workload path" "$CATALOG_TEMPLATE" 'tree/main/charts/workloads/${{ values.name }}/'
assert_contains "scaffold owns its namespace" "$NAMESPACE_TEMPLATE" "kind: Namespace"
assert_contains "scaffold namespace opts into the edge gateway" "$NAMESPACE_TEMPLATE" "gateway-routes: enabled"

report_results "Application Kubernetes scaffold"
