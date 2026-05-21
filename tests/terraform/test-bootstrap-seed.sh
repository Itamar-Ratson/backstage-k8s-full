#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../charts/helpers.sh
source "$(dirname "$0")/../charts/helpers.sh"

echo "=== Terraform bootstrap seed tests ==="

assert_file_exists "root Application manifest exists" "terraform/bootstrap/root-app.yaml"
assert_file_exists "tfvars example exists" "terraform/terraform.tfvars.example"

terraform_config=$(find terraform -name '*.tf' -type f -print0 | xargs -0 sed -n '1,$p')

assert_contains "ArgoCD seed helm release exists" "$terraform_config" 'resource "helm_release" "argocd"'
assert_contains "ArgoCD release ignores self-managed drift" "$terraform_config" "ignore_changes = [version, values]"
assert_contains "root app loaded from manifest file" "$terraform_config" 'yamldecode(file("${path.module}/bootstrap/root-app.yaml"))'
assert_contains "backstage namespace is managed" "$terraform_config" 'resource "kubernetes_namespace_v1" "backstage"'
assert_contains "backstage namespace has gateway opt-in label" "$terraform_config" 'gateway-routes = "enabled"'
assert_contains "GitHub App secret is managed" "$terraform_config" 'resource "kubernetes_secret_v1" "backstage_github_app"'
assert_contains "GitHub App private key is sensitive" "$terraform_config" 'variable "PRIVATE_KEY"'
assert_not_contains "Envoy Gateway helm release removed" "$terraform_config" 'resource "helm_release" "gateway"'
assert_not_contains "GatewayClass manifest removed" "$terraform_config" 'kind: GatewayClass'

chart_version=$(awk '
  /^[[:space:]]*-[[:space:]]*name:[[:space:]]*argo-cd[[:space:]]*$/ { in_dependency = 1; next }
  in_dependency && /^[[:space:]]*version:/ { sub(/^[[:space:]]*version:[[:space:]]*/, ""); print; exit }
' charts/platform/argo-cd/Chart.yaml)
assert_contains "Terraform ArgoCD chart pin matches wrapper chart" "$terraform_config" "version          = \"$chart_version\""

root_app=$(sed -n '1,$p' terraform/bootstrap/root-app.yaml 2>/dev/null || true)
assert_contains "root Application points at gitops/dev" "$root_app" "path: gitops/dev"
assert_contains "root Application tracks main" "$root_app" "targetRevision: main"
assert_contains "root Application prunes" "$root_app" "prune: true"
assert_contains "root Application self heals" "$root_app" "selfHeal: true"

gitignore=$(sed -n '1,$p' .gitignore)
assert_contains "terraform.tfvars is gitignored" "$gitignore" "terraform/terraform.tfvars"
assert_contains "terraform.tfstate is gitignored" "$gitignore" "terraform/terraform.tfstate"

report_results "Terraform bootstrap seed"
