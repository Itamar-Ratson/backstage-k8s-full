#!/usr/bin/env bash
set -euo pipefail

CHART_DIR="charts/workloads/backstage"
FIXTURES="tests/charts/fixtures"
PASS=0
FAIL=0

assert_contains() {
  local label="$1" output="$2" expected="$3"
  if echo "$output" | grep -qF -- "$expected"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $label"
    echo "  expected to contain: $expected"
  fi
}

assert_not_contains() {
  local label="$1" output="$2" unexpected="$3"
  if ! echo "$output" | grep -qF -- "$unexpected"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $label"
    echo "  expected NOT to contain: $unexpected"
  fi
}

assert_fails() {
  local label="$1" expected_msg="$2"
  shift 2
  local output
  if output=$("$@" 2>&1); then
    FAIL=$((FAIL + 1))
    echo "FAIL: $label (expected failure but succeeded)"
  elif echo "$output" | grep -qF -- "$expected_msg"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $label"
    echo "  expected error containing: $expected_msg"
    echo "  got: $output"
  fi
}

report_results() {
  local suite="$1"
  echo ""
  echo "$suite tests: $PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ]
}
