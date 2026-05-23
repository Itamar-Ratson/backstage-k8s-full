#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source tests/charts/helpers.sh

CATALOG_TEMPLATE_PATH="templates/ci-pipeline/skeleton/deploy/dev/\${{ values.name }}.catalog-info.yaml.njk"
CATALOG_TEMPLATE="$(cat "$CATALOG_TEMPLATE_PATH")"

echo "=== CI pipeline catalog scaffold tests ==="

assert_contains "catalog skeleton emits Component kind" "$CATALOG_TEMPLATE" "kind: Component"
assert_contains "catalog skeleton names pipeline with ci suffix" "$CATALOG_TEMPLATE" 'name: ${{ values.name }}-ci'
assert_contains "catalog skeleton uses ci-pipeline type" "$CATALOG_TEMPLATE" "type: ci-pipeline"
assert_contains "catalog skeleton has decommission marker" "$CATALOG_TEMPLATE" "backstage.io/managed-by-template: ci-pipeline"
assert_contains "catalog skeleton has exact source paths" "$CATALOG_TEMPLATE" "backstage.io/source-paths: '[\".github/workflows/caller-\${{ values.name }}.yaml\",\"deploy/dev/\${{ values.name }}.yaml\",\"deploy/dev/\${{ values.name }}.catalog-info.yaml\"]'"
assert_contains "catalog skeleton source paths include caller workflow" "$CATALOG_TEMPLATE" '.github/workflows/caller-${{ values.name }}.yaml'
assert_contains "catalog skeleton source paths include bump file" "$CATALOG_TEMPLATE" 'deploy/dev/${{ values.name }}.yaml'
assert_contains "catalog skeleton source paths include catalog file" "$CATALOG_TEMPLATE" 'deploy/dev/${{ values.name }}.catalog-info.yaml'
assert_contains "catalog skeleton has project slug" "$CATALOG_TEMPLATE" "github.com/project-slug: Itamar-Ratson/backstage-k8s-full"
assert_contains "catalog skeleton source link targets caller workflow" "$CATALOG_TEMPLATE" 'backstage.io/source-location: url:https://github.com/Itamar-Ratson/backstage-k8s-full/blob/main/.github/workflows/caller-${{ values.name }}.yaml'
assert_contains "catalog skeleton links to workflow runs" "$CATALOG_TEMPLATE" 'url: https://github.com/Itamar-Ratson/backstage-k8s-full/actions/workflows/caller-${{ values.name }}.yaml'
assert_contains "catalog skeleton carries system" "$CATALOG_TEMPLATE" 'system: ${{ values.system }}'
assert_contains "catalog skeleton carries owner" "$CATALOG_TEMPLATE" 'owner: ${{ values.owner }}'

report_results "CI pipeline catalog scaffold"
