variable "cluster_name" {
  description = "Name of the KinD cluster"
  type        = string
  default     = "backstage"
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
