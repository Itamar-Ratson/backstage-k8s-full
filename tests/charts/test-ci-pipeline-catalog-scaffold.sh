#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source tests/charts/helpers.sh

CATALOG_TEMPLATE_PATH="templates/ci-pipeline/skeleton/deploy/dev/\${{ values.name }}.catalog-info.yaml.njk"
CATALOG_TEMPLATE="$(cat "$CATALOG_TEMPLATE_PATH")"
CALLER_WORKFLOW_PATH=".github/workflows/caller-\${{ values.name }}.yaml"
BUMP_FILE_PATH="deploy/dev/\${{ values.name }}.yaml"
CATALOG_INFO_PATH="deploy/dev/\${{ values.name }}.catalog-info.yaml"
SOURCE_PATHS_ANNOTATION="backstage.io/source-paths: '[\"$CALLER_WORKFLOW_PATH\",\"$BUMP_FILE_PATH\",\"$CATALOG_INFO_PATH\"]'"
CALLER_WORKFLOW_URL="https://github.com/Itamar-Ratson/backstage-k8s-full/blob/main/$CALLER_WORKFLOW_PATH"
WORKFLOW_RUNS_URL="https://github.com/Itamar-Ratson/backstage-k8s-full/actions/workflows/caller-\${{ values.name }}.yaml"

echo "=== CI pipeline catalog scaffold tests ==="

assert_contains "catalog skeleton emits Component kind" "$CATALOG_TEMPLATE" "kind: Component"
assert_contains "catalog skeleton names pipeline with ci suffix" "$CATALOG_TEMPLATE" 'name: ${{ values.name }}-ci'
assert_contains "catalog skeleton uses ci-pipeline type" "$CATALOG_TEMPLATE" "type: ci-pipeline"
assert_contains "catalog skeleton has template ownership marker" "$CATALOG_TEMPLATE" "backstage.io/managed-by-template: ci-pipeline"
assert_contains "catalog skeleton has exact source paths" "$CATALOG_TEMPLATE" "$SOURCE_PATHS_ANNOTATION"
assert_contains "catalog skeleton source paths include caller workflow" "$CATALOG_TEMPLATE" "$CALLER_WORKFLOW_PATH"
assert_contains "catalog skeleton source paths include bump file" "$CATALOG_TEMPLATE" "$BUMP_FILE_PATH"
assert_contains "catalog skeleton source paths include catalog file" "$CATALOG_TEMPLATE" "$CATALOG_INFO_PATH"
assert_contains "catalog skeleton has project slug" "$CATALOG_TEMPLATE" "github.com/project-slug: Itamar-Ratson/backstage-k8s-full"
assert_contains "catalog skeleton source link targets caller workflow" "$CATALOG_TEMPLATE" "backstage.io/source-location: url:$CALLER_WORKFLOW_URL"
assert_contains "catalog skeleton links to workflow runs" "$CATALOG_TEMPLATE" "url: $WORKFLOW_RUNS_URL"
assert_contains "catalog skeleton carries system" "$CATALOG_TEMPLATE" 'system: ${{ values.system }}'
assert_contains "catalog skeleton carries owner" "$CATALOG_TEMPLATE" 'owner: ${{ values.owner }}'

report_results "CI pipeline catalog scaffold"
