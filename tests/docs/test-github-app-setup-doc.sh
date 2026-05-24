#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../charts/helpers.sh
source "$(dirname "$0")/../charts/helpers.sh"

DOC="docs/operator/github-app-setup.md"

echo "=== GitHub App setup doc tests ==="

if [ -f "$DOC" ]; then
  PASS=$((PASS + 1))
  content=$(<"$DOC")

  assert_contains "contents permission" "$content" "Contents: Read and write"
  assert_contains "pull requests permission" "$content" "Pull requests: Read and write"
  assert_contains "commit statuses permission" "$content" "Commit statuses: Read"
  assert_contains "workflows permission" "$content" "Workflows: Read and write"
  assert_contains "metadata permission" "$content" "Metadata: Read"
  assert_contains "dev callback URL" "$content" "http://backstage.localtest.me/api/auth/github/handler/frame"
  assert_not_contains "setup guide omits localtest.me port suffixes" "$content" "localtest.me"":8080"
  assert_contains "APP_ID mapping" "$content" "APP_ID"
  assert_contains "CLIENT_ID mapping" "$content" "CLIENT_ID"
  assert_contains "CLIENT_SECRET mapping" "$content" "CLIENT_SECRET"
  assert_contains "PRIVATE_KEY mapping" "$content" "PRIVATE_KEY"
  assert_contains "private key warning" "$content" ".pem"
  assert_contains "tfvars warning" "$content" "terraform.tfvars"
  assert_contains "do not commit warning" "$content" "must not be committed"
else
  FAIL=$((FAIL + 1))
  echo "FAIL: GitHub App setup guide exists"
  echo "  missing: $DOC"
fi

if grep -qF "operator/github-app-setup.md" mkdocs.yaml docs/index.md; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: GitHub App setup guide is discoverable"
  echo "  expected mkdocs.yaml or docs/index.md to link $DOC"
fi

report_results "GitHub App setup doc"
