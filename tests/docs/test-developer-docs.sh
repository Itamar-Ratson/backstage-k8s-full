#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../charts/helpers.sh
source "$(dirname "$0")/../charts/helpers.sh"

DEVELOPER_DIR="docs/developer"
BACKSTAGE_DOC="$DEVELOPER_DIR/backstage-development.md"

echo "=== Developer docs tests ==="

assert_directory_exists "developer docs directory exists" "$DEVELOPER_DIR"
assert_file_exists "Backstage development doc exists" "$BACKSTAGE_DOC"

if [ -f "$BACKSTAGE_DOC" ]; then
  doc="$(cat "$BACKSTAGE_DOC")"
  assert_contains "Backstage development doc keeps Node heading" "$doc" "### Node.js Version"
  assert_contains "Backstage development doc keeps isolated-vm rationale" "$doc" 'particularly with `isolated-vm` which depends on V8 APIs that change between Node versions.'
  assert_contains "Backstage development doc keeps nvm install" "$doc" "nvm install 22"
  assert_contains "Backstage development doc keeps build dependencies heading" "$doc" "### Build Dependencies"
  assert_contains "Backstage development doc keeps native build install" "$doc" "sudo apt-get install -y python3 g++ build-essential"
fi

report_results "Developer docs"
