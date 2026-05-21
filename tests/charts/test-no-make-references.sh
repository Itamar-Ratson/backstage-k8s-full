#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== No make references tests ==="

mapfile -t make_refs < <(
  grep -RInE 'make[[:space:]]+(smoke|tf-check|charts-lint|charts-test|rbac-test|rbac-admin-auth-test|verify|bootstrap)' \
    README.md docs charts .github/workflows \
    --include='*.md' --include='*.yaml' --include='*.yml' || true
)

if [ "${#make_refs[@]}" -eq 0 ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: docs and workflows should not reference make targets"
  printf '  %s\n' "${make_refs[@]}"
fi

report_results "No make references"
