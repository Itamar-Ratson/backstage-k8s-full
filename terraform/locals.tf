locals {
  root_application = yamldecode(file("${path.module}/bootstrap/root-app.yaml"))
  repo_slug        = "${data.external.git_remote.result.owner}/${data.external.git_remote.result.repo}"
  gitops_repo_url  = "https://github.com/${local.repo_slug}.git"
  ghcr_base        = "ghcr.io/${lower(local.repo_slug)}"
  rbac_admin_user  = lower(data.external.git_remote.result.owner)

  root_application_helm_parameters = [
    {
      name  = "repoURL"
      value = local.gitops_repo_url
    },
    {
      name  = "ghcrBase"
      value = local.ghcr_base
    },
    {
      name  = "rbacAdminUser"
      value = local.rbac_admin_user
    },
    {
      name  = "targetRevision"
      value = local.root_application.spec.source.targetRevision
    }
  ]

  root_application_source = merge(
    local.root_application.spec.source,
    {
      repoURL = local.gitops_repo_url
      helm = {
        parameters = local.root_application_helm_parameters
      }
    }
  )
}
