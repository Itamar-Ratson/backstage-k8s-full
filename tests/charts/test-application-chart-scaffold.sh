#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source tests/charts/helpers.sh

CHART_SKELETON_DIR="templates/application/skeleton/chart"
DEPLOY_DEV_SKELETON_DIR="templates/application/skeleton/chart-deploy-dev"
TEMPLATE="$(cat templates/application/template.yaml)"
CHART_TEMPLATE="$(cat "$CHART_SKELETON_DIR/Chart.yaml.njk" 2>/dev/null || true)"
VALUES_TEMPLATE="$(cat "$CHART_SKELETON_DIR/values.yaml.njk" 2>/dev/null || true)"
CATALOG_TEMPLATE="$(cat "$CHART_SKELETON_DIR/catalog-info.yaml.njk" 2>/dev/null || true)"
DEPLOY_DEV_TEMPLATE="$(cat "$DEPLOY_DEV_SKELETON_DIR/values.yaml.njk" 2>/dev/null || true)"

echo "=== Application chart scaffold tests ==="

assert_contains "template declares sourceType" "$TEMPLATE" "sourceType:"
assert_contains "template supports image source type" "$TEMPLATE" "- image"
assert_contains "template supports chart source type" "$TEMPLATE" "- chart"
assert_directory_exists "chart-case skeleton exists" "$CHART_SKELETON_DIR"

assert_contains "chart skeleton declares dependencies" "$CHART_TEMPLATE" "dependencies:"
assert_contains "chart skeleton aliases upstream chart" "$CHART_TEMPLATE" "alias: app"
assert_contains "chart skeleton parameterizes dependency name" "$CHART_TEMPLATE" 'name: ${{ values.chart }}'
assert_contains "chart skeleton parameterizes dependency version" "$CHART_TEMPLATE" 'version: ${{ values.targetRevision }}'
assert_contains "chart skeleton parameterizes dependency repository" "$CHART_TEMPLATE" 'repository: ${{ values.repoURL }}'

assert_contains "chart values expose alias scope" "$VALUES_TEMPLATE" "app: {}"
assert_contains "chart values explain discovery command" "$VALUES_TEMPLATE" "helm show values"
assert_contains "chart values mention injected image repository" "$VALUES_TEMPLATE" "image.repository"
assert_contains "chart values mention injected admin user" "$VALUES_TEMPLATE" "rbac.adminUser"

assert_contains "chart catalog records helm chart type" "$CATALOG_TEMPLATE" "type: helm-chart"
assert_contains "chart catalog records application template" "$CATALOG_TEMPLATE" "backstage.io/managed-by-template: application"
assert_contains "chart catalog records generated source paths" "$CATALOG_TEMPLATE" "backstage.io/source-paths: '[\"charts/workloads/\${{ values.name }}\"]'"
assert_contains "chart catalog uses Helm instance selector" "$CATALOG_TEMPLATE" "backstage.io/kubernetes-label-selector: 'app.kubernetes.io/instance=\${{ values.name }}'"
assert_not_contains "chart catalog omits kubernetes-id annotation" "$CATALOG_TEMPLATE" "backstage.io/kubernetes-id"

assert_path_missing "chart skeleton has no templates subdir" "$CHART_SKELETON_DIR/templates"
assert_no_matching_paths "chart skeleton omits _helpers.tpl" "$CHART_SKELETON_DIR" "_helpers.tpl"

assert_contains "template fetches chart skeleton" "$TEMPLATE" "url: ./skeleton/chart"
assert_contains "template writes deploy dev placeholder" "$TEMPLATE" 'targetPath: deploy/dev/${{ parameters.name }}.yaml'
assert_contains "template documents ci-pipeline caveat" "$TEMPLATE" "ci-pipeline does not compose with chart-based apps"
assert_contains "template documents upstream networking ownership" "$TEMPLATE" "Networking and ingress are the upstream chart's responsibility"
assert_contains "template documents dead injected values" "$TEMPLATE" "image.repository and rbac.adminUser injected by workloads-appset are inert dead values"
assert_directory_exists "deploy dev placeholder skeleton exists" "$DEPLOY_DEV_SKELETON_DIR"
assert_contains "deploy dev placeholder exposes alias scope" "$DEPLOY_DEV_TEMPLATE" "app: {}"
assert_contains "deploy dev placeholder explains alias" "$DEPLOY_DEV_TEMPLATE" "alias declared in charts/workloads/"
assert_path_missing "chart skeleton does not commit Chart.lock" "$CHART_SKELETON_DIR/Chart.lock"
assert_path_missing "chart skeleton does not vendor dependency archives" "$CHART_SKELETON_DIR/charts"

report_results "Application chart scaffold"
