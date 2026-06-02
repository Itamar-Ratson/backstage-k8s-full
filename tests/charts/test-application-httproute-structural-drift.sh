#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source tests/charts/helpers.sh

echo "=== Application HTTPRoute structural-drift tests ==="

IMAGE_HTTPROUTE="templates/application/skeleton/image/templates/httproute.yaml"
CHART_HTTPROUTE="templates/application/skeleton/chart/templates/httproute.yaml"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mask_intentional_backend_ref_name_difference() {
  awk '
    /^      backendRefs:/ {
      in_backend_refs = 1
      print
      next
    }
    in_backend_refs && /^          name: / {
      print "          name: __INTENTIONAL_BACKEND_REF_NAME_DIFFERENCE__"
      in_backend_refs = 0
      next
    }
    { print }
  ' "$1"
}

# The only intentional per-variant HTTPRoute difference is backendRefs[0].name:
# image-case targets workload.fullname, chart-case targets <release>-<serviceNameSuffix>.
mask_intentional_backend_ref_name_difference "$IMAGE_HTTPROUTE" > "$tmpdir/image-httproute.yaml"
mask_intentional_backend_ref_name_difference "$CHART_HTTPROUTE" > "$tmpdir/chart-httproute.yaml"

assert_files_equal "image-case and chart-case HTTPRoute templates only differ at backendRefs[0].name" "$tmpdir/image-httproute.yaml" "$tmpdir/chart-httproute.yaml"

report_results "Application HTTPRoute structural drift"
