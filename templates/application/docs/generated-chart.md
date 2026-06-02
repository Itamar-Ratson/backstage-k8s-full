# Generated Chart

## Image Source Files

A chart generated from a container image contains these files:

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

## Chart Source Files

A chart generated from an upstream OCI Helm chart is an umbrella wrapper around that upstream chart. It contains these files:

| Path | Purpose |
|------|---------|
| `Chart.yaml` | Helm chart metadata plus a dependency on the upstream chart, aliased as `app`. |
| `values.yaml` | Wrapper defaults for `host`, `port`, `serviceNameSuffix`, `gateway`, and the `app: {}` alias scope for upstream values. |
| `templates/namespace.yaml` | Namespace resource labeled for Gateway route admission. |
| `templates/httproute.yaml` | Gateway API route for the scaffolded host, targeting the upstream chart Service. |
| `templates/_helpers.tpl` | Naming and Kubernetes label helpers used by the wrapper-owned resources. |
| `catalog-info.yaml` | Backstage Component entity for the workload, using the Helm release instance label for Kubernetes discovery. |
| `mkdocs.yaml` and `docs/index.md` | Starter TechDocs site for the new Component. |

`templates/deployment.yaml` is not generated for chart-source scaffolds because the upstream chart owns the rendered Deployment.

`templates/service.yaml` is not generated for chart-source scaffolds because the upstream chart owns the rendered Service.

The platform-owned umbrella wrapper owns the Namespace, HTTPRoute, and labels helper; the upstream chart owns the rendered Deployment and Service.

For chart-source scaffolds, `serviceNameSuffix` defaults to `app` because the umbrella `Chart.yaml` aliases the upstream dependency as `app`. Conventional upstream fullname helpers derive the rendered Service name from the Helm release name plus `.Chart.Name`, and Helm resolves `.Chart.Name` to the alias inside the subchart. Override `serviceNameSuffix` only when the upstream chart sets `fullnameOverride` by default or uses a non-standard fullname helper that renders a different Service name.

## Conventions

The scaffolded chart follows the repo's local platform conventions:

- The chart is created under `charts/workloads/<name>/`.
- Image-source environment override values can be added later at `deploy/dev/<name>.yaml`, usually by the `ci-pipeline` template.
- Chart-source scaffolds immediately create `deploy/dev/<name>.yaml` with an empty `app: {}` override scope.
- Kubernetes names for wrapper-owned resources flow through the `workload.fullname` helper and are truncated to DNS-safe lengths where needed.
- Workload labels use the standard `app.kubernetes.io/*` keys plus `helm.sh/chart`.
- Image-source Deployments use the generated `image.repository`, `image.tag`, and `image.pullPolicy` values.
- Image-source Services and containers both use the submitted `port` value with a named `http` target port.
- Chart-source upstream values live under the `app:` alias scope.
- Chart-source `serviceNameSuffix` defaults to `app` and resolves the HTTPRoute backend Service name as `<release>-<serviceNameSuffix>`.
- Chart-source HTTPRoutes target the upstream chart's Service as their backend.
- The `HTTPRoute` attaches to the shared `edge-gateway` Gateway in the `gateway` namespace.
- The default hostname is `<name>.localtest.me`, matching the local Envoy Gateway wildcard listener.
- The generated Component is marked `lifecycle: experimental` and includes `backstage.io/managed-by-template: application`.
- The generated Component includes `backstage.io/techdocs-ref: dir:.`, so its co-located docs site can appear in Backstage.

## Before Merge

Reviewers should check that the owner and system point at real catalog entities, the image repository and tag are the intended deployable artifact, and the namespace that will host the workload is labeled for Gateway route admission.

The edge Gateway only admits routes from namespaces carrying the configured opt-in label, currently `gateway-routes=enabled`. Without that namespace label, the generated `HTTPRoute` can exist but will not be accepted by the shared Gateway.
