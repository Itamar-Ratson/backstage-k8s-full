#!/usr/bin/env bash
set -euo pipefail

source tests/charts/helpers.sh

build_workflow="$(<.github/workflows/build-image.yaml)"
cleanup_workflow="$(<.github/workflows/cleanup-ghcr.yaml)"

# Build the upstream slug from parts so this guard test does not itself embed the
# literal that tests/ci/test-no-literal-repo-slug.sh forbids.
upstream_lower_owner="$(printf '%s-%s' itamar ratson)"
upstream_repo="backstage-k8s-full"
upstream_lower_slug="${upstream_lower_owner}/${upstream_repo}"

assert_not_contains "build workflow has no literal GHCR slug" "$build_workflow" "$upstream_lower_slug"
assert_contains "build workflow lowercases github repository" "$build_workflow" 'slug="${GITHUB_REPOSITORY,,}"'
assert_contains "build workflow uses derived slug for image" "$build_workflow" 'image="ghcr.io/${slug}/${{ inputs.app-name }}"'

assert_not_contains "cleanup workflow has no literal package namespace" "$cleanup_workflow" "backstage-k8s-full"
assert_contains "cleanup workflow emits lowercased repo output" "$cleanup_workflow" 'repo="${GITHUB_REPOSITORY,,}"'
assert_contains "cleanup workflow uses derived package name" "$cleanup_workflow" 'package-name: ${{ steps.repo.outputs.repo }}/backstage'

report_results "GitHub workflow repo slug"
