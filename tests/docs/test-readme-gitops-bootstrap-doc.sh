#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../charts/helpers.sh
source "$(dirname "$0")/../charts/helpers.sh"

echo "=== README GitOps bootstrap docs tests ==="

line_for_heading() {
  local heading="$1"
  grep -nF "$heading" README.md | head -n1 | cut -d: -f1
}

assert_heading_order() {
  local label="$1"
  shift
  local previous_line=0
  local heading line

  for heading in "$@"; do
    line="$(line_for_heading "$heading")"
    if [ -z "$line" ] || [ "$line" -le "$previous_line" ]; then
      FAIL=$((FAIL + 1))
      echo "FAIL: $label"
      return
    fi
    previous_line="$line"
  done

  PASS=$((PASS + 1))
}

assert_heading_order \
  "README sections follow required order" \
  "## Prerequisites" \
  "## One-time GitHub setup" \
  "## Boot the cluster" \
  "## Verify it's working" \
  "## What's next" \
  "## Try the platform"

while IFS= read -r link; do
  assert_file_exists "README link resolves: $link" "$link"
done < <(grep -oE 'docs/(operator|developer|adr)/[^)]+' README.md | sort -u)

report_results "README GitOps bootstrap docs"
