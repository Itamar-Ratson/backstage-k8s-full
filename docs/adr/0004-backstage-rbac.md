# ADR-0004: Backstage RBAC

## Status

Accepted

Superseded in part by [ADR-0005](0005-backstage-rbac-on-kind.md): OAuth credentials no longer stay in `backstage/app-config.local.yaml`, and the deferred KinD / Helm-chart deployment item is closed. The RBAC plugin choice, CSV-as-source-of-truth decision, and `viewer` / `platform-admin` role design remain in force.

## Context

Backstage had `permission.enabled: true`, but the backend loaded the allow-all permission policy. That meant the permission framework was present without enforcing meaningful authorization. The project also only had guest sign-in, so there was no stable named identity to receive administrative access.

PRD #40 replaced the allow-all policy with a local `yarn dev` RBAC demonstration: guests can browse a view-only portal, and the maintainer can sign in through GitHub OAuth as a platform admin. This ADR records the decisions that made that slice reproducible and reviewable.

## Decision

### RBAC Community Plugin Over Hand-Written PermissionPolicy

Context: Backstage supports custom `PermissionPolicy` implementations, but PRD #40 needed a product-shaped RBAC layer with roles, assignments, an admin UI, and a path to future conditional rules.

Decision: Use `@backstage-community/plugin-rbac` and `@backstage-community/plugin-rbac-backend` as the active permission layer, replacing `@backstage/plugin-permission-backend-module-allow-all-policy`.

Consequences: The project now demonstrates real default-deny authorization instead of a TypeScript allow-list hidden in backend code. The `/rbac` UI can show and manage roles for local exploration. The accepted trade-off is adopting community-plugin behavior and configuration conventions instead of owning a smaller hand-written policy module.

### GitHub OAuth and users.yaml Over GitHub Org Ingestion

Context: The demo needed one named admin identity. GitHub organization-and-team ingestion would normally provide catalog `User` and `Group` entities, but the repo owner `Itamar-Ratson` is a GitHub User account, not an organization. `GET /orgs/Itamar-Ratson` returns 404, so org ingestion has nothing to sync for this repository owner.

Decision: Keep guest auth enabled and add GitHub OAuth as a second provider. Map the GitHub login to `user:default/itamar-ratson` with `usernameMatchingUserEntityName`, and commit a hand-written root `users.yaml` containing that user entity.

Consequences: The admin identity is deterministic, reviewable, and does not require a GitHub organization. The committed user entity is non-sensitive metadata, while OAuth credentials stay in `backstage/app-config.local.yaml`. A future move to GitHub org ingestion can produce the same user ref without changing RBAC policy lines.

### Committed CSV as Policy Source of Truth

Context: The RBAC plugin can manage policy through the `/rbac` UI, but `yarn dev` uses in-memory SQLite. UI-only policy changes would disappear on backend restart. A file-backed SQLite database would preserve local state, but it would be machine-local and unreviewable in pull requests.

Decision: Store starter roles and assignments in committed `backstage/rbac-policies.csv`, loaded through `permission.rbac.policies-csv-file`.

Consequences: Policy changes are visible in code review and re-seeded on backend startup. The `/rbac` UI remains useful for inspection and experimentation, but persistent policy intent lives in git. The trade-off is that durable changes require editing the CSV rather than relying on click-ops.

### View-Only Guest as the Denied Principal

Context: Removing guest auth would eliminate the easiest way to demonstrate a denied principal. Keeping only a single admin role would also fail under default-deny behavior because anonymous users would not receive the read permissions needed to browse the portal.

Decision: Keep guest enabled and seed two roles: `viewer` for `user:default/guest`, and `platform-admin` for `user:default/itamar-ratson`.

Consequences: The demo can show both sides of the gate: guest can browse catalog, templates, TechDocs, search, and Kubernetes entity views, but cannot execute scaffolder actions; the GitHub-authenticated admin keeps full access and can open `/rbac`. Two roles are required because there is no implicit global read baseline after allow-all is removed.

## Consequences

- The Backstage permission framework now has an active RBAC implementation instead of allow-all behavior.
- Dev-mode auth has both guest and GitHub sign-in, with secrets kept out of committed config.
- RBAC policy is reproducible across `yarn dev` restarts because the committed CSV is loaded on startup.
- The admin must be configured in both places: `permission.rbac.admin.users` for `/rbac` administration, and `backstage/rbac-policies.csv` for broad plugin permissions.
- The follow-up KinD/Helm-chart PRD will need to revisit `charts/workloads/backstage/templates/configmap.yaml`, `deploy/dev/backstage.yaml`, and the Helm `values.appConfig` schema to port the local-only settings into chart-managed runtime config.

## Deferred

- KinD / Helm-chart deployment of this RBAC configuration, including chart-mounted OAuth secrets and an RBAC CSV ConfigMap mount.
- GitHub organization-and-team ingestion.
- Demo user personas and persona switching.
- Conditional rules.
- Kubernetes-plugin fine-grained gating beyond the coarse Kubernetes proxy/read permissions.
- Service-to-service authorization.
- User-identity-based Kubernetes API access.
- Removing the guest auth provider entirely in production.
- Custom roles beyond `viewer` and `platform-admin`.
- Backups, export/import, and policy migration tooling.
- CI integration of the RBAC CSV test.
