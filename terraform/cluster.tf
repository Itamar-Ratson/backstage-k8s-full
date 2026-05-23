resource "kind_cluster" "this" {
  name = var.cluster_name

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      extra_port_mappings {
        container_port = 30080
        host_port      = 8080
        protocol       = "TCP"
      }
    }

    node {
      role = "worker"
    }
  }
}

resource "kubernetes_namespace_v1" "backstage" {
  metadata {
    name = "backstage"

    labels = {
      gateway-routes = "enabled"
    }
  }

  depends_on = [kind_cluster.this]
}

resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }

  depends_on = [kind_cluster.this]
}

resource "kubernetes_secret_v1" "backstage_github_app" {
  metadata {
    name      = "backstage-github-app"
    namespace = kubernetes_namespace_v1.backstage.metadata[0].name
  }

  data = {
    APP_ID        = var.APP_ID
    CLIENT_ID     = var.CLIENT_ID
    CLIENT_SECRET = var.CLIENT_SECRET
    PRIVATE_KEY   = var.PRIVATE_KEY
  }

  type = "Opaque"
}

resource "helm_release" "argocd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "9.5.15"
  namespace        = kubernetes_namespace_v1.argocd.metadata[0].name
  create_namespace = false

  lifecycle {
    ignore_changes = [version, values]
  }

  depends_on = [kubernetes_namespace_v1.argocd]
}

resource "kubectl_manifest" "root_app" {
  yaml_body = yamlencode(merge(
    local.root_application,
    {
      spec = merge(
        local.root_application.spec,
        {
          source = merge(
            local.root_application.spec.source,
            {
              repoURL = var.gitops_repo_url
            }
          )
        }
      )
    }
  ))

  depends_on = [helm_release.argocd]
}
