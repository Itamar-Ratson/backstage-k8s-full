# ADR-0008: Git-Derived Owner and Repo

## Status

Accepted

References [ADR-0007](0007-derived-platform-admin-identity.md) without superseding it. ADR-0007's decision that the platform admin identity is derived by the Backstage chart from a single value remains in force; only the upstream source of that value changes.

## Context

ADR-0007 replaced the committed maintainer admin identity with a derived platform admin identity, but the Terraform bootstrap path still required operators to supply `github_owner` and `github_repo` through interactive prompts or `terraform.tfvars`.

Those values already exist in a normal checkout as `git remote get-url origin`. Requiring an operator to retype them makes fresh fork bootstrap noisier and creates a typo surface that can affect the GitOps repository URL, GHCR image base, and derived admin identity.

## Decision

Terraform sources the GitHub owner and repository name from the local working tree's `origin` remote instead of from input variables.

A `data "external"` block invokes a versioned shell script that runs `git remote get-url origin` and emits the parsed owner and repo as JSON. The `github_owner` and `github_repo` Terraform variables are deleted entirely. There is no override path through defaults, `terraform.tfvars`, `-var`, or environment-specific fallbacks.

The script is the validation boundary. It fails during `terraform plan` when Terraform is not run from a git working tree, when the checkout has no `origin` remote, when `origin` is not a `github.com` URL, or when the URL cannot be parsed into an owner and repository.

## Consequences

`terraform apply` from a fresh GitHub clone can run without prompting for owner or repository values. Forks use their own owner and repository automatically because those values come from the checkout's remote.

Terraform bootstrap now requires a git working tree with a parseable `github.com` `origin` remote. Missing remotes, non-GitHub remotes, and malformed GitHub URLs fail before deployment begins instead of surfacing later through incorrect GitOps, GHCR, or RBAC configuration.

ADR-0007's chart behavior for an empty `rbac.adminUser` remains valid for non-Terraform chart consumers, but that branch is unreachable from this repository's Terraform deploy path because strict remote discovery fails before apply can render an empty derived admin identity.
