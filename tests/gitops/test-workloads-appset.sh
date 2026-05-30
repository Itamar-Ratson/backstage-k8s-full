#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../charts/helpers.sh
source "$(dirname "$0")/../charts/helpers.sh"
# shellcheck source=../lib/platform-identity.sh
source "$(dirname "$0")/../lib/platform-identity.sh"

echo "=== Workloads ApplicationSet tests ==="

appset_path="gitops/dev/templates/workloads-appset.yaml"
gitops_chart_path="gitops/dev"
backstage_chart_path="charts/workloads/backstage"
backstage_values_path="deploy/dev/backstage.yaml"

assert_file_exists "workloads ApplicationSet exists" "$appset_path"
assert_file_exists "gitops dev chart exists" "$gitops_chart_path/Chart.yaml"
assert_file_exists "gitops dev values exist" "$gitops_chart_path/values.yaml"
assert_directory_exists "backstage workload chart exists" "$backstage_chart_path"
assert_file_exists "backstage dev values exist" "$backstage_values_path"

appset=$(sed -n '1,$p' "$appset_path" 2>/dev/null || true)
rendered_appsets=$(helm template gitops-dev "$gitops_chart_path" \
  --set "repoURL=https://github.com/${TEST_REPO_SLUG}.git" \
  --set "ghcrBase=${TEST_GHCR_BASE}" \
  --set targetRevision=main)

assert_contains "ApplicationSet apiVersion" "$appset" "apiVersion: argoproj.io/v1alpha1"
assert_contains "ApplicationSet kind" "$appset" "kind: ApplicationSet"
assert_contains "ApplicationSet name" "$appset" "name: workloads-dev"
assert_contains "ApplicationSet uses Go templates" "$appset" "goTemplate: true"
assert_contains "Git generator uses repository value" "$appset" "repoURL: {{ .Values.repoURL | quote }}"
assert_contains "Git generator tracks target revision value" "$appset" "revision: {{ .Values.targetRevision | quote }}"
assert_contains "Git generator scans workload charts" "$appset" "path: charts/workloads/*"
assert_contains "Application name uses directory basename" "$appset" 'name: '\''{{ "{{.path.basename}}" }}'\'''
assert_contains "Application has resources finalizer" "$appset" "resources-finalizer.argocd.argoproj.io"
assert_contains "Application source uses repository value" "$appset" "repoURL: {{ .Values.repoURL | quote }}"
assert_contains "Application source uses target revision value" "$appset" "targetRevision: {{ .Values.targetRevision | quote }}"
assert_contains "source uses workload chart path" "$appset" 'path: '\''{{ "{{.path.path}}" }}'\'''
assert_contains "source uses matching dev values file" "$appset" '/deploy/dev/{{ "{{.path.basename}}" }}.yaml'
assert_contains "source injects default image repository" "$appset" "repository: {{ printf \"%s/{{.path.basename}}\" .Values.ghcrBase | quote }}"
assert_contains "destination namespace uses basename" "$appset" 'namespace: '\''{{ "{{.path.basename}}" }}'\'''
assert_contains "sync-wave is zero" "$appset" 'argocd.argoproj.io/sync-wave: "0"'
assert_not_contains "CreateNamespace sync option is disabled (workload charts own their namespace)" "$appset" "CreateNamespace=true"
assert_contains "ServerSideApply sync option is enabled" "$appset" "ServerSideApply=true"
assert_contains "automated prune is enabled" "$appset" "prune: true"
assert_contains "automated self-heal is enabled" "$appset" "selfHeal: true"
assert_contains "rendered AppSet uses synthetic repository" "$rendered_appsets" "repoURL: \"https://github.com/test-owner/test-repo.git\""
assert_contains "rendered AppSet injects synthetic image base" "$rendered_appsets" "repository: \"ghcr.io/test-owner/test-repo/{{.path.basename}}\""
assert_not_contains "workloads AppSet has no synthetic literal slug" "$appset" "${TEST_REPO_SLUG}"

echo ""
echo "=== Backstage PVC prune tests ==="

output=$(helm template backstage "$backstage_chart_path" -f "$backstage_values_path" 2>&1)
assert_contains "Backstage Postgres PVC renders" "$output" "kind: PersistentVolumeClaim"
assert_contains "Backstage Postgres PVC disables ArgoCD prune" "$output" "argocd.argoproj.io/sync-options: Prune=false"

report_results "Workloads ApplicationSet"
