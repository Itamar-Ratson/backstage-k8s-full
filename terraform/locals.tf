locals {
  root_application = yamldecode(file("${path.module}/bootstrap/root-app.yaml"))

  generated_dir             = abspath("${path.module}/.generated")
  nginx_lb_proxy_config     = "${local.generated_dir}/nginx-lb-proxy.conf"
  nginx_lb_proxy_config_raw = <<-EOT
    server {
      listen 80;
      listen [::]:80;
      location / {
        proxy_set_header Host $host;
        proxy_pass http://${var.envoy_lb_ip}:80;
      }
    }
  EOT
}
