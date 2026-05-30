#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "git remote discovery: $1" >&2
  exit 1
}

github_owner_pattern='[A-Za-z0-9][A-Za-z0-9-]*'
github_repo_pattern='[A-Za-z0-9][A-Za-z0-9._-]*'

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  fail "not inside a git working tree"
fi

if ! remote_url="$(git remote get-url origin 2>/dev/null)"; then
  fail "no 'origin' remote configured"
fi

owner=""
repo=""

if [[ "$remote_url" =~ ^https://([^/@]+(:[^@]*)?@)?github\.com/([^/]+)/([^/?#]+)$ ]]; then
  owner="${BASH_REMATCH[3]}"
  repo="${BASH_REMATCH[4]}"
elif [[ "$remote_url" =~ ^git@github\.com:([^/]+)/([^/]+)$ ]]; then
  owner="${BASH_REMATCH[1]}"
  repo="${BASH_REMATCH[2]}"
elif [[ "$remote_url" =~ ^ssh://git@github\.com/([^/]+)/([^/]+)$ ]]; then
  owner="${BASH_REMATCH[1]}"
  repo="${BASH_REMATCH[2]}"
elif [[ "$remote_url" =~ ^https://([^/@]+(:[^@]*)?@)?github\.com(/|$) ]] ||
  [[ "$remote_url" =~ ^git@github\.com: ]] ||
  [[ "$remote_url" =~ ^ssh://git@github\.com(/|$) ]]; then
  fail "could not parse github.com origin URL: $remote_url"
else
  fail "origin is not a github.com URL: $remote_url"
fi

repo="${repo%.git}"

if [[ ! "$owner" =~ ^${github_owner_pattern}$ ]] || [[ ! "$repo" =~ ^${github_repo_pattern}$ ]]; then
  fail "could not parse github.com origin URL: $remote_url"
fi

printf '{"owner":"%s","repo":"%s"}\n' "$owner" "$repo"
