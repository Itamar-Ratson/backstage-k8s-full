#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== Hello world source tests ==="

dockerfile_path="hello-world/Dockerfile"
index_path="hello-world/index.html"
catalog_path="hello-world/catalog-info.yaml"
platform_message="Hello world from the Backstage, Kubernetes, Argo CD, and GitHub Actions platform path."

assert_file_exists "hello-world Dockerfile exists" "$dockerfile_path"
assert_file_exists "hello-world index exists" "$index_path"
assert_path_missing "hello-world has no catalog registration" "$catalog_path"

expected_dockerfile=$'FROM nginx:alpine\nCOPY index.html /usr/share/nginx/html/index.html'
if [ -f "$dockerfile_path" ] && [ "$(cat "$dockerfile_path")" = "$expected_dockerfile" ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: hello-world Dockerfile uses exact two-line nginx form"
fi

if [ -f "$index_path" ]; then
  paragraph_count=$(grep -o "<p>" "$index_path" | wc -l | tr -d ' ')
  if [ "$paragraph_count" = "1" ] &&
    grep -qF "$platform_message" "$index_path" &&
    ! grep -qiE "<(script|style|link)[[:space:]>]" "$index_path"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: hello-world index is one plain HTML paragraph crediting platform layers"
  fi
fi

if git check-ignore -q "$index_path"; then
  FAIL=$((FAIL + 1))
  echo "FAIL: hello-world index.html must be trackable"
else
  PASS=$((PASS + 1))
fi

report_results "Hello world source"
