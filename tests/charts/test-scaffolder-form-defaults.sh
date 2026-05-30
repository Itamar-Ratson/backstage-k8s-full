#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source tests/charts/helpers.sh

echo "=== Scaffolder form-default tests ==="

if ! command -v yq >/dev/null 2>&1; then
  echo "ERROR: yq is required to validate scaffolder form defaults." >&2
  echo "Install yq and re-run this test." >&2
  exit 1
fi

# Backstage's scaffolder form does not eagerly evaluate ${{ parameters.X }}
# references inside `default:` values when the user accepts a default without
# editing the field. The literal placeholder string is submitted as the value,
# breaks the `or` fallback in the step section (truthy non-empty string), and
# lands in rendered output. The fallback must live in the steps section as
# `${{ parameters.X or ... }}`.

for template in templates/*/template.yaml; do
  matches=$(grep -nE '^[[:space:]]+default:[[:space:]]+.*\$\{\{[[:space:]]*parameters\.' "$template" || true)
  if [ -n "$matches" ]; then
    FAIL=$((FAIL + 1))
    echo "FAIL: $template has form-field defaults referencing \${{ parameters.X }}"
    echo "$matches" | sed 's/^/  /'
  else
    PASS=$((PASS + 1))
  fi
done

APPLICATION_TEMPLATE="templates/application/template.yaml"
source_type_enum="$(yq eval -r '.spec.parameters[0].properties.sourceType.enum[]' "$APPLICATION_TEMPLATE" 2>/dev/null || true)"
source_type_required="$(yq eval -r '.spec.parameters[0].required[]' "$APPLICATION_TEMPLATE" 2>/dev/null || true)"
source_type_widget="$(yq eval -r '.spec.parameters[0].properties.sourceType."ui:widget"' "$APPLICATION_TEMPLATE" 2>/dev/null || true)"
source_type_default="$(yq eval -r '.spec.parameters[0].properties.sourceType.default' "$APPLICATION_TEMPLATE" 2>/dev/null || true)"

assert_contains "sourceType enum includes image" "$source_type_enum" "image"
assert_contains "sourceType enum includes chart" "$source_type_enum" "chart"
assert_contains "sourceType is required" "$source_type_required" "sourceType"
assert_contains "sourceType uses radio widget" "$source_type_widget" "radio"
assert_contains "sourceType defaults to image" "$source_type_default" "image"

chart_branch_required="$(yq eval -r '.spec.parameters[0].dependencies.sourceType.oneOf[] | select(.properties.sourceType.const == "chart") | .required[]' "$APPLICATION_TEMPLATE" 2>/dev/null || true)"
chart_branch_properties="$(yq eval -r '.spec.parameters[0].dependencies.sourceType.oneOf[] | select(.properties.sourceType.const == "chart") | .properties | keys | .[]' "$APPLICATION_TEMPLATE" 2>/dev/null || true)"

for field in chart repoURL targetRevision; do
  assert_contains "chart branch requires ${field}" "$chart_branch_required" "$field"
  assert_contains "chart branch exposes ${field}" "$chart_branch_properties" "$field"
done

chart_title="$(yq eval -r '.spec.parameters[0].dependencies.sourceType.oneOf[] | select(.properties.sourceType.const == "chart") | .properties.chart.title' "$APPLICATION_TEMPLATE" 2>/dev/null || true)"
repo_url_title="$(yq eval -r '.spec.parameters[0].dependencies.sourceType.oneOf[] | select(.properties.sourceType.const == "chart") | .properties.repoURL.title' "$APPLICATION_TEMPLATE" 2>/dev/null || true)"
target_revision_title="$(yq eval -r '.spec.parameters[0].dependencies.sourceType.oneOf[] | select(.properties.sourceType.const == "chart") | .properties.targetRevision.title' "$APPLICATION_TEMPLATE" 2>/dev/null || true)"
repo_url_description="$(yq eval -r '.spec.parameters[0].dependencies.sourceType.oneOf[] | select(.properties.sourceType.const == "chart") | .properties.repoURL.description' "$APPLICATION_TEMPLATE" 2>/dev/null || true)"

assert_contains "chart field has expected title" "$chart_title" "Chart name"
assert_contains "repoURL field has expected title" "$repo_url_title" "OCI repository URL"
assert_contains "targetRevision field has expected title" "$target_revision_title" "Chart version"
assert_contains "repoURL field describes OCI prefix" "$repo_url_description" "oci://"

image_branch_properties="$(yq eval -r '.spec.parameters[0].dependencies.sourceType.oneOf[] | select(.properties.sourceType.const == "image") | .properties | keys | .[]' "$APPLICATION_TEMPLATE" 2>/dev/null || true)"
image_tag_default="$(yq eval -r '.spec.parameters[0].dependencies.sourceType.oneOf[] | select(.properties.sourceType.const == "image") | .properties.tag.default' "$APPLICATION_TEMPLATE" 2>/dev/null || true)"
image_port_default="$(yq eval -r '.spec.parameters[0].dependencies.sourceType.oneOf[] | select(.properties.sourceType.const == "image") | .properties.port.default' "$APPLICATION_TEMPLATE" 2>/dev/null || true)"

for field in repository tag host port; do
  assert_contains "image branch still exposes ${field}" "$image_branch_properties" "$field"
done
assert_contains "image tag default is unchanged" "$image_tag_default" "latest"
assert_contains "image port default is unchanged" "$image_port_default" "80"

report_results "Scaffolder form-default"
