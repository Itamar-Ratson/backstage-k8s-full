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

mkdir -p "$upstream_dir/templates"
cat > "$upstream_dir/Chart.yaml" <<EOF
apiVersion: v2
name: $chart_name
description: Local test dependency for chart-case wrapper rendering.
type: application
version: $chart_version
EOF

render_case() {
  local release="$1" host="$2" port="$3" service_name_suffix_input="$4" expected_service_name_suffix="$5"
  local case_dir="$tmpdir/$release"

  cp -R templates/application/skeleton/chart "$case_dir"

  while IFS= read -r file; do
    rendered="${file%.njk}"
    mv "$file" "$rendered"
  done < <(find "$case_dir" -type f -name '*.njk' | sort)

  perl -0pi -e '
    s/\$\{\{ values\.name \}\}/$ENV{RELEASE}/g;
    s/\$\{\{ values\.description \}\}/Chart HTTPRoute render test/g;
    s/\$\{\{ values\.owner \}\}/platform/g;
    s/\$\{\{ values\.system \}\}/developer-portal/g;
  ' "$case_dir"/Chart.yaml "$case_dir"/values.yaml "$case_dir"/catalog-info.yaml "$case_dir"/mkdocs.yaml "$case_dir"/docs/index.md

  CHART_NAME="$chart_name" \
  REPO_URL="file://$upstream_dir" \
  CHART_VERSION="$chart_version" \
  HOST="$host" \
  PORT="$port" \
  SERVICE_NAME_SUFFIX_INPUT="$service_name_suffix_input" \
  perl -0pi -e '
    s/\$\{\{ values\.chart \}\}/$ENV{CHART_NAME}/g;
    s/\$\{\{ values\.repoURL \}\}/$ENV{REPO_URL}/g;
    s/\$\{\{ values\.targetRevision \}\}/$ENV{CHART_VERSION}/g;
    s/\$\{\{ values\.host \}\}/$ENV{HOST}/g;
    s/\$\{\{ values\.port \}\}/$ENV{PORT}/g;
    s/\$\{\{ values\.serviceNameSuffix or "app" \}\}/$ENV{SERVICE_NAME_SUFFIX_INPUT}/g;
  ' "$case_dir"/Chart.yaml "$case_dir"/values.yaml "$case_dir"/catalog-info.yaml "$case_dir"/mkdocs.yaml "$case_dir"/docs/index.md

  if output=$(helm dependency build "$case_dir" 2>&1); then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: helm dependency build succeeds for $release"
    echo "$output"
  fi

  if rendered=$(helm template "$release" "$case_dir" --namespace "$release" 2>&1); then
    assert_contains "renders chart-case HTTPRoute for $release" "$rendered" "kind: HTTPRoute"
    assert_contains "HTTPRoute hostname matches scaffold input for $release" "$rendered" "$host"
    assert_contains "HTTPRoute parentRef points at edge-gateway for $release" "$rendered" "name: edge-gateway"
    assert_contains "HTTPRoute parentRef points at gateway namespace for $release" "$rendered" "namespace: gateway"
    assert_contains "HTTPRoute backend service resolves release and suffix for $release" "$rendered" "name: $release-$expected_service_name_suffix"
    assert_contains "HTTPRoute backend port matches scaffold input for $release" "$rendered" "port: $port"
  else
    FAIL=$((FAIL + 1))
    echo "FAIL: helm template succeeds for $release"
    echo "$rendered"
  fi
}

RELEASE="chart-http-route-default" render_case "chart-http-route-default" "chart-http-route-default.localtest.me" "9898" "app" "app"
RELEASE="chart-http-route-override" render_case "chart-http-route-override" "chart-http-route-override.localtest.me" "8080" "podinfo" "podinfo"

report_results "Application chart HTTPRoute render"
