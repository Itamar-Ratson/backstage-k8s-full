#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source tests/charts/helpers.sh

echo "=== Scaffolder form-default tests ==="

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

report_results "Scaffolder form-default"
