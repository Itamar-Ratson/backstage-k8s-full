#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../charts/helpers.sh
source "$(dirname "$0")/../charts/helpers.sh"

echo "=== Platform ApplicationSet tests ==="

appset_path="gitops/dev/platform-appset.yaml"
argocd_values_path="deploy/dev/argo-cd.yaml"
envoy_values_path="deploy/dev/envoy-gateway.yaml"

assert_file_exists "platform ApplicationSet exists" "$appset_path"
assert_file_exists "Argo CD dev values exist" "$argocd_values_path"
assert_file_exists "Envoy Gateway dev values exist" "$envoy_values_path"

appset=$(sed -n '1,$p' "$appset_path" 2>/dev/null || true)

assert_contains "ApplicationSet apiVersion" "$appset" "apiVersion: argoproj.io/v1alpha1"
assert_contains "ApplicationSet kind" "$appset" "kind: ApplicationSet"
assert_contains "ApplicationSet name" "$appset" "name: platform-dev"
assert_contains "ApplicationSet uses Go templates" "$appset" "goTemplate: true"
assert_contains "argo-cd list element exists" "$appset" "name: argo-cd"
assert_contains "argo-cd namespace is argocd" "$appset" "namespace: argocd"
assert_contains "argo-cd sync wave is -3" "$appset" 'syncWave: "-3"'
assert_contains "envoy-gateway list element exists" "$appset" "name: envoy-gateway"
assert_contains "envoy-gateway namespace is envoy-gateway-system" "$appset" "namespace: envoy-gateway-system"
assert_contains "envoy-gateway sync wave is -2" "$appset" 'syncWave: "-2"'
assert_contains "edge-gateway list element exists" "$appset" "name: edge-gateway"
assert_contains "edge-gateway namespace is gateway" "$appset" "namespace: gateway"
assert_contains "edge-gateway sync wave is -1" "$appset" 'syncWave: "-1"'
assert_contains "source uses platform chart path" "$appset" "charts/platform/{{.name}}"
assert_contains "source uses dev values file" "$appset" "/deploy/dev/{{.name}}.yaml"
assert_contains "destination namespace is templated" "$appset" "namespace: '{{.namespace}}'"
assert_contains "sync-wave annotation is templated" "$appset" "argocd.argoproj.io/sync-wave: '{{.syncWave}}'"
assert_contains "CreateNamespace sync option is enabled" "$appset" "CreateNamespace=true"
assert_contains "ServerSideApply sync option is enabled" "$appset" "ServerSideApply=true"
assert_contains "automated prune is enabled" "$appset" "prune: true"
assert_contains "automated self-heal is enabled" "$appset" "selfHeal: true"

argocd_values=$(sed -n '1,$p' "$argocd_values_path" 2>/dev/null || true)

assert_contains "Gateway health customization exists" "$argocd_values" "resource.customizations.health.networking.k8s.io_Gateway"
assert_contains "Gateway health waits for Programmed=True" "$argocd_values" 'condition.type == "Programmed" and condition.status == "True"'
assert_contains "HTTPRoute health customization exists" "$argocd_values" "resource.customizations.health.networking.k8s.io_HTTPRoute"
assert_contains "HTTPRoute health waits for Accepted=True" "$argocd_values" 'condition.type == "Accepted" and condition.status == "True"'

envoy_values=$(sed -n '1,$p' "$envoy_values_path" 2>/dev/null || true)

assert_contains "Envoy Gateway CRD values are configured" "$envoy_values" "crds:"
assert_contains "eg-nodeport GatewayClass is configured" "$envoy_values" "name: eg-nodeport"
assert_contains "GatewayClass controller is configured" "$envoy_values" "controllerName: gateway.envoyproxy.io/gatewayclass-controller"
assert_contains "GatewayClass references custom EnvoyProxy" "$envoy_values" "name: custom-proxy-config"
assert_contains "NodePort 30080 is configured" "$envoy_values" "nodePort: 30080"

report_results "Platform ApplicationSet"
