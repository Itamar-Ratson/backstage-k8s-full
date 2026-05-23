# Runtime Configuration

## Auth

The default app config enables the Backstage guest auth provider:

```yaml
auth:
  providers:
    guest: {}
```

The backend imports `@backstage/plugin-auth-backend` and the guest provider module, so a local KinD user can enter the portal without configuring an external identity provider. This is suitable for the repo's current single-developer local environment. A production identity provider would need a separate auth provider module, provider-specific secrets, and a matching sign-in resolver policy.

GitHub access and user sign-in share one GitHub App. The GitHub integration reads `APP_ID`, `CLIENT_ID`, `CLIENT_SECRET`, and `PRIVATE_KEY` from the runtime environment, and the Helm deployment sources those values from the `backstage-github-app` Kubernetes Secret. Backstage mints short-lived installation tokens from the private key for catalog discovery and scaffolder publishing actions.

## Catalog Discovery

The base catalog rules allow the entity kinds used by this repo:

```yaml
catalog:
  rules:
    - allow:
        [
          Component,
          System,
          API,
          Resource,
          Location,
          Domain,
          User,
          Group,
          Template,
        ]
```

The KinD values file adds a runtime catalog location that scans the GitHub repository for every `catalog-info.yaml` file:

```yaml
catalog:
  locations:
    - type: url
      target: https://github.com/Itamar-Ratson/backstage-k8s-full/blob/main/**/*catalog-info.yaml
```

That discovery model makes co-located entity ownership important. Root platform entities live in the repo-level `catalog-info.yaml`, the Backstage Component/API/Resource entities live in `backstage/catalog-info.yaml`, and scaffolded charts are expected to carry their own `catalog-info.yaml` under `charts/<name>/`.

## Enabled Plugins

The frontend uses the new frontend system through `createApp`, with the catalog plugin and a custom navigation module registered in `packages/app/src/App.tsx`. The custom sidebar keeps search as a modal entry, includes catalog and scaffolder navigation, and leaves other registered pages sorted below the main menu.

The backend imports the core platform plugins in `packages/backend/src/index.ts`:

- app backend and proxy backend
- scaffolder backend with GitHub and notification modules
- custom scaffolder utility actions
- TechDocs backend
- auth backend with guest auth
- catalog backend with GitHub discovery, scaffolder entity model, and logs modules
- permission backend with the allow-all policy
- search backend with PostgreSQL search engine, catalog collator, and TechDocs collator
- Kubernetes, notifications, signals, and MCP actions backends

This means catalog records, generated templates, docs pages, and search results are all served by the same Backstage backend process in the KinD deployment.

## AppConfig ConfigMap Mount

The Helm chart renders `.Values.appConfig` into a ConfigMap named `<release>-app-config`:

```yaml
data:
  app-config.runtime.yaml: |
    <values.appConfig>
```

The Deployment mounts that ConfigMap at `/etc/backstage` and starts the backend with two config files:

```bash
node packages/backend --config app-config.yaml --config /etc/backstage/app-config.runtime.yaml
```

The second config file overrides the repo defaults at runtime. In the KinD values file it is responsible for the GitHub catalog location and for making TechDocs run without Docker-in-Docker:

```yaml
techdocs:
  builder: local
  generator:
    runIn: local
  publisher:
    type: local
```

Those TechDocs settings are required in the Kubernetes pod. The image contains `mkdocs`, the generator runs in-process, and rendered docs are published to local pod storage. A pod restart clears that cache, so the first request for a docs site after restart rebuilds the site.
