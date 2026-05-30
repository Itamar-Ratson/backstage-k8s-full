#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../charts/helpers.sh
source "$(dirname "$0")/../charts/helpers.sh"

echo "=== Terraform bootstrap seed tests ==="

assert_file_exists "root Application manifest exists" "terraform/bootstrap/root-app.yaml"
assert_file_exists "tfvars example exists" "terraform/terraform.tfvars.example"

terraform_config=$(find terraform -name '*.tf' -type f -print0 | xargs -0 sed -n '1,$p')
argocd_namespace_config=$(awk '/resource "kubernetes_namespace_v1" "argocd"/,/depends_on = \[kind_cluster.this\]/' terraform/cluster.tf)

assert_contains "ArgoCD seed helm release exists" "$terraform_config" 'resource "helm_release" "argocd"'
assert_contains "ArgoCD release ignores self-managed drift" "$terraform_config" "ignore_changes = [version, values]"
assert_contains "root app loaded from manifest file" "$terraform_config" 'yamldecode(file("${path.module}/bootstrap/root-app.yaml"))'
assert_contains "backstage namespace is managed" "$terraform_config" 'resource "kubernetes_namespace_v1" "backstage"'
assert_contains "backstage namespace has gateway opt-in label" "$terraform_config" 'gateway-routes = "enabled"'
assert_contains "argocd namespace is managed" "$terraform_config" 'resource "kubernetes_namespace_v1" "argocd"'
assert_not_contains "argocd namespace gateway opt-in label moved to ApplicationSet" "$argocd_namespace_config" 'gateway-routes = "enabled"'
assert_contains "ArgoCD helm release uses managed namespace" "$terraform_config" 'namespace        = kubernetes_namespace_v1.argocd.metadata[0].name'
assert_contains "GitHub App secret is managed" "$terraform_config" 'resource "kubernetes_secret_v1" "backstage_github_app"'
assert_contains "GitHub owner variable is required" "$terraform_config" 'variable "github_owner"'
assert_contains "GitHub repo variable is required" "$terraform_config" 'variable "github_repo"'
assert_contains "GitOps repo URL is derived" "$terraform_config" 'gitops_repo_url  = "https://github.com/${local.repo_slug}.git"'
assert_contains "GHCR base is derived" "$terraform_config" 'ghcr_base        = "ghcr.io/${lower(local.repo_slug)}"'
assert_contains "platform identity ConfigMap is managed" "$terraform_config" 'resource "kubernetes_config_map_v1" "platform_identity"'
assert_contains "GitHub App private key is sensitive" "$terraform_config" 'variable "PRIVATE_KEY"'
assert_contains "GitHub owner variable is required" "$terraform_config" 'variable "github_owner"'
assert_not_contains "GitHub owner has no default" "$(awk '/variable "github_owner"/,/^}/' terraform/variables.tf)" 'default'
assert_contains "GitHub repo variable is required" "$terraform_config" 'variable "github_repo"'
assert_not_contains "GitHub repo has no default" "$(awk '/variable "github_repo"/,/^}/' terraform/variables.tf)" 'default'
assert_contains "GitOps repo URL is derived from slug" "$terraform_config" 'gitops_repo_url  = "https://github.com/${local.repo_slug}.git"'
assert_contains "GHCR base is derived from slug" "$terraform_config" 'ghcr_base        = "ghcr.io/${lower(local.repo_slug)}"'
assert_contains "RBAC admin user is lowercased from owner" "$terraform_config" 'rbac_admin_user  = lower(var.github_owner)'
assert_contains "Platform identity ConfigMap is managed" "$terraform_config" 'resource "kubernetes_config_map_v1" "platform_identity"'
assert_contains "Platform identity includes owner" "$terraform_config" 'GITHUB_OWNER = var.github_owner'
assert_contains "Platform identity includes repo" "$terraform_config" 'GITHUB_REPO  = var.github_repo'
assert_contains "Platform identity includes GHCR base" "$terraform_config" 'GHCR_BASE    = local.ghcr_base'
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
assert_contains "Terraform root Application injects repoURL Helm parameter" "$terraform_config" 'name  = "repoURL"'
assert_contains "Terraform root Application injects ghcrBase Helm parameter" "$terraform_config" 'name  = "ghcrBase"'
assert_contains "Terraform root Application injects rbacAdminUser Helm parameter" "$terraform_config" 'name  = "rbacAdminUser"'
assert_contains "Terraform root Application passes lowercased RBAC admin user" "$terraform_config" "value = local.rbac_admin_user"
assert_contains "Terraform root Application injects targetRevision Helm parameter" "$terraform_config" 'name  = "targetRevision"'

gitignore=$(sed -n '1,$p' .gitignore)
assert_contains "terraform.tfvars is gitignored" "$gitignore" "terraform/terraform.tfvars"
assert_contains "terraform.tfstate is gitignored" "$gitignore" "terraform/terraform.tfstate"

report_results "Terraform bootstrap seed"
