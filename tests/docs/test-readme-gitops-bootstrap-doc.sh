#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../charts/helpers.sh
source "$(dirname "$0")/../charts/helpers.sh"

README_CONTENT="$(cat README.md)"

echo "=== README GitOps bootstrap docs tests ==="

assert_contains "bootstrap section exists" "$README_CONTENT" "## Bootstrap"
assert_contains "bootstrap installs tools" "$README_CONTENT" "Install tools"
assert_contains "bootstrap links GitHub App setup guide" "$README_CONTENT" "docs/operator/github-app-setup.md"
assert_contains "bootstrap fills terraform tfvars" "$README_CONTENT" "terraform/terraform.tfvars"
assert_contains "bootstrap applies terraform" "$README_CONTENT" "cd terraform && terraform apply"
assert_contains "bootstrap points to Backstage URL" "$README_CONTENT" "http://backstage.localtest.me"
assert_contains "fork setup section exists" "$README_CONTENT" "## Fork setup"
assert_contains "fork setup copies tfvars example" "$README_CONTENT" "terraform/terraform.tfvars.example"
assert_contains "fork setup documents standard fork clone" "$README_CONTENT" "standard git clone of your fork"
assert_contains "fork setup derives owner and repo from git remote" "$README_CONTENT" "reads the GitHub owner and repository from the local git remote"
assert_contains "fork setup keeps tfvars app-credentials-only" "$README_CONTENT" "terraform.tfvars file carries only GitHub App credentials"
assert_contains "cosign example uses GHCR base placeholder" "$README_CONTENT" 'cosign verify ${GHCR_BASE}/<app>:<sha>'
assert_not_contains "README has no literal repo slug" "$README_CONTENT" "backstage-k8s-full/<app>"
assert_contains "verifying install section exists" "$README_CONTENT" "## Verifying the install"
assert_contains "verification uses ArgoCD applications" "$README_CONTENT" "kubectl get applications -n argocd"
assert_contains "verification has curl check" "$README_CONTENT" "curl -fsS --retry"
assert_contains "operations section exists" "$README_CONTENT" "## Operations"
assert_contains "force sync uses argocd" "$README_CONTENT" "argocd app sync <app>"
assert_contains "rotation uses terraform reapply" "$README_CONTENT" "terraform apply"
assert_contains "rotation restarts backstage" "$README_CONTENT" "kubectl rollout restart deployment/backstage -n backstage"
assert_contains "future ExternalSecrets path documented" "$README_CONTENT" "ExternalSecrets Operator"
assert_not_contains "README no longer has Smoke Test section" "$README_CONTENT" "## Smoke Test"
assert_not_contains "README has no make target references" "$README_CONTENT" "make "

report_results "README GitOps bootstrap docs"
