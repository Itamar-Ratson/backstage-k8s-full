# ADR-0003: Kubernetes Plugin Integration

## Status

Accepted

## Context

Backstage already had the Kubernetes backend plugin imported, but no cluster was configured, the frontend plugin was not explicitly registered, and the in-cluster ServiceAccount did not have the read permissions the plugin needs. Catalog entities also needed a stable way to match Backstage Components to Kubernetes resources.

Two modeling gaps blocked useful entity-level views. `edge-gateway` was cataloged as a Resource, but the new alpha frontend attaches Kubernetes content to Component pages by default. The `application` Software Template already emitted `backstage.io/kubernetes-id` on scaffolded Components, but its chart skeleton did not apply the matching label to rendered resources.

This ADR records the decisions that closed PRD #35 and documents the work intentionally left out of this slice.

## Decision

### edge-gateway is a Component

`edge-gateway` is modeled as `kind: Component` with `spec.type: gateway`.

Component is the correct kind for a workload the platform team operates. Resource remains a better fit for dependencies operated by another system or team, such as `backstage-postgres`.

This also matches the Kubernetes plugin frontend behavior in the new alpha app system: Kubernetes content is attached to Component pages. Rendering the same tab on Resource pages would require a separate `EntityContentBlueprint` registration, so Resource-page support is deferred.

The `backstage` Component's dependency now points to `component:edge-gateway`.

### Matching Uses backstage.io/kubernetes-id

Catalog Components use the `backstage.io/kubernetes-id` annotation, and chart-rendered Kubernetes resources use the matching `backstage.io/kubernetes-id` label.

The value derives from `.Chart.Name`. This keeps entity identity independent from the Helm release name.

Rejected alternative: `backstage.io/kubernetes-label-selector` targeting `app.kubernetes.io/instance`. That would couple the Backstage entity to the Helm release name, so a release rename would silently break the Kubernetes tab even though the workload identity had not changed.

### Labels Helper, Not Selector Labels

The Kubernetes ID label is emitted from each chart's broad `*.labels` helper, not from `*.selectorLabels`.

ADR-0002 restricts selector labels to stable identity fields because Deployment selectors are immutable after creation. Adding `backstage.io/kubernetes-id` to selector labels would change that selector and risk failed upgrades. Adding it to the broader labels helper propagates to templated resources without altering selectors.

### In-Cluster ServiceAccount Auth

Backstage authenticates to Kubernetes with `authProvider: serviceAccount`.

The pod uses its existing in-cluster ServiceAccount token mounted by Kubernetes at `/var/run/secrets/kubernetes.io/serviceaccount/token`, with the mounted cluster CA for TLS verification. The chart does not thread an explicit token through a Secret.

Rejected alternatives:
- **Explicit token via Secret** - redundant ceremony for the in-cluster case and another credential to provision and rotate.
- **Mounted kubeconfig** - useful for out-of-cluster clients, but not for a Backstage pod running inside the target cluster.

### Cluster Config Lives in Environment Values

Kubernetes plugin cluster config lives under `appConfig.kubernetes` in `deploy/<env>/backstage.yaml`; the base `backstage/app-config.yaml` keeps an empty `kubernetes:` block.

This keeps `yarn dev` silent because local development does not try to connect to `kubernetes.default.svc.cluster.local`. It also follows ADR-0002's principle that chart artifacts stay environment-neutral. A future multi-cluster setup can add entries to the same environment-specific cluster list.

The KinD environment config uses:
- `serviceLocatorMethod.type: multiTenant`
- one config-located cluster named `local`
- `url: https://kubernetes.default.svc.cluster.local`
- `authProvider: serviceAccount`
- `skipTLSVerify: false`

### RBAC is Cluster-Wide, Read-Only, and Enumerated

The `backstage` chart renders a single ClusterRole and ClusterRoleBinding for the Backstage ServiceAccount.

The scope is cluster-wide because scaffolded charts can deploy into arbitrary namespaces. Namespace-scoped Roles would require a new RoleBinding for each future workload namespace, adding operational friction without changing the plugin's need to discover workloads across namespaces.

The role is read-only. Verbs are limited to `get`, `list`, and `watch`, and resources are enumerated explicitly with no wildcards:
- core: `pods`, `services`, `configmaps`, `secrets`, `events`, `persistentvolumeclaims`, `pods/log`
- apps: `deployments`, `replicasets`, `statefulsets`, `daemonsets`
- batch: `jobs`, `cronjobs`
- autoscaling: `horizontalpodautoscalers`
- networking.k8s.io: `ingresses`
- gateway.networking.k8s.io: `gateways`, `httproutes`, `gatewayclasses`

`secrets` and `pods/log` are intentionally included. `pods/log` supports pod log viewing in the UI. `secrets` is a security trade-off accepted for this MVP because the role remains read-only and explicit.

### RBAC Can Be Disabled

`kubernetes.rbac.enabled` defaults to `true`.

Setting it to `false` skips both RBAC manifests. This lets environments where platform admins own cluster RBAC provision the binding externally while keeping the local KinD environment self-contained.

### Gateway API Resources Are Registered

The Kubernetes plugin custom resources list includes `gateways`, `httproutes`, and `gatewayclasses` from `gateway.networking.k8s.io/v1`.

Without `HTTPRoute`, chart-scaffolded Components would miss their routing manifest. Without `Gateway`, the `edge-gateway` Kubernetes tab would be empty because that chart renders a Gateway. `GatewayClass` is low-cost cluster-scoped metadata that helps explain which class backs the Gateway.

`EnvoyProxy` is deferred because there is no current use case for data-plane customization visibility.

### Frontend Registration is Explicit

The app imports `@backstage/plugin-kubernetes/alpha` and appends `kubernetesPlugin` to the `features` array in `App.tsx`, next to the existing explicit `catalogPlugin` registration.

Rejected alternative: relying on `app.packages: all` auto-discovery. Auto-discovery would work, but explicit registration keeps the plugin visible to grep and matches the current app pattern.

The standalone `/kubernetes` sidebar item is allowed by default. `Sidebar.tsx` renders unmapped navigation items via `nav.rest({ sortBy: 'title' })`, so no suppression config is added.

### Component View Scope

The `backstage` Component's Kubernetes tab includes the resources rendered by the `backstage` chart, including the bundled Postgres Deployment, Service, PVC, and Secret.

The `backstage-postgres` Resource remains in the catalog for dependency modeling, but it does not get its own Kubernetes tab in this slice.

The `edge-gateway` Component's Kubernetes tab includes chart-rendered resources such as the Gateway. Envoy proxy pods created by the Envoy Gateway controller are not shown because they carry controller-owned labels rather than this chart's `backstage.io/kubernetes-id` label.

## Consequences

- Operators can open Kubernetes views for the `backstage` and `edge-gateway` Components.
- Charts scaffolded from the `application` Software Template inherit the catalog annotation and rendered-resource label needed for a working Kubernetes tab.
- Local app development remains disconnected from the in-cluster Kubernetes API unless environment values are layered in.
- Chart-managed RBAC is self-contained for KinD and can be disabled for platform-admin-managed environments.
- The selector immutability rule from ADR-0002 remains intact because Kubernetes plugin labels are not selector labels.

Deferred follow-up work:
- Surface Envoy proxy pods on the `edge-gateway` Kubernetes tab.
- Attach Kubernetes content to Resource pages, such as `backstage-postgres`.
- Add multi-cluster configuration beyond the local KinD cluster.
- Add HTTPS/TLS termination at the Gateway.
- Register Argo CD `Application` custom resources in the Kubernetes tab.
- Register `EnvoyProxy` custom resources if data-plane customization becomes relevant.
- Integrate the Backstage permissions framework with the Kubernetes plugin.
- Add automated UI verification with Playwright or an API-level Kubernetes endpoint smoke test.
- Add NetworkPolicy controls restricting Backstage access to the kube-apiserver.
- Wire the new chart tests into CI.
- Revisit `readOnlyRootFilesystem: true` for the Backstage container as part of the ADR-0002 hardening backlog.
- Decide whether to hide the standalone `/kubernetes` sidebar item after more user feedback.
- Continue rejecting cluster-admin and wildcard RBAC unless a concrete future use case changes the security model.
