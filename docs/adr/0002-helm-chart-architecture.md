# ADR-0002: Helm Chart Architecture for Backstage + Edge-Gateway

## Status

Accepted

## Context

The repo originally deployed Backstage via flat manifests in a `kubernetes/` directory. This worked for a single KinD environment but embedded all environment-specific values (image references, hostnames, credentials, app-config) directly in committed YAML. Any change to environment-specific configuration required editing manifests and, for app-config, rebuilding the Docker image. There was no path to GitOps, no way to vary values per environment, and real secrets would have needed to be committed in the same shape.

The Gateway resource was hardcoded to Backstage-specific settings, making it impossible to share across multiple apps without duplicating and editing manifests.

## Decision

### Two Charts, Not One Umbrella

The system is packaged as two independent Helm charts: `backstage` (application workload) and `edge-gateway` (shared Gateway resource only).

Rejected alternatives:
- **Single umbrella chart with subcharts** — adds subchart-values-namespacing complexity without a use case; no plan to install postgres or gateway independently of backstage via the umbrella.
- **Separate postgres chart** — postgres in this chart is a dev convenience toggled off in production; pulling in bitnami/postgresql would import ~50 values keys for features the dev case does not consume.
- **BYO postgres only (no inline)** — removes the zero-config contributor experience; contributors would need to provision postgres externally before local smoke verification works.

### Edge-Gateway Reusability

The Gateway listener uses a wildcard hostname and admits HTTPRoutes via a label-selector on namespaces.

- The listener hostname is a values input, defaulting to a wildcard appropriate for the environment.
- The `allowedRoutes` field uses `from: Selector` with a configurable label key/value pair (default: `gateway-routes=enabled`).
- Apps opt in by labeling their own namespace with the agreed label.

Rejected alternatives:
- **Namespace-name selector** — ties the Gateway to a specific namespace name, preventing reuse.
- **`from: All`** — overly permissive; any namespace can inject routes without explicit opt-in.

### Hybrid Secrets

For each Secret (GitHub auth, postgres auth), values expose a `create` boolean, an `existingSecret` name, and the secret material fields.

- When `create=true`, the chart renders a Secret from values with Helm `required` guards that fail rendering if material is empty.
- When `create=false`, the chart references the named existing Secret without templating a Secret resource.

The chart is neutral on which external-secrets system (ESO, Sealed Secrets, SOPS, Vault) populates the pre-existing Secret in production.

Rejected alternatives:
- **Always render Secrets** — forces prod credentials through Helm value resolution and release storage.
- **Never render Secrets** — removes the zero-config local-dev path; contributors must manually create Secrets before local smoke verification works.
- **Commit to a specific external-secrets tooling** — premature; the choice depends on the production cluster's existing tooling.

### App-Config as a Mounted ConfigMap

The Docker image bakes only the base `app-config.yaml` defaults. The chart renders a ConfigMap from a `values.appConfig` block and mounts it into the pod at a stable runtime path. The container start command layers it via an additional `--config` argument.

`${VAR}` substitution syntax inside the appConfig block is preserved verbatim — Backstage resolves these at runtime against pod env vars sourced from Secrets.

Rejected alternatives:
- **Bake production config into image** — ties config changes to image rebuilds; change cycle is minutes instead of seconds.
- **Environment variables only** — Backstage's config schema is deeply nested; flattening to env vars loses structure and is error-prone.
- **External config file (git-sync sidecar)** — over-engineering for a chart that already has Helm-rendered values.

### External Namespaces

Neither chart templates a Namespace resource. Install uses `--create-namespace` (or Argo `CreateNamespace=true`). The `gateway-routes=enabled` label on the backstage namespace is an external precondition applied by the Makefile today and by a platform-namespaces Argo Application later.

Rejected alternatives:
- **Chart templates its own Namespace** — creates Argo tracking-annotation edge cases and ownership conflicts between charts.
- **Require manual namespace creation** — breaks the single-command local smoke experience.

### Image Fields with Chart.appVersion Fallback

Values expose `image.repository`, `image.tag`, `image.pullPolicy`, and `image.pullSecrets`. When `image.tag` is empty (the default), the Deployment renders the image reference using `Chart.AppVersion`. Bumping `appVersion` in `Chart.yaml` is the single edit that bumps the deployed image tag.

Rejected alternatives:
- **Hardcoded tag in values** — requires two edits (Chart.yaml appVersion + values tag) to bump a release.
- **Digest-only pinning** — not included initially; adding `image.digest` later is a non-breaking addition.

### Env Values Layout

Per-environment overrides live at `deploy/<env>/<chart>.yaml`, outside the chart artifact. Directories are grouped by environment, not by chart.

Rejected alternatives:
- **Per-chart directories** (`deploy/<chart>/<env>.yaml`) — `ls deploy/<env>/` should show everything that env overrides at a glance.
- **Values inside the chart** — chart artifacts should be environment-neutral; baking env overrides into the chart prevents clean OCI publishing later.

### Document-Only CRD Precondition

Gateway API v1 CRDs are cluster-shared infrastructure owned by Terraform. Charts assume they exist. No `crds/` bundling, no precheck hooks, no `lookup` guards.

Rejected alternatives:
- **Bundle CRDs in chart** — duplicates ownership of cluster-shared resources; multiple charts bundling the same CRDs conflict on install order.
- **`lookup` template guard** — fails silently at `helm template` time (lookup returns empty outside a cluster); adds complexity without improving the error path vs. the default "no matches for kind" Helm error.
- **Precheck hook Job** — adds a Job + RBAC + image dependency for a check that Helm already surfaces clearly.

### Publishing Deferred

Charts are consumed in-tree by path. Future GitOps consumption uses Argo CD pointing at this Git repo with `path: charts/<name>`. OCI publishing is deferred until multi-env rollouts demand versioned artifacts.

Rejected alternatives:
- **OCI publish from day one** — adds CI workflow, versioning ceremony, and registry infrastructure for a single-env repo with no consumer.
- **Chart Museum** — deprecated in favor of OCI; would be dead weight.

### Templating Conventions

- Standard `app.kubernetes.io/*` labels on every resource.
- `selectorLabels` restricted to `{name, instance}` only — these are immutable, so the Deployment selector stays stable across chart-version bumps.
- ServiceAccount per release with empty annotations for future identity wiring (IRSA / Workload Identity).
- Pod-level SecurityContext: `runAsNonRoot: true`, `seccompProfile.type: RuntimeDefault`.
- Container-level SecurityContext: `allowPrivilegeEscalation: false`, `capabilities.drop: [ALL]`, `readOnlyRootFilesystem: false` (Backstage writes temp files).
- Resource defaults set (Backstage: 200m/256Mi requests, 1000m/1Gi limits).
- Probes default to disabled until Backstage serves `/healthcheck`.

Rejected alternatives:
- **Include version in selectorLabels** — causes `field is immutable` errors on `helm upgrade` when chart version changes.
- **readOnlyRootFilesystem: true** — requires mapping every writable path Backstage plugins need; deferred as per-installation hardening.

## Consequences

- The chart structure is GitOps-ready: an Argo CD Application can point at `charts/<name>` with values files from `deploy/<env>/<chart>.yaml` and render the same way Helm renders today.
- The `edge-gateway` chart can be installed in clusters that host apps unrelated to Backstage by labeling those apps' namespaces with `gateway-routes=enabled`.
- Moving Backstage to a managed postgres (RDS / CloudSQL) is a values change: `postgres.enabled=false` and `postgres.auth.existingSecret` pointing at a Secret managed externally.
- Adding a per-environment `deploy/<env>/<chart>.yaml` extends the deployment footprint without touching the charts themselves.
- Future work: OCI publishing on demand; ESO / Sealed Secrets / SOPS integration on demand; NetworkPolicy, PodDisruptionBudget, HorizontalPodAutoscaler, and ServiceMonitor templates as separate hardening work.
