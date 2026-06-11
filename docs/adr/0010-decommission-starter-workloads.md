# ADR-0010: Decommission Starter Workloads

## Status

Accepted

Builds on ADR-0009 (Kubernetes Discovery by Template Ownership) without changing its discovery rule for controlled templates or third-party umbrella charts.

## Context

The repository previously shipped starter workload manifests and charts under `charts/workloads/podinfo`, `charts/workloads/hello-world`, and `deploy/dev/podinfo.yaml`. Those examples were useful while proving the platform path, but they become demo cruft for a fresh fork: Argo CD discovers them immediately, Backstage shows pre-installed sample components, and forkers must remove them before the repository represents their own platform.

The root-level `hello-world/` source directory has a different purpose. It is not a pre-installed workload. It is a small image source seed that forkers can edit, scaffold through the Backstage `application` template, and use to exercise the image-build CI path end-to-end.

ADR-0009 also records the separate third-party chart path for scaffolded application workloads. `podinfo` remains a useful example for that path because it is available as an OCI Helm chart and exercises the umbrella-chart discovery model without requiring this repository to ship a committed demo workload.

## Decision

Remove the committed starter workload charts and development manifest so a fresh fork has no pre-installed demo workloads.

Keep the root-level `hello-world/` source directory as the forker smoke-test seed for the image-source branch of the `application` Software Template. Forkers can edit that source, scaffold an Application that points at it, and let the generated caller workflow build and publish the image through the shared image-build workflow.

Reference `podinfo` only as a third-party-chart example in documentation. Forkers can scaffold an Application against `oci://ghcr.io/stefanprodan/charts/podinfo` when they want to test the chart-source branch and the ADR-0009 umbrella-chart discovery path.

## Consequences

Fresh forks start without sample workload noise. The first visible application workloads should be the ones a forker intentionally scaffolds.

The platform still keeps a lightweight image-build smoke-test path. The retained `hello-world/` source proves the Dockerfile-to-GHCR-to-Argo CD flow without requiring a committed workload chart.

The third-party Helm chart path remains documented and testable through scaffolding, while `podinfo` stops being part of the repository's installed default state.
