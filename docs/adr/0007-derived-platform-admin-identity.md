# ADR-0007: Derived Platform Admin Identity

## Status

Accepted

Supersedes ADR-0004's named maintainer admin identity. ADR-0004's RBAC plugin choice, CSV policy format, and `viewer` / `platform-admin` role design remain in force.

## Context

ADR-0004 used a single committed GitHub login as the platform admin because the original RBAC slice was a single-maintainer local demonstration. PRD #147 later made the repository fork-friendly for repository URLs and image paths, but the admin identity still required a forker to edit multiple committed RBAC files.

ADR-0005 also moved the supported OAuth admin demo to the KinD deployment path. That means the old root `users.yaml` local-dev artifact is no longer part of the supported runtime.

## Decision

The deployed platform admin identity derives from `lower(var.github_owner)`.

Terraform passes that value as `rbacAdminUser` through the root Argo CD Application into the `gitops/dev` chart. The workloads ApplicationSet forwards it to child workload Applications as `rbac.adminUser`.

The Backstage chart owns construction of the admin artifacts from that single value:

- a `User` entity in the RBAC ConfigMap's `users.yaml` key
- a `platform-admin` role binding appended to `rbac-policies.csv`
- a separate `app-config.admin.yaml` layer loaded as an additional Backstage `--config`

When `rbac.adminUser` is empty, the chart renders no derived admin identity so it remains usable outside this repo.

## Consequences

Forkers set `github_owner` and `github_repo` once in `terraform.tfvars`; the deployed Backstage identity and RBAC binding follow from that owner.

The committed local-dev admin artifacts are removed. Guest catalog browsing remains supported through the committed viewer role and guest binding. A maintainer who wants local OAuth admin behavior can configure a personal User entity through ignored local config.
