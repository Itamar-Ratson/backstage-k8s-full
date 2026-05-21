locals {
  root_application = yamldecode(file("${path.module}/bootstrap/root-app.yaml"))
}
