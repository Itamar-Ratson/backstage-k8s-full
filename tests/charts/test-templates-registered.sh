#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== Template registration tests ==="

if ! command -v yq >/dev/null 2>&1; then
  echo "ERROR: yq is required to validate template catalog registrations." >&2
  echo "Install yq and re-run this test." >&2
  exit 1
fi

catalog_info="catalog-info.yaml"
repo_url="https://github.com/Itamar-Ratson/backstage-k8s-full/blob/main"

mapfile -t templates < <(find templates -mindepth 2 -maxdepth 2 -type f -name template.yaml | sort)

for template_path in "${templates[@]}"; do
  template_name="$(basename "$(dirname "$template_path")")"
  expected_target="${repo_url}/${template_path}"
  output="$(EXPECTED_TARGET="$expected_target" yq eval-all -N 'select(.kind == "Location" and .spec.target == env(EXPECTED_TARGET)) | .spec.target' "$catalog_info")"

  assert_contains "registered template ${template_name}" "$output" "$expected_target"

  location_count="$(printf '%s\n' "$output" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ "$location_count" -eq 1 ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: exactly one Location for template ${template_name}"
    echo "  found: $location_count"
    echo "  expected target: $expected_target"
  fi
done

mapfile -t targets < <(yq eval-all -N 'select(.kind == "Location" and .spec.target != null and (.spec.target | contains("/templates/"))) | .spec.target' "$catalog_info" | sort)

for target in "${targets[@]}"; do
  template_path="${target#${repo_url}/}"

  if [ -f "$template_path" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: registered template target exists"
    echo "  missing template for Location target: $target"
  fi
done

report_results "Template registration"
