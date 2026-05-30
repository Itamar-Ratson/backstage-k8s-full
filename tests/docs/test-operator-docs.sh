#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../charts/helpers.sh
source "$(dirname "$0")/../charts/helpers.sh"

OPERATIONS="docs/operator/operations.md"
RBAC_DEMO="docs/operator/manual-rbac-demo.md"

echo "=== Operator docs tests ==="

assert_file_exists "operations doc exists" "$OPERATIONS"
assert_file_exists "manual RBAC demo doc exists" "$RBAC_DEMO"

if [ -f "$OPERATIONS" ]; then
  operations="$(cat "$OPERATIONS")"
  assert_contains "operations doc keeps Operations heading" "$operations" "## Operations"
  assert_contains "operations doc keeps Useful Commands heading" "$operations" "## Useful Commands"
  assert_contains "operations doc keeps Verifying Images heading" "$operations" "## Verifying Images"
  assert_contains "operations doc includes cosign verification" "$operations" "cosign verify"
fi

if [ -f "$RBAC_DEMO" ]; then
  rbac_demo="$(cat "$RBAC_DEMO")"
  assert_contains "manual RBAC demo keeps heading" "$rbac_demo" "## Manual RBAC Demo"
  assert_contains "manual RBAC demo keeps Guest sign-in step" "$rbac_demo" "Sign in as guest."
  assert_contains "manual RBAC demo keeps denied execution check" "$rbac_demo" "Confirm execution is denied by the permission framework."
fi

report_results "Operator docs"
