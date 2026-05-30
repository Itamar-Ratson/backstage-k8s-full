#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../charts/helpers.sh
source "$(dirname "$0")/../charts/helpers.sh"

echo "=== Catalog discovery identity tests ==="

backstage_values=$(sed -n '1,$p' deploy/dev/backstage.yaml 2>/dev/null || true)
catalog_files=$(find . -path './backstage/node_modules' -prune -o -path './node_modules' -prune -o \
  -name catalog-info.yaml -type f -print0 | xargs -0 sed -n '1,$p')

# Build the upstream slug from parts so this test does not itself embed the
# literal that tests/ci/test-no-literal-repo-slug.sh forbids.
upstream_owner="Itamar-Ratson"
upstream_repo="backstage-k8s-full"
upstream_slug="${upstream_owner}/${upstream_repo}"

assert_contains "catalog discovery target uses GitHub owner env" "$backstage_values" '${GITHUB_OWNER}'
assert_contains "catalog discovery target uses GitHub repo env" "$backstage_values" '${GITHUB_REPO}'
assert_not_contains "catalog discovery target has no upstream literal" "$backstage_values" "$upstream_slug"
assert_not_contains "catalog files have no project slug annotations" "$catalog_files" "github.com/project-slug"
assert_not_contains "catalog files have no source-location annotations" "$catalog_files" "backstage.io/source-location"
assert_not_contains "catalog files have no upstream literal" "$catalog_files" "$upstream_slug"

report_results "Catalog discovery identity"
