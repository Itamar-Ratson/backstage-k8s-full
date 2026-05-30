#!/usr/bin/env bash
set -euo pipefail

CHART_DIR="charts/workloads/backstage"
FIXTURES="tests/charts/fixtures"
PASS=0
FAIL=0

assert_contains() {
  local label="$1" output="$2" expected="$3"
  if grep -qF -- "$expected" <<<"$output"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $label"
    echo "  expected to contain: $expected"
  fi
}

assert_not_contains() {
  local label="$1" output="$2" unexpected="$3"
  if ! grep -qF -- "$unexpected" <<<"$output"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $label"
    echo "  expected NOT to contain: $unexpected"
  fi
}

assert_not_matches() {
  local label="$1" output="$2" unexpected_pattern="$3"
  if ! grep -qE -- "$unexpected_pattern" <<<"$output"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $label"
    echo "  expected NOT to match: $unexpected_pattern"
  fi
}

assert_equals() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $label"
    echo "  expected: $expected"
    echo "  got: $actual"
  fi
}

assert_fails() {
  local label="$1" expected_msg="$2"
  shift 2
  local output
  if output=$("$@" 2>&1); then
    FAIL=$((FAIL + 1))
    echo "FAIL: $label (expected failure but succeeded)"
  elif grep -qF -- "$expected_msg" <<<"$output"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $label"
    echo "  expected error containing: $expected_msg"
    echo "  got: $output"
  fi
}

assert_file_exists() {
  local label="$1" path="$2"
  if [ -f "$path" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $label"
    echo "  missing: $path"
  fi
}

assert_files_equal() {
  local label="$1" expected="$2" actual="$3"
  if diff -u "$expected" "$actual" >/dev/null; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $label"
  fi
}

assert_directory_exists() {
  local label="$1" path="$2"
  if [ -d "$path" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $label"
    echo "  missing: $path"
  fi
}

assert_path_missing() {
  local label="$1" path="$2"
  if [ ! -e "$path" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $label"
    echo "  still present: $path"
  fi
}

assert_no_matching_paths() {
  local label="$1" root="$2" name_pattern="$3"
  local match

  match="$(find "$root" -name "$name_pattern" -print -quit)"
  if [ -z "$match" ]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $label"
    echo "  unexpected match: $match"
  fi
}

assert_git_ignored() {
  local label="$1" path="$2"
  if git check-ignore -q "$path"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: $label"
    echo "  expected ignored: $path"
  fi
}

render_gitops_dev_chart() {
  local repo_url="$1" target_revision="$2"
  helm template gitops-dev gitops/dev \
    --set-string "repoURL=$repo_url" \
    --set-string "targetRevision=$target_revision" 2>&1
}

report_results() {
  local suite="$1"
  echo ""
  echo "$suite tests: $PASS passed, $FAIL failed"
  [ "$FAIL" -eq 0 ]
}
