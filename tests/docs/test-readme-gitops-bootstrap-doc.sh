#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../charts/helpers.sh
source "$(dirname "$0")/../charts/helpers.sh"

README_CONTENT="$(cat README.md)"

echo "=== README GitOps bootstrap docs tests ==="

line_for_heading() {
  local heading="$1"
  grep -nF "$heading" README.md | head -n1 | cut -d: -f1
}

assert_heading_order() {
  local label="$1"
  shift
  local previous_line=0
  local heading line

  for heading in "$@"; do
    line="$(line_for_heading "$heading")"
    if [ -z "$line" ] || [ "$line" -le "$previous_line" ]; then
      FAIL=$((FAIL + 1))
      echo "FAIL: $label"
      return
    fi
    previous_line="$line"
  done

  PASS=$((PASS + 1))
}

assert_contains "title exists" "$README_CONTENT" "# Deploying Backstage on Kubernetes"
assert_contains "description matches PRD" "$README_CONTENT" "A fork-and-run local Kubernetes environment for Backstage on KinD, provisioned by Terraform and continuously reconciled by ArgoCD, with Envoy Gateway for ingress."
assert_contains "prerequisites section exists" "$README_CONTENT" "## Prerequisites"
assert_contains "GitHub setup section exists" "$README_CONTENT" "## One-time GitHub setup"
assert_contains "boot section exists" "$README_CONTENT" "## Boot the cluster"
assert_contains "verification section exists" "$README_CONTENT" "## Verify it's working"
assert_contains "what's next section exists" "$README_CONTENT" "## What's next"

assert_heading_order \
  "README sections follow required order" \
  "## Prerequisites" \
  "## One-time GitHub setup" \
  "## Boot the cluster" \
  "## Verify it's working" \
  "## What's next"

assert_contains "prerequisites include Docker" "$README_CONTENT" "- [Docker](https://docs.docker.com/get-docker/)"
assert_contains "prerequisites include KinD" "$README_CONTENT" "- [KinD](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)"
assert_contains "prerequisites include Terraform" "$README_CONTENT" "- [Terraform](https://developer.hashicorp.com/terraform/downloads) (>= 1.5)"
assert_contains "prerequisites include Helm" "$README_CONTENT" "- [Helm](https://helm.sh/docs/intro/install/) (>= 3)"
assert_contains "prerequisites include kubectl" "$README_CONTENT" "- [kubectl](https://kubernetes.io/docs/tasks/tools/)"
assert_not_contains "README omits actionlint prerequisite" "$README_CONTENT" "actionlint"
assert_not_contains "README omits yq prerequisite" "$README_CONTENT" "[yq]"
assert_not_contains "README omits cosign prerequisite" "$README_CONTENT" "[cosign]"
assert_not_contains "README omits Node prerequisite" "$README_CONTENT" "Node.js 20 or 22"
assert_not_contains "README omits nvm setup" "$README_CONTENT" "nvm install"
assert_not_contains "README omits native build setup" "$README_CONTENT" "build-essential"

assert_contains "setup leads with forking" "$README_CONTENT" "Fork the repo."
assert_contains "setup clones fork" "$README_CONTENT" "Clone your fork"
assert_contains "setup links GitHub App guide" "$README_CONTENT" "docs/operator/github-app-setup.md"
assert_contains "setup copies tfvars example" "$README_CONTENT" "cp terraform/terraform.tfvars.example terraform/terraform.tfvars"
assert_contains "setup notes ignored credentials" "$README_CONTENT" ".pem file and terraform/terraform.tfvars are gitignored"
assert_contains "boot applies terraform" "$README_CONTENT" "cd terraform && terraform apply"
assert_contains "boot opens Backstage URL" "$README_CONTENT" "http://backstage.localtest.me"
assert_contains "verification has curl check" "$README_CONTENT" "curl -fsS --retry"
assert_contains "verification has ArgoCD password command" "$README_CONTENT" "argocd-initial-admin-secret"
assert_contains "verification expects sign-in buttons" "$README_CONTENT" "Guest and GitHub sign-in buttons"
assert_contains "what's next links operations" "$README_CONTENT" "docs/operator/operations.md"
assert_contains "what's next links RBAC demo" "$README_CONTENT" "docs/operator/manual-rbac-demo.md"
assert_contains "what's next links developer doc" "$README_CONTENT" "docs/developer/backstage-development.md"

while IFS= read -r link; do
  assert_file_exists "README link resolves: $link" "$link"
done < <(grep -oE 'docs/(operator|developer)/[^)]+' README.md | sort -u)

assert_not_contains "README drops Fork setup section" "$README_CONTENT" "## Fork setup"
assert_not_contains "README drops Operations section" "$README_CONTENT" "## Operations"
assert_not_contains "README drops Useful Commands section" "$README_CONTENT" "## Useful Commands"
assert_not_contains "README drops Verifying Images section" "$README_CONTENT" "## Verifying Images"
assert_not_contains "README drops Manual RBAC Demo section" "$README_CONTENT" "## Manual RBAC Demo"
assert_not_contains "README drops Next Steps section" "$README_CONTENT" "## Next Steps"
assert_not_contains "README drops isolated-vm rationale" "$README_CONTENT" "isolated-vm"
assert_contains "README ends with ADR pointer" "$(tail -n 1 README.md)" "See [ADR-0001](docs/adr/0001-kind-terraform-envoy-gateway.md) for the KinD + Terraform + Envoy Gateway rationale."
assert_not_contains "README has no literal repo slug" "$README_CONTENT" "backstage-k8s-full/<app>"
assert_not_contains "README no longer has Smoke Test section" "$README_CONTENT" "## Smoke Test"
assert_not_contains "README has no make target references" "$README_CONTENT" "make "

report_results "README GitOps bootstrap docs"
