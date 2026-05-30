# Application Template

The `application` Template scaffolds a new workload chart under `charts/workloads/<name>/` and opens a pull request against this repository. Use it when a service needs the standard local-platform shape: a Deployment, Service, Gateway API `HTTPRoute`, catalog metadata, and a starter TechDocs site.

## Parameters

The Create form collects the values needed to render the chart and catalog entity:

| Parameter | Required | Purpose |
|-----------|----------|---------|
| `name` | Yes | Slug for the chart, workload, release name base, and catalog Component name. Must match `^[a-z][a-z0-9-]{1,38}$`. |
| `description` | Yes | Human-readable summary used in `Chart.yaml`, `catalog-info.yaml`, and starter docs. |
| `owner` | Yes | Backstage `Group` or `User` that owns the generated Component. Defaults to `platform`. |
| `system` | Yes | Backstage `System` that the generated Component belongs to. |
| `repository` | Yes | Container image repository placed in the chart defaults. Defaults to `${GHCR_BASE}/<name>`. |
| `tag` | Yes | Container image tag placed in the chart defaults. Defaults to `latest`. |
| `host` | No | Public hostname for the generated `HTTPRoute`. Defaults to `<name>.localtest.me`. |
| `port` | No | Container and Service port. Defaults to `80`. |

The template does not run deployment commands. It creates a pull request containing the chart files. After merge, the workloads ApplicationSet discovers the chart and ArgoCD reconciles it. A `ci-pipeline` scaffold can later create `deploy/dev/<name>.yaml` to override the image tag without changing the chart.

## Pull Request Output

When the scaffolder runs, it fetches `templates/application/skeleton/image`, renders every `.njk` file with the submitted values, and writes the result to `charts/workloads/<name>/`.

The pull request branch is named `scaffold/application/<name>` and targets `main`. The PR description records the submitted name, description, owner, system, image repository, image tag, host, and port so reviewers can compare the rendered files with the form input.

After the PR is created, the Template output links directly to the GitHub pull request.
