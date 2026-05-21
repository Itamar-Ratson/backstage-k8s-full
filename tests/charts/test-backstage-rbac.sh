#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=helpers.sh
source "$(dirname "$0")/helpers.sh"

echo "=== Backstage Kubernetes RBAC tests ==="

enabled_output=$(helm template backstage "$CHART_DIR" -f deploy/dev/backstage.yaml 2>&1)

assert_contains "RBAC ConfigMap is rendered" "$enabled_output" "name: backstage-rbac"
assert_contains "RBAC ConfigMap has policies key" "$enabled_output" "rbac-policies.csv: |"
assert_contains "RBAC ConfigMap includes configured policy content" "$enabled_output" "p, role:default/platform-admin, policy-entity, update, allow"
assert_contains "RBAC ConfigMap has users key" "$enabled_output" "users.yaml: |"
assert_contains "RBAC ConfigMap includes configured user content" "$enabled_output" "name: itamar-ratson"
assert_contains "Deployment mounts RBAC ConfigMap volume" "$enabled_output" "name: rbac-config"
assert_contains "Deployment mounts RBAC files at Backstage config path" "$enabled_output" "mountPath: /etc/backstage/rbac"
assert_contains "app-config references mounted RBAC policies path" "$enabled_output" "policies-csv-file: /etc/backstage/rbac/rbac-policies.csv"
assert_contains "app-config references mounted catalog users path" "$enabled_output" "target: /etc/backstage/rbac/users.yaml"

assert_contains "ClusterRole rendered by default" "$enabled_output" "kind: ClusterRole"
assert_contains "ClusterRoleBinding rendered by default" "$enabled_output" "kind: ClusterRoleBinding"
assert_contains "ClusterRoleBinding references ServiceAccount" "$enabled_output" "kind: ServiceAccount"

for resource in \
  "pods" \
  "services" \
  "configmaps" \
  "secrets" \
  "events" \
  "persistentvolumeclaims" \
  "pods/log" \
  "deployments" \
  "replicasets" \
  "statefulsets" \
  "daemonsets" \
  "jobs" \
  "cronjobs" \
  "horizontalpodautoscalers" \
  "ingresses" \
  "gateways" \
  "httproutes" \
  "gatewayclasses"; do
  assert_contains "ClusterRole includes $resource" "$enabled_output" "- $resource"
done

for verb in get list watch; do
  assert_contains "ClusterRole includes $verb verb" "$enabled_output" "- $verb"
done

assert_not_contains "ClusterRole does not use wildcard resources" "$enabled_output" "- '*'"
assert_not_contains "ClusterRole does not use unquoted wildcard resources" "$enabled_output" "- *"

disabled_output=$(helm template backstage "$CHART_DIR" -f deploy/dev/backstage.yaml --set kubernetes.rbac.enabled=false 2>&1)
assert_not_contains "ClusterRole omitted when RBAC disabled" "$disabled_output" "kind: ClusterRole"
assert_not_contains "ClusterRoleBinding omitted when RBAC disabled" "$disabled_output" "kind: ClusterRoleBinding"

report_results "Backstage Kubernetes RBAC"
