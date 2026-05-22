#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== Workloads ApplicationSet missing value file tests ==="

appset_path="gitops/dev/workloads-appset.yaml"
ignore_missing="$(yq eval '.spec.template.spec.source.helm.ignoreMissingValueFiles' "$appset_path")"

assert_contains "workloads ApplicationSet ignores missing Helm value files" "$ignore_missing" "true"

report_results "Workloads ApplicationSet missing value file"
