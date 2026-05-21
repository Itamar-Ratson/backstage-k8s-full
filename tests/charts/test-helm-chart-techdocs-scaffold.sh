#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source tests/charts/helpers.sh

SKELETON_DIR="templates/helm-chart/skeleton"
TEMPLATE="$(cat templates/helm-chart/template.yaml)"
MKDOCS_TEMPLATE="$(cat "$SKELETON_DIR/mkdocs.yaml.njk" 2>/dev/null || true)"
DOCS_INDEX_TEMPLATE="$(cat "$SKELETON_DIR/docs/index.md.njk" 2>/dev/null || true)"
CATALOG_TEMPLATE="$(cat "$SKELETON_DIR/catalog-info.yaml.njk")"

echo "=== Helm chart TechDocs scaffold tests ==="

assert_contains "template targets workload chart path" "$TEMPLATE" 'targetPath: charts/workloads/${{ parameters.name }}'
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
assert_contains "catalog source-location uses workload path" "$CATALOG_TEMPLATE" 'tree/main/charts/workloads/${{ values.name }}/'

report_results "Helm chart TechDocs scaffold"
