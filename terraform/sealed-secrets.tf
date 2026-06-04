resource "kubernetes_namespace_v1" "sealed_secrets" {
  metadata {
    name = "sealed-secrets"
  }

  depends_on = [kind_cluster.this]
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
