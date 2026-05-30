# Deploying Backstage on Kubernetes

A fork-and-run local Kubernetes environment for Backstage on KinD, provisioned by Terraform and continuously reconciled by ArgoCD, with Envoy Gateway for ingress.

## Prerequisites

Install these tools:

- [Docker](https://docs.docker.com/get-docker/)
- [KinD](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) (>= 1.5)
- [Helm](https://helm.sh/docs/intro/install/) (>= 3)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

## One-time GitHub setup

1. Fork the repo.
2. Clone your fork, not the upstream repository. For future fork-based projects, clone your fork the usual way.
3. Create and install the GitHub App with the [operator setup guide](docs/operator/github-app-setup.md).
4. Copy the Terraform variables example:

   ```bash
   cp terraform/terraform.tfvars.example terraform/terraform.tfvars
   ```

5. Fill `terraform/terraform.tfvars` with the GitHub App credentials; the downloaded .pem file and terraform/terraform.tfvars are gitignored.

## Boot the cluster

Run Terraform:

```bash
cd terraform && terraform apply
```

Wait for ArgoCD to finish syncing.

Open <http://backstage.localtest.me>. You'll see Backstage through the local Envoy Gateway.

## Verify it's working

Check Backstage through the Gateway:

```bash
curl -fsS --retry 10 --retry-delay 3 --retry-connrefused --retry-all-errors \
  http://backstage.localtest.me | grep -q '<title>'
```

Retrieve the ArgoCD admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

Open <http://backstage.localtest.me> and confirm the Guest and GitHub sign-in buttons are visible.

## What's next

- Use [operator operations](docs/operator/operations.md) for syncs, credential rotation, common commands, and image verification.
- Run the [manual RBAC demo](docs/operator/manual-rbac-demo.md) to check Guest and GitHub permissions.
- Prepare for local Backstage source builds with the [developer setup guide](docs/developer/backstage-development.md).

See [ADR-0001](docs/adr/0001-kind-terraform-envoy-gateway.md) for the KinD + Terraform + Envoy Gateway rationale.
