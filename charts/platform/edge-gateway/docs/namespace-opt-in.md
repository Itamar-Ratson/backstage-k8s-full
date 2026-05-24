# Namespace Opt-In

The Gateway uses a namespace label selector to control which workloads may attach routes. This keeps the shared edge from accepting `HTTPRoute` resources from every namespace in the cluster.

## Required Label

By default, a namespace must carry this label:

```bash
kubectl label namespace <namespace> gateway-routes=enabled --overwrite --context kind-backstage
```

The corresponding Gateway listener policy is rendered from `charts/platform/edge-gateway/values.yaml`:

```yaml
allowedRoutes:
  label:
    key: gateway-routes
    value: enabled
```

The template turns that into an `allowedRoutes.namespaces.from: Selector` rule. Envoy Gateway will only admit routes from namespaces matching the configured key/value pair.

## What Happens Without It

An application can still install its Deployment, Service, and `HTTPRoute` without the label, but the route will not be admitted by the Gateway. The result is a workload that exists inside the cluster but is not reachable through the shared edge hostname.

Use this as the first check when a service is healthy but the browser cannot reach `http://<name>.localtest.me`:

```bash
kubectl get namespace <namespace> --show-labels --context kind-backstage
kubectl describe httproute <route-name> -n <namespace> --context kind-backstage
```

The route status should show whether it has been accepted by the parent Gateway.

## Current Automation

The local deployment flow labels the `backstage` namespace before installing the Backstage chart:

```bash
kubectl label namespace backstage gateway-routes=enabled --overwrite --context kind-backstage
```

New workload namespaces need the same opt-in step before their `HTTPRoute` resources can attach to the shared Gateway. The Helm chart does not template Namespace resources, so namespace creation and labeling remain outside the chart boundary.
