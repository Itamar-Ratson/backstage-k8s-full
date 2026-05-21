# Deploying Backstage on Kubernetes (KinD + Terraform + Gateway API)

A local Kubernetes development environment for Backstage, provisioned by Terraform with Envoy Gateway for ingress.

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

## Step 1: Create the Backstage App

```bash
npx @backstage/create-app@latest
```

This scaffolds a complete Backstage application in a `backstage/` folder with all necessary files.

## Step 2: Configure Repository Files

Two files in your generated `backstage/` directory need to be replaced or added. The reference versions live in this repo at the matching paths — overwrite or create them in your `backstage/` directory before building:

| File | Purpose |
|------|---------|
| `backstage/Dockerfile` | Multi-stage build that compiles everything inside Docker |
| `backstage/.dockerignore` | Must NOT exclude source files (unlike the host build version) |

After scaffolding, install the GitHub catalog discovery backend module:

```bash
cd backstage
yarn --cwd packages/backend add @backstage/plugin-catalog-backend-module-github
```

Then add this import to `packages/backend/src/index.ts`:

```typescript
backend.add(import('@backstage/plugin-catalog-backend-module-github'));
```

This enables the catalog to discover `catalog-info.yaml` files from GitHub via URL discovery.

Key configuration note: `backstage/.dockerignore` must NOT exclude `packages/*/src`. The default from `create-app` excludes source files, which causes `yarn tsc` to fail with "No inputs were found".

Production app-config is no longer baked into the image. Instead, the Helm chart renders a ConfigMap from `values.appConfig` and mounts it into the pod at runtime via `--config /etc/backstage/app-config.runtime.yaml`. To change runtime configuration, edit `deploy/dev/backstage.yaml` (or the chart's `values.appConfig` defaults) and run `helm upgrade` — no image rebuild required.

## Step 3: Provision the Cluster

Terraform brings up a KinD cluster and the Envoy Gateway controller:

```bash
cd terraform
terraform init
terraform apply
```

This creates:
- A 2-node KinD cluster (1 control-plane + 1 worker) with port 8080 mapped to the Envoy data plane
- Gateway API CRDs + Envoy Gateway controller
- A custom `GatewayClass` (`eg-nodeport`) wired for NodePort exposure

Verify the cluster is ready:

```bash
kubectl get nodes
# Should show 2 nodes (control-plane + worker) in Ready state
```

## Step 4: Confirm the Backstage Image

The dev overlay pulls Backstage from GHCR:

```bash
grep -A3 '^image:' deploy/dev/backstage.yaml
```

The `image.tag` value is populated by the CI/CD image build workflow after the first successful build. Until that first build has landed a tag in `deploy/dev/backstage.yaml`, a fresh clone may not have a pullable image for the local Helm deployment.

GHCR packages default to private after the first push. Flip package visibility to public manually in GitHub package settings once per package so the local cluster can pull without image pull secrets.

## Verifying Images

Verify a CI-built image with cosign:

```bash
cosign verify ghcr.io/itamar-ratson/backstage-k8s-full/<app>:<sha> \
  --certificate-identity-regexp ".+" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## First-Deploy Bootstrap

A fresh clone needs the first image build to populate `deploy/dev/backstage.yaml` with an `image.tag` value before the local Helm deployment can pull Backstage from GHCR. After the build workflow lands, trigger the bootstrap build with a small path-matching change under `backstage/`; [issue #5](https://github.com/Itamar-Ratson/backstage-k8s-full/issues/5) is the bootstrap runbook for that first deployment.

## Step 5: Create the GitHub App Secret

Backstage discovers catalog entities from this GitHub repo at runtime, uses scaffolder actions to publish GitHub changes, and supports GitHub sign-in. It uses one GitHub App for all of those GitHub calls.

1. Create and install a GitHub App for this repo:
   - **Repository access:** Only select `Itamar-Ratson/backstage-k8s-full`
   - **Permissions:**
     - `Contents: Read and write` — read catalog-info.yaml files and publish scaffolded changes
     - `Commit statuses: Read` — preflight check the catalog URL provider performs before reading (without this you get `403 Forbidden` and an empty catalog)
     - `Pull requests: Read and write` — open pull requests from scaffolder actions
     - `Workflows: Read and write` — publish changes that include workflow files
     - `Metadata: Read` — auto-granted
   - **Callback URL:** `http://backstage.localtest.me:8080/api/auth/github/handler/frame`

2. Create the Kubernetes secret. Either use the imperative form:

```bash
kubectl create namespace backstage --dry-run=client -o yaml | kubectl apply -f - --context kind-backstage
kubectl create secret generic backstage-github-app \
  --from-literal=APP_ID="$APP_ID" \
  --from-literal=CLIENT_ID="$CLIENT_ID" \
  --from-literal=CLIENT_SECRET="$CLIENT_SECRET" \
  --from-file=PRIVATE_KEY=path/to/private-key.pem \
  -n backstage --context kind-backstage
```

Keep the downloaded `.pem` file out of version control.

Verify:

```bash
kubectl get secret backstage-github-app -n backstage --context kind-backstage
```

This Secret is a one-time bootstrap prerequisite for a fresh kind cluster. Verify that it exists before installing the Backstage chart; the chart consumes the Secret but does not create it.

## Step 6: Deploy with Helm

Install the edge-gateway chart (shared Gateway resource) and then the backstage chart:

```bash
# Install the edge-gateway (creates the gateway namespace)
helm upgrade --install edge-gateway charts/platform/edge-gateway \
  --namespace gateway --create-namespace --wait \
  --kube-context kind-backstage \
  -f deploy/dev/edge-gateway.yaml

# Pre-create the backstage namespace and apply the opt-in label (idempotent)
kubectl create namespace backstage --dry-run=client -o yaml | kubectl apply -f - --context kind-backstage
kubectl label namespace backstage gateway-routes=enabled --overwrite --context kind-backstage

# Install backstage
helm upgrade --install backstage charts/workloads/backstage \
  --namespace backstage --wait --timeout 5m \
  --kube-context kind-backstage \
  -f deploy/dev/backstage.yaml
```

**Namespace label requirement:** Any app fronting the shared edge-gateway must have its namespace labeled with `gateway-routes=enabled`. The Gateway uses a label-selector `allowedRoutes` policy — only HTTPRoutes in namespaces carrying this label are admitted. Apply the label before installing workloads that define HTTPRoutes.

## Step 7: Access Backstage

Open <http://backstage.localtest.me:8080> in your browser. No port-forwarding required.

`localtest.me` is a real DNS domain that resolves to 127.0.0.1. Traffic flows through KinD's port mappings into the Envoy Gateway, which routes based on the hostname to the Backstage service.

You should see both `Guest` and `GitHub` sign-in options.

## Manual RBAC Demo

Run the Helm deployment sequence above after changing frontend code or pulling a new image tag.

Then verify the end-to-end flow:

1. Visit <http://backstage.localtest.me:8080>.
2. Confirm both Guest and GitHub sign-in buttons are visible.
3. Sign in with GitHub.
4. Open `/rbac` and confirm the `viewer` and `platform-admin` roles are listed.
5. Sign out.
6. Sign in as guest.
7. Open a scaffolder template and attempt to create it.
8. Confirm execution is denied by the permission framework.

## Updating Backstage

When you make changes and need to redeploy:

```bash
# Upgrade the helm release with the image tag recorded in deploy/dev/backstage.yaml
helm upgrade backstage charts/workloads/backstage \
  --namespace backstage --wait --timeout 5m \
  --kube-context kind-backstage \
  -f deploy/dev/backstage.yaml
```

## Useful Commands

```bash
# View pod logs
kubectl logs -n backstage -l app.kubernetes.io/name=backstage

# View pod logs with timestamps
kubectl logs -n backstage deploy/backstage --timestamps

# Restart deployment
kubectl rollout restart deployment backstage -n backstage

# Check Gateway status
kubectl get gateway -n gateway
kubectl get httproute -n backstage

# View Envoy Gateway controller logs
kubectl logs -n envoy-gateway-system deploy/envoy-gateway

# View all resources in the namespace
kubectl get all -n backstage

# Uninstall charts
helm uninstall backstage -n backstage
helm uninstall edge-gateway -n gateway

# Tear down the cluster
cd terraform && terraform destroy
```

## Smoke Test

Run the full end-to-end verification. This assumes `deploy/dev/backstage.yaml` points at a Backstage image tag that exists in GHCR:

```bash
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init -backend=false -input=false
terraform -chdir=terraform validate
helm lint charts/platform/edge-gateway -f deploy/dev/edge-gateway.yaml
helm lint charts/workloads/backstage -f deploy/dev/backstage.yaml
curl -fsS --retry 10 --retry-delay 3 --retry-connrefused --retry-all-errors http://backstage.localtest.me:8080 | grep -q '<title>'
```

Run Terraform validation only:

```bash
terraform -chdir=terraform fmt -check -recursive
terraform -chdir=terraform init -backend=false -input=false
terraform -chdir=terraform validate
```

Run Helm chart linting only:

```bash
./tests/charts/test-actionlint.sh
./tests/charts/test-templates-registered.sh
./tests/charts/test-chart-layout.sh
helm dependency build charts/platform/argo-cd
helm lint charts/platform/argo-cd
helm dependency build charts/platform/envoy-gateway
helm lint charts/platform/envoy-gateway
helm lint charts/platform/edge-gateway -f deploy/dev/edge-gateway.yaml
helm lint charts/workloads/backstage -f deploy/dev/backstage.yaml
```

## Next Steps

1. **Define a production auth target** — The kind deployment now carries the supported GitHub OAuth path. A production deployment still needs HTTPS callbacks, environment-specific OAuth Apps, and a decision on guest auth. See the [Authentication documentation](https://backstage.io/docs/auth/).

2. **Add the Helm chart scaffolder template** — Use Backstage to scaffold new workload charts and publish them as pull requests instead of copying `charts/` by hand.

3. **Decommission a scaffolded Helm chart** — Use the `helm-chart-decommission` template to select a catalog Component, verify it was created by `helm-chart`, block removal when dependents still reference it, and open a PR deleting `charts/<name>/`. Merging that PR removes the entity from catalog discovery on the next refresh. The template does not uninstall the running release; do that manually with `helm uninstall <name> -n <namespace>` until ArgoCD lands.

4. **Set up TechDocs** — Add `backstage.io/techdocs-ref` annotations and enable documentation generation and viewing.

5. **Deploy to a production cluster** — Move beyond KinD to EKS, GKE, or another managed Kubernetes service.

6. **Add HTTPS** — Configure cert-manager or mkcert for TLS termination at the Gateway.

## Architecture Decision

See [ADR-0001](docs/adr/0001-kind-terraform-envoy-gateway.md) for the full rationale behind the KinD + Terraform + Envoy Gateway architecture.
