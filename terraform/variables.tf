variable "cluster_name" {
  description = "Name of the KinD cluster"
  type        = string
  default     = "backstage"
}

variable "github_owner" {
  description = "GitHub account or organization that owns this fork."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]*$", var.github_owner))
    error_message = "github_owner must be a GitHub owner name, not a URL, path, empty string, or slash-containing value."
  }
}

variable "github_repo" {
  description = "GitHub repository name for this fork."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", var.github_repo))
    error_message = "github_repo must be a GitHub repository name, not a URL, path, empty string, or slash-containing value."
  }
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
