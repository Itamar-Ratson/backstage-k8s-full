# ADR-0007: LoadBalancer via cloud-provider-kind

## Status

Accepted

## Context

The original KinD exposure path used `Service.type=NodePort` plus KinD `extraPortMappings` from host port 8080 to node port 30080. That worked, but it made the local Envoy data plane Service dev-only, leaked `:8080` into every URL, and made future exposed services depend on Terraform/KinD port mapping changes.

The current local development goal is a Service shape that looks like a production cluster: `Service.type=LoadBalancer`, one stable external IP, and normal HTTP URLs such as `http://backstage.localtest.me`.

## Decision

Use `cloud-provider-kind` in Linux native mode to reconcile the Envoy data plane Service as `type: LoadBalancer`. Terraform manages the daemon as a docker container using `kreuzwerker/docker`, pinned to `registry.k8s.io/cloud-provider-kind/cloud-controller-manager:v0.10.0`, with host networking and `/var/run/docker.sock` mounted.

The `--enable-lb-port-mapping` flag is deliberately not used. The upstream cloud-provider-kind README documents that flag under "Enabling Load Balancer Port Mapping" and discusses it again under "Mac, Windows and WSL2 support"; it is a fallback for environments where the Docker bridge is not directly reachable from the host and uses Docker port mapping rather than a stable host URL strategy. This repo's local stack is Linux-only for this path.

The Envoy data plane Service pins `spec.loadBalancerIP` to `172.18.0.250` by default, with `ipFamilies: [IPv4]`. Terraform exposes the same value as `var.envoy_lb_ip` so a developer can override it in `terraform.tfvars` when that address collides with another Docker bridge network.

Because `*.localtest.me` resolves to loopback rather than the KinD bridge address, Terraform also manages a second docker container running `nginx:1.27-alpine`. The nginx container uses host networking, listens on both IPv4 and IPv6 (`listen 80; listen [::]:80;`), preserves the `Host` header, and forwards all HTTP traffic to the pinned LoadBalancer IP on port 80. nginx is only the explicit cloud-LB-to-host-port bridge; Envoy Gateway remains the in-cluster routing layer.

## Consequences

Terraform now has a fifth provider, `kreuzwerker/docker`, responsible for two local containers: `cloud-provider-kind` and the nginx forwarder. `terraform apply` starts the local LoadBalancer machinery with the cluster, and `terraform destroy` removes it with the rest of the stack.

The docker socket mount is a deliberate dev-only concession. A process with access to `/var/run/docker.sock` can control the host Docker daemon, so this is not a production trust boundary.

The local platform no longer uses KinD `extraPortMappings` or a hardcoded Envoy NodePort. URLs drop the `:8080` suffix: `http://backstage.localtest.me` and `http://argocd.localtest.me`.

Mac, Windows, and WSL2 are explicitly not supported by this exposure scheme. Those platforms need a different bridge because the KinD Docker bridge is not directly routable from the host in the same way.

## References

- [cloud-provider-kind README](https://github.com/kubernetes-sigs/cloud-provider-kind), especially the "Enabling Load Balancer Port Mapping" and "Mac, Windows and WSL2 support" sections.
- [KinD LoadBalancer guide](https://kind.sigs.k8s.io/docs/user/loadbalancer/).
