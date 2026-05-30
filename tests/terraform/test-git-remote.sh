#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../charts/helpers.sh
source "$(dirname "$0")/../charts/helpers.sh"

SCRIPT="$(cd "$(dirname "$0")/../.." && pwd)/terraform/scripts/git-remote.sh"

echo "=== Terraform git remote discovery tests ==="

assert_json_for_remote() {
  local label="$1" remote_url="$2" expected_owner="$3" expected_repo="$4"
  local tmp output expected
  tmp="$(mktemp -d)"
  git -C "$tmp" init >/dev/null 2>&1
  git -C "$tmp" remote add origin "$remote_url"

  output="$(cd "$tmp" && "$SCRIPT")"
  expected="{\"owner\":\"$expected_owner\",\"repo\":\"$expected_repo\"}"
  assert_contains "$label emits expected JSON" "$output" "$expected"

  rm -rf "$tmp"
}

assert_remote_failure() {
  local label="$1" expected_error="$2"
  shift 2
  local output status

  set +e
  output="$("$@" 2>&1 >/dev/null)"
  status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    FAIL=$((FAIL + 1))
    echo "FAIL: $label"
    echo "  expected non-zero exit"
  else
    assert_contains "$label reports expected error" "$output" "$expected_error"
  fi
}

assert_json_for_remote "HTTPS remote with .git" "https://github.com/acme-platform/service-portal.git" "acme-platform" "service-portal"
assert_json_for_remote "HTTPS remote without .git" "https://github.com/acme-platform/service_portal" "acme-platform" "service_portal"
assert_json_for_remote "SCP-style SSH remote with .git" "git@github.com:octo-team/service.portal.git" "octo-team" "service.portal"
assert_json_for_remote "SCP-style SSH remote without .git" "git@github.com:octo-team/service.portal" "octo-team" "service.portal"
assert_json_for_remote "ssh URL remote" "ssh://git@github.com/example-org/service-repo.git" "example-org" "service-repo"
assert_json_for_remote "token HTTPS remote" "https://x-access-token:secret-token@github.com/token-org/token-repo.git" "token-org" "token-repo"

tmp_no_repo="$(mktemp -d)"
assert_remote_failure "Not in a git repo" "not inside a git working tree" bash -c "cd '$tmp_no_repo' && '$SCRIPT'"
rm -rf "$tmp_no_repo"

tmp_no_origin="$(mktemp -d)"
git -C "$tmp_no_origin" init >/dev/null 2>&1
assert_remote_failure "Missing origin remote" "no 'origin' remote" bash -c "cd '$tmp_no_origin' && '$SCRIPT'"
rm -rf "$tmp_no_origin"

tmp_non_github="$(mktemp -d)"
git -C "$tmp_non_github" init >/dev/null 2>&1
git -C "$tmp_non_github" remote add origin "https://notgithub.com/example-org/service-repo.git"
assert_remote_failure "Non-GitHub origin remote" "origin is not a github.com URL" bash -c "cd '$tmp_non_github' && '$SCRIPT'"
rm -rf "$tmp_non_github"

tmp_malformed="$(mktemp -d)"
git -C "$tmp_malformed" init >/dev/null 2>&1
git -C "$tmp_malformed" remote add origin "https://github.com/example-org"
assert_remote_failure "Malformed GitHub origin remote" "could not parse github.com origin URL" bash -c "cd '$tmp_malformed' && '$SCRIPT'"
rm -rf "$tmp_malformed"

report_results "Terraform git remote discovery"
