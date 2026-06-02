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
NAMESPACE_TEMPLATE="$(cat "$CHART_SKELETON_DIR/templates/namespace.yaml" 2>/dev/null || true)"
HTTPROUTE_TEMPLATE="$(cat "$CHART_SKELETON_DIR/templates/httproute.yaml" 2>/dev/null || true)"
HELPERS_TEMPLATE="$(cat "$CHART_SKELETON_DIR/templates/_helpers.tpl" 2>/dev/null || true)"
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
assert_contains "chart values expose HTTPRoute host" "$VALUES_TEMPLATE" 'host: ${{ values.host }}'
assert_contains "chart values expose HTTPRoute port" "$VALUES_TEMPLATE" 'port: ${{ values.port }}'
assert_contains "chart values default service name suffix" "$VALUES_TEMPLATE" 'serviceNameSuffix: ${{ values.serviceNameSuffix or "app" }}'
assert_contains "chart values default gateway name" "$VALUES_TEMPLATE" "name: edge-gateway"
assert_contains "chart values default gateway namespace" "$VALUES_TEMPLATE" "namespace: gateway"
assert_contains "chart values explain discovery command" "$VALUES_TEMPLATE" "helm show values"
assert_contains "chart values mention injected image repository" "$VALUES_TEMPLATE" "image.repository"
assert_contains "chart values mention injected admin user" "$VALUES_TEMPLATE" "rbac.adminUser"

assert_contains "chart catalog records helm chart type" "$CATALOG_TEMPLATE" "type: helm-chart"
assert_contains "chart catalog records application template" "$CATALOG_TEMPLATE" "backstage.io/managed-by-template: application"
assert_contains "chart catalog records generated source paths" "$CATALOG_TEMPLATE" "backstage.io/source-paths: '[\"charts/workloads/\${{ values.name }}\"]'"
assert_contains "chart catalog uses Helm instance selector" "$CATALOG_TEMPLATE" "backstage.io/kubernetes-label-selector: 'app.kubernetes.io/instance=\${{ values.name }}'"
assert_not_contains "chart catalog omits kubernetes-id annotation" "$CATALOG_TEMPLATE" "backstage.io/kubernetes-id"

assert_directory_exists "chart skeleton has templates subdir" "$CHART_SKELETON_DIR/templates"
assert_file_exists "chart skeleton ships namespace template" "$CHART_SKELETON_DIR/templates/namespace.yaml"
assert_file_exists "chart skeleton ships httproute template" "$CHART_SKELETON_DIR/templates/httproute.yaml"
assert_file_exists "chart skeleton ships labels helper" "$CHART_SKELETON_DIR/templates/_helpers.tpl"
assert_contains "chart namespace template declares Namespace kind" "$NAMESPACE_TEMPLATE" "kind: Namespace"
assert_contains "chart namespace template uses release namespace" "$NAMESPACE_TEMPLATE" "name: {{ .Release.Namespace }}"
assert_contains "chart namespace template applies workload labels" "$NAMESPACE_TEMPLATE" '{{- include "workload.labels" . | nindent 4 }}'
assert_contains "chart namespace template enables gateway routes" "$NAMESPACE_TEMPLATE" "gateway-routes: enabled"
CHART_TEMPLATE_FILES="$(find "$CHART_SKELETON_DIR/templates" -maxdepth 1 -type f -printf '%f\n' 2>/dev/null | sort || true)"
assert_equals "chart skeleton templates contains namespace, httproute, and helper" "$CHART_TEMPLATE_FILES" "_helpers.tpl
httproute.yaml
namespace.yaml"
assert_contains "chart helper defines workload labels" "$HELPERS_TEMPLATE" '{{- define "workload.labels" -}}'
assert_contains "chart helper defines workload fullname for HTTPRoute metadata" "$HELPERS_TEMPLATE" '{{- define "workload.fullname" -}}'
assert_not_contains "chart helper omits selector labels" "$HELPERS_TEMPLATE" '{{- define "workload.selectorLabels" -}}'
assert_contains "chart HTTPRoute declares Gateway API kind" "$HTTPROUTE_TEMPLATE" "kind: HTTPRoute"
assert_contains "chart HTTPRoute names route with workload fullname" "$HTTPROUTE_TEMPLATE" 'name: {{ include "workload.fullname" . }}'
assert_contains "chart HTTPRoute applies workload labels" "$HTTPROUTE_TEMPLATE" '{{- include "workload.labels" . | nindent 4 }}'
assert_contains "chart HTTPRoute targets shared gateway name" "$HTTPROUTE_TEMPLATE" "name: {{ .Values.gateway.name }}"
assert_contains "chart HTTPRoute targets shared gateway namespace" "$HTTPROUTE_TEMPLATE" "namespace: {{ .Values.gateway.namespace }}"
assert_contains "chart HTTPRoute uses scaffolded host" "$HTTPROUTE_TEMPLATE" '{{ .Values.host | quote }}'
assert_contains "chart HTTPRoute matches all paths" "$HTTPROUTE_TEMPLATE" "type: PathPrefix"
assert_contains "chart HTTPRoute matches root path" "$HTTPROUTE_TEMPLATE" "value: /"
assert_contains "chart HTTPRoute resolves upstream service from suffix" "$HTTPROUTE_TEMPLATE" 'name: {{ .Release.Name }}-{{ .Values.serviceNameSuffix }}'
assert_contains "chart HTTPRoute uses scaffolded service port" "$HTTPROUTE_TEMPLATE" "port: {{ .Values.port }}"

assert_contains "template exposes single chart reference field" "$TEMPLATE" "chartRef:"
assert_contains "template labels chart reference field" "$TEMPLATE" "title: Chart reference"
assert_contains "template exposes chart service suffix field" "$TEMPLATE" "serviceNameSuffix:"
assert_contains "template labels chart service suffix field" "$TEMPLATE" "title: Service name suffix"
assert_contains "template defaults chart service suffix to app" "$TEMPLATE" "default: app"
assert_contains "template exposes chart port field" "$TEMPLATE" "title: Service port"
assert_contains "template exposes chart host field" "$TEMPLATE" "title: Host"
assert_contains "template defaults chart host from name" "$TEMPLATE" "host: \${{ parameters.host or (parameters.name + '.localtest.me') }}"
assert_not_contains "template does not require chart service suffix" "$TEMPLATE" "                - serviceNameSuffix"
assert_contains "template rejects missing OCI chart version in form" "$TEMPLATE" 'pattern: ^(oci://)?[a-z0-9.-]+(:[0-9]+)?(/[a-zA-Z0-9._-]+)+:[a-zA-Z0-9._-]+$'
assert_not_contains "template no longer exposes separate chart field" "$TEMPLATE" "title: Chart name"
assert_not_contains "template no longer exposes separate repoURL field" "$TEMPLATE" "title: OCI repository URL"
assert_not_contains "template no longer exposes separate targetRevision field" "$TEMPLATE" "title: Chart version"
assert_contains "template parses chart reference before rendering" "$TEMPLATE" "id: parseRef"
assert_contains "template uses OCI parser action" "$TEMPLATE" "action: platform:parse-oci-ref"
assert_contains "template passes chartRef into parser" "$TEMPLATE" 'ref: ${{ parameters.chartRef }}'
assert_contains "template feeds parsed chart to skeleton" "$TEMPLATE" 'chart: ${{ steps.parseRef.output.chart }}'
assert_contains "template feeds parsed repository to skeleton" "$TEMPLATE" 'repoURL: ${{ steps.parseRef.output.repository }}'
assert_contains "template feeds parsed version to skeleton" "$TEMPLATE" 'targetRevision: ${{ steps.parseRef.output.version }}'
assert_contains "template feeds resolved service suffix to skeleton" "$TEMPLATE" 'serviceNameSuffix: ${{ parameters.serviceNameSuffix or "app" }}'
assert_contains "template feeds service port to skeleton" "$TEMPLATE" 'port: ${{ parameters.port }}'
assert_contains "template feeds host to skeleton" "$TEMPLATE" "host: \${{ parameters.host or (parameters.name + '.localtest.me') }}"
assert_contains "template fetches chart skeleton" "$TEMPLATE" "url: ./skeleton/chart"
assert_contains "template writes deploy dev placeholder" "$TEMPLATE" 'targetPath: deploy/dev/${{ parameters.name }}.yaml'
assert_contains "template echoes original chartRef in PR description" "$TEMPLATE" 'Chart reference: `${{ parameters.chartRef }}`'
assert_contains "template echoes parsed chart in PR description" "$TEMPLATE" 'Parsed chart: `${{ steps.parseRef.output.chart }}`'
assert_contains "template echoes parsed repository in PR description" "$TEMPLATE" 'Parsed repository: `${{ steps.parseRef.output.repository }}`'
assert_contains "template echoes parsed version in PR description" "$TEMPLATE" 'Parsed version: `${{ steps.parseRef.output.version }}`'
assert_contains "template echoes resolved service suffix in PR description" "$TEMPLATE" 'Service name suffix: `${{ parameters.serviceNameSuffix or "app" }}`'
assert_contains "template echoes port in PR description" "$TEMPLATE" 'Service port: `${{ parameters.port }}`'
assert_contains "template echoes host in PR description" "$TEMPLATE" "Host: \`\${{ parameters.host or (parameters.name + '.localtest.me') }}\`"
assert_contains "template documents ci-pipeline caveat" "$TEMPLATE" "ci-pipeline does not compose with chart-based apps"
assert_contains "template documents umbrella ownership" "$TEMPLATE" "The umbrella wrapper owns the Namespace, HTTPRoute, and labels helper; the upstream chart owns the rendered Deployment and Service."
assert_contains "template documents dead injected values" "$TEMPLATE" "image.repository and rbac.adminUser injected by workloads-appset are inert dead values"
assert_directory_exists "deploy dev placeholder skeleton exists" "$DEPLOY_DEV_SKELETON_DIR"
assert_contains "deploy dev placeholder exposes alias scope" "$DEPLOY_DEV_TEMPLATE" "app: {}"
assert_contains "deploy dev placeholder explains alias" "$DEPLOY_DEV_TEMPLATE" "alias declared in charts/workloads/"
assert_path_missing "chart skeleton does not commit Chart.lock" "$CHART_SKELETON_DIR/Chart.lock"
assert_path_missing "chart skeleton does not vendor dependency archives" "$CHART_SKELETON_DIR/charts"

report_results "Application chart scaffold"
