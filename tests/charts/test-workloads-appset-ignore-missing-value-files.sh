#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== Workloads ApplicationSet missing value file tests ==="

appset_path="gitops/dev/templates/workloads-appset.yaml"
ignore_missing="$(sed -n '1,$p' "$appset_path")"

assert_contains "workloads ApplicationSet ignores missing Helm value files" "$ignore_missing" "true"

report_results "Workloads ApplicationSet missing value file"
