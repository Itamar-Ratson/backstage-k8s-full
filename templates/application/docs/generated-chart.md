# Generated Chart

## Files Created

A generated chart contains these files:

| Path | Purpose |
|------|---------|
| `Chart.yaml` | Helm chart metadata with the submitted name and description. |
| `values.yaml` | Runtime defaults for replicas, image repository, image tag, host, port, Gateway reference, and resource requests/limits. |
| `templates/deployment.yaml` | Single-container Deployment using the submitted image and port. |
| `templates/service.yaml` | ClusterIP Service targeting the Deployment's named `http` port. |
| `templates/httproute.yaml` | Gateway API route for the submitted or default hostname. |
| `templates/_helpers.tpl` | Shared naming and Kubernetes label helpers. |
| `catalog-info.yaml` | Backstage Component entity for the workload. |
| `mkdocs.yaml` and `docs/index.md` | Starter TechDocs site for the new Component. |

## Conventions

The scaffolded chart follows the repo's local platform conventions:

- The chart is created under `charts/workloads/<name>/`.
- Environment override values can be added later at `deploy/dev/<name>.yaml`, usually by the `ci-pipeline` template.
- Kubernetes names flow through the `workload.fullname` helper and are truncated to DNS-safe lengths where needed.
- Workload labels use the standard `app.kubernetes.io/*` keys plus `helm.sh/chart`.
- The Deployment uses the generated `image.repository`, `image.tag`, and `image.pullPolicy` values.
- The Service and container both use the submitted `port` value with a named `http` target port.
- The `HTTPRoute` attaches to the shared `edge-gateway` Gateway in the `gateway` namespace.
- The default hostname is `<name>.localtest.me`, matching the local Envoy Gateway wildcard listener.
- The generated Component is marked `lifecycle: experimental` and includes `backstage.io/managed-by-template: application`.
- The generated Component includes `backstage.io/techdocs-ref: dir:.`, so its co-located docs site can appear in Backstage.

## Before Merge

Reviewers should check that the owner and system point at real catalog entities, the image repository and tag are the intended deployable artifact, and the namespace that will host the workload is labeled for Gateway route admission.

The edge Gateway only admits routes from namespaces carrying the configured opt-in label, currently `gateway-routes=enabled`. Without that namespace label, the generated `HTTPRoute` can exist but will not be accepted by the shared Gateway.
