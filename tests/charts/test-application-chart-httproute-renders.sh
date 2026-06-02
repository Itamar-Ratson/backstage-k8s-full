#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source tests/charts/helpers.sh

echo "=== Application chart HTTPRoute render tests ==="

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

chart_dir="$tmpdir/chart-http-route"
upstream_dir="$tmpdir/upstream-chart"
chart_name="podinfo"
chart_version="6.0.0"
host="chart-http-route.localtest.me"
port="9898"
service_name_suffix="podinfo"

mkdir -p "$upstream_dir/templates"
cat > "$upstream_dir/Chart.yaml" <<EOF
apiVersion: v2
name: $chart_name
description: Local test dependency for chart-case wrapper rendering.
type: application
version: $chart_version
EOF

cp -R templates/application/skeleton/chart "$chart_dir"

while IFS= read -r file; do
  rendered="${file%.njk}"
  mv "$file" "$rendered"
done < <(find "$chart_dir" -type f -name '*.njk' | sort)

perl -0pi -e '
  s/\$\{\{ values\.name \}\}/chart-http-route/g;
  s/\$\{\{ values\.description \}\}/Chart HTTPRoute render test/g;
  s/\$\{\{ values\.owner \}\}/platform/g;
  s/\$\{\{ values\.system \}\}/developer-portal/g;
' "$chart_dir"/Chart.yaml "$chart_dir"/values.yaml "$chart_dir"/catalog-info.yaml "$chart_dir"/mkdocs.yaml "$chart_dir"/docs/index.md

CHART_NAME="$chart_name" \
REPO_URL="file://$upstream_dir" \
CHART_VERSION="$chart_version" \
HOST="$host" \
PORT="$port" \
SERVICE_NAME_SUFFIX="$service_name_suffix" \
perl -0pi -e '
  s/\$\{\{ values\.chart \}\}/$ENV{CHART_NAME}/g;
  s/\$\{\{ values\.repoURL \}\}/$ENV{REPO_URL}/g;
  s/\$\{\{ values\.targetRevision \}\}/$ENV{CHART_VERSION}/g;
  s/\$\{\{ values\.host \}\}/$ENV{HOST}/g;
  s/\$\{\{ values\.port \}\}/$ENV{PORT}/g;
  s/\$\{\{ values\.serviceNameSuffix \}\}/$ENV{SERVICE_NAME_SUFFIX}/g;
' "$chart_dir"/Chart.yaml "$chart_dir"/values.yaml "$chart_dir"/catalog-info.yaml "$chart_dir"/mkdocs.yaml "$chart_dir"/docs/index.md

if output=$(helm dependency build "$chart_dir" 2>&1); then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: helm dependency build succeeds for local chart-case skeleton"
  echo "$output"
fi

if rendered=$(helm template chart-http-route "$chart_dir" --namespace chart-http-route 2>&1); then
  assert_contains "renders chart-case HTTPRoute" "$rendered" "kind: HTTPRoute"
  assert_contains "HTTPRoute hostname matches scaffold input" "$rendered" "$host"
  assert_contains "HTTPRoute parentRef points at edge-gateway" "$rendered" "name: edge-gateway"
  assert_contains "HTTPRoute parentRef points at gateway namespace" "$rendered" "namespace: gateway"
  assert_contains "HTTPRoute backend service resolves release and suffix" "$rendered" "name: chart-http-route-$service_name_suffix"
  assert_contains "HTTPRoute backend port matches scaffold input" "$rendered" "port: $port"
else
  FAIL=$((FAIL + 1))
  echo "FAIL: helm template succeeds for chart-case skeleton"
  echo "$rendered"
fi

report_results "Application chart HTTPRoute render"
