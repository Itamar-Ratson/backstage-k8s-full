#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== Hello world source tests ==="

assert_file_exists "hello-world Dockerfile exists" "hello-world/Dockerfile"
assert_file_exists "hello-world index exists" "hello-world/index.html"
assert_path_missing "hello-world has no catalog registration" "hello-world/catalog-info.yaml"

expected_dockerfile=$'FROM nginx:alpine\nCOPY index.html /usr/share/nginx/html/index.html'
if [ -f "hello-world/Dockerfile" ] && [ "$(cat hello-world/Dockerfile)" = "$expected_dockerfile" ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: hello-world Dockerfile uses exact two-line nginx form"
fi

if [ -f "hello-world/index.html" ]; then
  paragraph_count=$(grep -o "<p>" hello-world/index.html | wc -l | tr -d ' ')
  if [ "$paragraph_count" = "1" ] &&
    grep -qF "Hello world from the Backstage, Kubernetes, Argo CD, and GitHub Actions platform path." hello-world/index.html &&
    ! grep -qiE "<(script|style|link)[[:space:]>]" hello-world/index.html; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: hello-world index is one plain HTML paragraph crediting platform layers"
  fi
fi

if git check-ignore -q "hello-world/index.html"; then
  FAIL=$((FAIL + 1))
  echo "FAIL: hello-world index.html must be trackable"
else
  PASS=$((PASS + 1))
fi

report_results "Hello world source"
