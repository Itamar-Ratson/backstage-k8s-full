variable "cluster_name" {
  description = "Name of the KinD cluster"
  type        = string
  default     = "backstage"
}

variable "gitops_repo_url" {
  description = "Git repository URL ArgoCD uses for the root Application."
  type        = string
  default     = "https://github.com/Itamar-Ratson/backstage-k8s-full.git"
}

variable "envoy_lb_ip" {
  description = "Static LoadBalancer IP assigned to the Envoy Gateway data plane Service on the KinD docker bridge."
  type        = string
  default     = "172.18.0.250"
}

variable "APP_ID" {
  description = "GitHub App ID used by Backstage."
  type        = string
  sensitive   = true
}

variable "CLIENT_ID" {
  description = "GitHub App OAuth client ID used by Backstage sign-in."
  type        = string
  sensitive   = true
}

variable "CLIENT_SECRET" {
  description = "GitHub App OAuth client secret used by Backstage sign-in."
  type        = string
  sensitive   = true
}

variable "PRIVATE_KEY" {
  description = "GitHub App private key PEM used to mint installation tokens."
  type        = string
  sensitive   = true
}
