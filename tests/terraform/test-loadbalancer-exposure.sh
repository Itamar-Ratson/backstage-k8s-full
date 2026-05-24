#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=../charts/helpers.sh
source "$(dirname "$0")/../charts/helpers.sh"

echo "=== Terraform LoadBalancer exposure tests ==="

terraform_config=$(find terraform -name '*.tf' -type f -print0 | xargs -0 sed -n '1,$p')
tfvars_example=$(sed -n '1,$p' terraform/terraform.tfvars.example 2>/dev/null || true)
cluster_config=$(sed -n '1,$p' terraform/cluster.tf 2>/dev/null || true)
gitignore=$(sed -n '1,$p' .gitignore 2>/dev/null || true)
smoke_test=$(sed -n '1,$p' tests/cluster/test-loadbalancer.sh 2>/dev/null || true)

assert_contains "docker provider is declared" "$terraform_config" 'source  = "kreuzwerker/docker"'
assert_contains "docker provider is configured" "$terraform_config" 'provider "docker"'
assert_contains "envoy_lb_ip variable exists" "$terraform_config" 'variable "envoy_lb_ip"'
assert_contains "envoy_lb_ip default is pinned" "$terraform_config" 'default     = "172.18.0.250"'
assert_contains "tfvars example documents envoy_lb_ip" "$tfvars_example" 'envoy_lb_ip = "172.18.0.250"'

assert_not_contains "KinD extra port mappings removed" "$cluster_config" "extra_port_mappings"
assert_not_contains "KinD host port 8080 removed" "$cluster_config" "host_port      = 8080"

assert_contains "cloud-provider-kind image resource exists" "$terraform_config" 'resource "docker_image" "cloud_provider_kind"'
assert_contains "cloud-provider-kind image is pinned" "$terraform_config" 'registry.k8s.io/cloud-provider-kind/cloud-controller-manager:v0.10.0'
assert_contains "cloud-provider-kind container exists" "$terraform_config" 'resource "docker_container" "cloud_provider_kind"'
assert_contains "cloud-provider-kind uses host network" "$terraform_config" 'network_mode = "host"'
assert_contains "cloud-provider-kind mounts docker socket" "$terraform_config" 'host_path      = "/var/run/docker.sock"'
assert_contains "cloud-provider-kind restarts unless stopped" "$terraform_config" 'restart      = "unless-stopped"'
assert_not_contains "cloud-provider-kind port mapping flag is not used" "$terraform_config" "--enable-lb-port-mapping"

assert_contains "nginx image resource exists" "$terraform_config" 'resource "docker_image" "nginx_lb_proxy"'
assert_contains "nginx image is pinned" "$terraform_config" 'nginx:1.27-alpine'
assert_contains "nginx container exists" "$terraform_config" 'resource "docker_container" "nginx_lb_proxy"'
assert_contains "nginx uses host network" "$terraform_config" 'network_mode = "host"'
assert_contains "nginx config is mounted at default.conf" "$terraform_config" 'container_path = "/etc/nginx/conf.d/default.conf"'
assert_contains "nginx config mount is read only" "$terraform_config" 'read_only      = true'
assert_contains "nginx listens on IPv4" "$terraform_config" "listen 80;"
assert_contains "nginx listens on IPv6" "$terraform_config" "listen [::]:80;"
assert_contains "nginx forwards to envoy_lb_ip" "$terraform_config" 'proxy_pass http://${var.envoy_lb_ip}:80;'
assert_contains "nginx preserves Host header" "$terraform_config" 'proxy_set_header Host $host;'
assert_contains "generated nginx config is gitignored" "$gitignore" "terraform/.generated/"

assert_file_exists "LoadBalancer smoke test exists" "tests/cluster/test-loadbalancer.sh"
assert_contains "smoke test checks EXTERNAL-IP equality" "$smoke_test" "EXTERNAL-IP"
assert_contains "smoke test curls direct LB IP" "$smoke_test" 'http://${EXPECTED_LB_IP}/'
assert_contains "smoke test curls Backstage localtest.me" "$smoke_test" "http://backstage.localtest.me/"
assert_contains "smoke test curls ArgoCD localtest.me" "$smoke_test" "http://argocd.localtest.me/"

if [ -x tests/cluster/test-loadbalancer.sh ]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "FAIL: LoadBalancer smoke test is executable"
fi

report_results "Terraform LoadBalancer exposure"
