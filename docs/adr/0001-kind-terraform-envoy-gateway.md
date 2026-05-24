# ADR-0001: KinD + Terraform + Envoy Gateway for Local Development

## Status

Accepted

## Context

The previous local development workflow used minikube with manual `minikube image load` commands, `imagePullPolicy: Never`, and `kubectl port-forward` to access Backstage. Every change cycle required multiple imperative commands that don't transfer to production patterns.

The active TODO "implement a ingress/gatewayapi" was unaddressed — the only way to reach Backstage was via port-forwarding.

## Decision

Replace minikube with **KinD provisioned by Terraform** and exposed via the **Kubernetes Gateway API** (Envoy Gateway).

### Cluster Tool: KinD (over minikube)

KinD runs Kubernetes nodes as Docker containers. Combined with `extraPortMappings`, it gives us a 127.0.0.1 ingress point without external tools.

### IaC Tool: Terraform

Terraform owns the cluster lifecycle (create/destroy) and Gateway controller bootstrap. A single `terraform apply` replaces a sequence of imperative commands. App-layer resources remain as plain YAML in `kubernetes/` for fast iteration.

### Gateway API Controller: Envoy Gateway v1.8

The Gateway API reference implementation. Alternatives considered:
- **Contour** — mature but adds complexity beyond what we need
- **NGINX Gateway Fabric** — viable but less aligned with Gateway API evolution
- **Cilium** — rejected: wants to be the CNI, too heavy for a learning cluster

### Cluster Exposure: NodePort + extraPortMappings

*Superseded for current local development by [ADR-0007: LoadBalancer via cloud-provider-kind](0007-loadbalancer-cloud-provider-kind.md).*

The data plane uses `Service.type=NodePort` on port 30080. KinD's `extraPortMappings` routes host:8080 to the control-plane node's port 30080. Alternatives considered:
- **hostNetwork: true** — bypasses Service abstraction, anti-pattern
- **MetalLB** — same complexity, worse URL story (LB IPs are Docker bridge addresses)
- **Cloud Provider KIND** — out-of-cluster daemon to install and explain

### URL Strategy: backstage.localtest.me:8080

`localtest.me` is a real DNS domain resolving all subdomains to 127.0.0.1 — no `/etc/hosts` edits, real hostname for Gateway listener filtering. HTTPS deferred (would pull in cert-manager or mkcert complexity).

### Provider Stack (3 providers)

| Provider | Purpose |
|----------|---------|
| `tehcyx/kind` | KinD cluster lifecycle |
| `hashicorp/helm` | Gateway API CRDs + Envoy Gateway controller |
| `gavinbunney/kubectl` | EnvoyProxy CR + custom GatewayClass |

The `gavinbunney/kubectl` provider is used instead of `kubernetes_manifest` because the latter validates against CRD schemas at plan time — failing before the CRDs exist.

### Two Helm Releases for Gateway

CRDs and controller are installed as separate Helm releases (`gateway-crds-helm` then `gateway-helm` with `crds.enabled=false`). This matches FluxCD's recommended "CRDs separate from controllers" pattern for future GitOps migration.

### Custom GatewayClass (eg-nodeport)

A custom `GatewayClass` with `parametersRef` pointing to the `EnvoyProxy` CR, rather than patching the default `eg` class the Helm chart creates. Avoids fighting chart ownership on upgrades.

### Namespace Strategy

- `gateway` namespace: owns the Gateway resource (platform-team pattern)
- `backstage` namespace: owns the HTTPRoute, Deployment, Services
- Gateway's `allowedRoutes` uses a namespace selector for `backstage`

### Terraform Layout

Flat files at `terraform/` split by concern: `versions.tf`, `providers.tf`, `variables.tf`, `cluster.tf`, `gateway.tf`, `outputs.tf`. No sub-modules — each logical unit is consumed once; sub-modules would force artificial variable/output plumbing.

## Consequences

- `terraform apply` brings up a working cluster end-to-end
- `terraform destroy` cleanly tears it down
- Browser access at a real hostname with no port-forwarding
- YAML matches production patterns (`imagePullPolicy: IfNotPresent`, registry-prefixed images)
- Future GitOps migration is structural translation, not a refactor
