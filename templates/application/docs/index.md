# Application Template

The `application` Template scaffolds a new workload chart under `charts/workloads/<name>/` and opens a pull request against this repository. Use it when a workload should be deployed by the workloads ApplicationSet from either a container image or a third-party Helm chart.

## Parameters

The Create form collects the values needed to render the chart and catalog entity:

| Parameter | Required | Purpose |
|-----------|----------|---------|
| `sourceType` | Yes | Choose `image` for the standard local-platform Deployment / Service / HTTPRoute shape, or `chart` for an umbrella chart around an upstream OCI Helm chart. Defaults to `image`. |
| `name` | Yes | Slug for the chart, workload, release name base, and catalog Component name. Must match `^[a-z][a-z0-9-]{1,38}$`. |
| `description` | Yes | Human-readable summary used in `Chart.yaml`, `catalog-info.yaml`, and starter docs. |
| `owner` | Yes | Backstage `Group` or `User` that owns the generated Component. Defaults to `platform`. |
| `system` | Yes | Backstage `System` that the generated Component belongs to. |
| `repository` | Image only | Container image repository placed in the chart defaults. Defaults to `${GHCR_BASE}/<name>`. |
| `tag` | Image only | Container image tag placed in the chart defaults. Defaults to `latest`. |
| `host` | Image only | Public hostname for the generated `HTTPRoute`. Defaults to `<name>.localtest.me`. |
| `port` | Image only | Container and Service port. Defaults to `80`. |
| `chartRef` | Chart only | OCI chart reference, with optional `oci://` prefix, including the upstream chart version. |
| `serviceNameSuffix` | Chart only | Suffix appended to the Helm release name to form the upstream Service name targeted by the generated `HTTPRoute`. |
| `port` | Chart only | Upstream Service port targeted by the generated `HTTPRoute`. |
| `host` | Chart only | Public hostname for the generated `HTTPRoute`. Defaults to `<name>.localtest.me`. |

The template does not run deployment commands. It creates a pull request containing the chart files. After merge, the workloads ApplicationSet discovers the chart and ArgoCD reconciles it. A `ci-pipeline` scaffold can later create `deploy/dev/<name>.yaml` to override the image tag without changing the chart.

## Pull Request Output

When the scaffolder runs with `sourceType: image`, it fetches `templates/application/skeleton/image`, renders every `.njk` file with the submitted values, and writes the result to `charts/workloads/<name>/`.

When the scaffolder runs with `sourceType: chart`, it fetches `templates/application/skeleton/chart`, writes an umbrella chart at `charts/workloads/<name>/`, and writes `deploy/dev/<name>.yaml` with an empty `app: {}` override scope for the upstream dependency alias. The umbrella chart owns the Namespace, HTTPRoute, and labels helper; the upstream chart owns the rendered Deployment and Service.

The pull request branch is named `scaffold/application/<name>` and targets `main`. The PR description records the submitted source type and source-specific fields so reviewers can compare the rendered files with the form input.

After the PR is created, the Template output links directly to the GitHub pull request.
