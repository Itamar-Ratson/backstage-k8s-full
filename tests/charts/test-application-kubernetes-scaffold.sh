#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source tests/charts/helpers.sh

SKELETON_DIR="templates/application/skeleton/image"
TEMPLATE="$(cat templates/application/template.yaml)"
HELPERS_TEMPLATE="$(cat "$SKELETON_DIR/templates/_helpers.tpl")"
NAMESPACE_TEMPLATE="$(cat "$SKELETON_DIR/templates/namespace.yaml")"
CATALOG_TEMPLATE="$(cat "$SKELETON_DIR/catalog-info.yaml.njk")"
VALUES_TEMPLATE="$(cat "$SKELETON_DIR/values.yaml.njk")"
DEPLOYMENT_TEMPLATE="$(cat "$SKELETON_DIR/templates/deployment.yaml")"

echo "=== Application Kubernetes scaffold tests ==="

assert_contains "template targets workload chart path" "$TEMPLATE" 'targetPath: charts/workloads/${{ parameters.name }}'
assert_not_contains "template does not emit dev values file" "$TEMPLATE" "targetPath: deploy/dev"
assert_path_missing "application dev values skeleton is removed" "templates/application/skeleton-values"
assert_contains "template name is application" "$TEMPLATE" "name: application"
assert_contains "catalog records application template" "$CATALOG_TEMPLATE" "backstage.io/managed-by-template: application"
assert_contains "catalog records generated source paths" "$CATALOG_TEMPLATE" "backstage.io/source-paths: '[\"charts/workloads/\${{ values.name }}\"]'"
assert_contains "catalog identifies scaffolded artifact as Helm chart" "$CATALOG_TEMPLATE" "type: helm-chart"
assert_contains "values skeleton contains image object" "$VALUES_TEMPLATE" "image:"
assert_contains "values skeleton contains image repository" "$VALUES_TEMPLATE" 'repository: ${{ values.repository }}'
assert_contains "values skeleton contains image tag" "$VALUES_TEMPLATE" 'tag: ${{ values.tag }}'
assert_contains "values skeleton contains image pull policy" "$VALUES_TEMPLATE" "pullPolicy: IfNotPresent"
assert_contains "deployment composes image repository and tag" "$DEPLOYMENT_TEMPLATE" 'image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"'
assert_contains "deployment uses image pull policy value" "$DEPLOYMENT_TEMPLATE" 'imagePullPolicy: {{ .Values.image.pullPolicy }}'
assert_contains "helpers scaffold emits kubernetes-id label" "$HELPERS_TEMPLATE" "backstage.io/kubernetes-id: {{ .Chart.Name }}"
assert_contains "catalog scaffold has kubernetes-id annotation" "$CATALOG_TEMPLATE" 'backstage.io/kubernetes-id: ${{ values.name }}'
assert_not_contains "catalog scaffold omits source-location annotation" "$CATALOG_TEMPLATE" "backstage.io/source-location"
assert_not_contains "catalog scaffold omits project slug annotation" "$CATALOG_TEMPLATE" "github.com/project-slug"
assert_contains "scaffold owns its namespace" "$NAMESPACE_TEMPLATE" "kind: Namespace"
assert_contains "scaffold namespace opts into the edge gateway" "$NAMESPACE_TEMPLATE" "gateway-routes: enabled"

report_results "Application Kubernetes scaffold"
