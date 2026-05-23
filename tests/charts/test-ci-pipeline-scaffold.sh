#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source tests/charts/helpers.sh

SKELETON_DIR="templates/ci-pipeline/skeleton"
TEMPLATE="$(cat templates/ci-pipeline/template.yaml)"
CALLER_TEMPLATE="$(cat "$SKELETON_DIR/.github/workflows/caller-\${{ values.name }}.yaml.njk")"
OVERLAY_TEMPLATE="$(cat "$SKELETON_DIR/deploy/dev/\${{ values.name }}.yaml.njk")"
APPLICATION_TEMPLATE="$(cat templates/application/template.yaml)"
DECOMMISSION_TEMPLATE="$(cat templates/decommission-component/template.yaml)"

echo "=== CI pipeline scaffold tests ==="

assert_contains "template name is ci-pipeline" "$TEMPLATE" "name: ci-pipeline"
assert_contains "template title is user-facing" "$TEMPLATE" "title: New CI Pipeline"
assert_contains "template publishes a pull request" "$TEMPLATE" "publish:github:pull-request"
assert_contains "template documents Dockerfile prerequisite" "$TEMPLATE" "Requires a working Dockerfile"
assert_contains "template documents scaffold-created bump file" "$TEMPLATE" "bump file is created by this scaffold"
assert_not_contains "template does not catalog register" "$TEMPLATE" "catalog:register"
assert_file_exists "skeleton includes pipeline catalog-info file" "$SKELETON_DIR/deploy/dev/\${{ values.name }}.catalog-info.yaml.njk"

assert_contains "caller uses reusable build workflow" "$CALLER_TEMPLATE" "uses: ./.github/workflows/build-image.yaml"
assert_contains "caller emits app-name substitution" "$CALLER_TEMPLATE" 'app-name: ${{ values.name }}'
assert_contains "caller emits context substitution" "$CALLER_TEMPLATE" 'context: ${{ values.context }}'
assert_contains "caller emits dockerfile substitution" "$CALLER_TEMPLATE" 'dockerfile: ${{ values.dockerfile }}'
assert_contains "caller emits bump-file substitution" "$CALLER_TEMPLATE" "bump-file: \${{ values['bump-file'] }}"
assert_contains "caller emits bump-yaml-path substitution" "$CALLER_TEMPLATE" "bump-yaml-path: \${{ values['bump-yaml-path'] }}"
assert_contains "caller renders path filter patterns" "$CALLER_TEMPLATE" "path-filter-patterns"

assert_contains "overlay references GHCR app path" "$OVERLAY_TEMPLATE" 'repository: ghcr.io/itamar-ratson/backstage-k8s-full/${{ values.name }}'
assert_contains "overlay starts with empty tag" "$OVERLAY_TEMPLATE" 'tag: ""'
assert_contains "overlay uses IfNotPresent pull policy" "$OVERLAY_TEMPLATE" "pullPolicy: IfNotPresent"
assert_not_contains "application scaffold does not emit deploy values path" "$APPLICATION_TEMPLATE" "targetPath: deploy/dev"
assert_contains "decommission reads source paths annotation" "$DECOMMISSION_TEMPLATE" "backstage.io/source-paths"
assert_contains "decommission PR documents ArgoCD prune" "$DECOMMISSION_TEMPLATE" "ArgoCD will detect the removal and prune the running resources within ~3 minutes."
assert_not_contains "decommission PR does not mention manual helm uninstall" "$DECOMMISSION_TEMPLATE" "helm uninstall"

report_results "CI pipeline scaffold"
