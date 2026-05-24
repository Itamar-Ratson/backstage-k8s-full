#!/usr/bin/env bash
set -euo pipefail

CONTEXT="${CONTEXT:-kind-backstage}"
EXPECTED_LB_IP="${EXPECTED_LB_IP:-172.18.0.250}"
SERVICE_NAMESPACE="${SERVICE_NAMESPACE:-envoy-gateway-system}"
SERVICE_SELECTOR="${SERVICE_SELECTOR:-gateway.envoyproxy.io/owning-gateway-namespace=gateway,gateway.envoyproxy.io/owning-gateway-name=edge-gateway}"
BACKSTAGE_MARKER="${BACKSTAGE_MARKER:-<title>}"
ARGOCD_MARKER="${ARGOCD_MARKER:-<title>Argo CD</title>}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

contains_marker() {
  local label="$1" body="$2" marker="$3"
  if ! grep -qF -- "$marker" <<<"$body"; then
    fail "$label did not contain marker: $marker"
  fi
}

service_name=$(
  kubectl --context "$CONTEXT" -n "$SERVICE_NAMESPACE" get svc \
    -l "$SERVICE_SELECTOR" \
    -o jsonpath='{.items[0].metadata.name}'
)

[ -n "$service_name" ] || fail "Envoy data plane Service was not found"

external_ip=$(
  kubectl --context "$CONTEXT" -n "$SERVICE_NAMESPACE" get svc "$service_name" \
    -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
)

if [ "$external_ip" != "$EXPECTED_LB_IP" ]; then
  kubectl --context "$CONTEXT" -n "$SERVICE_NAMESPACE" get svc "$service_name" -o wide
  fail "EXTERNAL-IP for $service_name was $external_ip, expected $EXPECTED_LB_IP"
fi

echo "PASS: EXTERNAL-IP equals $EXPECTED_LB_IP"

direct_body=$(
  curl -fsS --retry 10 --retry-delay 3 --retry-connrefused --retry-all-errors \
    -H "Host: backstage.localtest.me" \
    "http://${EXPECTED_LB_IP}/"
)
contains_marker "Direct LB IP curl" "$direct_body" "$BACKSTAGE_MARKER"
echo "PASS: direct LB IP reaches Backstage through the cluster"

backstage_body=$(
  curl -fsS --retry 10 --retry-delay 3 --retry-connrefused --retry-all-errors \
    "http://backstage.localtest.me/"
)
contains_marker "Backstage localtest.me curl" "$backstage_body" "$BACKSTAGE_MARKER"
echo "PASS: backstage.localtest.me reaches Backstage through nginx"

argocd_body=$(
  curl -fsS --retry 10 --retry-delay 3 --retry-connrefused --retry-all-errors \
    "http://argocd.localtest.me/"
)
contains_marker "ArgoCD localtest.me curl" "$argocd_body" "$ARGOCD_MARKER"
echo "PASS: argocd.localtest.me reaches ArgoCD through nginx"
