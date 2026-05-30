# ADR-0009: Kubernetes Discovery by Template Ownership

## Status

Accepted

Touches ADR-0003 (Kubernetes Plugin Integration) without contradiction - ADR-0003 remains the controlled-template branch of the broader rule: use the strongest Kubernetes discovery signal the platform controls for each workload source type.

## Context

ADR-0003 chose `backstage.io/kubernetes-id` annotations on Backstage Components matched to `backstage.io/kubernetes-id` labels on chart-rendered resources. That choice deliberately rejected `backstage.io/kubernetes-label-selector` over `app.kubernetes.io/instance` for charts the platform team owns, because tying catalog identity to the Helm release name creates a rename risk: changing the release name can silently break the Kubernetes tab even when the Backstage-domain workload identity has not changed.

The same decision also decouples Backstage component identity from Helm deployment plumbing. A controlled workload chart can derive its Kubernetes plugin identity from `.Chart.Name` and emit that identity through its shared labels helper, while keeping Helm release naming as an installation detail.

Third-party umbrella charts have a different constraint. The platform owns the wrapper chart under `charts/workloads/`, but it does not own the upstream chart templates that render the Deployment, Service, Job, or other Kubernetes resources. The platform cannot rely on those templates to emit `backstage.io/kubernetes-id`, and it cannot rely on every upstream chart to expose a `commonLabels`, `extraLabels`, or equivalent values hook that is present, correctly wired across all resources, and stable across chart versions.

PRD #177 adds a chart-based branch to the `application` Software Template for third-party OCI Helm charts. That branch needs Kubernetes plugin discovery to work for the resources the upstream chart creates, without requiring the platform to patch or fork each upstream template.

## Decision

Use the strongest Kubernetes discovery signal the platform controls.

For controlled templates, including first-party charts under `charts/workloads/` and `charts/platform/`, Backstage Components use the `backstage.io/kubernetes-id` annotation and chart-rendered Kubernetes resources use the matching `backstage.io/kubernetes-id` label. ADR-0003 remains in force for these charts.

For third-party umbrella charts whose upstream templates the platform does not own, Backstage Components use `backstage.io/kubernetes-label-selector` targeting Helm's conventional `app.kubernetes.io/instance` label. The chart-case `application` template sets the selector to `app.kubernetes.io/instance=<component-name>`, matching the Argo CD release name produced by the workloads ApplicationSet.

The release-rename failure mode ADR-0003 identified is further mitigated in this repository. `gitops/dev/templates/workloads-appset.yaml` names each Argo CD Application from `{{.path.basename}}`; that value is also the chart directory name under `charts/workloads/` and the catalog entity name emitted by the scaffolder. For scaffolded workloads, release name, chart directory, and Backstage component name move together by construction.

This ADR does not migrate any existing first-party chart. It does not change the `backstage`, `edge-gateway`, `hello-world`, or controlled `application` image-case discovery model. It only records the ownership-based rule that chooses between custom `kubernetes-id` matching for controlled templates and Helm-conventional instance-label matching for third-party umbrella charts.

## Consequences

Third-party chart workloads can populate the Backstage Kubernetes tab without platform-owned Kubernetes templates and without requiring upstream charts to support a custom labels values hook.

The repository now has an explicit rule for future workload source types: prefer the platform-owned identity signal when the platform controls the rendered templates, and fall back to the strongest conventional signal when the platform only owns an umbrella wrapper.

ADR-0003 remains the rule for first-party charts because those charts can continue to emit the custom Kubernetes plugin label directly from their helpers.
