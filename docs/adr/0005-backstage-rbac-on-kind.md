# ADR-0005: Backstage RBAC on kind

## Status

Accepted

Supersedes ADR-0004's decision that GitHub OAuth credentials stay in `backstage/app-config.local.yaml`.

Closes ADR-0004's deferred KinD / Helm-chart deployment item for the RBAC configuration.

## Context

ADR-0004 recorded the first RBAC slice as a local `yarn dev` demonstration. That slice established the RBAC plugin choice, committed CSV policy, the `viewer` and `platform-admin` roles, and a GitHub admin identity. It also kept OAuth credentials in `backstage/app-config.local.yaml` and deferred chart deployment.

The supported runtime for the demo is now the kind cluster. Maintaining GitHub OAuth sign-in for both `yarn start` and kind would require separate callback URLs and separate secret delivery paths for no current workflow benefit.

## Decision

### GitHub App Credentials Use a Kubernetes Secret

GitHub App credentials are delivered to the pod through a Kubernetes Secret named `backstage-github-app` by default. The chart exposes:

```yaml
oauth:
  github:
    create: false
    existingSecret: backstage-github-app
    clientId: ""
    clientSecret: ""
```

The Deployment references the configured existing Secret. The chart does not render GitHub credential Secrets.

This keeps GitHub App credentials out of committed config while allowing the same App to back catalog/scaffolder access and user sign-in.

### RBAC Files Are Delivered by ConfigMap

The chart's runtime ConfigMap delivers `app-config.runtime.yaml`, `rbac-policies.csv`, and `users.yaml` to `/etc/backstage`.

The canonical files remain at their repo-root locations and are passed during install with:

```bash
helm upgrade --install backstage charts/workloads/backstage \
  --set-file rbac.policies=backstage/rbac-policies.csv \
  --set-file rbac.users=users.yaml
```

The Deployment's `checksum/config` annotation covers the full rendered ConfigMap, so edits to runtime config, policies, or users roll the pod on the next Helm upgrade.

### Kind Is the Supported GitHub OAuth Runtime

GitHub OAuth sign-in is supported on the kind deployment at `http://backstage.localtest.me:8080`.

`yarn start` remains useful for typecheck, tests, and guest UI iteration, but GitHub sign-in through `yarn start` is no longer part of the supported surface.

### Delete the Local Example

`backstage/app-config.local.example.yaml` is deleted because it documented the unsupported `yarn start` GitHub sign-in path. Git history preserves the old content if that path is intentionally revived later.

The existing `.gitignore` entry for `backstage/app-config.local.yaml` remains in force. A maintainer's existing local file may remain on disk, but it is inert for the kind deployment path.

## Consequences

- ADR-0004's RBAC plugin choice remains in force.
- ADR-0004's committed CSV-as-source-of-truth decision remains in force.
- ADR-0004's `viewer` and `platform-admin` role design remains in force.
- ADR-0004's OAuth-credentials-in-`backstage/app-config.local.yaml` decision is superseded.
- The deferred kind / Helm-chart deployment item from ADR-0004 is closed.
- Secret bootstrap is a one-time cluster setup step, not a file committed to git.
- RBAC policy and catalog identity edits no longer require rebuilding the Backstage image.

## Out of Scope

- Production deployment beyond kind.
- HTTPS OAuth callbacks.
- Multi-environment OAuth App management.
- External secret managers.
- GitHub organization-and-team ingestion.
- Custom roles beyond `viewer` and `platform-admin`.
- Conditional rules and finer-grained plugin permissions.
- Automated OAuth App provisioning.
