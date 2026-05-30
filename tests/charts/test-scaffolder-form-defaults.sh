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
APPLICATION_PARAMETERS_QUERY=".spec.parameters[0]"
IMAGE_BRANCH_QUERY="${APPLICATION_PARAMETERS_QUERY}.dependencies.sourceType.oneOf[] | select(.properties.sourceType.const == \"image\")"
CHART_BRANCH_QUERY="${APPLICATION_PARAMETERS_QUERY}.dependencies.sourceType.oneOf[] | select(.properties.sourceType.const == \"chart\")"

read_application_template() {
  local query="$1"
  yq eval -r "$query" "$APPLICATION_TEMPLATE"
}

assert_line_not_present() {
  local label="$1" output="$2" unexpected="$3"
  if ! grep -qxF -- "$unexpected" <<<"$output"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $label"
    echo "  expected no line equal to: $unexpected"
  fi
}

source_type_enum="$(read_application_template "${APPLICATION_PARAMETERS_QUERY}.properties.sourceType.enum[]")"
source_type_required="$(read_application_template "${APPLICATION_PARAMETERS_QUERY}.required[]")"
source_type_widget="$(read_application_template "${APPLICATION_PARAMETERS_QUERY}.properties.sourceType.\"ui:widget\"")"
source_type_default="$(read_application_template "${APPLICATION_PARAMETERS_QUERY}.properties.sourceType.default")"

assert_contains "sourceType enum includes image" "$source_type_enum" "image"
assert_contains "sourceType enum includes chart" "$source_type_enum" "chart"
assert_contains "sourceType is required" "$source_type_required" "sourceType"
assert_contains "sourceType uses radio widget" "$source_type_widget" "radio"
assert_contains "sourceType defaults to image" "$source_type_default" "image"

chart_branch_required="$(read_application_template "${CHART_BRANCH_QUERY} | .required[]")"
chart_branch_properties="$(read_application_template "${CHART_BRANCH_QUERY} | .properties | keys | .[]")"

assert_contains "chart branch requires chartRef" "$chart_branch_required" "chartRef"
assert_contains "chart branch exposes chartRef" "$chart_branch_properties" "chartRef"
assert_line_not_present "chart branch no longer exposes chart" "$chart_branch_properties" "chart"
assert_line_not_present "chart branch no longer exposes repoURL" "$chart_branch_properties" "repoURL"
assert_line_not_present "chart branch no longer exposes targetRevision" "$chart_branch_properties" "targetRevision"

chart_ref_title="$(read_application_template "${CHART_BRANCH_QUERY} | .properties.chartRef.title")"
chart_ref_description="$(read_application_template "${CHART_BRANCH_QUERY} | .properties.chartRef.description")"
chart_ref_pattern="$(read_application_template "${CHART_BRANCH_QUERY} | .properties.chartRef.pattern")"

assert_contains "chartRef field has expected title" "$chart_ref_title" "Chart reference"
assert_contains "chartRef field describes OCI prefix" "$chart_ref_description" "The oci:// prefix is optional."
assert_contains "chartRef field describes example full reference" "$chart_ref_description" "ghcr.io/kagent-dev/kagent/helm/kagent:0.9.4"
assert_contains "chartRef field has validation pattern" "$chart_ref_pattern" '^(oci://)?[a-z0-9.-]+(:[0-9]+)?(/[a-zA-Z0-9._-]+)+:[a-zA-Z0-9._-]+$'

image_branch_properties="$(read_application_template "${IMAGE_BRANCH_QUERY} | .properties | keys | .[]")"
image_tag_default="$(read_application_template "${IMAGE_BRANCH_QUERY} | .properties.tag.default")"
image_port_default="$(read_application_template "${IMAGE_BRANCH_QUERY} | .properties.port.default")"

for field in repository tag host port; do
  assert_contains "image branch still exposes ${field}" "$image_branch_properties" "$field"
done
assert_contains "image tag default is unchanged" "$image_tag_default" "latest"
assert_contains "image port default is unchanged" "$image_port_default" "80"

report_results "Scaffolder form-default"
