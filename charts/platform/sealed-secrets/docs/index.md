# Sealed Secrets

This chart mirrors the Terraform bootstrap install of the Bitnami Labs Sealed Secrets controller. Terraform installs the controller once so the cluster can decrypt sealed material during first boot; Argo CD then reconciles `charts/platform/sealed-secrets` like the other platform charts.

## Bootstrap Key

Terraform generates a 4096-bit RSA private key and a 10-year self-signed certificate, then seeds them into the controller namespace as a TLS Secret labeled `sealedsecrets.bitnami.com/sealed-secrets-key=active`. The keypair lives in `terraform.tfstate`, which is intentionally gitignored with the rest of the bootstrap state.

Routine `kind delete cluster && terraform apply` preserves the sealing key because Terraform state is still present. The recreated controller adopts the same seeded key, so committed `SealedSecret` manifests remain decryptable.

## Rotation

`terraform destroy` removes the state-backed keypair and invalidates committed sealed material. Explicitly running `terraform taint tls_private_key.sealed_secrets` and applying again is the targeted rotation path when the cluster should receive a new sealing key.

The controller's scheduled key rotation appends new keys without invalidating old keys, so existing sealed material remains decryptable across controller-managed rotations.
