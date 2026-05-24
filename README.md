# Deploying Backstage on Kubernetes (KinD + Terraform + ArgoCD)

A local Kubernetes development environment for Backstage, provisioned by Terraform and reconciled by ArgoCD. Envoy Gateway provides ingress for workloads.

**Official Documentation:**

- [Backstage Docker Deployment](https://backstage.io/docs/deployment/docker/)
- [Backstage Kubernetes Deployment](https://backstage.io/docs/deployment/k8s)
- [Backstage Authentication](https://backstage.io/docs/auth/)

## Prerequisites

Install the following tools:

- [Docker](https://docs.docker.com/get-docker/)
- [KinD](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)
- [Terraform](https://developer.hashicorp.com/terraform/downloads) (>= 1.5)
- [Helm](https://helm.sh/docs/intro/install/) (>= 3.x)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [actionlint](https://github.com/rhysd/actionlint/releases) (used by CI to validate workflow files)
- [yq](https://github.com/mikefarah/yq/releases) (used by CI to validate template catalog registrations)
- [cosign](https://docs.sigstore.dev/cosign/installation/) (optional, only needed to verify GHCR image signatures)
- Node.js 20 or 22 (for building Backstage from source)

### Node.js Version

Backstage requires Node.js 20 or 22. Using an older or incompatible version will cause native module compilation failures, particularly with `isolated-vm` which depends on V8 APIs that change between Node versions.

```bash
# Install nvm if not already installed
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
source ~/.bashrc

# Install and use Node 22 (recommended - matches the Dockerfile runtime)
nvm install 22
nvm use 22
```

### Build Dependencies

Install build tools required for compiling native Node.js modules:

```bash
sudo apt-get update
sudo apt-get install -y python3 g++ build-essential
```

## Bootstrap

1. Install tools: Docker, KinD, kubectl, Helm, Terraform, Node.js, `actionlint`, and `yq`.
2. Create and install the GitHub App using the [operator guide](docs/operator/github-app-setup.md).
3. Fill `terraform/terraform.tfvars` from `terraform/terraform.tfvars.example` with the GitHub App credentials. Keep both the downloaded `.pem` key and `terraform.tfvars` out of version control.
4. Apply Terraform:

   ```bash
   cd terraform && terraform apply
   ```

5. Wait for ArgoCD to finish syncing, then visit <http://backstage.localtest.me>.

Terraform creates the KinD cluster, the Backstage namespace, the `backstage-github-app` Secret, the ArgoCD seed install, and the root ArgoCD Application. ArgoCD then reconciles platform charts from `charts/platform/` and workloads from `charts/workloads/`.

The dev overlay pulls Backstage from GHCR using the tag in `deploy/dev/backstage.yaml`. The CI image build workflow updates that tag after a successful image build. GHCR packages default to private after the first push; set package visibility to public once per package so the local cluster can pull without image pull secrets.

## Verifying Images

Verify a CI-built image with cosign:

```bash
cosign verify ghcr.io/itamar-ratson/backstage-k8s-full/<app>:<sha> \
  --certificate-identity-regexp ".+" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Verifying the install

Check ArgoCD Applications first:

```bash
kubectl get applications -n argocd
```

The platform Applications should include `argo-cd`, `envoy-gateway`, and `edge-gateway`. The workloads ApplicationSet should create `backstage` from `charts/workloads/backstage` and `deploy/dev/backstage.yaml`.

Then check Backstage through the Gateway:

```bash
curl -fsS --retry 10 --retry-delay 3 --retry-connrefused --retry-all-errors \
  http://backstage.localtest.me | grep -q '<title>'
```

Open <http://backstage.localtest.me> in your browser. No port-forwarding is required.

`localtest.me` is a real DNS domain that resolves to 127.0.0.1. Traffic flows through KinD's port mappings into the Envoy Gateway, which routes based on the hostname to the Backstage service.

You should see both `Guest` and `GitHub` sign-in options.

Open ArgoCD at <http://argocd.localtest.me>. The username is `admin`; retrieve the initial password with:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

## Operations

**Force a sync during debugging:** the local KinD cluster has no GitHub webhook receiver, so use ArgoCD as the escape hatch when you do not want to wait for polling:

```bash
argocd app sync <app>
```

**Rotate GitHub App credentials:** edit `terraform/terraform.tfvars`, re-apply Terraform, then restart Backstage so envFrom values are re-read:

```bash
cd terraform && terraform apply
kubectl rollout restart deployment/backstage -n backstage
```

**Future migration path:** Terraform-managed Secrets are the local-development bootstrap path. ExternalSecrets Operator is the planned migration when production or shared cloud secret stores arrive.

## Manual RBAC Demo

After changing frontend code or pulling a new image tag, wait for ArgoCD to sync the updated `deploy/dev/backstage.yaml` value.

Then verify the end-to-end flow:

1. Visit <http://backstage.localtest.me>.
2. Confirm both Guest and GitHub sign-in buttons are visible.
3. Sign in with GitHub.
4. Open `/rbac` and confirm the `viewer` and `platform-admin` roles are listed.
5. Sign out.
6. Sign in as guest.
7. Open a scaffolder template and attempt to create it.
8. Confirm execution is denied by the permission framework.

## Useful Commands

```bash
# View ArgoCD Applications
kubectl get applications -n argocd

# View pod logs
kubectl logs -n backstage -l app.kubernetes.io/name=backstage

# View pod logs with timestamps
kubectl logs -n backstage deploy/backstage --timestamps

# Restart deployment
kubectl rollout restart deployment backstage -n backstage

# Check Gateway status
kubectl get gateway -n gateway
kubectl get httproute -n backstage
kubectl get httproute -n argocd

# View Envoy Gateway controller logs
kubectl logs -n envoy-gateway-system deploy/envoy-gateway

# View all resources in the namespace
kubectl get all -n backstage

# Tear down the cluster
cd terraform && terraform destroy
```

## Next Steps

1. **Define a production auth target** — The kind deployment now carries the supported GitHub App auth path. A production deployment still needs HTTPS callbacks, environment-specific GitHub Apps, and a decision on guest auth. See the [Authentication documentation](https://backstage.io/docs/auth/).

2. **Add the application scaffolder template** — Use the `application` template to scaffold new deployable applications and publish them as pull requests instead of copying chart files by hand. Merged charts under `charts/workloads/` are discovered by the workloads ApplicationSet.

3. **Decommission a scaffolded application** — Use the `decommission-component` template to select a catalog Component, verify it was created by a scaffolder template, block removal when dependents still reference it, and open a PR deleting the paths recorded in `backstage.io/source-paths`. Merging that PR lets ArgoCD prune the running resources.

4. **Set up TechDocs** — Add `backstage.io/techdocs-ref` annotations and enable documentation generation and viewing.

5. **Deploy to a production cluster** — Move beyond KinD to EKS, GKE, or another managed Kubernetes service.

6. **Add HTTPS** — Configure cert-manager or mkcert for TLS termination at the Gateway.

## Architecture Decision

See [ADR-0001](docs/adr/0001-kind-terraform-envoy-gateway.md) for the full rationale behind the KinD + Terraform + Envoy Gateway architecture.
