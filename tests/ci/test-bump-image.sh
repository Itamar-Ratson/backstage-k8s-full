#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../charts/helpers.sh
source "$(dirname "$0")/../charts/helpers.sh"

SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/.github/scripts/bump-image.sh"
SOURCE="$(cd "$(dirname "$0")/../.." && pwd)/deploy/dev/backstage.yaml"

echo "=== Image bump script tests ==="

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

overlay="$tmp/backstage.yaml"
before_rbac="$tmp/rbac.before.yaml"
before_app_config="$tmp/app-config.before.yaml"
before_postgres="$tmp/postgres.before.yaml"
after_rbac="$tmp/rbac.after.yaml"
after_app_config="$tmp/app-config.after.yaml"
after_postgres="$tmp/postgres.after.yaml"

cp "$SOURCE" "$overlay"
yq '.rbac' "$overlay" > "$before_rbac"
yq '.appConfig' "$overlay" > "$before_app_config"
yq '.postgres' "$overlay" > "$before_postgres"

"$SCRIPT" "$overlay" "ghcr.io/example-org/example-repo/backstage" "abc1234"

repository="$(yq -r '.image.repository' "$overlay")"
tag="$(yq -r '.image.tag' "$overlay")"
assert_contains "rewrites image repository" "$repository" "ghcr.io/example-org/example-repo/backstage"
assert_contains "rewrites image tag" "$tag" "abc1234"

first_checksum="$(sha256sum "$overlay" | awk '{print $1}')"
"$SCRIPT" "$overlay" "ghcr.io/example-org/example-repo/backstage" "abc1234"
second_checksum="$(sha256sum "$overlay" | awk '{print $1}')"
assert_contains "second rewrite is idempotent" "$second_checksum" "$first_checksum"

yq '.rbac' "$overlay" > "$after_rbac"
yq '.appConfig' "$overlay" > "$after_app_config"
yq '.postgres' "$overlay" > "$after_postgres"
assert_files_equal "leaves RBAC policies untouched" "$before_rbac" "$after_rbac"
assert_files_equal "leaves app config untouched" "$before_app_config" "$after_app_config"
assert_files_equal "leaves postgres config untouched" "$before_postgres" "$after_postgres"

assert_fails "missing arguments fail" "usage:" "$SCRIPT" "$overlay" "ghcr.io/example-org/example-repo/backstage"
assert_fails "missing input file fails" "not found:" "$SCRIPT" "$tmp/missing.yaml" "ghcr.io/example-org/example-repo/backstage" "abc1234"

report_results "Image bump script"
