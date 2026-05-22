# Application Template

The `application` Template scaffolds a new workload chart under `charts/workloads/<name>/`, adds a matching `deploy/dev/<name>.yaml` values file, and opens a pull request against this repository. Use it when a service needs the standard local-platform shape: a Deployment, Service, Gateway API `HTTPRoute`, catalog metadata, and a starter TechDocs site.

## Parameters

The Create form collects the values needed to render the chart and catalog entity:

| Parameter | Required | Purpose |
|-----------|----------|---------|
| `name` | Yes | Slug for the chart, workload, release name base, and catalog Component name. Must match `^[a-z][a-z0-9-]{1,38}$`. |
| `description` | Yes | Human-readable summary used in `Chart.yaml`, `catalog-info.yaml`, and starter docs. |
| `owner` | Yes | Backstage `Group` or `User` that owns the generated Component. Defaults to `platform`. |
| `system` | Yes | Backstage `System` that the generated Component belongs to. |
| `image` | Yes | Container image string placed in the dev values file. Defaults to `nginx:latest`. |
| `host` | No | Public hostname for the generated `HTTPRoute`. Defaults to `<name>.localtest.me`. |
| `port` | No | Container and Service port. Defaults to `80`. |

The template does not run deployment commands. It creates a pull request containing the chart files and dev values file. After merge, the workloads ApplicationSet discovers the chart and ArgoCD reconciles it.

## Pull Request Output

When the scaffolder runs, it fetches `templates/application/skeleton`, renders every `.njk` file with the submitted values, and writes the result to `charts/workloads/<name>/`. It also renders the dev values skeleton to `deploy/dev/<name>.yaml`.

The pull request branch is named `scaffold/application/<name>` and targets `main`. The PR description records the submitted name, description, owner, system, image, host, and port so reviewers can compare the rendered files with the form input.

After the PR is created, the Template output links directly to the GitHub pull request.
