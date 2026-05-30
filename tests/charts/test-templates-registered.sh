#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
# shellcheck source=../lib/platform-identity.sh
source "$(dirname "$0")/../lib/platform-identity.sh"

echo "=== Template registration tests ==="

if ! command -v yq >/dev/null 2>&1; then
  echo "ERROR: yq is required to validate template catalog registrations." >&2
  echo "Install yq and re-run this test." >&2
  exit 1
fi

CATALOG_INFO="catalog-info.yaml"

mapfile -t templates < <(find templates -mindepth 2 -maxdepth 2 -type f -name template.yaml | sort)

for template_path in "${templates[@]}"; do
  template_name="$(basename "$(dirname "$template_path")")"
  expected_target="./${template_path}"
  matching_targets="$(EXPECTED_TARGET="$expected_target" yq eval-all -N 'select(.kind == "Location" and .spec.target == env(EXPECTED_TARGET)) | .spec.target' "$CATALOG_INFO")"

  assert_contains "registered template ${template_name}" "$matching_targets" "$expected_target"

  matching_location_count="$(printf '%s\n' "$matching_targets" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ "$matching_location_count" -eq 1 ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: exactly one Location for template ${template_name}"
    echo "  found: $matching_location_count"
    echo "  expected target: $expected_target"
  fi
done

mapfile -t registered_template_targets < <(yq eval-all -N 'select(.kind == "Location" and .spec.target != null and (.spec.target | contains("/templates/"))) | .spec.target' "$CATALOG_INFO" | sort)

for target in "${registered_template_targets[@]}"; do
  template_path="${target#./}"

  if [ -f "$template_path" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: registered template target exists"
    echo "  missing template for Location target: $target"
  fi
done

application_template="$(cat templates/application/template.yaml)"
assert_contains "application template reaches image skeleton" "$application_template" "url: ./skeleton/image"
assert_contains "application template reaches chart skeleton" "$application_template" "url: ./skeleton/chart"

report_results "Template registration"
