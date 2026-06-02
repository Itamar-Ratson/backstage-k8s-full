#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source tests/charts/helpers.sh

SKELETON_DIR="templates/application/skeleton/image"
TEMPLATE="$(cat templates/application/template.yaml)"
APPLICATION_DOCS_INDEX="$(cat templates/application/docs/index.md 2>/dev/null || true)"
GENERATED_CHART_DOC="$(cat templates/application/docs/generated-chart.md 2>/dev/null || true)"
MKDOCS_TEMPLATE="$(cat "$SKELETON_DIR/mkdocs.yaml.njk" 2>/dev/null || true)"
DOCS_INDEX_TEMPLATE="$(cat "$SKELETON_DIR/docs/index.md.njk" 2>/dev/null || true)"
CATALOG_TEMPLATE="$(cat "$SKELETON_DIR/catalog-info.yaml.njk")"

echo "=== Application TechDocs scaffold tests ==="

assert_contains "template targets workload chart path" "$TEMPLATE" 'targetPath: charts/workloads/${{ parameters.name }}'
assert_contains "template title is user-facing" "$TEMPLATE" "title: New Application"
assert_contains "mkdocs scaffold inherits shared base" "$MKDOCS_TEMPLATE" "INHERIT: ../../shared-mkdocs-base.yml"
assert_contains "mkdocs scaffold uses chart name" "$MKDOCS_TEMPLATE" 'site_name: '\''${{ values.name }}'\'''
assert_contains "mkdocs scaffold sets docs dir" "$MKDOCS_TEMPLATE" "docs_dir: docs"
assert_contains "mkdocs scaffold has explicit nav" "$MKDOCS_TEMPLATE" "nav: [Home: index.md]"

assert_contains "docs index has chart title" "$DOCS_INDEX_TEMPLATE" '# ${{ values.name }}'
assert_contains "docs index includes chart description" "$DOCS_INDEX_TEMPLATE" '${{ values.description }}'
assert_contains "docs index has single TODO callout" "$DOCS_INDEX_TEMPLATE" "> TODO: Describe what this chart does, its inputs, and how to operate it."

todo_count="$(grep -cF "TODO:" "$SKELETON_DIR/docs/index.md.njk" 2>/dev/null || echo 0)"
if [ "$todo_count" -eq 1 ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: docs index has exactly one TODO callout"
  echo "  expected TODO count: 1"
  echo "  got: $todo_count"
fi

assert_contains "catalog scaffold has techdocs annotation" "$CATALOG_TEMPLATE" "backstage.io/techdocs-ref: dir:."
assert_not_contains "catalog scaffold omits source-location annotation" "$CATALOG_TEMPLATE" "backstage.io/source-location"

assert_contains "application docs describe chartRef parameter" "$APPLICATION_DOCS_INDEX" '`chartRef`'
assert_contains "application docs describe chart service suffix parameter" "$APPLICATION_DOCS_INDEX" '`serviceNameSuffix`'
assert_contains "application docs describe chart host parameter" "$APPLICATION_DOCS_INDEX" "Chart only | Public hostname"
assert_not_contains "application docs omit old chart parameter" "$APPLICATION_DOCS_INDEX" '`chart` | Chart only'
assert_not_contains "application docs omit old repoURL parameter" "$APPLICATION_DOCS_INDEX" '`repoURL`'
assert_not_contains "application docs omit old targetRevision parameter" "$APPLICATION_DOCS_INDEX" '`targetRevision`'

assert_contains "generated-chart docs split image-case section" "$GENERATED_CHART_DOC" "## Image Source Files"
assert_contains "generated-chart docs split chart-case section" "$GENERATED_CHART_DOC" "## Chart Source Files"
assert_contains "generated-chart docs list chart HTTPRoute" "$GENERATED_CHART_DOC" '`templates/httproute.yaml` | Gateway API route for the scaffolded host, targeting the upstream chart Service.'
assert_contains "generated-chart docs list chart helper" "$GENERATED_CHART_DOC" '`templates/_helpers.tpl` | Naming and Kubernetes label helpers used by the wrapper-owned resources.'
assert_contains "generated-chart docs list missing deployment" "$GENERATED_CHART_DOC" '`templates/deployment.yaml` is not generated for chart-source scaffolds'
assert_contains "generated-chart docs list missing service" "$GENERATED_CHART_DOC" '`templates/service.yaml` is not generated for chart-source scaffolds'
assert_contains "generated-chart docs state ownership boundary" "$GENERATED_CHART_DOC" "The platform-owned umbrella wrapper owns the Namespace, HTTPRoute, and labels helper; the upstream chart owns the rendered Deployment and Service."
assert_contains "generated-chart docs explain service suffix default" "$GENERATED_CHART_DOC" 'serviceNameSuffix` defaults to `app`'
assert_contains "generated-chart docs explain service suffix convention" "$GENERATED_CHART_DOC" 'resolves the HTTPRoute backend Service name as `<release>-<serviceNameSuffix>`'
assert_contains "generated-chart docs explain service suffix override case" "$GENERATED_CHART_DOC" 'Override `serviceNameSuffix` only when the upstream chart sets `fullnameOverride` by default'
assert_contains "generated-chart docs explain app alias convention" "$GENERATED_CHART_DOC" 'Chart-source upstream values live under the `app:` alias scope.'

report_results "Application TechDocs scaffold"
