resource "kind_cluster" "this" {
  name = var.cluster_name

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"

    node {
      role = "control-plane"

      extra_port_mappings {
        container_port = 30080
        host_port      = 80
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
    annotations = {
      # Threaded to the destroy provisioner via self.metadata, since provisioners
      # cannot reference other resources or vars.
      "terraform.io/kubeconfig" = kind_cluster.this.kubeconfig_path
    }
  }

  # Strip Argo CD finalizers before the namespace is deleted; once helm_release.argocd
  # tears down the controller, nothing else can clear them and namespace delete hangs.
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      export KUBECONFIG='${self.metadata[0].annotations["terraform.io/kubeconfig"]}'
      if ! kubectl cluster-info >/dev/null 2>&1; then
        echo "[argocd-cleanup] cluster unreachable, skipping" >&2
        exit 0
      fi
      for kind in applications.argoproj.io appprojects.argoproj.io applicationsets.argoproj.io; do
        kubectl get "$kind" -n '${self.metadata[0].name}' -o name 2>/dev/null | \
          xargs -r -I{} kubectl patch {} -n '${self.metadata[0].name}' --type=json \
            -p='[{"op":"remove","path":"/metadata/finalizers"}]' 2>/dev/null || true
      done
    EOT
  }

  depends_on = [kind_cluster.this]
}

resource "kubernetes_namespace_v1" "sealed_secrets" {
  metadata {
    name = "sealed-secrets"
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

resource "tls_private_key" "sealed_secrets" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "sealed_secrets" {
  private_key_pem = tls_private_key.sealed_secrets.private_key_pem

  subject {
    common_name  = "sealed-secrets"
    organization = "Sandcastle"
  }

  allowed_uses = [
    "cert_signing",
    "digital_signature",
    "key_encipherment",
    "server_auth",
  ]

  validity_period_hours = 87600
}

resource "kubernetes_secret_v1" "sealed_secrets_key" {
  metadata {
    name      = "sealed-secrets-key"
    namespace = kubernetes_namespace_v1.sealed_secrets.metadata[0].name

    labels = {
      "sealedsecrets.bitnami.com/sealed-secrets-key" = "active"
    }
  }

  data = {
    "tls.crt" = tls_self_signed_cert.sealed_secrets.cert_pem
    "tls.key" = tls_private_key.sealed_secrets.private_key_pem
  }

  type = "kubernetes.io/tls"
}

resource "kubernetes_config_map_v1" "platform_identity" {
  metadata {
    name      = "platform-identity"
    namespace = kubernetes_namespace_v1.backstage.metadata[0].name
  }

  data = {
    GITHUB_OWNER = data.external.git_remote.result.owner
    GITHUB_REPO  = data.external.git_remote.result.repo
    GHCR_BASE    = local.ghcr_base
  }
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

resource "helm_release" "sealed_secrets" {
  name             = "sealed-secrets"
  repository       = "https://bitnami-labs.github.io/sealed-secrets"
  chart            = "sealed-secrets"
  version          = "2.18.6"
  namespace        = kubernetes_namespace_v1.sealed_secrets.metadata[0].name
  create_namespace = false

  lifecycle {
    ignore_changes = [version, values]
  }

  depends_on = [
    kubernetes_namespace_v1.sealed_secrets,
    kubernetes_secret_v1.sealed_secrets_key,
  ]
}

resource "kubectl_manifest" "root_app" {
  yaml_body = yamlencode(merge(
    local.root_application,
    {
      spec = merge(
        local.root_application.spec,
        {
          source = local.root_application_source
        }
      )
    }
  ))

  depends_on = [
    helm_release.argocd,
    kubernetes_config_map_v1.platform_identity,
  ]
}
