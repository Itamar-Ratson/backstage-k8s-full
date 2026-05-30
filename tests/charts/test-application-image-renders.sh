#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"
# shellcheck source=../lib/platform-identity.sh
source "$(dirname "$0")/../lib/platform-identity.sh"

echo "=== Application image render tests ==="

hello_world_values="$(sed -n '1,$p' charts/workloads/hello-world/values.yaml)"
assert_not_contains "committed hello-world values omit default image repository" "$hello_world_values" "repository:"

hello_world_render="$(helm template hello-world charts/workloads/hello-world --set "image.repository=${TEST_GHCR_BASE}/hello-world")"
assert_contains "committed hello-world chart renders injected repository and tag" "$hello_world_render" "image: \"${TEST_GHCR_BASE}/hello-world:latest\""

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

chart_dir="$tmpdir/hello-world"
cp -R templates/application/skeleton/image "$chart_dir"

while IFS= read -r file; do
  rendered="${file%.njk}"
  mv "$file" "$rendered"
done < <(find "$chart_dir" -type f -name '*.njk' | sort)

perl -0pi -e '
  s/\$\{\{ values\.name \}\}/hello-world/g;
  s/\$\{\{ values\.description \}\}/Reference workload/g;
  s/\$\{\{ values\.owner \}\}/platform/g;
  s/\$\{\{ values\.system \}\}/developer-portal/g;
  s#\$\{\{ values\.repository \}\}#'"$TEST_GHCR_BASE"'/hello-world#g;
  s/\$\{\{ values\.tag \}\}/latest/g;
  s/\$\{\{ values\.host \}\}/hello-world.localtest.me/g;
  s/\$\{\{ values\.port \}\}/80/g;
' "$chart_dir"/Chart.yaml "$chart_dir"/values.yaml "$chart_dir"/catalog-info.yaml "$chart_dir"/mkdocs.yaml "$chart_dir"/docs/index.md

default_render="$(helm template hello-world "$chart_dir")"
assert_contains "default values render repository and tag" "$default_render" "image: \"${TEST_GHCR_BASE}/hello-world:latest\""

override_values="$tmpdir/override.yaml"
cat > "$override_values" <<EOF
image:
  repository: ${TEST_GHCR_BASE}/hello-world
  tag: abc1234
  pullPolicy: IfNotPresent
EOF

override_render="$(helm template hello-world "$chart_dir" -f "$override_values")"
assert_contains "override values render bumped tag" "$override_render" "image: \"${TEST_GHCR_BASE}/hello-world:abc1234\""

report_results "Application image render"
