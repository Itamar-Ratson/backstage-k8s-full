# Helm Chart Decommission Template

The `helm-chart-decommission` Template opens a pull request that removes a scaffolded workload chart from this repository. It is intended for Components originally created by the `helm-chart` Template.

The Template is deliberately conservative. It validates the selected catalog entity, checks for catalog relationships that would make removal unsafe, calculates the exact repository files to delete, and then creates a GitHub pull request for review.

## What It Removes

The pull request deletes the selected chart directory:

```text
charts/workloads/<component-name>/
```

For charts scaffolded by the `helm-chart` Template, that directory includes the Helm chart, workload catalog entity, `mkdocs.yaml`, and the chart's `docs/` folder. The pull request also deletes `deploy/dev/<component-name>.yaml`. Removing both files stops the workloads ApplicationSet from materializing the Application for that Component.

## What It Does Not Remove

The Template does not run imperative Kubernetes commands, delete namespaces, or clean up resources outside the Helm release directly. After the pull request merges, ArgoCD detects the removed chart directory and prunes the running release through the workloads ApplicationSet.

The Template also does not remove external DNS records, secrets, databases, queues, object storage, or downstream dependencies. Those resources must be handled by the owning team before or alongside the repository cleanup.

## Pull Request Output

The generated pull request targets `main` on a branch named `decommission/helm-chart/<component-name>`. Its description records the Component name, removed chart path, removed values file, file count, requesting user, and the expected ArgoCD prune behavior.
