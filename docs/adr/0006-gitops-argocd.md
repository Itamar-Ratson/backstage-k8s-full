# ADR-0006: GitOps with ArgoCD

## Status

Accepted

Touches ADR-0002 (Helm Chart Architecture) without contradiction — the two-chart pattern extends to four charts (two local, two vendored wrappers) and retains the chart/values separation. ADR-0002's "Future GitOps consumption uses Argo CD pointing at this Git repo with `path: charts/<name>`" is the path this ADR commits to.

Touches ADR-0005 (Backstage RBAC on kind) without contradiction — Backstage authentication still flows through a Kubernetes Secret consumed via `existingSecret`, but the Secret name and shape change as part of replacing the PAT + OAuth App pair with a single GitHub App.

## Context

The local KinD environment previously bootstrapped through a smoke target, which chained `terraform apply`, two `helm upgrade --install` calls, manual namespace + label commands, two `kubectl get secret` preconditions, a `kubectl wait` on the Backstage Deployment, and a curl smoke check. The Makefile was the orchestrator, and CI invoked the same target bodies to lint and test charts.

This works for a single environment with one operator, but four gaps compound:

- The old chart-specific decommission scaffolder template opened a PR deleting `charts/<name>/`, but the running Helm release was not uninstalled. The template's PR description warned the operator to run `helm uninstall <name> -n <namespace>` manually. The README's Next Steps documented this as the "until ArgoCD lands" gap.
- The `helm-chart` scaffolder template produces charts in `charts/<name>/` that nothing deploys. Each scaffolded chart requires a follow-up manual `helm install`.
- Bootstrap is imperative and multi-step: two manual Secrets (`backstage-github-token`, `backstage-github-oauth`) via `kubectl create secret`, `terraform apply`, two `helm upgrade --install`s, namespace creation, namespace labeling, secret existence checks, then a Deployment wait.
- Drift between Git and the running cluster is invisible. A failed imperative smoke retry can leave half-deployed state. No dashboard, no audit trail, no self-healing.

The repo's `charts/` and `deploy/<env>/` layout was deliberately built (ADR-0002) so an in-cluster reconciliation controller could consume it without restructure. This ADR records the decisions that activate that path.

## Decision

### ArgoCD Over Flux

ArgoCD is the in-cluster GitOps controller. One ArgoCD instance per environment (per cluster), not hub-and-spoke.

The two decision factors:

- **Backstage IDP integration.** ArgoCD has a polished, well-maintained Backstage plugin (`@roadiehq/backstage-plugin-argo-cd`) that surfaces per-component sync status on Backstage component pages. This is structurally aligned with the project's IDP direction.
- **App-of-apps with `Application` and `ApplicationSet` CRs maps directly to the two-chart-now-four-chart layout.** Sync waves enforce the natural ordering (envoy-gateway → edge-gateway → workloads) that the old smoke command sequence previously enforced.

Rejected alternatives:

- **Flux.** Image automation built in (`ImageRepository` + `ImageUpdateAutomation`) is its strongest unique feature, but the existing `build-image.yaml` workflow already commits image tag bumps to `deploy/dev/backstage.yaml` and would be replaced for no net gain. The Flux Backstage plugin is thinner. CLI-only flow is fine but doesn't compete with ArgoCD's dashboard when a single operator is debugging at 11pm.
- **Hub-and-spoke ArgoCD.** One central ArgoCD registering remote clusters is appropriate at 5+ clusters with a dedicated platform team. Operational overhead at the one-dev-plus-future-prod scale is not justified.

### Thin Terraform: Cluster Only

Terraform's responsibility shrinks to: create the KinD cluster, materialize the `backstage` namespace, materialize a single bootstrap Secret (`backstage-github-app`) from `terraform.tfvars`, and install ArgoCD with an embedded root Application. Envoy Gateway, the `eg-nodeport` GatewayClass, and every Helm release move into the GitOps tree.

Rejected alternatives:

- **Fat Terraform managing Envoy Gateway + GatewayClass + GitOps controller, GitOps for application layer only.** Two control planes for the same cluster blurs ownership and complicates the decommission loop (if Envoy Gateway is in Terraform and Backstage charts are in ArgoCD, a future "remove this entire stack" workflow has two systems to drive).
- **Pure GitOps including infra via Crossplane/tf-controller.** Out of proportion for a project that has no multi-cloud play and no Terraform-via-Kubernetes operator already installed.

### Single Repo, Path-Scoped Sync

ArgoCD watches this repo. The controller is scoped to `charts/` and `deploy/` paths (and `gitops/` for its own config) so changes under `backstage/` source do not cause spurious reconciles.

Rejected alternatives:

- **Split config repo.** Standard at scale; adds coordination cost (two PRs per feature) without an org-boundary benefit at solo scale. The image-tag bump flow that already commits to `deploy/dev/backstage.yaml` would become a cross-repo PR, which is fiddly.
- **Same repo, no path scoping.** ArgoCD reconciles on every commit even when only Backstage source changes. Wastes reconciliation cycles and obscures the actual sources of truth for the cluster.

### Bootstrap via Terraform `helm_release` With Embedded Root Application

Terraform installs ArgoCD via `helm_release`. The seed root `Application` ships as a Kubernetes manifest inside the `helm_release` `extraObjects` value, loaded from an external file `terraform/bootstrap/root-app.yaml` via `yamldecode(file(...))`. The release carries `lifecycle { ignore_changes = [version, values] }` so ArgoCD self-manages after seed.

ArgoCD's child Application for `argo-cd` itself points at the vendored wrapper chart `charts/platform/argo-cd/`, which declares the same upstream chart at the same version. ArgoCD adopts the Terraform-installed release on first reconcile.

Rejected alternatives:

- **Separate bootstrap target after `terraform apply`.** Adds a second command between cluster creation and a working cluster; "did you remember to run it?" is a real footgun even with documentation.
- **`argocd-autopilot`.** Opinionated directory layout (Kustomize overlay-based `bootstrap/argo-cd/`, `projects/`, `apps/<app>/overlays/<cluster>/`) fights the existing Helm-based shape. Designed for greenfield platform-team setups.
- **`extraObjects` inline in the `.tf` file.** External file aligns with the repo's existing aesthetic (Helm values in `deploy/<env>/`, not embedded in Terraform), supports `kubectl apply -f` as a disaster-recovery escape hatch, and gets editor schema validation.
- **`argocd-apps` companion chart for the seed Application.** Two `helm_release` resources instead of one for a single Application is over-machined. argocd-apps is the right tool when used inside `gitops/` to declare a batch of children; not for the Terraform-side seed.

### Charts Categorized by Role: `charts/platform/` + `charts/workloads/`

The `charts/` tree splits into two role-based subdirectories:

- `charts/platform/` — infrastructure the cluster needs to host workloads. Few, hand-curated, sync-ordered. Today: `envoy-gateway` (vendored wrapper), `argo-cd` (vendored wrapper for self-management), `edge-gateway` (local).
- `charts/workloads/` — applications running on top of the platform. Many, convention-shaped, parallel-deployable. Today: `backstage`. Future: any chart produced by the `application` Backstage scaffolder template.

Rejected alternatives:

- **Top-level `platform/` + `charts/` as siblings.** Asymmetric (two root concepts instead of one), watches three paths instead of two, more rename churn in existing scripts.
- **Flat `charts/<name>/` with role expressed via annotations or files.** Convention by file content rather than directory placement obscures the platform-vs-workloads distinction from anyone browsing the tree.

### Wrapper Charts for Vendored Upstream Dependencies

Both `envoy-gateway` and `argo-cd` ship as wrapper charts inside `charts/platform/`. Each has a minimal `Chart.yaml` declaring the upstream chart as a `dependencies` entry, an optional `values.yaml` for chart-default overrides, and no templates. Per-env overrides live in `deploy/dev/envoy-gateway.yaml` and `deploy/dev/argo-cd.yaml`. ArgoCD runs `helm dependency build` at sync time; dependency `.tgz` files are gitignored.

The wrapper-chart pattern unifies the source type across all platform Applications: every Application has a local-path source pointing at `charts/platform/<name>/`, and the platform ApplicationSet template needs no Go-template conditional for remote-vs-local.

Rejected alternatives:

- **Remote chart references in the ApplicationSet template.** ApplicationSet supports `chart` + `repoURL` for remote Helm sources, but mixing local-path and remote sources in one ApplicationSet's template requires Go-template conditionals and a heterogeneous list-generator schema. Vendoring trades two thin `Chart.yaml` files for a homogeneous, simpler template.
- **Committing the dependency `.tgz` files in-tree (vendor everything literally).** Hermetic and offline-reproducible, but inflates the repo and produces noisy diffs on dependency bumps. Sync-time `helm dependency build` is the better trade-off for a project that does not optimize for offline operation.

### Two ApplicationSets: List Generator for Platform, Git Directory Generator for Workloads

`gitops/dev/platform-appset.yaml` uses a `list` generator with explicit elements for `argo-cd`, `envoy-gateway`, and `edge-gateway`, each with `name`, `namespace`, and `syncWave` (`-3`, `-2`, `-1` respectively). Its template materializes one `Application` per element with a local-path source pointing at `charts/platform/{{.name}}/` and values from `deploy/dev/{{.name}}.yaml`.

`gitops/dev/workloads-appset.yaml` uses a `git` directory generator scanning `charts/workloads/*`. Its template materializes one `Application` per directory: name = directory basename, source path = the directory, values file = `/deploy/dev/{{.path.basename}}.yaml`, destination namespace = directory basename, default sync-wave `"0"`. The template carries the finalizer `resources-finalizer.argocd.argoproj.io` so deleting the chart directory prunes the Application's owned resources.

Both ApplicationSets share sync options `CreateNamespace=true` and `ServerSideApply=true`, and `automated: { prune: true, selfHeal: true }`.

The workloads ApplicationSet enforces the convention: chart name = namespace = values-file basename. Scaffolded charts that follow this convention auto-deploy when their PR merges, without anyone touching `gitops/`.

Rejected alternatives:

- **One unified ApplicationSet with a Git files generator over `gitops/dev/apps/*.yaml`.** Workable, but the scaffolder template would have to produce both a chart directory and a spec file in `gitops/dev/apps/` — two artifacts per new chart instead of one. The IDP win is sharpest when scaffold → PR → deployed needs zero touches beyond `charts/workloads/`.
- **Matrix generator combining list and Git directory.** Powerful but the matrix semantics are hard to debug; failures in either dimension produce confusing error messages.
- **One ApplicationSet per Application.** Defeats the point of `ApplicationSet`; same complexity as plain `Application` CRs.

### Single GitHub App Replaces PAT + OAuth App

A single GitHub App per environment handles both Backstage's GitHub integration (catalog discovery, scaffolder actions, via auto-rotating installation tokens minted in-process from the App's private key) and user sign-in (via the App's `clientId` and `clientSecret`). The App is created in the GitHub UI per a README checklist; one credential surface replaces today's two.

The bootstrap Secret name is `backstage-github-app` with keys `APP_ID`, `CLIENT_ID`, `CLIENT_SECRET`, `PRIVATE_KEY`.

Rejected alternatives:

- **Keep PAT + OAuth App.** Two manual setup forms instead of one, two Secrets to manage, long-lived PAT in cluster Secret state, user-tied identity instead of bot identity.
- **GitHub App manifest flow automation.** The manifest-flow protocol is real but no widely-adopted maintained CLI exists. Probot's implementation is framework-internal; a custom 80-line script is the alternative. At one-environment-plus-future-prod scale, the labor saved by automation (a few minutes ever) does not justify a script to maintain. Documented UI form is the chosen path.

### Bootstrap Secret Terraform-Managed From `terraform.tfvars`

Terraform owns the `backstage-github-app` Secret via a `kubernetes_secret_v1` resource. The operator fills `terraform/terraform.tfvars` (gitignored) with the GitHub App credentials. `terraform apply` creates the cluster, namespace, Secret, and ArgoCD seed in one command.

`terraform.tfstate` contains the App's private key after this change and must be gitignored (already is) and treated as sensitive in any remote-state scenario.

Rotation is operator-initiated: edit tfvars, `terraform apply`, `kubectl rollout restart deployment/backstage -n backstage`.

Rejected alternatives:

- **Manual `kubectl create secret` after `terraform apply`.** Forces a second imperative step into the bootstrap. Fine today; eliminating it is the explicit goal of this work.
- **SOPS + age committing encrypted Secrets in Git.** A real and standard pattern for shared credentials, but the GitHub App's private key is per-environment-shared at most (today it is per-operator because each operator registers their own App for the dev environment). SOPS adds a `ConfigManagementPlugin` to ArgoCD plus age-key bootstrap, replacing one manual step (Secret) with a different manual step (age key). Justified when the count of shared dev secrets exceeds one.
- **External Secrets Operator with a cloud secret manager backend.** Right answer when production exists and has a real cloud secret store (AWS Secrets Manager, GCP Secret Manager, Vault). For local KinD without a backend, no value.
- **ESO with GitHub Actions secrets as the backend.** Not viable. GitHub's API does not expose Actions secret values; they can be written but not read. No ESO provider exists for this reason.

### Argo Behavior Conventions

The vendored `charts/platform/argo-cd/` values declare custom health checks for Gateway API resources via `argocd-cm` `resource.customizations.health.*`:

- `Gateway.networking.k8s.io` reports Healthy when `.status.conditions[?(@.type=="Programmed")].status == "True"`.
- `HTTPRoute.networking.k8s.io` reports Healthy when `.status.parents[].conditions[?(@.type=="Accepted")].status == "True"`.

Without these, ArgoCD treats Gateway/HTTPRoute as Healthy on creation, and sync-wave ordering breaks (the workloads HTTPRoute can sync before the Gateway is actually serving).

Sync options applied at the platform ApplicationSet level: `CreateNamespace=true`, `ServerSideApply=true` (Gateway API resources have multiple controllers writing status; server-side apply avoids spurious diffs).

The Backstage chart's Postgres `PersistentVolumeClaim` template carries `argocd.argoproj.io/sync-options: Prune=false` so an accidental decommission cannot wipe the dev database. The `application` scaffolder template encodes the same convention for PVCs in scaffolded stateful workloads.

Rejected alternatives:

- **Cluster-wide "never prune PVCs" via `ResourceCustomization`.** No such global toggle exists in ArgoCD; `Prune=false` is per-resource. Per-resource annotation is correct.
- **Skip custom health checks; rely on default "Healthy on creation."** Sync waves stop being meaningful; the platform → workloads ordering degrades to a race.

### Makefile Deleted; CI Pre-Flights Inline

The Makefile's responsibilities split cleanly under GitOps:

- Imperative deploy (Helm installs, namespace creation, secret-existence kubectl checks, Deployment waits) — owned by ArgoCD.
- Pre-flight validation (`terraform fmt -check`, `terraform validate`, `helm lint`, `actionlint`, chart-test bash scripts in `tests/charts/`, RBAC test scripts in `tests/rbac/`) — inlined into `.github/workflows/test.yaml`.

The Makefile is deleted. The chart-test and rbac-test bash scripts remain on disk and are invoked directly from the workflow. `helm lint` covers all four charts (`charts/platform/{argo-cd,envoy-gateway,edge-gateway}`, `charts/workloads/backstage`).

Rejected alternatives:

- **Slim the Makefile to a single verify target.** Acceptable but the explicit goal is "no Makefile." If the convenience signal is missed later, a 3-line `scripts/verify.sh` is the recovery — still no Makefile.
- **Keep a thin smoke wrapper.** "One command says I'm done" has value, but `kubectl get applications -n argocd` and a browser visit provide the same signal with no orchestrator.

### Prod Deferred; Env-Scoped Layout Future-Proofs

This ADR is dev-only. Production gets its own cluster (per-cluster ArgoCD, not hub-and-spoke), its own `gitops/prod/`, its own `deploy/prod/` (full-copy values, not base+overlay), and its own Terraform stack. Promotion is sequential PRs on a single `main` branch.

The current dev-scoped layout — `gitops/dev/`, `deploy/dev/`, ApplicationSet names `platform-dev` and `workloads-dev` — leaves the prod slot empty and ready to fill without restructure.

Rejected alternatives:

- **Base values + per-env overlay today.** Premature DRY. Today there is one env; the second env will reveal what is truly shared vs what is dev-specific. The current `deploy/dev/backstage.yaml` content (KinD-specific gateway class, `localtest.me` hostname, guest auth, in-cluster Postgres) is largely dev-only; "80% shared with prod" is more likely 30%.
- **Branch-per-env promotion.** Linear history under a single `main` is simpler at this scale. Branch-per-env is appropriate when a regulated promotion process needs to gate prod merges separately.

## Consequences

- Fresh-clone bootstrap collapses to: install tools; create a GitHub App in the UI; fill `terraform/terraform.tfvars`; `cd terraform && terraform apply`; visit `http://backstage.localtest.me` when the workloads `backstage` Application reports Healthy in `kubectl get applications -n argocd`. The README's prior eight numbered steps shrink to five.
- The `decommission-component` scaffolder template's loop fully closes. Merging a decommission PR removes the annotated source paths such as `charts/workloads/<name>/`; the Git directory generator stops producing the Application; the finalizer prunes its resources; the running Helm release is gone. The README's "until ArgoCD lands" caveat is removed.
- The `application` scaffolder template's output deploys without intervention: any chart it produces under `charts/workloads/<name>/` with a sibling `deploy/dev/<name>.yaml` is auto-discovered by the workloads ApplicationSet on the next reconcile.
- The two-chart pattern from ADR-0002 extends to four charts. The `existingSecret`-based Hybrid Secrets pattern from ADR-0002 carries through; only the Secret name and shape change, and only the `existingSecret: false` rendering path is exercised under GitOps.
- The Backstage RBAC Secret pattern from ADR-0005 is preserved in shape (Backstage reads credentials from a Kubernetes Secret via `existingSecret`). The Secret's identity changes from a pair (`backstage-github-token`, `backstage-github-oauth`) to a single `backstage-github-app`, and its content changes from PAT + OAuth credentials to GitHub App App ID + private key + client ID + client secret.
- The Backstage chart's `--set-file rbac.policies=...` and `--set-file rbac.users=...` invocations are eliminated. The chart consumes RBAC content from a sibling ConfigMap (rendered from values in `deploy/dev/backstage.yaml` or from a separate manifest in `gitops/dev/`), because ArgoCD's Helm source has no `--set-file` equivalent.
- The existing `build-image.yaml` workflow that commits image tag bumps to `deploy/dev/backstage.yaml` is unchanged. ArgoCD's polling interval (default 3 minutes) determines when bumps reach the cluster. Faster sync via GitHub webhook is not configured because local KinD cannot receive webhooks from github.com.
- `terraform.tfstate` becomes sensitive — it contains the GitHub App private key after this change. Already gitignored locally. Any future remote-state backend must use encryption.
- Disaster recovery on the dev cluster is one command: `terraform destroy && terraform apply`. ArgoCD reconciles everything from Git on the new cluster.
- ArgoCD self-manages from minute two. Bumping ArgoCD's version is a PR to `charts/platform/argo-cd/Chart.yaml`; Terraform's `helm_release` is dead-code state thanks to `ignore_changes = [version, values]`.
- Future work that this ADR explicitly leaves open: ExternalSecrets Operator + cloud secret manager when production with a real secret store exists; SOPS+age when shared dev secrets exceed one; ArgoCD Image Updater if the existing CI image-bump workflow is ever retired; an ApplicationSet matrix or SCM-provider generator if many environments emerge; HTTPS termination via cert-manager (already on the README's Next Steps); a `gitops/prod/` sibling when a production cluster is provisioned.
